class_name Pinos
extends Node3D

## OS 10 PINOS: montagem no triângulo, reposição animada, contagem dos
## caídos, "ajuda" para o resultado planejado e gravação para o replay.
##
## Numeração oficial (vista de quem joga):
##          7   8   9   10
##            4   5   6
##              2   3
##                1

signal batida(posicao: Vector3, forca: float)

var pinos: Array[Pino] = []


static func posicao_do_pino(n: int) -> Vector3:
	var fileira := 0
	var primeiro := 1
	while n >= primeiro + fileira + 1:
		primeiro += fileira + 1
		fileira += 1
	var k := n - primeiro
	var x := (float(k) - float(fileira) * 0.5) * Mundo.ESPACO_PINOS
	return Vector3(x, 0.0, Mundo.Z_PINO1 - fileira * Mundo.FILEIRA)


func montar() -> void:
	var malha: Mesh = load("res://modelos/pino.res")
	var forma: Shape3D = load("res://modelos/pino_colisao.res")
	var rosto := Materiais.textura("rosto_pino")
	var meta: Dictionary = malha.get_meta("rosto", {})
	for n in range(1, 11):
		var p := Pino.new()
		add_child(p)
		p.montar(n, posicao_do_pino(n), malha, forma, rosto, meta)
		p.bateu.connect(func(pino: Pino, f: float): batida.emit(pino.global_position, f))
		pinos.append(p)


func em_pe() -> Array[int]:
	var r: Array[int] = []
	for p in pinos:
		if not p.removido and not p.esta_caido():
			r.append(p.numero)
	return r


func caidos_desde(antes: Array[int]) -> Array[int]:
	var r: Array[int] = []
	var agora := em_pe()
	for n in antes:
		if not agora.has(n):
			r.append(n)
	return r


func pino(n: int) -> Pino:
	return pinos[n - 1]


## Antes da bola chegar: libera a física dos que estão em pé; os que o
## planejamento manda ficar ficam "teimosos" (balançam, mas aguentam).
func preparar(planejados: Array) -> void:
	for p in pinos:
		if p.removido:
			continue
		p.definir_teimoso(not planejados.has(p.numero))
		p.soltar()


## Carinha de medo quando a bola se aproxima.
func susto(bola_pos: Vector3) -> void:
	for p in pinos:
		if p.removido or p.esta_caido():
			continue
		var d := p.global_position.distance_to(bola_pos)
		if d < 3.2 and p._expr == "normal":
			p.expressao("medo")


## Empurrãozinho nos pinos que deviam cair e ainda estão em pé.
func ajudar(planejados: Array, origem: Vector3) -> void:
	for n in planejados:
		var p := pino(n)
		if p.removido or p.esta_caido():
			continue
		var dir := p.global_position - origem
		dir.y = 0.0
		if dir.length() < 0.01:
			dir = Vector3(randf_range(-1, 1), 0, -1)
		dir = (dir.normalized() + Vector3(randf_range(-0.35, 0.35), 0, randf_range(-0.2, 0.0))).normalized()
		p.sleeping = false
		p.apply_impulse(dir * 2.2 + Vector3(0, 0.6, 0), Vector3(0, 0.38, 0))


## Efeito desenho animado no strike: os pinos "pulam" um pouco.
func estourar(origem: Vector3) -> void:
	for p in pinos:
		if p.removido:
			continue
		var dir := p.global_position - origem
		dir.y = 0.0
		dir = dir.normalized() if dir.length() > 0.01 else Vector3(0, 0, -1)
		p.sleeping = false
		p.apply_impulse(dir * randf_range(1.0, 2.0) + Vector3(0, randf_range(2.2, 3.6), 0), Vector3(randf_range(-0.03, 0.03), 0.3, 0))
		p.apply_torque_impulse(Vector3(randf_range(-0.4, 0.4), randf_range(-0.2, 0.2), randf_range(-0.4, 0.4)))


## Replay: os pinos voltam a ter cara normal (sem estrelinhas) para
## "reviver" a jogada.
func reviver() -> void:
	for p in pinos:
		if not p.removido:
			p.expressao("normal")
			p._estrelas.visible = false


func todos_parados() -> bool:
	for p in pinos:
		if p.removido or p.freeze:
			continue
		if p.linear_velocity.length() > 0.06 or p.angular_velocity.length() > 0.25:
			return false
	return true


func marcar_tontos() -> void:
	for p in pinos:
		if p.removido:
			continue
		if p.esta_caido():
			p.ficar_tonto()
		elif p._expr == "medo":
			p.expressao("feliz")


func prender_todos() -> void:
	for p in pinos:
		p.prender()


## Tira os caídos (com "puf") e devolve os em pé ao lugar certo.
## Retorna a lista de posições onde houve "puf" (para efeitos).
func varrer() -> Array[Vector3]:
	var pufs: Array[Vector3] = []
	for p in pinos:
		if p.removido:
			continue
		if p.esta_caido():
			pufs.append(p.global_position + Vector3(0, 0.1, 0))
			p.tirar()
		else:
			p.prender()
			var tw := create_tween()
			tw.tween_property(p, "global_transform", Transform3D(Basis(), p.lugar), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			p.definir_teimoso(false)
			p.expressao("normal")
	return pufs


## Rack novo: os 10 caem do céu, um de cada vez, com quique.
func repor_todos(animar := true) -> void:
	var ordem := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	for i in ordem.size():
		var p := pino(ordem[i])
		p.recolocar()
		if animar:
			p.global_position = p.lugar + Vector3(0, 1.4, 0)
			p.malha.scale = Vector3(0.6, 1.4, 0.6)
			var tw := create_tween()
			tw.tween_interval(0.05 * i)
			tw.tween_property(p, "global_position", p.lugar, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_property(p.malha, "scale", Vector3(1.25, 0.75, 1.25), 0.07)
			tw.tween_property(p.malha, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- replay
func foto() -> Array:
	var r := []
	for p in pinos:
		r.append(p.global_transform)
	return r


func aplicar_foto(f: Array) -> void:
	for i in pinos.size():
		if not pinos[i].removido:
			pinos[i].global_transform = f[i]
