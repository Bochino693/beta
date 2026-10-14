class_name Efeitos
extends Node3D

## EFEITOS 3D: explosão de estrelas, poeira do impacto, "puf" dos pinos
## que somem, chuva de confete e fogos (fim de jogo).

const ARCO_IRIS := [Color("#FF4B5C"), Color("#FF9F2E"), Color("#FFE14D"), Color("#5ED16A"), Color("#4FC3F7"), Color("#2E7BFF"), Color("#FFFFFF")]

var _mat_estrela: StandardMaterial3D
var _mat_faisca: StandardMaterial3D
var _mat_fumaca: StandardMaterial3D
var _mat_confete: StandardMaterial3D


func _ready() -> void:
	_mat_estrela = Materiais.particula("estrela", false)
	_mat_faisca = Materiais.particula("faisca", true)
	_mat_fumaca = Materiais.particula("fumaca", false)
	_mat_confete = Materiais.particula("confete", false)
	_mat_confete.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES


func _arco_iris() -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.17, 0.34, 0.5, 0.67, 0.84, 1.0])
	g.colors = PackedColorArray(ARCO_IRIS)
	return g


func _novo(qtd: int, vida: float, mat: Material, tam: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = qtd
	p.lifetime = vida
	p.one_shot = true
	p.explosiveness = 0.9
	p.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(tam, tam)
	q.material = mat
	p.mesh = q
	add_child(p)
	get_tree().create_timer(vida + 0.6, false).timeout.connect(p.queue_free)
	return p


## Explosão de estrelas coloridas (strike, spare).
func estrelas(pos: Vector3, qtd := 30, forca := 1.0) -> void:
	var p := _novo(qtd, 1.3, _mat_estrela, 0.16)
	p.global_position = pos
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 2.5 * forca
	p.initial_velocity_max = 5.0 * forca
	p.gravity = Vector3(0, -6.0, 0)
	p.angular_velocity_min = -400
	p.angular_velocity_max = 400
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	p.color_initial_ramp = _arco_iris()
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(0.75, 1))
	c.add_point(Vector2(1, 0))
	p.scale_amount_curve = c
	p.emitting = true
	var f := _novo(20, 0.6, _mat_faisca, 0.22)
	f.global_position = pos
	f.spread = 180.0
	f.initial_velocity_min = 1.5
	f.initial_velocity_max = 3.5
	f.gravity = Vector3.ZERO
	f.damping_min = 3.0
	f.damping_max = 5.0
	f.color = Color(1.0, 0.95, 0.7)
	f.emitting = true


## Poeirinha no chão (impacto da bola nos pinos, pino caindo).
func poeira(pos: Vector3, forca := 1.0) -> void:
	var p := _novo(int(10 * forca) + 4, 0.8, _mat_fumaca, 0.35)
	p.global_position = pos
	p.direction = Vector3.UP
	p.spread = 85.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.4 * forca
	p.gravity = Vector3(0, 0.3, 0)
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var c := Curve.new()
	c.add_point(Vector2(0, 0.4))
	c.add_point(Vector2(0.3, 1.0))
	c.add_point(Vector2(1, 1.3))
	p.scale_amount_curve = c
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.85))
	g.set_color(1, Color(1, 0.95, 1, 0.0))
	p.color_ramp = g
	p.emitting = true


## "Puf" de pino sumindo.
func puf(pos: Vector3) -> void:
	poeira(pos, 0.8)
	var p := _novo(8, 0.7, _mat_estrela, 0.1)
	p.global_position = pos + Vector3(0, 0.2, 0)
	p.spread = 180.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.0
	p.gravity = Vector3(0, -2.0, 0)
	p.color_initial_ramp = _arco_iris()
	p.emitting = true


## Chuva de confete na frente da câmera (posição e largura da área).
func confete(pos: Vector3, largura := 3.0, qtd := 120) -> void:
	var p := _novo(qtd, 3.2, _mat_confete, 0.07)
	p.explosiveness = 0.3
	p.global_position = pos
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(largura, 0.2, largura * 0.5)
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -2.2, 0)
	p.damping_min = 0.8
	p.damping_max = 1.6
	p.angular_velocity_min = -720
	p.angular_velocity_max = 720
	p.angle_min = 0
	p.angle_max = 360
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.4
	p.color_initial_ramp = _arco_iris()
	p.emitting = true


## Fogos de artifício (vários estouros).
func fogos(centro: Vector3, quantos := 5) -> void:
	for i in quantos:
		var t := get_tree().create_timer(0.35 * i, false)
		t.timeout.connect(func():
			var pos := centro + Vector3(randf_range(-2.5, 2.5), randf_range(-0.5, 1.5), randf_range(-1.0, 1.0))
			var p := _novo(46, 1.4, _mat_faisca, 0.18)
			p.global_position = pos
			p.spread = 180.0
			p.initial_velocity_min = 3.0
			p.initial_velocity_max = 3.6
			p.gravity = Vector3(0, -2.0, 0)
			p.damping_min = 1.2
			p.damping_max = 1.6
			p.color = ARCO_IRIS[randi() % ARCO_IRIS.size()]
			var c := Curve.new()
			c.add_point(Vector2(0, 1))
			c.add_point(Vector2(1, 0))
			p.scale_amount_curve = c
			p.emitting = true)
