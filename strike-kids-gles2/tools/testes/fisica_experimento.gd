extends "res://tools/testes/custo_fisica.gd"

## EXPERIMENTOS DE CUSTO DA FÍSICA (só no PC; o binário "server" do Godot 3
## roda sem placa de vídeo e mede só a física e os scripts):
##   EXP=casco80 godot3_server --path . --fixed-fps 120 res://tools/testes/fisica_experimento.tscn -- --linha=C,0.0,0.06,8.8,0.0
## EXP (separados por vírgula): monitor (pinos sem lista de contatos),
## cascoNN (forma do pino com NN pontos), ccd (bola sem CCD).


func _ready() -> void:
	var exp_ := OS.get_environment("EXP")
	for e in exp_.split(","):
		if e == "monitor":
			for p in pinos.pinos:
				p.contact_monitor = false
		elif e.begins_with("casco"):
			var n := int(e.substr(5))
			var forma := _casco(n)
			for p in pinos.pinos:
				for c in p.get_children():
					if c is CollisionShape:
						c.shape = forma
		elif e == "ccd":
			bola.continuous_cd = false
	print("EXP=", exp_)


## A forma do pino com menos anéis: os anéis que mais mudam o casco ficam.
func _casco(n: int) -> ConvexPolygonShape:
	var f: ConvexPolygonShape = load("res://modelos/pino_colisao.res")
	var aneis := {}
	for p in f.points:
		var y = stepify(p.y, 0.001)
		if not aneis.has(y):
			aneis[y] = []
		aneis[y].append(p)
	var ys := aneis.keys()
	ys.sort()
	var quero := []
	if n <= 60:
		quero = [0.0, 0.048, 0.112, 0.144, 0.442, 0.475]
	elif n <= 80:
		quero = [0.0, 0.021, 0.08, 0.112, 0.144, 0.176, 0.442, 0.469]
	else:
		quero = ys
	var pts := PoolVector3Array()
	for y in ys:
		var perto := false
		for q in quero:
			if abs(float(y) - float(q)) < 0.0015:
				perto = true
		if perto:
			for p in aneis[y]:
				pts.append(p)
	var nova := ConvexPolygonShape.new()
	nova.points = pts
	nova.margin = f.margin if f.margin < 0.01 else 0.003
	print("casco: %d pontos" % pts.size())
	return nova
