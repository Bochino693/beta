class_name Personagem
extends Node3D

## UM PERSONAGEM (Bob, o cachorrinho, ou Mia, a gatinha): modelo articulado
## + animação por poses + rosto com expressões + piscar + olhar para a bola
## + rabinho que abana + brilhos de festa + bola na mão (solta no momento
## certo do arremesso).

signal soltou_bola(posicao: Vector3)
signal som(nome: String)
signal animacao_terminou(nome: String)

const EXPRESSOES := ["feliz", "piscando", "empolgado", "triste", "concentrado", "surpreso", "risada", "piscadinha"]
const JUNTAS := ["corpo", "cabeca", "braco_e", "antebraco_e", "braco_d", "antebraco_d", "coxa_e", "canela_e", "coxa_d", "canela_d"]
const ALTURA_QUADRIL := 0.40

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
	bola_mao.position = Vector3(-0.034, -0.27, 0.05)
	bola_mao.visible = false
	# sombra redonda
	_sombra = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.75, 0.75)
	q.orientation = PlaneMesh.FACE_Y
	_sombra.mesh = q
	_sombra.material_override = Materiais.sombra_blob(0.5)
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
	# respiração
	var resp := sin(_tempo * 2.4) * 0.006
	var altura: float = pose.get("altura", 0.0) + resp
	var voo: float = pose.get("voo", 0.0)
	var frente: float = pose.get("frente", 0.0)
	var giro: float = pose.get("giro", 0.0)
	for j in JUNTAS:
		var no: Node3D = juntas[j]
		var r: Vector3 = pose.get(j, Vector3.ZERO)
		if j.begins_with("coxa"):
			r.x -= corpo_rot.x   # pernas em relação ao chão
		if j == "cabeca":
			r += Vector3(_olhar.y, _olhar.x, 0)
		no.rotation_degrees = r
	(juntas["corpo"] as Node3D).position = _pos_repouso["corpo"] + Vector3(0, altura, 0)
	# deslocamento da corrida (para a frente do personagem) e voo
	var frente_mundo := base.basis.z.normalized() * frente
	position = base.origin + frente_mundo + Vector3(0, voo, 0)
	rotation.y = base.basis.get_euler().y + deg_to_rad(giro)
	# sombra fica no chão, menor quando voa
	_sombra.global_position = Vector3(global_position.x, 0.006, global_position.z)
	_sombra.global_rotation = Vector3.ZERO
	var esc: float = clamp(1.0 - voo * 0.6, 0.35, 1.0)
	_sombra.scale = Vector3(esc, 1, esc)
	# olhar
	var alvo := Vector2.ZERO
	if olhar_alvo != null:
		var local := (juntas["corpo"] as Node3D).global_transform.affine_inverse() * (olhar_alvo as Vector3)
		var yaw := rad_to_deg(atan2(local.x, local.z))
		var pitch := -rad_to_deg(atan2(local.y - 0.6, Vector2(local.x, local.z).length()))
		alvo = Vector2(clamp(yaw, -55.0, 55.0), clamp(pitch, -25.0, 30.0))
	_olhar = _olhar.lerp(alvo, min(1.0, delta * 6.0))
	# rabinho abanando (mais rápido quando está feliz)
	if _rabo:
		var vel := 7.0 + _alegria * 9.0
		_rabo.rotation = Vector3(sin(_tempo * vel * 0.5) * 0.12, sin(_tempo * vel) * (0.35 + _alegria * 0.35), 0)


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
	rotation = Vector3(0, deg_to_rad(direcao_y), 0)
	base = transform


## Brilho de destaque (personagem da vez fica "aceso").
func destaque(valor: float) -> void:
	for m in _mats:
		m.set_shader_parameter("flash", valor)


## Onde a mão direita fica no meio do arremesso (para a câmera mirar).
func posicao_mao() -> Vector3:
	return bola_mao.global_position
