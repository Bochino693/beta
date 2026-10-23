class_name Pino
extends RigidBody

## UM PINO com carinha. Corpo físico com o centro de massa no lugar de um
## pino de verdade (ele tomba fácil), sons de batida e expressões:
## normal / piscando / medo (bola chegando) / tonto ou bravinho (caiu) /
## feliz (ficou de pé — às vezes até dá pulinhos de comemoração).
## Os pulinhos são animação (o pino fica preso, sem física) e terminam
## exatamente onde ele estava: na hora da jogada está tudo no lugar.
##
## Godot 3 (Bullet): o centro de massa é sempre a ORIGEM do corpo. Então a
## origem do pino fica no centro de massa (COM, 17 cm acima da base) e a
## malha e a colisão descem 17 cm. `lugar` continua sendo a BASE do pino;
## posicao_base() / colocar_em() fazem a conta.

signal bateu(pino, forca)

const EXPR := ["normal", "piscando", "medo", "tonto", "feliz", "surpreso", "triste", "bravo"]
const MASSA := 1.8
const COM := Vector3(0, 0.17, 0)

var numero := 1
var lugar := Vector3.ZERO
var malha: MeshInstance
var mat: ShaderMaterial
var removido := false
var _expr := "normal"
var _piscar := rand_range(1.0, 4.0)
var _piscando := 0.0
var _estrelas: Spatial
var _ultimo_som := 0
var _pulo: SceneTreeTween
var _base_pulo := Transform()
var _pulando := false
var _raiva: SceneTreeTween
var _escuro := 1.0      # 1 = normal; menor = caindo no poço do alçapão
## caiu no FOSSO (atrás do fim da pista, abaixo dela): dali não volta para a
## pista (Pinos segura) e assenta logo, sem ficar pulando
var no_fosso := false
## (na Bullet o amortecimento é a fração perdida por segundo, de 0 a 1:
## acima de 1 ela corta em 1 e zera o giro a cada passo)
const GIRO_AMORTECE := 0.6


func montar(n: int, pos: Vector3, malha_pino: Mesh, formas: Array, rosto: Texture, meta: Dictionary) -> void:
	numero = n
	lugar = pos
	name = "Pino%d" % n
	# (a bola, no fosso, procura os pinos para passar entre eles)
	add_to_group("pinos")
	mass = MASSA
	# pino de madeira: cai firme (mais gravidade só nele) e não fica rodando
	gravity_scale = Medidas.GRAVIDADE_PINO
	angular_damp = GIRO_AMORTECE
	can_sleep = true
	contact_monitor = true
	contacts_reported = 4
	collision_layer = Medidas.CAMADA_PINOS
	collision_mask = Medidas.CAMADA_MUNDO | Medidas.CAMADA_PINOS | Medidas.CAMADA_BOLA | Medidas.CAMADA_PISO_PINOS | Medidas.CAMADA_SO_PINOS
	# atrito 0,38 e quique 0,38 do Godot 4, na conta da Bullet (Medidas)
	var pm := PhysicsMaterial.new()
	pm.friction = Medidas.ATRITO_PINO
	pm.bounce = Medidas.QUIQUE_PINO
	physics_material_override = pm
	# a forma de colisão: os cilindros de `formas` (Pinos.formas_do_pino)
	for f in formas:
		var cs := CollisionShape.new()
		cs.shape = f[0]
		cs.translation = f[1] - COM
		add_child(cs)
	malha = MeshInstance.new()
	malha.mesh = malha_pino
	mat = Materiais.toon(true, 0.0026, {
		"usa_rosto": true, "rosto": rosto, "rosto_grade": Vector2(4, 2),
		"rosto_centro": Vector2(meta.get("centro", [0, 0.215])[0], meta.get("centro", [0, 0.215])[1]),
		"rosto_tamanho": Vector2(meta.get("tamanho", [0.15, 0.13])[0], meta.get("tamanho", [0.15, 0.13])[1]),
		"borda": 0.4, "cor_borda": Color(0.92, 0.96, 1.0),
	})
	malha.material_override = mat
	malha.translation = -COM
	add_child(malha)
	_estrelas = Spatial.new()
	_estrelas.set_as_toplevel(true)
	_estrelas.visible = false
	var me := SpatialMaterial.new()
	me.flags_unshaded = true
	me.albedo_texture = Materiais.textura("estrela")
	me.albedo_color = Color("#FFE14D")
	me.params_use_alpha_scissor = true
	me.params_alpha_scissor_threshold = 0.5
	# em pé no mundo (com a TV girada a câmera também gira: virada para ela
	# a estrelinha saía deitada)
	me.params_billboard_mode = SpatialMaterial.BILLBOARD_FIXED_Y
	for i in 3:
		var e := MeshInstance.new()
		var qe := QuadMesh.new()
		qe.size = Vector2(0.07, 0.07)
		e.mesh = qe
		e.material_override = me
		var a = TAU * i / 3.0
		e.translation = Vector3(cos(a) * 0.1, 0, sin(a) * 0.1)
		_estrelas.add_child(e)
	add_child(_estrelas)
	connect("body_entered", self, "_ao_bater")
	# o pino anda pela física e pela máquina (passos da física): interpolado.
	# As estrelinhas da tontura são postas a cada quadro.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	_estrelas.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	recolocar()


## A base do pino (onde ele pisa), no mundo.
func posicao_base() -> Vector3:
	return global_transform.xform(-COM)


## Põe o pino em pé com a base em `base`.
func colocar_em(base: Vector3) -> void:
	global_transform = Transform(Basis(), base + COM)


## Preso = sem física (a máquina carrega, os pulinhos animam).
func preso() -> bool:
	return mode != RigidBody.MODE_RIGID


func recolocar() -> void:
	parar_pulo()
	mode = RigidBody.MODE_KINEMATIC
	removido = false
	_sair_do_fosso()
	visible = true
	colocar_em(lugar)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	collision_layer = Medidas.CAMADA_PINOS
	collision_mask = Medidas.CAMADA_MUNDO | Medidas.CAMADA_PINOS | Medidas.CAMADA_BOLA | Medidas.CAMADA_PISO_PINOS | Medidas.CAMADA_SO_PINOS
	malha.scale = Vector3.ONE
	_estrelas.visible = false
	_escurecer(1.0)
	expressao("normal")
	if is_inside_tree():
		reset_physics_interpolation()


## Libera a física (antes da bola chegar).
func soltar() -> void:
	if removido:
		return
	parar_pulo()
	if physics_interpolation_mode != Node.PHYSICS_INTERPOLATION_MODE_ON:
		interpolar(true)
	mode = RigidBody.MODE_RIGID
	sleeping = false


func prender() -> void:
	mode = RigidBody.MODE_KINEMATIC


## Caiu no fosso: assenta rápido (amortece) — Pinos não deixa voltar.
func entrou_no_fosso() -> void:
	no_fosso = true
	linear_damp = 0.9
	angular_damp = 1.6


func _sair_do_fosso() -> void:
	no_fosso = false
	linear_damp = -1.0
	angular_damp = GIRO_AMORTECE


func esta_caido() -> bool:
	if removido:
		return true
	var up := global_transform.basis.y.normalized()
	if up.y < 0.74:
		return true
	var b := posicao_base()
	if b.y < -0.12:
		return true
	if Vector2(b.x - lugar.x, b.z - lugar.z).length() > 0.75:
		return true
	return false


func tirar() -> void:
	removido = true
	prender()
	visible = false
	collision_layer = 0
	collision_mask = 0
	colocar_em(lugar + Vector3(0, -3, 0))
	_estrelas.visible = false


func expressao(nome: String) -> void:
	_expr = nome
	_celula(nome)


func _escurecer(k: float) -> void:
	if abs(k - _escuro) < 0.01 and (k < 1.0 or _escuro == 1.0):
		return
	_escuro = k
	mat.set_shader_param("escuro", k)


func _celula(nome: String) -> void:
	var i := EXPR.find(nome)
	mat.set_shader_param("rosto_celula", Vector2(i % 4, i / 4))


func _process(delta: float) -> void:
	if not visible:
		return
	# caindo no poço do alçapão: escurece com a fundura até sumir no preto
	var y := posicao_base().y
	if y < Medidas.Y_CHAO_FOSSO - 0.05 or _escuro < 1.0:
		_escurecer(clamp(1.0 + (y - Medidas.Y_CHAO_FOSSO + 0.05) * 0.66, 0.0, 1.0))
	# tontura: estrelinhas girando em volta da cabeça
	if _estrelas.visible:
		var topo = global_transform.xform(Vector3(0, 0.42, 0) - COM)
		_estrelas.global_translation = topo + Vector3(0, 0.1, 0)
		_estrelas.rotation.y += delta * 5.0
	# piscar
	if _piscando > 0.0:
		_piscando -= delta
		if _piscando <= 0.0:
			_celula(_expr)
	elif _expr == "normal" or _expr == "feliz":
		_piscar -= delta
		if _piscar <= 0.0:
			_piscar = rand_range(1.5, 4.5)
			_piscando = 0.12
			_celula("piscando")


func ficar_tonto() -> void:
	if not removido:
		expressao("tonto")
		_estrelas.visible = true


## Caiu e ficou bravinho: cara brava e uma tremidinha de raiva.
func ficar_bravo() -> void:
	if removido:
		return
	expressao("bravo")
	_estrelas.visible = false
	if _raiva != null and _raiva.is_valid():
		_raiva.kill()
	_raiva = create_tween()
	_raiva.tween_interval(rand_range(0.1, 0.5))
	for i in 3:
		_raiva.tween_property(malha, "rotation:x", 0.09, 0.05)
		_raiva.tween_property(malha, "rotation:x", -0.09, 0.07)
	_raiva.tween_property(malha, "rotation:x", 0.0, 0.06)


## Ficou de pé: feliz. pulos > 0: pulinhos de comemoração (agacha, pula,
## amortece), começando depois de `atraso`; no fim volta exatamente ao
## lugar de onde saiu.
func comemorar(atraso: float, pulos: int) -> void:
	if removido:
		return
	expressao("feliz")
	if pulos <= 0:
		return
	parar_pulo()
	prender()
	_base_pulo = global_transform
	_pulando = true
	# os pulinhos são animados a cada quadro: sem interpolar
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_pulo = create_tween()
	_pulo.tween_interval(atraso)
	for i in pulos:
		var h := 0.16 if i == 0 else 0.1
		_pulo.tween_property(malha, "scale", Vector3(1.08, 0.86, 1.08), 0.08)
		_pulo.tween_property(malha, "scale", Vector3(0.94, 1.1, 0.94), 0.07)
		_pulo.parallel().tween_method(self, "_altura_pulo", 0.0, h, 0.17).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_pulo.tween_method(self, "_altura_pulo", h, 0.0, 0.17).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_pulo.parallel().tween_property(malha, "scale", Vector3.ONE, 0.17)
		_pulo.tween_property(malha, "scale", Vector3(1.07, 0.9, 1.07), 0.06)
		_pulo.tween_property(malha, "scale", Vector3.ONE, 0.1)
	_pulo.tween_callback(self, "parar_pulo")


func _altura_pulo(h: float) -> void:
	global_transform = Transform(_base_pulo.basis, _base_pulo.origin + Vector3(0, h, 0))


## Interrompe a comemoração e põe o pino de volta onde estava.
func parar_pulo() -> void:
	if _pulo != null and _pulo.is_valid():
		_pulo.kill()
	_pulo = null
	if _raiva != null and _raiva.is_valid():
		_raiva.kill()
	_raiva = null
	if malha:
		malha.rotation = Vector3.ZERO
		malha.scale = Vector3.ONE
	if _pulando:
		global_transform = _base_pulo
		_pulando = false
		interpolar(true)


## Liga/desliga a interpolação da física (desligada no replay e nos pulinhos).
func interpolar(sim: bool) -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON if sim else Node.PHYSICS_INTERPOLATION_MODE_OFF
	if sim and is_inside_tree():
		reset_physics_interpolation()


func _ao_bater(corpo: Node) -> void:
	var agora := Time.get_ticks_msec()
	if agora - _ultimo_som < 90:
		return
	_ultimo_som = agora
	var v := linear_velocity.length()
	if corpo is RigidBody:
		v = max(v, (corpo as RigidBody).linear_velocity.length())
	if v > 0.35:
		emit_signal("bateu", self, v)
