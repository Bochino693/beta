extends Node

## TESTE: modo livre começando pela BOLA (7.5, máquina sem botões; só no
## PC, não vai no APK).
## godot3 --path . -- --inicio-bola=<pasta_das_fotos>
##  * 1 bola na espera (direita) = 1 jogador com a Mia já escolhida; a
##    mesma bola passando por outro sensor não vira 2 jogadores; rolar na
##    esquerda troca para o Bob e ele confirma sozinho;
##  * 2 bolas = 2 jogadores (Bob x Mia), a partida chega na 1ª jogada;
##  * a bola interrompe a demonstração (bola rolando) e começa;
##  * no fim de jogo a bola começa outra partida;
##  * com o ajuste desligado a bola não começa e a porta fica fechada.
## Imprime "INICIO BOLA OK" no fim (ou as linhas "ERRO ...").

var pasta := "user://inicio_bola"
var principal: Node
var erros := 0
var n_foto := 0
var _antes := {}


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	for a in OS.get_cmdline_args():
		if a.begins_with("--inicio-bola="):
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


## A bola passando num sensor (A S D F G = Z X C V B).
func bola(zona: String) -> void:
	var teclas := {"Z": KEY_A, "X": KEY_S, "C": KEY_D, "V": KEY_F, "B": KEY_G}
	var k := InputEventKey.new()
	k.scancode = teclas[zona]
	k.physical_scancode = k.scancode
	k.pressed = true
	Input.parse_input_event(k)
	yield(esperar(0.1), "completed")
	var k2: InputEventKey = k.duplicate()
	k2.pressed = false
	Input.parse_input_event(k2)


func voltar_atracao() -> void:
	principal._atracao()
	yield(esperar(0.6), "completed")


func _rodar() -> void:
	for c in ["modo_livre", "inicio_bola"]:
		_antes[c] = Ajustes.valor("jogo", c)
	Ajustes.definir("jogo", "modo_livre", true)
	Ajustes.definir("jogo", "inicio_bola", true)
	var t := 0.0
	while principal._preparando and t < 180.0:
		yield(get_tree(), "idle_frame")
		t += get_process_delta_time()
	yield(voltar_atracao(), "completed")
	var hud = principal.hud

	# ------------------------------------------------ 1 bola = 1 jogador (Mia)
	if hud._aperte.text != "ROLE A BOLA!" or not hud._aperte_sub.visible:
		erro("espera sem 'ROLE A BOLA!' ('%s')" % hud._aperte.text)
	if not ArduinoBridge.porta_quer:
		erro("porta fechada na espera do modo pela bola")
	yield(foto("espera_role_a_bola"), "completed")
	yield(bola("B"), "completed")
	if not yield(esperar_estado("JOGADORES", 0.6), "completed"):
		erro("a bola na espera não começou")
	# a MESMA bola passando no sensor vizinho logo depois: continua 1 jogador
	yield(esperar(0.4), "completed")
	yield(bola("V"), "completed")
	yield(esperar(0.5), "completed")
	if principal._escolha_n != 1:
		erro("a mesma bola (2 sensores) virou 2 jogadores")
	var cartao: Label = hud._jog_cartoes[1].get_node("vezes")
	if cartao.text != "2 BOLAS":
		erro("cartão dos 2 jogadores: '%s'" % cartao.text)
	yield(foto("jogadores_pela_bola"), "completed")
	if not yield(esperar_estado("PERSONAGEM", 9.0), "completed"):
		erro("1 bola não foi para a escolha do amigo")
	else:
		yield(esperar(0.8), "completed")
		if principal._destaque != 1:
			erro("bola na direita não escolheu a Mia (destaque %d)" % principal._destaque)
		yield(foto("amigo_mia_pela_bola"), "completed")
		yield(bola("Z"), "completed")
		yield(esperar(0.4), "completed")
		if principal._destaque != 0:
			erro("bola na esquerda não trocou para o Bob")
		# sem mais bola: confirma sozinho
		t = 0.0
		while _estado() == "PERSONAGEM" and t < 8.0:
			yield(get_tree(), "idle_frame")
			t += get_process_delta_time() / max(Engine.time_scale, 0.01)
		if _estado() == "PERSONAGEM":
			erro("a escolha do amigo não confirmou sozinha")
		else:
			print("AMIGO confirmou sozinho em %.1f s" % t)
			if not yield(esperar_estado("PRONTO", 40.0), "completed"):
				erro("1 jogador: não chegou na 1ª jogada")
			elif principal.placar.jogadores.size() != 1 or principal.placar.jogadores[0]["personagem"] != "bob":
				erro("1 jogador: placar %s" % str(principal.placar.jogadores))
			else:
				print("BOLA OK 1 jogador (Mia pela direita, trocou para o Bob)")
	yield(voltar_atracao(), "completed")

	# ------------------------------------------------ 2 bolas = 2 jogadores
	yield(bola("C"), "completed")
	if not yield(esperar_estado("JOGADORES", 0.6), "completed"):
		erro("bola no meio não começou")
	yield(esperar(2.0), "completed")
	yield(bola("X"), "completed")
	yield(esperar(0.3), "completed")
	if principal._escolha_n != 2:
		erro("a 2ª bola não fez 2 jogadores")
	yield(foto("jogadores_2_bolas"), "completed")
	if not yield(esperar_estado("PRONTO", 40.0), "completed"):
		erro("2 jogadores: não chegou na 1ª jogada")
	elif principal.placar.jogadores.size() != 2:
		erro("2 jogadores: placar com %d" % principal.placar.jogadores.size())
	else:
		print("BOLA OK 2 jogadores")
		# fim de jogo: a porta continua aberta e a bola começa outra
		principal._fim_de_jogo()
		yield(esperar(0.5), "completed")
		if not ArduinoBridge.porta_quer:
			erro("porta fechou no fim de jogo do modo pela bola")
		yield(bola("C"), "completed")
		yield(esperar(0.3), "completed")
		if _estado() != "FIM":
			erro("bola logo no começo do fim de jogo já começou")
		yield(esperar(2.6), "completed")
		var ap = hud._fim.find_node("aperte", true, false)
		if ap == null or not str(ap.text).begins_with("ROLE A BOLA"):
			erro("fim de jogo sem 'ROLE A BOLA' (%s)" % ("" if ap == null else ap.text))
		yield(foto("fim_role_a_bola"), "completed")
		yield(bola("Z"), "completed")
		if not yield(esperar_estado("JOGADORES", 0.6), "completed"):
			erro("a bola no fim de jogo não começou outra")
		else:
			print("BOLA OK fim de jogo")
	yield(voltar_atracao(), "completed")

	# ------------------------------------------------ demonstração
	Jogada.forcar().push_front(10)
	principal._jogada_demo()
	if not yield(esperar_estado("ROLANDO", 25.0), "completed"):
		erro("demonstração não chegou na bola rolando")
	else:
		yield(bola("V"), "completed")
		if not yield(esperar_estado("JOGADORES", 0.6), "completed"):
			erro("a bola não interrompeu a demonstração")
		elif principal.demo or principal._quem_bola != "mia":
			erro("demonstração: demo=%s quem=%s" % [str(principal.demo), principal._quem_bola])
		else:
			print("BOLA OK demonstração")
	yield(voltar_atracao(), "completed")

	# ------------------------------------------------ ajuste desligado
	Ajustes.definir("jogo", "inicio_bola", false)
	yield(voltar_atracao(), "completed")
	if ArduinoBridge.porta_quer:
		erro("ajuste desligado: porta aberta na espera")
	if hud._aperte.text != "APERTE START":
		erro("ajuste desligado: '%s'" % hud._aperte.text)
	yield(bola("C"), "completed")
	yield(esperar(0.5), "completed")
	if _estado() != "ATRACAO":
		erro("ajuste desligado: a bola começou")
	else:
		print("BOLA OK desligado (só o START)")
	yield(foto("espera_aperte_start"), "completed")

	for c in _antes:
		Ajustes.definir("jogo", c, _antes[c])
	yield(esperar(0.5), "completed")
	if erros == 0:
		print("INICIO BOLA OK")
	else:
		print("INICIO BOLA COM %d ERROS" % erros)
	get_tree().quit()
