extends Node

## TESTE: A VARRIDA LEVA TODOS OS PINOS PARA O ALÇAPÃO (só no PC)
##   godot3_server --path . --fixed-fps 60 res://tools/testes/varrida.tscn -- [--rodadas=60]
## Em cada rodada deita alguns pinos ao acaso — nas canaletas e no fim da
## pista —, deixa assentar e roda a máquina: 3 de cada 4 rodadas com
## reposicionar (os em pé ficam), a outra com rack_novo (os em pé também
## são varridos). Quando o alçapão abre confere cada pino varrido: no fosso
## (atrás do fim da pista), para trás (por cima de outro, na beirada: cai
## pelo pulinho de lá mesmo) ou ERRO (o alçapão não abriu ou o pino ficou
## fora da queda — sumiria sem cair). Conta também os que voaram (subiram
## mais de 0,35 m) durante a varrida.

var mundo: Mundo
var pinos: Pinos
var maquina: Maquina
var total := 60
var feitas := 0
var fase := -1
var t := 0.0
var rack := false
var varridos := []   # [pino, "canaleta" / "pista" / "em pé"]
var _abriu := false
var _fim_ciclo := false
var _conta := {"fosso": 0, "atras": 0, "erros": 0, "canaleta": 0, "canaleta_fosso": 0, "voos": 0}
var _alto := 0.0
var _voou := {}


func _ready() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("--rodadas="):
			total = int(a.substr(10))
	seed(2468)
	mundo = Mundo.new()
	add_child(mundo)
	mundo.construir()
	mundo.definir_protecao(false)
	pinos = Pinos.new()
	add_child(pinos)
	pinos.montar()
	maquina = Maquina.new()
	add_child(maquina)
	maquina.montar(pinos)
	maquina.connect("alcapao", self, "_alcapao")
	maquina.connect("terminou", self, "_terminou")


func _alcapao(abrindo: bool) -> void:
	if not abrindo or _abriu:
		return
	_abriu = true
	# a máquina escolhe quem cai 0,25 s depois de avisar: confere junto
	yield(get_tree().create_timer(0.2, false), "timeout")
	_conferir("alcapao")


func _terminou() -> void:
	_fim_ciclo = true


func _conferir(quando: String) -> void:
	var queda: Array = maquina._pinos_do_fosso([]) if _abriu else []
	for item in varridos:
		var p: Pino = item[0]
		var b := p.posicao_base()
		if not queda.has(p):
			_conta["erros"] += 1
			print("  ERRO (%s): %s %s ficou em %s" % [quando, p.name, item[1], str(b)])
		elif b.z < Medidas.Z_FIM_DECK + 0.02:
			_conta["fosso"] += 1
			if item[1] == "canaleta":
				_conta["canaleta_fosso"] += 1
		else:
			_conta["atras"] += 1
			print("  para tras: %s %s em %s" % [p.name, item[1], str(b)])
	varridos.clear()


func _physics_process(delta: float) -> void:
	t += delta
	if fase == -1:
		if feitas >= total:
			print("VARRIDA: %d rodadas  no fosso %d  para tras %d  erros %d  (canaleta %d de %d)  voos %d  mais alto %.2f m" % [
				total, _conta["fosso"], _conta["atras"], _conta["erros"], _conta["canaleta_fosso"], _conta["canaleta"],
				_conta["voos"], _alto])
			print("VARRIDA OK" if _conta["erros"] == 0 else "VARRIDA COM ERROS")
			get_tree().quit()
			set_physics_process(false)
			return
		maquina.instantaneo()
		pinos.soltar_todos()
		rack = feitas % 4 == 3
		t = 0.0
		fase = 0
		return
	if fase == 0 and t > 0.2:
		# deita de 3 a 7 pinos: metade nas canaletas, o resto no fim da pista
		var lista: Array = pinos.pinos.duplicate()
		lista.shuffle()
		var n := 3 + randi() % 5
		varridos.clear()
		for i in lista.size():
			var p: Pino = lista[i]
			if i >= n:
				if rack:
					varridos.append([p, "em pé"])
				continue
			var na_canaleta := randf() < 0.5
			var x: float
			if na_canaleta:
				x = (1.0 if randf() < 0.5 else -1.0) * (Medidas.MEIA_LARGURA + Medidas.CANALETA * 0.5)
			else:
				x = rand_range(-Medidas.MEIA_LARGURA + 0.12, Medidas.MEIA_LARGURA - 0.12)
			var z := rand_range(Medidas.Z_FIM_DECK + 0.15, Medidas.Z_PINO1 + 0.35)
			# deitado: o eixo do pino na horizontal, numa direção qualquer
			# (na canaleta, quase ao longo dela)
			var giro := rand_range(-0.4, 0.4) if na_canaleta else rand_range(-PI, PI)
			var bas := Basis(Vector3.UP, giro) * Basis(Vector3.RIGHT, PI * 0.5)
			p.global_transform = Transform(bas, Vector3(x, 0.15, z))
			p.linear_velocity = Vector3.ZERO
			p.angular_velocity = Vector3.ZERO
			p.soltar()
			varridos.append([p, "canaleta" if na_canaleta else "pista"])
			if na_canaleta:
				_conta["canaleta"] += 1
		t = 0.0
		fase = 1
		return
	if fase == 1 and t > 1.5:
		_abriu = false
		_fim_ciclo = false
		_voou.clear()
		if rack:
			maquina.rack_novo()
		else:
			maquina.reposicionar()
		t = 0.0
		fase = 2
		return
	if fase == 2 and not _abriu:
		for item in varridos:
			var o: Vector3 = (item[0] as Pino).global_transform.origin
			_alto = max(_alto, o.y)
			if o.y > 0.35 and not _voou.has(item[0]):
				_voou[item[0]] = true
				_conta["voos"] += 1
				print("  voo: %s %s em %s (barra z=%.2f)" % [(item[0] as Node).name, item[1], str(o), maquina.barra.translation.z])
	if fase == 2 and (_fim_ciclo or t > 15.0):
		if not _abriu:
			_conferir("sem alcapao")
		feitas += 1
		fase = -1
