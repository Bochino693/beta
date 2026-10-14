class_name Pinos
extends Node3D

## OS 10 PINOS: montagem no triângulo, contagem dos caídos, carinhas e
## gravação para o replay. Quem varre e recoloca é a Maquina (maquina.gd).
## A queda é 100% física (Jolt): um pino derruba o outro, batem nas
## paredes e voltam, caem no fosso.
##
## Numeração oficial (vista de quem joga):
##          7   8   9   10
##            4   5   6
##              2   3
##                1

signal batida(posicao: Vector3, forca: float)
signal som_pousar

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


## Antes da bola chegar: libera a física dos pinos em pé.
func soltar_todos() -> void:
	for p in pinos:
		if not p.removido:
			p.soltar()


## Carinha de medo quando a bola se aproxima.
func susto(bola_pos: Vector3) -> void:
	for p in pinos:
		if p.removido or p.esta_caido():
			continue
		var d := p.global_position.distance_to(bola_pos)
		if d < 3.2 and p._expr == "normal":
			p.expressao("medo")


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


## Rack completo no lugar, sem animação.
func repor_todos(_animar := false) -> void:
	for p in pinos:
		p.recolocar()


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
