extends SceneTree

## FORMA DE COLISÃO DO PINO MAIS LEVE (modelos/pino_colisao.res): de 14
## anéis de 10 pontos (140) para 7 anéis + a pontinha (71 pontos), os que
## mais definem o casco — a forma muda no máximo 2,5 mm. Cada teste de
## batida percorre todos os pontos: com metade deles a física da batida
## (10 pinos + bola) custa ~40% menos — na TV Box era o que travava a
## jogada. Depois de mudar a forma a tabela de jogadas é calibrada de novo
## (tools/testes/calibrar.gd).
##   godot3 --no-window --path . -s res://tools/forma_pino_leve.gd

const CAMINHO := "res://modelos/pino_colisao.res"
## alturas (m, da base) dos anéis que ficam; o de cima vira um ponto só
const ANEIS := [0.0, 0.048, 0.112, 0.176, 0.457, 0.469, 0.475]
const PONTA := 0.480


func _init() -> void:
	var forma: ConvexPolygonShape = load(CAMINHO)
	var orig := forma.points
	var novos := PoolVector3Array()
	var ponta := Vector3.ZERO
	var n_ponta := 0
	for p in orig:
		if abs(p.y - PONTA) < 0.0015:
			ponta += p
			n_ponta += 1
			continue
		for y in ANEIS:
			if abs(p.y - float(y)) < 0.0015:
				novos.append(p)
				break
	if n_ponta > 0:
		novos.append(Vector3(0.0, ponta.y / n_ponta, 0.0))
	print("forma do pino: %d -> %d pontos" % [orig.size(), novos.size()])
	if novos.size() < orig.size():
		var nova := ConvexPolygonShape.new()
		nova.points = novos
		nova.margin = forma.margin
		print("gravado: ", ResourceSaver.save(CAMINHO, nova) == OK)
	quit()
