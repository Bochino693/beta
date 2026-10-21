extends Node

## TESTE: A BOLA NO FOSSO (só no PC, não vai no APK)
##   godot3_server --path . --fixed-fps 120 res://tools/testes/bola_fosso.tscn -- [--jogadas=300] [--dificuldade=normal]
## Joga como o jogo joga (Jogada.planejar, saindo da mão, máquina de pinos
## com o alçapão fechado) e acompanha a bola DEPOIS do fim da pista, até a
## caçapa: quanto ela pula (quica), em quantos pinos bate lá dentro,
## quanto demora até entrar na caçapa e se ficou presa (recolhida pelo
## tempo). E, para conferir que nada mudou na jogada, quantos pinos caíram.

const ZONAS := ["Z", "X", "C", "V", "B"]
## pulo que conta como "quicou": a bola subiu pelo menos isto acima do
## chão do fosso (centro em Y_CHAO_FOSSO + RAIO)
const PULO_MIN := 0.03

var mundo: Mundo
var pinos: Pinos
var maquina: Maquina
var bola: Bola
var dificuldade := "normal"
var total := 300
var feitas := 0
var t := 0.0
var fase := -1
var zona := "C"
var j
var em_pe_antes := []
var r := {}
var lista := []
var _recolhida := false
var _y_ant := 0.0


func _ready() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("--jogadas="):
			total = int(a.substr(10))
		elif a.begins_with("--dificuldade="):
			dificuldade = a.substr(14)
	seed(4321)
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
	bola.vestir("bob")
	bola.guardar()
	bola.connect("bateu", self, "_bola_bateu")
	bola.connect("recolhida", self, "_recolheu")
	print("jogadas: %d  dificuldade: %s" % [total, dificuldade])


func _bola_bateu(corpo: Node, _vel: float) -> void:
	if fase == 1 and r.get("t_fosso", -1.0) >= 0.0 and corpo is Pino:
		r["pinos_no_fosso"] += 1


func _recolheu() -> void:
	_recolhida = true


func _physics_process(delta: float) -> void:
	if fase == -1:
		if feitas >= total:
			_fim()
			set_physics_process(false)
			return
		zona = ZONAS[feitas % ZONAS.size()]
		maquina.instantaneo()
		bola.guardar()
		t = 0.0
		fase = 0
		return
	t += delta
	if fase == 0:
		if t < 0.05:
			return
		em_pe_antes = pinos.em_pe()
		j = Jogada.planejar(zona, em_pe_antes, true, dificuldade, true)
		var z0 := rand_range(0.3, 0.45)
		var u := (0.35 - z0) / (0.35 - Medidas.Z_PINO1)
		var origem := Vector3(lerp(j.origem_x, j.alvo_x, u), Bola.RAIO + 0.04, z0)
		var dir := Vector3(j.alvo_x, Bola.RAIO, Medidas.Z_PINO1) - origem
		dir.y = 0
		bola.lancar(origem, dir.normalized() * j.velocidade, j.efeito)
		pinos.soltar_todos()
		r = {"zona": zona, "esperado": j.esperado, "canaleta": j.canaleta, "t_fosso": -1.0, "t_cacapa": -1.0,
			"pulo": 0.0, "pinos_no_fosso": 0, "presa": false, "pulo_pista": 0.0}
		_recolhida = false
		_y_ant = bola.global_translation.y
		t = 0.0
		fase = 1
		return
	var b := bola.global_translation
	if bola.visible:
		if float(r["t_fosso"]) < 0.0:
			if b.z < Medidas.Z_FIM_DECK:
				r["t_fosso"] = t
			elif t > 0.3:
				# pulo na pista (depois de sair da mão): o centro acima do raio
				r["pulo_pista"] = max(float(r.get("pulo_pista", 0.0)), b.y - Bola.RAIO)
		else:
			# no fosso: quanto o centro subiu acima de onde ela rola no chão
			# (depois de pousar: a descida da pista para o fosso não conta)
			var acima: float = b.y - (Medidas.Y_CHAO_FOSSO + Bola.RAIO)
			if acima < 0.01:
				r["pousou"] = true
			if r.get("pousou", false) and b.z > Medidas.Z_FUNDO + 0.05:
				r["pulo"] = max(float(r["pulo"]), acima)
	if _recolhida and float(r["t_cacapa"]) < 0.0:
		r["t_cacapa"] = t
		r["presa"] = b.z > Medidas.Z_FUNDO - 0.3
	var fim := false
	if float(r["t_cacapa"]) >= 0.0:
		fim = t - float(r["t_cacapa"]) > 1.0
	if t > 9.0:
		fim = true
	if not fim:
		return
	r["caidos"] = pinos.caidos_desde(em_pe_antes).size()
	lista.append(r.duplicate())
	feitas += 1
	if feitas % 50 == 0:
		print(feitas, " jogadas")
	fase = -1


func _fim() -> void:
	var n := lista.size()
	var quicou := 0
	var bateu := 0
	var presa := 0
	var nunca := 0
	var soma_t := 0.0
	var n_t := 0
	var pior_pulo := 0.0
	var soma_caidos := 0
	var pulou_pista := 0
	var pior_pista := 0.0
	for x in lista:
		if float(x.get("pulo_pista", 0.0)) > PULO_MIN:
			pulou_pista += 1
		pior_pista = max(pior_pista, float(x.get("pulo_pista", 0.0)))
		if float(x["pulo"]) > PULO_MIN:
			quicou += 1
		pior_pulo = max(pior_pulo, float(x["pulo"]))
		if int(x["pinos_no_fosso"]) > 0:
			bateu += 1
		if x["presa"]:
			presa += 1
		if float(x["t_cacapa"]) < 0.0:
			nunca += 1
		elif float(x["t_fosso"]) >= 0.0:
			soma_t += float(x["t_cacapa"]) - float(x["t_fosso"])
			n_t += 1
		soma_caidos += int(x["caidos"])
	print("FOSSO (%d jogadas): quicou (> %d cm) em %d, pior pulo %.1f cm; bateu em pino no fosso em %d; presa (recolhida pelo tempo) %d; nunca chegou %d; fim da pista -> caçapa %.2f s em média; média de pinos caídos %.2f" % [
		n, int(PULO_MIN * 100), quicou, pior_pulo * 100.0, bateu, presa, nunca, soma_t / max(n_t, 1), float(soma_caidos) / max(n, 1)])
	print("PISTA: pulou (> %d cm) em %d, pior pulo %.1f cm" % [int(PULO_MIN * 100), pulou_pista, pior_pista * 100.0])
	print("BOLA_FOSSO OK")
	get_tree().quit()
