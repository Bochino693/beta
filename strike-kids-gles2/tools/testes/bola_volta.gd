extends Node

## TESTE: A BOLA VOLTA? (só no PC, não vai no APK)
##   godot3 --no-window --path . --fixed-fps 60 res://tools/testes/bola_volta.tscn -- [--jogadas=300] [--sem-protecao] [--dificuldade=facil]
## Monta o mundo como o jogo (pista, fosso, MÁQUINA DE PINOS com o alçapão
## fechado) e joga a 1ª bola como o jogo joga (Jogada.planejar, saindo da
## mão), rastreando a bola: se ela volta na direção de quem joga depois de
## chegar nos pinos, se sai do fosso de volta para a pista, se termina
## parada na pista / em cima do para-choque em vez de ir para a caçapa, e
## em que ela bateu quando voltou, e se bola de canaleta derrubou pino.
## No fim, um resumo e as jogadas com problema.

const ZONAS := ["Z", "X", "C", "V", "B"]
const VOLTA_MIN := 0.35      # metros que a bola anda de volta para contar

var mundo: Mundo
var pinos: Pinos
var maquina: Maquina
var bola: Bola
var protecao := true
var dificuldade := "facil"
var total := 300
var feitas := 0
var t := 0.0
var fase := -1
var zona := "C"
var j
var em_pe_antes := []
var r := {}
var problemas := []
var resumo := {"voltou": 0, "voltou_fosso": 0, "parada_na_pista": 0, "derrubou_na_volta": 0, "canaleta_derrubou": 0,
	"canaletas": 0}
var _batidas := []


func _ready() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("--jogadas="):
			total = int(a.substr(10))
		elif a == "--sem-protecao":
			protecao = false
		elif a.begins_with("--dificuldade="):
			dificuldade = a.substr(14)
	seed(12345)
	Jogada.preparar()
	mundo = Mundo.new()
	add_child(mundo)
	mundo.construir()
	mundo.definir_protecao(protecao)
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
	print("jogadas: %d  protecao: %s  dificuldade: %s" % [total, protecao, dificuldade])


func _bola_bateu(corpo: Node, vel: float) -> void:
	if fase == 1:
		_batidas.append([stepify(t, 0.01), _nome(corpo), stepify(vel, 0.01), bola.global_translation])


static func _nome(n: Node) -> String:
	if n == null:
		return "?"
	if n is Pino or n.name == "fisica":
		return n.name
	var forma := ""
	for c in n.get_children():
		if c is CollisionShape:
			var sh: Shape = (c as CollisionShape).shape
			forma = sh.get_class().replace("Shape", "")
			if sh is BoxShape:
				forma += str((sh as BoxShape).extents * 2.0)
	var g := (n as Spatial).global_translation
	return "%s%s@(%.2f,%.2f,%.2f)" % [n.name, forma, g.x, g.y, g.z]


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
		j = Jogada.planejar(zona, em_pe_antes, true, dificuldade, protecao)
		# como principal._soltou_bola: a bola sai da mão em z <= 0,45
		var z0 := rand_range(0.3, 0.45)
		var u := (0.35 - z0) / (0.35 - Medidas.Z_PINO1)
		var origem := Vector3(lerp(j.origem_x, j.alvo_x, u), Bola.RAIO + 0.04, z0)
		var dir := Vector3(j.alvo_x, Bola.RAIO, Medidas.Z_PINO1) - origem
		dir.y = 0
		bola.lancar(origem, dir.normalized() * j.velocidade, j.efeito)
		pinos.soltar_todos()
		r = {"zona": zona, "esperado": j.esperado, "zmin": 9.0, "volta": 0.0, "fosso": false, "impacto": -1.0,
			"caidos_no_minimo": -1, "t_volta": -1.0, "ymax_depois": -9.0}
		_batidas.clear()
		t = 0.0
		fase = 1
		return
	# fase 1: a jogada, com o mesmo fim do jogo (principal._rolando)
	var b := bola.global_translation
	if bola.visible:
		if b.z < r["zmin"]:
			r["zmin"] = b.z
			r["caidos_no_minimo"] = pinos.caidos_desde(em_pe_antes).size()
		var volta: float = b.z - float(r["zmin"])
		# (andar um pouco para trás DENTRO do fosso, empurrada pelos pinos
		# caídos, não é voltar: dali ela só vai para a caçapa)
		if b.z < Medidas.Z_FIM_DECK - 0.05:
			volta = 0.0
		if volta > float(r["volta"]):
			r["volta"] = volta
			if volta > VOLTA_MIN and float(r["t_volta"]) < 0.0:
				r["t_volta"] = t
		if float(r["zmin"]) < Medidas.Z_FIM_DECK - 0.2 and b.z > Medidas.Z_FIM_DECK:
			r["fosso"] = true
		if float(r["impacto"]) >= 0.0:
			r["ymax_depois"] = max(float(r["ymax_depois"]), b.y)
	if float(r["impacto"]) < 0.0 and b.z < Medidas.Z_PINO1 + 0.22 and abs(b.x) < Medidas.MEIA_LARGURA:
		r["impacto"] = t
	var fim := false
	if float(r["impacto"]) >= 0.0:
		var dt := t - float(r["impacto"])
		fim = dt > 2.8 or (dt > 1.4 and pinos.todos_parados())
	elif b.z < Medidas.Z_FIM_DECK - 0.4 or b.y < -0.5:
		fim = t > 0.5
	if t > 7.5:
		fim = true
	if not fim:
		return
	var caidos := pinos.caidos_desde(em_pe_antes).size()
	r["caidos"] = caidos
	r["bola_fim"] = b if bola.visible else "caçapa"
	r["parada"] = bola.visible and b.z > Medidas.Z_FIM_DECK and b.y > -0.3
	var ruim := false
	if float(r["volta"]) > VOLTA_MIN:
		resumo["voltou"] += 1
		ruim = true
		if caidos > int(r["caidos_no_minimo"]):
			resumo["derrubou_na_volta"] += 1
	if r["fosso"]:
		resumo["voltou_fosso"] += 1
		ruim = true
	if r["parada"]:
		resumo["parada_na_pista"] += 1
		ruim = true
	if j.canaleta:
		resumo["canaletas"] += 1
		if caidos > 0:
			# bola de canaleta (planejada para 0) não pode derrubar pino
			resumo["canaleta_derrubou"] += 1
			ruim = true
	if ruim:
		r["batidas"] = _batidas.duplicate()
		problemas.append(r.duplicate())
	feitas += 1
	if feitas % 50 == 0:
		print(feitas, " jogadas ", resumo)
	fase = -1


func _fim() -> void:
	print("RESUMO (%d jogadas): %s" % [total, resumo])
	for p in problemas:
		var bat := []
		for x in p["batidas"]:
			bat.append("%s %s v%s z%.2f y%.2f" % [x[0], x[1], x[2], (x[3] as Vector3).z, (x[3] as Vector3).y])
		print("PROBLEMA %s esp=%d caidos=%d (no ponto mais longe %d) zmin=%.2f volta=%.2f t_volta=%.2f fosso=%s parada=%s fim=%s ymax=%.2f" % [
			p["zona"], p["esperado"], p["caidos"], p["caidos_no_minimo"], p["zmin"], p["volta"], p["t_volta"], p["fosso"], p["parada"],
			str(p["bola_fim"]), p["ymax_depois"]])
		print("   batidas: ", PoolStringArray(bat).join(" | "))
	print("BOLA_VOLTA OK")
	get_tree().quit()
