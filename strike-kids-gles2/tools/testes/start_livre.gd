extends Node

## TESTE: START e FICHA valem a qualquer momento da espera (só no PC, não vai
## no APK).
## godot3 --path . -- --start-livre=<pasta_das_fotos>
##  * na capa (o jogo montando): a ficha conta e o START fica guardado;
##  * em vários pontos da abertura;
##  * em cada etapa da demonstração (os bichinhos jogando): antes de jogar,
##    arremesso, bola rolando, resultado e replay do strike — sem crédito o
##    START não vale (INSIRA FICHA), com a ficha vale;
##  * depois de interromper a demonstração, uma partida de verdade anda.
## Imprime "START LIVRE OK" no fim (ou as linhas "ERRO ...").

var pasta := "user://start_livre"
var principal: Node
var erros := 0
var n_foto := 0
var _livre_antes = null


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	for a in OS.get_cmdline_args():
		if a.begins_with("--start-livre="):
			pasta = a.substr(14)
	Directory.new().make_dir_recursive(pasta)
	principal = get_parent()
	_rodar()


func _estado() -> String:
	return principal.E.keys()[principal.estado]


func erro(txt: String) -> void:
	erros += 1
	print("ERRO ", txt, "  (estado ", _estado(), ")")


func foto(nome: String) -> void:
	yield(VisualServer, "frame_post_draw")
	var img := get_viewport().get_texture().get_data()
	img.flip_y()
	n_foto += 1
	img.save_png("%s/%02d_%s.png" % [pasta, n_foto, nome])


func esperar(seg: float) -> void:
	var t := 0.0
	while true:
		yield(get_tree(), "idle_frame")
		t += get_process_delta_time() / max(Engine.time_scale, 0.01)
		if t >= seg:
			return


func esperar_estado(nome: String, limite := 20.0) -> bool:
	var t := 0.0
	yield(get_tree(), "idle_frame")
	while _estado() != nome:
		yield(get_tree(), "idle_frame")
		t += get_process_delta_time() / max(Engine.time_scale, 0.01)
		if t > limite:
			return false
	return true


func apertar(acao: String) -> void:
	var teclas := {"input_start": KEY_1, "input_c": KEY_D, "input_credit": KEY_5}
	var k := InputEventKey.new()
	k.scancode = teclas[acao]
	k.physical_scancode = k.scancode
	k.pressed = true
	Input.parse_input_event(k)
	yield(esperar(0.1), "completed")
	var k2: InputEventKey = k.duplicate()
	k2.pressed = false
	Input.parse_input_event(k2)


## Saiu da espera direitinho: na escolha dos jogadores, sem nada da
## abertura/demonstração sobrando.
func conferir_escolha(onde: String) -> void:
	if not yield(esperar_estado("JOGADORES", 0.6), "completed"):
		erro("%s: o START não valeu" % onde)
		return
	yield(esperar(0.6), "completed")
	var hud = principal.hud
	if principal.demo:
		erro("%s: ainda em demonstração" % onde)
	if Sons.mudo_demo:
		erro("%s: som ainda mudo da demonstração" % onde)
	if principal._lenta_t0 >= 0:
		erro("%s: câmera lenta continuou" % onde)
	if principal._replay_ativo or principal.bola.visible:
		erro("%s: replay/bola sobrando" % onde)
	if principal.mundo.bola_z < 99.0:
		erro("%s: brilho da bola parado na pista" % onde)
	if hud._tarja_cima.rect_size.y > 1.0 or hud._marca_tela != null:
		erro("%s: faixas de cinema/marca na tela" % onde)
	if hud._atracao.visible:
		erro("%s: tela de espera por cima da escolha" % onde)
	print("START OK ", onde)


func voltar_atracao() -> void:
	principal._atracao()
	yield(esperar(0.5), "completed")


func _rodar() -> void:
	# ---------------------------------------------------------------- capa
	_livre_antes = Ajustes.valor("jogo", "modo_livre")
	Ajustes.definir("jogo", "modo_livre", false)
	Ajustes.creditos = 0
	yield(esperar(0.3), "completed")
	if not principal._preparando:
		erro("a capa acabou antes do teste")
	yield(apertar("input_credit"), "completed")
	if Ajustes.creditos != 1:
		erro("ficha na capa não contou (%d)" % Ajustes.creditos)
	else:
		print("FICHA OK capa")
	yield(apertar("input_start"), "completed")
	if not principal._preparando:
		erro("a capa acabou antes do START")
	# (o estado já nasce ABERTURA: espera a capa sair)
	var t := 0.0
	while principal._preparando and t < 180.0:
		yield(get_tree(), "idle_frame")
		t += get_process_delta_time()
	if principal._preparando:
		erro("a capa não saiu")
	print("capa saiu em %.1f s" % t)
	yield(conferir_escolha("capa"), "completed")
	yield(foto("escolha_da_capa"), "completed")
	Ajustes.definir("jogo", "modo_livre", true)

	# ---------------------------------------------------------------- abertura
	for d in [0.05, 0.3, 1.4, 2.6, 4.2, 6.0]:
		principal._abertura()
		yield(esperar(d), "completed")
		if _estado() != "ABERTURA":
			print("(abertura já tinha acabado em %.2f s)" % d)
			yield(voltar_atracao(), "completed")
			continue
		yield(apertar("input_start"), "completed")
		yield(conferir_escolha("abertura %.2f s" % d), "completed")
		if d == 0.3:
			yield(foto("escolha_da_abertura"), "completed")
		yield(voltar_atracao(), "completed")
	# ficha no meio da abertura aparece na tela
	principal._abertura()
	yield(esperar(1.0), "completed")
	Ajustes.definir("jogo", "modo_livre", false)
	Ajustes.creditos = 0
	yield(apertar("input_credit"), "completed")
	if Ajustes.creditos != 1 or principal.hud._creditos.text != "CRÉDITOS: 1":
		erro("ficha na abertura: %d / '%s'" % [Ajustes.creditos, principal.hud._creditos.text])
	else:
		print("FICHA OK abertura")
	yield(voltar_atracao(), "completed")

	# ---------------------------------------------------------------- demonstração
	# (a da bola rolando por último: dela segue a partida de verdade)
	for etapa in ["DEMO", "ARREMESSO", "RESULTADO", "REPLAY", "ROLANDO"]:
		Ajustes.creditos = 0
		principal._atualizar_atracao()
		# o strike garante o replay
		Jogada.forcar().push_front(10)
		principal._jogada_demo()
		if not yield(esperar_estado(etapa, 25.0), "completed"):
			erro("demonstração não chegou em %s" % etapa)
			yield(voltar_atracao(), "completed")
			continue
		if not principal.demo:
			erro("%s sem demonstração" % etapa)
		yield(esperar(0.25), "completed")
		# sem crédito: não começa
		yield(apertar("input_start"), "completed")
		yield(esperar(0.2), "completed")
		if _estado() == "JOGADORES":
			erro("demonstração %s: começou sem crédito" % etapa)
			yield(voltar_atracao(), "completed")
			continue
		# a ficha conta e aparece na tela
		yield(apertar("input_credit"), "completed")
		if Ajustes.creditos != 1 or principal.hud._creditos.text != "CRÉDITOS: 1":
			erro("ficha na demonstração %s: %d / '%s'" % [etapa, Ajustes.creditos, principal.hud._creditos.text])
		else:
			print("FICHA OK demonstração ", etapa)
		if etapa == "ROLANDO":
			yield(foto("demo_rolando_com_ficha"), "completed")
		if not principal.demo:
			# (a demonstração acabou sozinha nesse meio tempo)
			print("(demonstração %s acabou antes do START)" % etapa)
		yield(apertar("input_start"), "completed")
		yield(conferir_escolha("demonstração " + etapa), "completed")
		if etapa == "REPLAY":
			yield(foto("escolha_do_replay"), "completed")
		if etapa != "ROLANDO":
			yield(voltar_atracao(), "completed")

	# ---------------------------------------------------------------- partida
	# (veio da demonstração interrompida com a bola rolando) 2 jogadores
	if _estado() == "JOGADORES":
		yield(apertar("input_start"), "completed")
		if not yield(esperar_estado("PRONTO", 40.0), "completed"):
			erro("a partida não chegou na primeira jogada")
		else:
			t = 0.0
			while not principal._liberada and t < 6.0:
				yield(get_tree(), "idle_frame")
				t += get_process_delta_time() / max(Engine.time_scale, 0.01)
			yield(foto("partida_pronto"), "completed")
			yield(apertar("input_c"), "completed")
			if not yield(esperar_estado("ROLANDO", 5.0), "completed"):
				erro("a jogada da partida não saiu")
			elif not yield(esperar_estado("RESULTADO", 20.0), "completed"):
				erro("a jogada da partida não terminou")
			else:
				if principal.demo:
					erro("partida marcada como demonstração")
				print("PARTIDA OK  pinos de pé: ", principal.pinos.em_pe().size(), "  créditos: ", Ajustes.creditos)
	else:
		erro("não ficou na escolha depois da demonstração")

	Ajustes.definir("jogo", "modo_livre", _livre_antes)
	Ajustes.creditos = 0
	yield(esperar(0.5), "completed")
	if erros == 0:
		print("START LIVRE OK")
	else:
		print("START LIVRE COM %d ERROS" % erros)
	get_tree().quit()
