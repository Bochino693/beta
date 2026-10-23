class_name Bola
extends RigidBody

## A BOLA: corpo físico, textura do personagem (patinhas do Bob,
## estrelas da Mia), rastro de arco-íris no chão e brilhinhos. Com 2 ou
## mais strikes seguidos ela vira BOLA DE FOGO (rastro e chamas).

signal bateu(corpo, velocidade)
## entrou na caçapa das bolas (no fundo do fosso)
signal recolhida

const RAIO := 0.14
## pesada como uma bola de verdade perto dos pinos (9 kg x 1,5 kg): leve
## demais, ela era jogada para o lado na batida (até 66 cm no fim da pista)
const MASSA := 9.0
## FIRMEZA NA LINHA: nos pinos, a cada passo (1/60 s) a bola volta 10%
## para a direção em que chegou neles — ela atravessa os pinos firme, sem
## ser rebatida para a canaleta. Com a massa: desvio médio de 16 para 8 cm
## e o pior de 66 para 25 cm (tools/testes/calibrar.gd --linha: desvio=)
const FIRMEZA := 0.1
## NO FOSSO (_comecar_fosso): a velocidade até a caçapa e onde o caminho
## termina (já dentro do túnel)
const VEL_FOSSO_MIN := 3.2
const VEL_FOSSO_MAX := 7.0
const Z_DENTRO := Medidas.Z_FUNDO - 0.4
const GRAVIDADE := 9.8
const FOGO := [Color("#FFF3B0"), Color("#FFD43B"), Color("#FF9F2E"), Color("#FF5A1E"), Color("#E0301E")]

var malha: MeshInstance
var _sombra: MeshInstance
var _rastro: ImmediateGeometry
var _pontos: Array = []
var _brilhos: CPUParticles
var _chamas: CPUParticles
var _fogo := false
var _grad_arco: Gradient
var _grad_fogo: Gradient
var curva := 0.0              # força lateral (efeito "gancho")
var rolando := false
## no replay a bola só é "posta" nos lugares gravados (sem física)
var em_replay := false
var _mat: ShaderMaterial
## no fosso a bola segue um caminho até a caçapa (_comecar_fosso): desde
## quando (s), de onde, a faixa (x) entre os pinos caídos e a velocidade
var _guiada := false
var _g_t := 0.0
var _g_de := Vector3.ZERO
var _g_x := 0.0
var _g_vel := 0.0
var _g_vy := 0.0
## caiu na canaleta nesta jogada (dali ela não volta para a pista)
var _na_canaleta := false
## já chegou nos pinos nesta jogada (dali ela não volta para quem joga)
var _nos_pinos := false
## a direção (x por z) em que ela chegou nos pinos (FIRMEZA)
var _direcao_x := 0.0


static func material(nome: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = Materiais.shader("res://shaders/bola.shader")
	m.set_shader_param("textura", Materiais.textura("bola_" + nome))
	# sem contorno na OpenGL ES 2 (desenharia a bola 2 vezes)
	return Materiais.registrar(m)


func _init() -> void:
	mass = MASSA
	continuous_cd = true
	contact_monitor = true
	contacts_reported = 6
	can_sleep = false
	collision_layer = Medidas.CAMADA_BOLA
	collision_mask = Medidas.CAMADA_MUNDO | Medidas.CAMADA_PINOS | Medidas.CAMADA_PISO_BOLA
	# atrito 0,12 e quique 0,12 do Godot 4, na conta da Bullet (Medidas)
	var pm := PhysicsMaterial.new()
	pm.friction = Medidas.ATRITO_BOLA
	pm.bounce = Medidas.QUIQUE_BOLA
	physics_material_override = pm
	var cs := CollisionShape.new()
	var sh := SphereShape.new()
	sh.radius = RAIO
	cs.shape = sh
	add_child(cs)
	malha = MeshInstance.new()
	var esfera := SphereMesh.new()
	esfera.radius = RAIO
	esfera.height = RAIO * 2
	esfera.radial_segments = 32
	esfera.rings = 16
	malha.mesh = esfera
	add_child(malha)
	_sombra = MeshInstance.new()
	# Godot 3: a QuadMesh só olha para Z; a PlaneMesh já é deitada
	var q := PlaneMesh.new()
	q.size = Vector2(0.42, 0.42)
	_sombra.mesh = q
	_sombra.material_override = Materiais.sombra_blob(0.6)
	_sombra.set_as_toplevel(true)
	add_child(_sombra)
	# rastro: no Godot 3 é a ImmediateGeometry (desenho refeito a cada quadro)
	_rastro = ImmediateGeometry.new()
	_rastro.set_as_toplevel(true)
	var mr := SpatialMaterial.new()
	mr.flags_unshaded = true
	mr.vertex_color_use_as_albedo = true
	mr.flags_transparent = true
	mr.params_blend_mode = SpatialMaterial.BLEND_MODE_ADD
	mr.params_cull_mode = SpatialMaterial.CULL_DISABLED
	mr.params_depth_draw_mode = SpatialMaterial.DEPTH_DRAW_DISABLED
	_rastro.material_override = mr
	_rastro.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	add_child(_rastro)
	_brilhos = CPUParticles.new()
	_brilhos.amount = 40
	_brilhos.lifetime = 0.7
	_brilhos.emitting = false
	_brilhos.local_coords = false
	_brilhos.emission_shape = CPUParticles.EMISSION_SHAPE_SPHERE
	_brilhos.emission_sphere_radius = RAIO
	_brilhos.direction = Vector3(0, 1, 0)
	_brilhos.spread = 70.0
	# Godot 3: valor máximo + quanto ele varia (0,3..0,9 / 0,5..1,0)
	_brilhos.initial_velocity = 0.9
	_brilhos.initial_velocity_random = 0.67
	_brilhos.gravity = Vector3(0, -0.6, 0)
	_brilhos.scale_amount = 1.0
	_brilhos.scale_amount_random = 0.5
	var curva_esc := Curve.new()
	curva_esc.add_point(Vector2(0, 1))
	curva_esc.add_point(Vector2(1, 0))
	_brilhos.scale_amount_curve = curva_esc
	_brilhos.color_initial_ramp = _arco_iris()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.09, 0.09)
	qm.material = Materiais.particula("faisca")
	_brilhos.mesh = qm
	add_child(_brilhos)
	_chamas = CPUParticles.new()
	_chamas.amount = 46
	_chamas.lifetime = 0.45
	_chamas.emitting = false
	_chamas.local_coords = false
	_chamas.emission_shape = CPUParticles.EMISSION_SHAPE_SPHERE
	_chamas.emission_sphere_radius = RAIO * 0.8
	_chamas.direction = Vector3(0, 1, 0)
	_chamas.spread = 25.0
	_chamas.initial_velocity = 1.4
	_chamas.initial_velocity_random = 0.57
	_chamas.gravity = Vector3(0, 1.5, 0)
	_chamas.scale_amount = 1.3
	_chamas.scale_amount_random = 0.46
	var ce := Curve.new()
	ce.add_point(Vector2(0, 0.6))
	ce.add_point(Vector2(0.3, 1.0))
	ce.add_point(Vector2(1, 0.0))
	_chamas.scale_amount_curve = ce
	var gc := Gradient.new()
	gc.offsets = PoolRealArray([0.0, 0.35, 1.0])
	gc.colors = PoolColorArray([Color(1.0, 0.95, 0.6, 1.0), Color(1.0, 0.55, 0.12, 0.9), Color(0.9, 0.15, 0.05, 0.0)])
	_chamas.color_ramp = gc
	var qc := QuadMesh.new()
	qc.size = Vector2(0.2, 0.2)
	qc.material = Materiais.particula("fumaca", true)
	_chamas.mesh = qc
	add_child(_chamas)
	_grad_arco = _arco_iris()
	_grad_fogo = Gradient.new()
	_grad_fogo.offsets = PoolRealArray([0.0, 0.25, 0.5, 0.75, 1.0])
	_grad_fogo.colors = PoolColorArray(FOGO)
	connect("body_entered", self, "_ao_bater")
	# a bola anda pela física: aparece interpolada entre os passos (lisa em
	# qualquer monitor); sombra, rastro e brilhos são postos a cada quadro
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	for n in [_sombra, _rastro, _brilhos, _chamas]:
		(n as Node).physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _ready() -> void:
	get_global_transform_interpolated()


static func _arco_iris() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color("#FF4B5C"))
	g.set_color(1, Color("#2E7BFF"))
	g.add_point(0.2, Color("#FF9F2E"))
	g.add_point(0.4, Color("#FFE14D"))
	g.add_point(0.6, Color("#5ED16A"))
	g.add_point(0.8, Color("#4FC3F7"))
	return g


func vestir(nome: String) -> void:
	_mat = material(nome)
	malha.material_override = _mat


func lancar(origem: Vector3, velocidade: Vector3, efeito := 0.0) -> void:
	_guiada = false
	_colidir(true)
	mode = RigidBody.MODE_RIGID
	visible = true
	global_translation = origem
	rotation = Vector3.ZERO
	linear_velocity = velocidade
	angular_velocity = Vector3.UP.cross(velocidade) / RAIO
	curva = efeito
	rolando = true
	em_replay = false
	_na_canaleta = false
	_nos_pinos = false
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	reset_physics_interpolation()
	_pontos.clear()
	replay_ritmo(1.0)
	_brilhos.emitting = true
	_chamas.emitting = _fogo


func guardar() -> void:
	rolando = false
	em_replay = false
	_guiada = false
	_colidir(true)
	_na_canaleta = false
	_nos_pinos = false
	mode = RigidBody.MODE_STATIC
	visible = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_translation = Vector3(0, -5, 20)
	reset_physics_interpolation()
	_pontos.clear()
	_rastro.clear()
	_brilhos.emitting = false
	_chamas.emitting = false


## ENSAIO GERAL da preparação (principal.ensaio): a bola parada em `pos`,
## com o rastro, os brilhinhos e as chamas — só para a placa de vídeo
## preparar esses desenhos. guardar() desfaz.
func ensaio(pos: Vector3) -> void:
	visible = true
	global_translation = pos
	reset_physics_interpolation()
	_pontos.clear()
	for i in 6:
		marcar_rastro(pos + Vector3(0, 0, 0.25 * i))
	_brilhos.emitting = true
	_chamas.emitting = _fogo


## Bola de fogo (sequência de strikes): rastro de fogo e chamas.
func fogo(ligar: bool) -> void:
	_fogo = ligar
	_brilhos.color_initial_ramp = _grad_fogo if ligar else _grad_arco
	if not ligar:
		_chamas.emitting = false


func _physics_process(delta: float) -> void:
	if not rolando or em_replay:
		return
	if _guiada:
		_andar_no_fosso(delta)
		return
	var p := global_translation
	# Godot 3: add_central_force fica valendo para sempre; a força de UM
	# passo (o apply_central_force do Godot 4) é um impulso de força x passo
	if curva != 0.0 and p.z > Medidas.Z_PINO1 + 1.4 and p.y > -0.02:
		apply_central_impulse(Vector3(curva * mass, 0, 0) * delta)
	# NA CANALETA a bola fica na canaleta. Ela é mais larga que a calha
	# (raio 0,14 x 0,125) e corre apoiada nos dois lábios: um empurrãozinho de
	# lado (a quina da parede do fundo, um pino caído) a jogava de volta na
	# pista — bola de canaleta derrubando pinos. Caiu na canaleta, o lado da
	# pista fica fechado para ela; e devagar (encostada em pinos caídos) a
	# calha a leva até o fosso, como a de verdade.
	var lado: float = abs(p.x)
	if not _na_canaleta and p.z > Medidas.Z_FIM_DECK and lado > Medidas.MEIA_LARGURA + 0.03 and p.y < RAIO * 0.8:
		_na_canaleta = true
	if _na_canaleta and p.z > Medidas.Z_FIM_DECK - 0.05:
		var meio := Medidas.MEIA_LARGURA + Medidas.CANALETA * 0.5
		if lado < meio and linear_velocity.x * sign(p.x) < 0.0:
			apply_central_impulse(Vector3(-linear_velocity.x * mass, 0, 0))
		if linear_velocity.z > -1.2:
			apply_central_impulse(Vector3(0, 0, -2.5) * mass * delta)
	# NO FIM DA PISTA (depois do pino 1), parando no meio dos pinos caídos:
	# a bola é levada até o fosso (num boliche ela quase nunca para ali;
	# parada, a máquina de pinos teria que trabalhar com ela na mesa).
	elif p.z < Medidas.Z_PINO1 - 0.3 and p.z > Medidas.Z_FIM_DECK and p.y > -0.02 and linear_velocity.length() < 0.8:
		apply_central_impulse(Vector3(0, 0, -3.0) * mass * delta)
	# DEPOIS DE CHEGAR NOS PINOS a bola não volta na direção de quem joga: a
	# pista é lisa para ela (óleo) e um pino voltando da parede a empurrava
	# metros para trás — derrubando pinos na volta.
	if not _nos_pinos and p.z < Medidas.Z_PINO1 + 0.2:
		_nos_pinos = true
		_direcao_x = linear_velocity.x / min(linear_velocity.z, -0.5)
	if _nos_pinos and linear_velocity.z > 0.0:
		apply_central_impulse(Vector3(0, 0, -linear_velocity.z * mass))
	elif _nos_pinos and not _na_canaleta and p.y > -0.02:
		var vx_linha := _direcao_x * linear_velocity.z
		apply_central_impulse(Vector3((vx_linha - linear_velocity.x) * mass * FIRMEZA, 0, 0))
	# PASSOU DO FIM DA PISTA: daqui ela vai sozinha para a caçapa
	if p.z < Medidas.Z_FIM_DECK:
		_comecar_fosso(p)


## NO FOSSO a bola vai direto para a caçapa, SEM QUICAR: cai até o chão do
## fosso como a gravidade faria (sem voltar a subir) e rola por uma faixa
## entre os pinos caídos — a que tem mais espaço —, girando como quem rola,
## até entrar na boca da caçapa. Ali ela não bate em mais nada: no fosso a
## jogada já acabou (os pinos da pista não são mais alcançados) e, solta na
## física, ela quicava nos pinos caídos (até 80 cm), voltava e ficava presa
## no fosso em 1 de cada 4 jogadas (tools/testes/bola_fosso.gd). O replay
## repete o mesmo caminho (é gravado a cada passo, como o resto).
func _comecar_fosso(p: Vector3) -> void:
	_guiada = true
	_g_t = 0.0
	_g_de = p
	_g_vel = clamp(-linear_velocity.z, VEL_FOSSO_MIN, VEL_FOSSO_MAX)
	_g_vy = clamp(linear_velocity.y, -1.0, 1.5)
	_g_x = _faixa_livre(p)
	_colidir(false)
	mode = RigidBody.MODE_KINEMATIC


func _andar_no_fosso(delta: float) -> void:
	_g_t += delta
	var z := _g_de.z - _g_vel * _g_t
	var curso: float = max(_g_de.z - Z_DENTRO, 0.01)
	var s: float = clamp((_g_de.z - z) / curso, 0.0, 1.0)
	var x: float = lerp(_g_de.x, _g_x, smoothstep(0.0, 0.75, s))
	var y: float = max(_g_de.y + _g_vy * _g_t - 0.5 * GRAVIDADE * _g_t * _g_t, Medidas.Y_CHAO_FOSSO + RAIO)
	var novo := Vector3(x, y, z)
	var t := global_transform
	var chao := Vector3(novo.x - t.origin.x, 0.0, novo.z - t.origin.z)
	if chao.length() > 0.00001:
		# rola: gira em volta do eixo deitado, de lado para o caminho
		t.basis = (Basis(Vector3.UP.cross(chao.normalized()), chao.length() / RAIO) * t.basis).orthonormalized()
	t.origin = novo
	global_transform = t
	# entrou no túnel da caçapa: some e volta no retorno de bolas
	if z < Medidas.Z_FUNDO - 0.35:
		rolando = false
		_guiada = false
		_brilhos.emitting = false
		_chamas.emitting = false
		visible = false
		call_deferred("set_mode", RigidBody.MODE_STATIC)
		emit_signal("recolhida")


## A faixa (x na boca da caçapa) com mais espaço entre os pinos que estão no
## fosso ou chegando nele; no empate, a que menos desvia do caminho da bola.
func _faixa_livre(p: Vector3) -> float:
	var limite := Medidas.LARGURA_BOCA * 0.5 - RAIO - 0.06
	var reto: float = clamp(p.x, -limite, limite)
	var pontos := []
	for n in get_tree().get_nodes_in_group("pinos"):
		var pino := n as Spatial
		if pino == null or not pino.is_visible_in_tree():
			continue
		# 3 pontos ao longo do pino (base, meio, cabeça): deitado, ele é comprido
		var base: Vector3 = pino.global_transform.xform(Vector3(0, -0.17, 0))
		var eixo: Vector3 = pino.global_transform.basis.y.normalized()
		for k in 3:
			var q: Vector3 = base + eixo * (0.06 + 0.14 * k)
			if q.z < Medidas.Z_FIM_DECK + 0.3 and q.z > Medidas.Z_FUNDO - 0.1 and q.y < 0.7:
				pontos.append(q)
	if pontos.empty():
		return reto
	var curso: float = max(p.z - Z_DENTRO, 0.01)
	var melhor := reto
	var nota_melhor := -1000.0
	for i in 11:
		var xt: float = lerp(-limite, limite, i / 10.0)
		var folga := 1.0
		for q in pontos:
			var s: float = clamp((p.z - (q as Vector3).z) / curso, 0.0, 1.0)
			var xc: float = lerp(p.x, xt, smoothstep(0.0, 0.75, s))
			folga = min(folga, abs((q as Vector3).x - xc))
		var nota: float = min(folga, 0.5) - 0.12 * abs(xt - reto)
		if nota > nota_melhor:
			nota_melhor = nota
			melhor = xt
	return melhor


## Liga ou desliga as batidas da bola (no caminho do fosso ela não bate em nada).
func _colidir(sim: bool) -> void:
	collision_layer = Medidas.CAMADA_BOLA if sim else 0
	collision_mask = (Medidas.CAMADA_MUNDO | Medidas.CAMADA_PINOS | Medidas.CAMADA_PISO_BOLA) if sim else 0


func _process(_delta: float) -> void:
	if not visible:
		return
	# onde a bola APARECE neste quadro (entre dois passos da física)
	var g := Medidas.na_tela(self).origin
	var alt: float = clamp(1.0 - (g.y - RAIO) * 1.5, 0.3, 1.0)
	# a sombra é um adesivo reto: só no chão reto (pista, área de quem joga,
	# fundo do fosso). Indo para a canaleta ela some — dentro da calha
	# curva ela atravessaria a parede.
	if g.z > Medidas.Z_FIM_DECK and g.z < 0.12:
		alt *= clamp((Medidas.MEIA_LARGURA - abs(g.x)) / 0.2, 0.0, 1.0)
	_sombra.global_transform = Transform(Basis().scaled(Vector3(max(alt, 0.001), 1, max(alt, 0.001))),
		Vector3(g.x, max(g.y - RAIO, -0.3) + 0.008, g.z))
	if rolando:
		marcar_rastro(g)
	if (rolando or em_replay) and g.z < Medidas.Z_PINO1 + 0.4:
		_brilhos.emitting = false
		_chamas.emitting = false
	_desenhar_rastro()


## Mais um ponto do rastro de arco-íris (o replay chama nos mesmos
## instantes da jogada de verdade).
func marcar_rastro(p: Vector3) -> void:
	# o rastro é desenhado NA PISTA: saindo dela (canaleta, fosso) ele só
	# vai sumindo — nunca atravessa a calha nem as paredes
	if abs(p.x) > Medidas.MEIA_LARGURA - 0.03 or p.y - RAIO < -0.03 or p.z < Medidas.Z_FIM_DECK:
		if not _pontos.empty():
			_pontos.pop_back()
		return
	_pontos.push_front(Vector3(p.x, max(p.y - RAIO, 0.0) + 0.012, p.z))
	if _pontos.size() > 28:
		_pontos.pop_back()


## REPLAY: rastro recomeça e os brilhinhos voltam (em câmera lenta).
func replay(ligar: bool) -> void:
	em_replay = ligar
	# no replay quem move a bola é o jogo, quadro a quadro (sem interpolar)
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF if ligar else Node.PHYSICS_INTERPOLATION_MODE_ON
	if not ligar:
		reset_physics_interpolation()
	_pontos.clear()
	_rastro.clear()
	_brilhos.emitting = ligar
	_chamas.emitting = ligar and _fogo
	replay_ritmo(1.0)


## Os brilhinhos andam no ritmo do replay (0,45 = 45% da velocidade).
func replay_ritmo(vel: float) -> void:
	_brilhos.speed_scale = vel
	_chamas.speed_scale = vel


func _desenhar_rastro() -> void:
	_rastro.clear()
	if _pontos.size() < 2:
		return
	var g := _grad_fogo if _fogo else _grad_arco
	_rastro.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := _pontos.size()
	for i in n:
		var p: Vector3 = _pontos[i]
		var d: Vector3
		if i < n - 1:
			d = (p - _pontos[i + 1])
		else:
			d = (_pontos[i - 1] - p)
		d.y = 0.0
		if d.length() < 0.0001:
			d = Vector3(0, 0, -1)
		var lado := d.normalized().cross(Vector3.UP)
		var f := 1.0 - float(i) / float(n - 1)
		var w := RAIO * (1.2 if _fogo else 0.95) * (0.35 + 0.65 * f)
		# nunca passa da borda da pista
		w = clamp(min(w, Medidas.MEIA_LARGURA - abs(p.x)), 0.0, w)
		var c := g.interpolate(float(i) / float(n - 1) if _fogo else fposmod(float(i) / 10.0, 1.0))
		c.a = f * 0.75
		_rastro.set_color(c)
		_rastro.add_vertex(p + lado * w)
		_rastro.set_color(c)
		_rastro.add_vertex(p - lado * w)
	_rastro.end()


func velocidade() -> float:
	if not rolando:
		return 0.0
	return _g_vel if _guiada else linear_velocity.length()


func _ao_bater(corpo: Node) -> void:
	emit_signal("bateu", corpo, linear_velocity.length())


## O brilho na bola (aceso no strike / replay).
func acender(v: float) -> void:
	if _mat:
		_mat.set_shader_param("aceso", v)
