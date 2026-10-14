class_name Personagem
extends Node3D

## UM PERSONAGEM (Bob, o cachorrinho, ou Mia, a gatinha): modelo articulado
## + animação por poses + rosto com expressões + piscar + olhar para a bola
## + rabinho que abana + brilhos de festa + bola na mão (solta no momento
## certo do arremesso).
##
## Movimento com peso de verdade:
##   * IK de duas juntas nas pernas (quadril > joelho > tornozelo): o pé que
##     apoia fica TRAVADO no chão (não escorrega nem flutua) e o joelho dobra
##     sozinho quando o corpo abaixa; se o corpo anda/gira, o pé dá um
##     passinho para acompanhar; o quadril desce se o pé não alcançaria.
##   * Pé sempre de sola chata no chão; sombra de contato embaixo de cada pé.
##   * Pulos com arco de gravidade e "mola" (agacha na aterrissagem, estica
##     na subida).

signal soltou_bola(posicao: Vector3)
signal som(nome: String)
signal animacao_terminou(nome: String)

const EXPRESSOES := ["feliz", "piscando", "empolgado", "triste", "concentrado", "surpreso", "risada", "piscadinha"]
const JUNTAS := ["corpo", "cabeca", "braco_e", "antebraco_e", "braco_d", "antebraco_d",
	"coxa_e", "canela_e", "pe_e", "coxa_d", "canela_d", "pe_d"]
const PASSO_DUR := 0.17          # duração de um passinho automático (s)
const PASSO_ALTURA := 0.045      # quanto o pé sobe no passinho (m)
const DIST_PASSO := 0.13         # pé travado longe assim do lugar certo = dá um passo

var nome_modelo := "bob"
var modelo: Node3D
var juntas := {}
var _pos_repouso := {}
var _mat_cabeca: ShaderMaterial
var _mats: Array[ShaderMaterial] = []
var bola_mao: MeshInstance3D
var _sombra: MeshInstance3D
var _festa: CPUParticles3D
var _rabo: Node3D
var _alegria := 0.5           # abana mais rápido quando está feliz
# pernas (IK) e pés
var _torn_y := 0.078          # altura do tornozelo com o pé apoiado
var chao := 0.0               # altura do chão onde ele pisa (pódio da escolha)
var _l1 := {}                 # coxa (quadril -> joelho)
var _l2 := {}                 # canela (joelho -> tornozelo)
var _pes := {}                # lado -> {preso, pos, passo (0..1 ou -1), de, para}
var _sombras_pe := {}
var _modo_ik := "trava"       # "trava" (pé preso), "chao" (só não afunda), "livre"
# pulo e mola (agacha/estica)
var _voo_antes := 0.0
var _vel_voo := 0.0
var _mola := 0.0
var _mola_v := 0.0

var _clip := {}
var _nome_clip := ""
var _t := 0.0
var _de := {}
var _mistura := 1.0
var _dur_mistura := 0.2
var _eventos_feitos := {}
var _ultima_pose := {}
var base := Transform3D()      # onde a animação "começou" (a corrida parte daqui)
var giro_base := 0.0

var _expressao := "feliz"
var _piscar_em := 2.0
var _piscando := 0.0
var olhar_alvo = null          # Vector3 (mundo) ou null
var _olhar := Vector2.ZERO     # yaw, pitch atuais
var _tempo := 0.0
var brilho := 1.4


func montar(nome: String) -> void:
	nome_modelo = nome
	modelo = load("res://modelos/%s.scn" % nome).instantiate()
	add_child(modelo)
	var meta: Dictionary = modelo.get_meta("rosto", {})
	var rosto := Materiais.textura("rosto_" + nome)
	for j in JUNTAS:
		var no := modelo.find_child(j, true, false) as Node3D
		if no == null:
			continue
		juntas[j] = no
		_pos_repouso[j] = no.position
		var mi := no.get_node("malha") as MeshInstance3D
		var parametros := {"borda": 0.22, "cor_borda": Color(1.0, 0.92, 1.0), "brilho_luz": brilho, "faixa": 0.15, "luz_minima": 0.32}
		if j == "cabeca":
			parametros["usa_rosto"] = true
			parametros["rosto"] = rosto
			if meta.has("centro"):
				parametros["rosto_centro"] = Vector2(meta["centro"][0], meta["centro"][1])
				parametros["rosto_tamanho"] = Vector2(meta["tamanho"][0], meta["tamanho"][1])
		var m := Materiais.toon(true, 0.0032, parametros)
		mi.material_override = m
		# detalhe alto até de longe (orelhas e focinho não podem sumir)
		mi.lod_bias = 6.0
		_mats.append(m)
		if j == "cabeca":
			_mat_cabeca = m
	# bola na mão direita
	bola_mao = MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = Bola.RAIO
	esfera.height = Bola.RAIO * 2
	esfera.radial_segments = 32
	esfera.rings = 16
	bola_mao.mesh = esfera
	bola_mao.material_override = Bola.material(nome)
	var ante := juntas["antebraco_d"] as Node3D
	ante.add_child(bola_mao)
	var mao: Array = modelo.get_meta("mao_d", [-0.034, -0.15, 0.025])
	bola_mao.position = Vector3(mao[0], mao[1], mao[2]) + Vector3(0.0, -0.118, 0.028)
	bola_mao.visible = false
	# pernas: comprimentos e altura do tornozelo
	_torn_y = float(modelo.get_meta("tornozelo_y", 0.078))
	for lado in ["e", "d"]:
		if juntas.has("pe_" + lado):
			_l1[lado] = (_pos_repouso["canela_" + lado] as Vector3).length()
			_l2[lado] = (_pos_repouso["pe_" + lado] as Vector3).length()
		_pes[lado] = {"preso": false, "pos": Vector3.ZERO, "passo": -1.0, "de": Vector3.ZERO, "para": Vector3.ZERO}
		var sp := MeshInstance3D.new()
		var qp := QuadMesh.new()
		qp.size = Vector2(0.17, 0.24)
		qp.orientation = PlaneMesh.FACE_Y
		sp.mesh = qp
		sp.material_override = Materiais.sombra_blob(0.62)
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sp.top_level = true
		add_child(sp)
		_sombras_pe[lado] = sp
	# sombra redonda
	_sombra = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.75, 0.75)
	q.orientation = PlaneMesh.FACE_Y
	_sombra.mesh = q
	_sombra.material_override = Materiais.sombra_blob(0.38)
	_sombra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sombra)
	# rabinho (abana sozinho)
	_rabo = modelo.find_child("rabo", true, false) as Node3D
	if _rabo:
		var mr := _rabo.get_node("malha") as MeshInstance3D
		var m2 := Materiais.toon(true, 0.0032, {"borda": 0.22, "faixa": 0.15, "luz_minima": 0.32})
		mr.material_override = m2
		_mats.append(m2)
	# brilhos de festa (estrelinhas e faíscas subindo em volta) para as comemorações
	_festa = CPUParticles3D.new()
	_festa.amount = 36
	_festa.lifetime = 0.9
	_festa.local_coords = false
	_festa.emitting = false
	_festa.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_festa.emission_ring_axis = Vector3.UP
	_festa.emission_ring_radius = 0.42
	_festa.emission_ring_inner_radius = 0.25
	_festa.emission_ring_height = 0.1
	_festa.direction = Vector3.UP
	_festa.spread = 25.0
	_festa.initial_velocity_min = 1.0
	_festa.initial_velocity_max = 2.2
	_festa.gravity = Vector3(0, -1.5, 0)
	_festa.angular_velocity_min = -300
	_festa.angular_velocity_max = 300
	_festa.scale_amount_min = 0.6
	_festa.scale_amount_max = 1.2
	var curva := Curve.new()
	curva.add_point(Vector2(0, 1.0))
	curva.add_point(Vector2(1, 0.0))
	_festa.scale_amount_curve = curva
	_festa.color_initial_ramp = Bola._arco_iris()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.09, 0.09)
	qm.material = Materiais.particula("estrela", false)
	_festa.mesh = qm
	_festa.position = Vector3(0, 0.25, 0)
	add_child(_festa)
	tocar("parado")
	_piscar_em = randf_range(1.0, 3.0)


# ---------------------------------------------------------------- animação
## Troca a animação. `mistura`: segundos de transição suave.
func tocar(nome: String, mistura := 0.22, reiniciar := false) -> void:
	if nome == _nome_clip and not reiniciar:
		return
	_de = _ultima_pose.duplicate()
	_mistura = 0.0 if not _de.is_empty() else 1.0
	_dur_mistura = max(mistura, 0.001)
	_clip = Animacoes.pegar(nome)
	_nome_clip = nome
	_modo_ik = str(_clip.get("ik", "trava"))
	_t = 0.0
	_eventos_feitos.clear()
	# o quanto ele andou/girou na animação anterior vira o novo ponto de partida
	if modelo != null:
		base = Transform3D(Basis(Vector3.UP, rotation.y), Vector3(position.x, base.origin.y, position.z))
	_de["frente"] = 0.0
	_de["giro"] = 0.0


func animacao() -> String:
	return _nome_clip


func _amostra(t: float) -> Dictionary:
	var chaves: Array = _clip["chaves"]
	var n := chaves.size()
	if n == 1:
		return chaves[0][1]
	var i := 0
	while i < n - 2 and t >= float(chaves[i + 1][0]):
		i += 1
	var t0: float = chaves[i][0]
	var t1: float = chaves[i + 1][0]
	var u: float = clamp((t - t0) / max(t1 - t0, 0.0001), 0.0, 1.0)
	var a: Dictionary = chaves[i][1]
	var b: Dictionary = chaves[i + 1][1]
	var a0: Dictionary = chaves[max(i - 1, 0)][1]
	var b1: Dictionary = chaves[min(i + 2, n - 1)][1]
	var res := {}
	var nomes := {}
	for k in a:
		nomes[k] = true
	for k in b:
		nomes[k] = true
	for k in nomes:
		var zero = 0.0 if (k == "altura" or k == "frente" or k == "giro" or k == "voo") else Vector3.ZERO
		res[k] = _catmull(a0.get(k, zero), a.get(k, zero), b.get(k, zero), b1.get(k, zero), u)
	return res


static func _catmull(p0, p1, p2, p3, t: float):
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func _process(delta: float) -> void:
	if modelo == null:
		return
	_tempo = fposmod(_tempo + delta, 1000.0)
	var dur: float = _clip.get("dur", 1.0)
	var t_antes := _t
	_t += delta
	var loop: bool = _clip.get("loop", false)
	if loop:
		_t = fposmod(_t, dur)
	elif _t >= dur:
		_t = dur
		if t_antes < dur:
			animacao_terminou.emit.call_deferred(_nome_clip)
	_eventos(t_antes, _t, loop and _t < t_antes)
	var pose := _amostra(_t)
	if _mistura < 1.0:
		_mistura = min(1.0, _mistura + delta / _dur_mistura)
		var e := _mistura * _mistura * (3.0 - 2.0 * _mistura)
		var mix := {}
		for k in pose:
			var zero = 0.0 if pose[k] is float else Vector3.ZERO
			mix[k] = lerp(_de.get(k, zero), pose[k], e)
		for k in _de:
			if not pose.has(k):
				var zero = 0.0 if _de[k] is float else Vector3.ZERO
				mix[k] = lerp(_de[k], zero, e)
		pose = mix
	_ultima_pose = pose
	_aplicar(pose, delta)
	_rosto(delta)


func _eventos(de: float, ate: float, deu_volta: bool) -> void:
	var evs: Array = _clip.get("eventos", [])
	for i in evs.size():
		var ev: Array = evs[i]
		var t: float = ev[0]
		var passou := (t > de and t <= ate) or (de == 0.0 and t == 0.0 and not _eventos_feitos.has(i)) or (deu_volta and (t > de or t <= ate))
		if passou and not _eventos_feitos.has(i):
			_eventos_feitos[i] = true
			match ev[1]:
				"soltar":
					if bola_mao.visible:
						var p := bola_mao.global_position
						bola_mao.visible = false
						soltou_bola.emit(p)
				"jatos":
					jatos(bool(ev[2]))
				"expressao":
					expressao(str(ev[2]))
				"som":
					som.emit(str(ev[2]))
	if deu_volta:
		_eventos_feitos.clear()


func _aplicar(pose: Dictionary, delta: float) -> void:
	var corpo_rot: Vector3 = pose.get("corpo", Vector3.ZERO)
	# respiração (bem de leve)
	var resp := sin(_tempo * 2.4) * 0.004
	var altura: float = pose.get("altura", 0.0) + resp
	var quadril: Vector3 = pose.get("quadril", Vector3.ZERO)
	var voo: float = maxf(pose.get("voo", 0.0), 0.0) + _pulo(_t)
	var frente: float = pose.get("frente", 0.0)
	var giro: float = pose.get("giro", 0.0)
	for j in juntas:
		var no: Node3D = juntas[j]
		var r: Vector3 = pose.get(j, Vector3.ZERO)
		if j.begins_with("coxa"):
			r.x -= corpo_rot.x   # pernas em relação ao chão
		if j == "cabeca":
			r += Vector3(_olhar.y, _olhar.x, 0)
		# base nova a cada quadro (rotação pura, escala 1: nada acumula)
		no.basis = Basis.from_euler(r * (PI / 180.0))
	(juntas["corpo"] as Node3D).position = _pos_repouso["corpo"] + Vector3(quadril.x, altura, quadril.z)
	# deslocamento da corrida (para a frente do personagem) e voo
	var frente_mundo := base.basis.z.normalized() * frente
	position = base.origin + frente_mundo + Vector3(0, voo, 0)
	rotation.y = base.basis.get_euler().y + deg_to_rad(giro)
	_mola_pulo(voo, delta)
	if juntas.has("pe_e") and juntas.has("pe_d"):
		_ik_pernas(delta, voo)
	_sombras(voo)
	# olhar
	var alvo := Vector2.ZERO
	if olhar_alvo != null:
		var local := (juntas["corpo"] as Node3D).global_transform.affine_inverse() * (olhar_alvo as Vector3)
		var yaw := rad_to_deg(atan2(local.x, local.z))
		var pitch := -rad_to_deg(atan2(local.y - 0.55, Vector2(local.x, local.z).length()))
		alvo = Vector2(clamp(yaw, -55.0, 55.0), clamp(pitch, -25.0, 30.0))
	_olhar = _olhar.lerp(alvo, min(1.0, delta * 6.0))
	# rabinho abanando (mais rápido quando está feliz)
	if _rabo:
		var vel := 7.0 + _alegria * 9.0
		_rabo.rotation = Vector3(sin(_tempo * vel * 0.5) * 0.12, sin(_tempo * vel) * (0.35 + _alegria * 0.35), 0)


## Altura extra dos pulos do clipe: arco de gravidade h = 4H·u·(1-u).
func _pulo(t: float) -> float:
	var h := 0.0
	for p in _clip.get("pulos", []):
		var t0: float = p[0]
		var t1: float = p[1]
		if t > t0 and t < t1:
			var u := (t - t0) / (t1 - t0)
			h += 4.0 * float(p[2]) * u * (1.0 - u)
	return h


## Mola de agachar/esticar: estica subindo, amassa ao bater no chão.
func _mola_pulo(voo: float, delta: float) -> void:
	if delta <= 0.0:
		return
	var v := (voo - _voo_antes) / delta
	if _voo_antes > 0.02 and voo <= 0.02 and _vel_voo < -1.0:
		_mola_v -= clampf(-_vel_voo * 0.11, 0.0, 0.5)    # aterrissou: amassa
	if _voo_antes <= 0.02 and voo > 0.02:
		_mola_v += 0.35                                      # decolou: estica
	_vel_voo = v
	_voo_antes = voo
	var k := 260.0
	var amort := 16.0
	_mola_v += (-k * _mola - amort * _mola_v) * delta
	_mola += _mola_v * delta
	_mola = clampf(_mola, -0.12, 0.1)
	var sy := 1.0 + _mola
	var sxz := 1.0 / sqrt(maxf(sy, 0.5))
	modelo.scale = Vector3(sxz, sy, sxz)


## IK das pernas com pé travado no chão.
func _ik_pernas(delta: float, voo: float) -> void:
	var alvos := {}
	var ancora := {}
	var passando := false
	for lado in ["e", "d"]:
		var st: Dictionary = _pes[lado]
		if st["passo"] >= 0.0:
			passando = true
	var corpo := juntas["corpo"] as Node3D
	var ty := chao + _torn_y
	for lado in ["e", "d"]:
		var pe := juntas["pe_" + lado] as Node3D
		var st: Dictionary = _pes[lado]
		var fk := pe.global_position
		var altura_pe := fk.y - ty
		var livre := Vector3(fk.x, maxf(fk.y, ty), fk.z)
		var alvo := livre
		if _modo_ik != "trava" or voo > 0.01:
			st["preso"] = false
			st["passo"] = -1.0
		elif st["passo"] >= 0.0:
			# passinho em andamento: vai do lugar antigo ao novo, subindo um pouco
			st["passo"] = minf(1.0, float(st["passo"]) + delta / PASSO_DUR)
			var u: float = st["passo"]
			var para := Vector3(fk.x, ty, fk.z)
			var e := u * u * (3.0 - 2.0 * u)
			alvo = (st["de"] as Vector3).lerp(para, e) + Vector3(0, PASSO_ALTURA * 4.0 * u * (1.0 - u), 0)
			if u >= 1.0:
				st["passo"] = -1.0
				st["preso"] = true
				st["pos"] = para
		elif st["preso"]:
			var pos: Vector3 = st["pos"]
			var longe := Vector2(fk.x - pos.x, fk.z - pos.z).length()
			if altura_pe > 0.05:
				st["preso"] = false             # a perna levantou de propósito
			elif longe > DIST_PASSO and not passando:
				st["preso"] = false             # ficou para trás: um passinho
				st["passo"] = 0.0
				st["de"] = pos
				passando = true
				alvo = pos
			else:
				alvo = pos
		elif altura_pe < 0.02:
			st["preso"] = true
			st["pos"] = Vector3(fk.x, ty, fk.z)
			alvo = st["pos"]
		alvos[lado] = alvo
		ancora[lado] = st["preso"] or st["passo"] >= 0.0
	# o quadril desce se um pé apoiado não alcançaria o chão
	var descer := 0.0
	for lado in ["e", "d"]:
		if not ancora[lado]:
			continue
		var coxa := juntas["coxa_" + lado] as Node3D
		var q := coxa.global_position
		var alvo: Vector3 = alvos[lado]
		var lmax: float = (_l1[lado] + _l2[lado]) * 0.985
		var dv := q.y - alvo.y
		var dh := Vector2(q.x - alvo.x, q.z - alvo.z).length()
		if dh < lmax:
			var precisa := dv - sqrt(lmax * lmax - dh * dh)
			descer = maxf(descer, precisa)
	if descer > 0.0:
		corpo.position.y -= minf(descer, 0.12) / maxf(modelo.scale.y, 0.5)
	for lado in ["e", "d"]:
		_resolver_perna(lado, alvos[lado], ancora[lado])


func _resolver_perna(lado: String, alvo: Vector3, apoiado: bool) -> void:
	var coxa := juntas["coxa_" + lado] as Node3D
	var canela := juntas["canela_" + lado] as Node3D
	var pe := juntas["pe_" + lado] as Node3D
	var esc := modelo.scale.y
	var l1: float = _l1[lado] * esc
	var l2: float = _l2[lado] * esc
	var q := coxa.global_position
	var j_fk := canela.global_position
	var v := alvo - q
	var d := clampf(v.length(), absf(l1 - l2) + 0.001, l1 + l2 - 0.0008)
	var dir := v.normalized()
	var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(l1 * l1 - a * a, 0.0))
	# o joelho dobra para onde a pose mandou (e sempre para a frente)
	var frente := global_transform.basis.z.normalized()
	var polo := (j_fk - q) - dir * (j_fk - q).dot(dir) + frente * 0.02
	polo = polo - dir * polo.dot(dir)
	if polo.length() < 0.0001:
		polo = frente
	polo = polo.normalized()
	var j := q + dir * a + polo * h
	var de1 := (j_fk - q).normalized()
	var para1 := (j - q).normalized()
	if de1.dot(para1) < 0.99999:
		_girar_global(coxa, Quaternion(de1, para1))
	var a_agora := pe.global_position
	var de2 := (a_agora - j).normalized()
	var para2 := (q + dir * d - j).normalized()
	if de2.dot(para2) < 0.99999:
		_girar_global(canela, Quaternion(de2, para2))
	# pé de sola chata quando está no chão (ou perto dele)
	var peso := 1.0 if apoiado else clampf(1.0 - (alvo.y - chao - _torn_y) / 0.08, 0.0, 1.0)
	if peso > 0.0:
		var pai := canela.global_transform.basis.orthonormalized()
		var plano := pai.inverse() * Basis(Vector3.UP, global_rotation.y)
		var q_fk := pe.basis.orthonormalized().get_rotation_quaternion()
		var q_plano := plano.orthonormalized().get_rotation_quaternion()
		pe.basis = Basis(q_fk.slerp(q_plano, peso))


## Gira uma junta por uma rotação dada no espaço do mundo, mexendo só na
## rotação local dela (a escala continua 1, sem distorcer).
func _girar_global(no: Node3D, q: Quaternion) -> void:
	var pai := (no.get_parent() as Node3D).global_transform.basis.orthonormalized()
	var local := pai.inverse() * Basis(q) * pai
	no.basis = Basis(local.orthonormalized().get_rotation_quaternion()) * no.basis


func _sombras(voo: float) -> void:
	# sombra do corpo: fica no chão, menor quando voa
	_sombra.global_position = Vector3(global_position.x, chao + 0.006, global_position.z)
	_sombra.global_rotation = Vector3.ZERO
	var esc: float = clamp(1.0 - voo * 0.9, 0.35, 1.0)
	_sombra.scale = Vector3(esc, 1, esc)
	# sombra de contato de cada pé (some quando o pé sobe)
	for lado in _sombras_pe:
		var sp: MeshInstance3D = _sombras_pe[lado]
		if not juntas.has("pe_" + lado):
			sp.visible = false
			continue
		var pe := juntas["pe_" + lado] as Node3D
		var p := pe.global_position + pe.global_transform.basis.z.normalized() * 0.025
		var alto := maxf(0.0, p.y - chao - _torn_y)
		var e := clampf(1.0 - alto / 0.25, 0.25, 1.0)
		sp.global_position = Vector3(p.x, chao + 0.008, p.z)
		sp.global_rotation = Vector3(0, global_rotation.y, 0)
		sp.scale = Vector3(e, 1, e)


# ---------------------------------------------------------------- rosto
func expressao(nome: String) -> void:
	_expressao = nome
	_definir_celula(nome)
	_alegria = {"empolgado": 1.0, "risada": 1.0, "feliz": 0.7, "piscadinha": 0.8, "triste": 0.0, "concentrado": 0.25,
		"surpreso": 0.5}.get(nome, 0.5)


func _definir_celula(nome: String) -> void:
	var i := EXPRESSOES.find(nome)
	if i < 0:
		i = 0
	_mat_cabeca.set_shader_parameter("rosto_celula", Vector2(i % 4, i / 4))


func _rosto(delta: float) -> void:
	if _piscando > 0.0:
		_piscando -= delta
		if _piscando <= 0.0:
			_definir_celula(_expressao)
		return
	_piscar_em -= delta
	if _piscar_em <= 0.0:
		_piscar_em = randf_range(2.0, 4.5)
		if _expressao in ["feliz", "concentrado", "surpreso", "empolgado"]:
			_piscando = 0.13
			_definir_celula("piscando")


# ---------------------------------------------------------------- festa
## Estrelinhas subindo em volta (comemorações). O nome antigo "jatos" ficou
## nas animações e chamadas por compatibilidade.
func jatos(ligar: bool) -> void:
	_festa.emitting = ligar


func segurar_bola(sim: bool) -> void:
	bola_mao.visible = sim


## Coloca o personagem num lugar, olhando para `direcao_y` (graus).
func posicionar(pos: Vector3, direcao_y: float) -> void:
	position = pos
	chao = pos.y
	rotation = Vector3(0, deg_to_rad(direcao_y), 0)
	base = transform
	for lado in _pes:
		_pes[lado]["preso"] = false
		_pes[lado]["passo"] = -1.0


## Brilho de destaque (personagem da vez fica "aceso").
func destaque(valor: float) -> void:
	for m in _mats:
		m.set_shader_parameter("flash", valor)


## Onde a mão direita fica no meio do arremesso (para a câmera mirar).
func posicao_mao() -> Vector3:
	return bola_mao.global_position
