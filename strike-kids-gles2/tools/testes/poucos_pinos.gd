extends Node

## TESTE: POUCOS PINOS EM PÉ (a bola da sobra, o "spare") — só no PC.
##   godot3_server --path . --fixed-fps 60 res://tools/testes/poucos_pinos.tscn -- [--vezes=2] [--casos=7;10;7,10]
## Para cada grupo de pinos que sobrou (um pino só, dois, três...) e cada
## posição do sensor, o planejador (Jogada) escolhe a linha como no jogo,
## pedindo ACERTO; a bola sai como no jogo e a física faz o resto. Anota:
##   * acerto planejado que não derrubou o que o planejador prometeu (o
##     "bug" mais visível) e quantas vezes sobrou pino (7-10 é quase
##     impossível também no boliche de verdade);
##   * pino que balançou e voltou a ficar em pé;
##   * a bola que passou sem encostar no pino da mira;
##   * o quanto o pino batido sobe (o centro dele) e gira, e se a bola pula.

const ZONAS := ["Z", "X", "C", "V", "B"]
const CASOS := [[1], [2], [3], [4], [5], [6], [7], [8], [9], [10],
	[7, 10], [4, 7], [6, 10], [2, 4], [3, 6], [1, 5], [2, 8], [3, 9], [3, 6, 10], [2, 4, 7], [1, 2, 4], [1, 3, 6]]

var mundo: Mundo
var pinos: Pinos
var maquina: Maquina
var bola: Bola
var fila := []
var atual = null
var t := 0.0
var fase := 0
var vezes := 2
var _tocou := {}
var _alto := 0.0
var _giro := 0.0
var _tombou := {}
var _conta := {"jogadas": 0, "falhou": 0, "sobrou": 0, "balancou": 0, "sem_toque": 0, "alto": 0.0, "giro": 0.0}
var _falhas := {}


func _ready() -> void:
	var casos: Array = CASOS
	for a in OS.get_cmdline_args():
		if a.begins_with("--vezes="):
			vezes = int(a.substr(8))
		elif a.begins_with("--casos="):
			casos = []
			for c in a.substr(8).split(";"):
				var g := []
				for n in c.split(","):
					g.append(int(n))
				casos.append(g)
	seed(1357)
	Jogada.preparar()
	mundo = Mundo.new()
	add_child(mundo)
	mundo.construir()
	mundo.definir_protecao(true)
	pinos = Pinos.new()
	add_child(pinos)
	pinos.montar()
	maquina = Maquina.new()
	add_child(maquina)
	maquina.montar(pinos)
	bola = Bola.new()
	add_child(bola)
	pinos.bola = bola
	bola.vestir("bob")
	bola.guardar()
	bola.connect("bateu", self, "_bola_bateu")
	for c in casos:
		for z in ZONAS:
			for i in vezes:
				fila.append([c, z])
	print("jogadas: ", fila.size())


func _bola_bateu(corpo: Node, _v: float) -> void:
	if corpo is Pino and fase == 1:
		_tocou[(corpo as Pino).numero] = true


func _physics_process(delta: float) -> void:
	if atual == null:
		if fila.empty():
			_fim()
			set_physics_process(false)
			return
		atual = fila.pop_front()
		maquina.instantaneo()
		pinos.repor_todos()
		for p in pinos.pinos:
			if not (atual[0] as Array).has((p as Pino).numero):
				p.tirar()
		pinos.soltar_todos()
		bola.guardar()
		t = 0.0
		fase = 0
		return
	t += delta
	if fase == 0 and t > 0.1:
		var em_pe: Array = atual[0]
		Jogada.forcar().clear()
		Jogada.forcar().append(em_pe.size())
		var j = Jogada.planejar(atual[1], em_pe, false, "normal", true)
		var z0 := rand_range(0.3, 0.45)
		var u := (0.35 - z0) / (0.35 - Medidas.Z_PINO1)
		var origem := Vector3(lerp(j.origem_x, j.alvo_x, u), Bola.RAIO + 0.04, z0)
		var dir := Vector3(j.alvo_x, Bola.RAIO, Medidas.Z_PINO1) - origem
		dir.y = 0
		bola.lancar(origem, dir.normalized() * j.velocidade, j.efeito)
		pinos.soltar_todos()
		atual.append(j.alvo_x)
		atual.append(j.origem_x)
		atual.append(j.esperado)
		_tocou.clear()
		_tombou.clear()
		_alto = 0.0
		_giro = 0.0
		fase = 1
		t = 0.0
		return
	if fase >= 1:
		for n in atual[0]:
			var p: Pino = pinos.pino(n)
			var up := p.global_transform.basis.y.normalized()
			if up.y < 0.9:
				_tombou[n] = true
			# quanto o pino sobe (o centro de massa; tombando, a base sobe sem voar)
			_alto = max(_alto, p.global_transform.origin.y - Pino.COM.y)
			_giro = max(_giro, p.angular_velocity.length())
	if fase == 1:
		var b := bola.global_translation
		if b.z < Medidas.Z_FIM_DECK - 0.3 or b.y < -0.4 or t > 5.0:
			fase = 2
			t = 0.0
		return
	if fase == 2 and (t > 3.0 or (t > 1.2 and pinos.todos_parados())):
		var de_pe := pinos.em_pe()
		var grupo: Array = atual[0]
		_conta["jogadas"] += 1
		_conta["alto"] = max(float(_conta["alto"]), _alto)
		_conta["giro"] = max(float(_conta["giro"]), _giro)
		var nota := ""
		if not de_pe.empty():
			_conta["sobrou"] += 1
			nota += " SOBROU %s" % str(de_pe)
		if grupo.size() - de_pe.size() < int(atual[4]):
			_conta["falhou"] += 1
			nota += " FALHOU (prometeu %d)" % int(atual[4])
			var k := str(grupo)
			_falhas[k] = int(_falhas.get(k, 0)) + 1
		for n in de_pe:
			if _tombou.has(n):
				_conta["balancou"] += 1
				nota += " BALANCOU %d" % n
		var tocou_algum := false
		for n in grupo:
			if _tocou.has(n):
				tocou_algum = true
		if not tocou_algum:
			_conta["sem_toque"] += 1
			nota += " SEM TOQUE"
		print("%-10s %s alvo=%.3f origem=%.3f subiu=%.2f giro=%.1f%s" % [str(grupo), atual[1], atual[2], atual[3], _alto, _giro, nota])
		atual = null


func _fim() -> void:
	print("POUCOS PINOS: %d jogadas (acerto pedido)  falhou %d  sobrou pino %d  balancou e ficou %d  sem toque %d  mais alto %.2f m  giro max %.1f" % [
		_conta["jogadas"], _conta["falhou"], _conta["sobrou"], _conta["balancou"], _conta["sem_toque"], _conta["alto"], _conta["giro"]])
	print("falhas por grupo: ", _falhas)
	get_tree().quit()
