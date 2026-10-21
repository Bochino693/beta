extends SceneTree

## Tira da forma de colisão do pino (modelos/pino_colisao.res) os pontos que
## ficam DENTRO dela (o pescoço e a cintura: o casco convexo passa por
## fora). A forma continua exatamente a mesma — a física acha sempre o mesmo
## ponto mais longe e as jogadas saem iguais —, mas com 140 pontos em vez de
## 240 cada teste de batida fica mais barato. Os que ficam mantêm a ordem
## original (no empate a física fica com o primeiro da lista).
##   godot3 --no-window --path . -s res://tools/limpar_forma_pino.gd

const CAMINHO := "res://modelos/pino_colisao.res"


func _init() -> void:
	var forma: ConvexPolygonShape = load(CAMINHO)
	var orig := forma.points
	var am := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = orig
	am.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arr)
	var casco: ConvexPolygonShape = am.create_convex_shape(true, false)
	# cada ponto do casco é um dos originais (o mais perto)
	var ficam := {}
	for v in casco.points:
		var melhor := 0
		for i in orig.size():
			if orig[i].distance_squared_to(v) < orig[melhor].distance_squared_to(v):
				melhor = i
		ficam[melhor] = true
	var novos := PoolVector3Array()
	for i in orig.size():
		if ficam.has(i):
			novos.append(orig[i])
	print("forma do pino: %d -> %d pontos" % [orig.size(), novos.size()])
	if novos.size() < orig.size():
		var nova := ConvexPolygonShape.new()
		nova.points = novos
		nova.margin = forma.margin
		print("gravado: ", ResourceSaver.save(CAMINHO, nova) == OK)
	quit()
