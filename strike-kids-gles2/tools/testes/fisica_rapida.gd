extends SceneTree

## Teste rápido da física (Bullet): pista lisa simples, 10 pinos, bola.
##   godot3 --no-window --fixed-fps 60 --path . -s res://tools/testes/fisica_rapida.gd -- x0 xt vel efeito
## Mostra quantos pinos caíram e onde a bola passou.

var pinos
var bola
var t := 0.0
var fase := 0
var args := [0.0, 0.08, 8.0, 0.0]


func _init() -> void:
	var a := OS.get_cmdline_args()
	var nums := []
	for s in a:
		if s.is_valid_float():
			nums.append(float(s))
	if nums.size() >= 4:
		args = nums
	if a.has("--assentar"):
		args = [9.0, 9.0, 0.0, 0.0]
	# chão da pista: a parte da bola (lisa) e a dos pinos (madeira seca)
	for d in [[Medidas.CAMADA_PISO_BOLA, 0.05, 0.05, "bola"], [Medidas.CAMADA_PISO_PINOS, 0.42, 0.1, "pinos"]]:
		var sb := StaticBody.new()
		var cs := CollisionShape.new()
		var bs := BoxShape.new()
		bs.extents = Vector3(Medidas.MEIA_LARGURA, 0.1, 7.0)
		cs.shape = bs
		sb.add_child(cs)
		sb.translation = Vector3(0, -0.1, -5.5)
		sb.collision_layer = d[0]
		sb.collision_mask = 0
		sb.physics_material_override = Medidas.material(d[1], d[2], d[3])
		root.add_child(sb)
	pinos = load("res://scripts/pinos.gd").new()
	root.add_child(pinos)
	pinos.montar()
	bola = load("res://scripts/bola.gd").new()
	root.add_child(bola)
	bola.vestir("bob")
	bola.guardar()


func _iteration(delta: float) -> bool:
	t += delta
	if fase == 0 and t > 0.1 and args[0] > 8.0:
		pinos.soltar_todos()
		fase = 3
		t = 0.0
	elif fase == 3 and t > 1.5:
		for p in pinos.pinos:
			var base: Vector3 = p.posicao_base()
			print("  assentado %d base.y=%.4f up.y=%.4f dxz=%.4f" % [p.numero, base.y, p.global_transform.basis.y.normalized().y, Vector2(base.x - p.lugar.x, base.z - p.lugar.z).length()])
		bola.lancar(Vector3(0, Bola.RAIO + 0.04, 0.35), Vector3(0, 0, -0.01), 0.0)
		fase = 4
		t = 0.0
	elif fase == 4 and t > 1.0:
		print("  bola y=%.4f (raio %.3f)" % [bola.global_translation.y, Bola.RAIO])
		Engine.set_meta("compat_estados", null)
		return true
	elif fase == 0 and t > 0.1:
		pinos.soltar_todos()
		var x0: float = args[0]
		var xt: float = args[1]
		var zs := 0.35
		var origem := Vector3(x0, Bola.RAIO + 0.04, zs)
		var alvo := Vector3(xt, Bola.RAIO, Medidas.Z_PINO1)
		var dir := alvo - origem
		dir.y = 0
		bola.lancar(origem, dir.normalized() * float(args[2]), float(args[3]))
		fase = 1
		t = 0.0
	elif fase == 1:
		var b: Vector3 = bola.global_translation
		if int(t * 120) % 24 == 0:
			print("t=%.2f bola=(%.3f, %.3f, %.3f) v=%.2f" % [t, b.x, b.y, b.z, bola.linear_velocity.length()])
		if b.z < Medidas.Z_FIM_DECK - 0.3 or b.y < -0.4 or t > 5.0:
			fase = 2
			t = 0.0
	elif fase == 2 and (t > 3.0 or (t > 1.2 and pinos.todos_parados())):
		var em_pe: Array = pinos.em_pe()
		print("EM PE: ", em_pe, "  caidos=", 10 - em_pe.size())
		for p in pinos.pinos:
			var base: Vector3 = p.posicao_base()
			print("  pino %d base=(%.2f, %.2f, %.2f) up.y=%.2f" % [p.numero, base.x, base.y, base.z, p.global_transform.basis.y.normalized().y])
		Engine.set_meta("compat_estados", null)
		return true
	return false
