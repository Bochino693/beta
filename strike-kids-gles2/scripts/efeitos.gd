class_name Efeitos
extends Spatial

## EFEITOS 3D: explosão de estrelas, poeira do impacto, "puf" dos pinos
## que somem, chuva de confete e fogos (fim de jogo).

const ARCO_IRIS := [Color("#FF4B5C"), Color("#FF9F2E"), Color("#FFE14D"), Color("#5ED16A"), Color("#4FC3F7"), Color("#2E7BFF"), Color("#FFFFFF")]

var _mat_estrela: SpatialMaterial
var _mat_faisca: SpatialMaterial
var _mat_fumaca: SpatialMaterial
var _mat_confete: SpatialMaterial


func _ready() -> void:
	_mat_estrela = Materiais.particula("estrela", false)
	_mat_faisca = Materiais.particula("faisca", true)
	_mat_fumaca = Materiais.particula("fumaca", false)
	_mat_confete = Materiais.particula("confete", false)
	_mat_confete.params_billboard_mode = SpatialMaterial.BILLBOARD_PARTICLES


## Os materiais das partículas (o Aquecer prepara antes da 1ª jogada).
func materiais() -> Array:
	return [_mat_estrela, _mat_faisca, _mat_fumaca, _mat_confete]


## Malhas, degradês e curvas dos efeitos são feitos uma vez só e
## reaproveitados (criar malha nova a cada estrela/confete pesava na TV Box
## bem na hora do strike).
var _quads := {}
var _arco: Gradient
var _poeira_cor: Gradient
var _curvas := {}


func _arco_iris() -> Gradient:
	if _arco == null:
		_arco = Gradient.new()
		_arco.offsets = PoolRealArray([0.0, 0.17, 0.34, 0.5, 0.67, 0.84, 1.0])
		_arco.colors = PoolColorArray(ARCO_IRIS)
	return _arco


func _curva(pontos: Array) -> Curve:
	var chave := str(pontos)
	if not _curvas.has(chave):
		var c := Curve.new()
		for pt in pontos:
			c.add_point(pt)
		_curvas[chave] = c
	return _curvas[chave]


func _novo(qtd: int, vida: float, mat: Material, tam: float) -> CPUParticles:
	var p := CPUParticles.new()
	p.amount = qtd
	p.lifetime = vida
	p.one_shot = true
	p.explosiveness = 0.9
	p.local_coords = false
	var chave := "%d|%.3f" % [mat.get_instance_id(), tam]
	if not _quads.has(chave):
		var nq := QuadMesh.new()
		nq.size = Vector2(tam, tam)
		nq.material = mat
		_quads[chave] = nq
	p.mesh = _quads[chave]
	add_child(p)
	# Godot 3: sem o sinal "finished" nem lambda — um relógio apaga o efeito
	get_tree().create_timer(vida + 0.6, false).connect("timeout", p, "queue_free")
	return p


## Apaga na hora todos os efeitos que ainda estão no ar (fim do ensaio
## geral da preparação).
func limpar() -> void:
	for c in get_children():
		if c is CPUParticles:
			c.queue_free()


## FAIXAS SORTEADAS: no Godot 4 cada parâmetro das partículas tinha mínimo e
## máximo; no Godot 3 tem um valor e uma variação, com contas diferentes
## para cada tipo. Estas funções acham o valor e a variação que sorteiam
## exatamente entre `minimo` e `maximo` (os cenários, temas.gd, também usam).
## Velocidade, freio (damping) e ângulo: o Godot 3 sorteia entre
## valor * (1 - variação) e valor.
static func faixa(p: CPUParticles, nome: String, minimo: float, maximo: float) -> void:
	p.set(nome, maximo)
	p.set(nome + "_random", 1.0 - minimo / maximo if maximo != 0.0 else 0.0)


## Giro (angular_velocity): o Godot 3 sorteia entre valor * (1 - 2 * variação) e valor.
static func faixa_giro(p: CPUParticles, minimo: float, maximo: float) -> void:
	p.angular_velocity = maximo
	p.angular_velocity_random = (1.0 - minimo / maximo) * 0.5 if maximo != 0.0 else 0.0


## Tamanho (scale_amount): o Godot 3 sorteia de valor em direção a 1
## (valor + (1 - valor) * variação); a variação pode passar de 1.
static func faixa_escala(p: CPUParticles, minimo: float, maximo: float) -> void:
	if is_equal_approx(minimo, maximo):
		p.scale_amount = minimo
		p.scale_amount_random = 0.0
	elif minimo < 1.0:
		p.scale_amount = minimo
		p.scale_amount_random = (maximo - minimo) / (1.0 - minimo)
	else:
		p.scale_amount = maximo
		p.scale_amount_random = (maximo - minimo) / (maximo - 1.0)


## Explosão de estrelas coloridas (strike, spare).
func estrelas(pos: Vector3, qtd := 30, forca := 1.0) -> void:
	var p := _novo(qtd, 1.3, _mat_estrela, 0.16)
	p.global_translation = pos
	p.direction = Vector3.UP
	p.spread = 80.0
	faixa(p, "initial_velocity", 2.5 * forca, 5.0 * forca)
	p.gravity = Vector3(0, -6.0, 0)
	faixa_giro(p, -400, 400)
	faixa_escala(p, 0.6, 1.3)
	p.color_initial_ramp = _arco_iris()
	p.scale_amount_curve = _curva([Vector2(0, 1), Vector2(0.75, 1), Vector2(1, 0)])
	p.emitting = true
	var f := _novo(20, 0.6, _mat_faisca, 0.22)
	f.global_translation = pos
	f.spread = 180.0
	faixa(f, "initial_velocity", 1.5, 3.5)
	f.gravity = Vector3.ZERO
	faixa(f, "damping", 3.0, 5.0)
	f.color = Color(1.0, 0.95, 0.7)
	f.emitting = true


## Poeirinha no chão (impacto da bola nos pinos, pino caindo).
func poeira(pos: Vector3, forca := 1.0) -> void:
	var p := _novo(int(10 * forca) + 4, 0.8, _mat_fumaca, 0.35)
	p.global_translation = pos
	p.direction = Vector3.UP
	p.spread = 85.0
	faixa(p, "initial_velocity", 0.4, 1.4 * forca)
	p.gravity = Vector3(0, 0.3, 0)
	faixa(p, "damping", 1.5, 2.5)
	faixa_escala(p, 0.6, 1.2)
	p.scale_amount_curve = _curva([Vector2(0, 0.4), Vector2(0.3, 1.0), Vector2(1, 1.3)])
	if _poeira_cor == null:
		_poeira_cor = Gradient.new()
		_poeira_cor.set_color(0, Color(1, 1, 1, 0.85))
		_poeira_cor.set_color(1, Color(1, 0.95, 1, 0.0))
	p.color_ramp = _poeira_cor
	p.emitting = true


## "Puf" de pino sumindo.
func puf(pos: Vector3) -> void:
	poeira(pos, 0.8)
	var p := _novo(8, 0.7, _mat_estrela, 0.1)
	p.global_translation = pos + Vector3(0, 0.2, 0)
	p.spread = 180.0
	faixa(p, "initial_velocity", 1.0, 2.0)
	p.gravity = Vector3(0, -2.0, 0)
	p.color_initial_ramp = _arco_iris()
	p.emitting = true


## Chuva de confete na frente da câmera (posição e largura da área).
func confete(pos: Vector3, largura := 3.0, qtd := 120) -> void:
	var p := _novo(qtd, 3.2, _mat_confete, 0.07)
	p.explosiveness = 0.3
	p.global_translation = pos
	p.emission_shape = CPUParticles.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(largura, 0.2, largura * 0.5)
	p.direction = Vector3.UP
	p.spread = 60.0
	faixa(p, "initial_velocity", 1.5, 4.0)
	p.gravity = Vector3(0, -2.2, 0)
	faixa(p, "damping", 0.8, 1.6)
	faixa_giro(p, -720, 720)
	faixa(p, "angle", 0, 360)
	faixa_escala(p, 0.8, 1.4)
	p.color_initial_ramp = _arco_iris()
	p.emitting = true


## Fogos de artifício (vários estouros).
func fogos(centro: Vector3, quantos := 5) -> void:
	for i in quantos:
		var t := get_tree().create_timer(0.35 * i, false)
		# Godot 3: sem lambda — o estouro é um método (com o centro junto)
		t.connect("timeout", self, "_estouro", [centro])


## Um estouro dos fogos, perto do centro.
func _estouro(centro: Vector3) -> void:
	var pos := centro + Vector3(rand_range(-2.5, 2.5), rand_range(-0.5, 1.5), rand_range(-1.0, 1.0))
	var p := _novo(46, 1.4, _mat_faisca, 0.18)
	p.global_translation = pos
	p.spread = 180.0
	faixa(p, "initial_velocity", 3.0, 3.6)
	p.gravity = Vector3(0, -2.0, 0)
	faixa(p, "damping", 1.2, 1.6)
	p.color = ARCO_IRIS[randi() % ARCO_IRIS.size()]
	p.scale_amount_curve = _curva([Vector2(0, 1), Vector2(1, 0)])
	p.emitting = true
