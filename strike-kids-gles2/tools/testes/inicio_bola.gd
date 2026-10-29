extends Node

## TESTE: a MÁQUINA SEM BOTÕES - a bola é o START (só no PC, não vai no APK).
## godot3 --path . -- --inicio-bola=<pasta_das_fotos>
## MODO LIVRE (sem ficha e sem trava: a porta fica sempre aberta):
##  * 1 bola na espera (direita) = 1 jogador com a MIA (o lado escolhe); a
##    mesma bola passando por outro sensor não vira 2 jogadores; a Mia
##    confirma sozinha e a partida chega na 1ª jogada;
##  * 2 bolas = 2 jogadores (Bob x Mia); no fim de jogo a porta continua
##    aberta e a bola começa outra partida;
##  * bola no MEIO: ninguém escolhido; a bola na esquerda escolhe o Bob;
##    sem bola nenhuma o jogo SORTEIA;
##  * a bola interrompe a demonstração (bola rolando) e começa.
## MODO FICHAS:
##  * sem ficha: trava FECHADA, "INSIRA FICHA", a bola não começa;
##  * 1 ficha: a trava ABRE, "ROLE A BOLA!"; a bola começa com 1 jogador
##    (sem a tela "QUANTOS VÃO JOGAR?"), o lado escolhe o amigo, gasta a
##    ficha e a trava fecha de novo na espera;
##  * 2 fichas: "BOB x MIA" e a bola começa com os 2;
##  * 3 fichas: 2 jogadores e sobra 1 - no fim de jogo a trava fica aberta
##    e a bola começa outra (1 jogador); sem ficha no fim, fecha e a ficha
##    no fim abre.
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


func _tecla(scancode: int) -> void:
	var k := InputEventKey.new()
	k.scancode = scancode
	k.physical_scancode = k.scancode
	k.pressed = true
	Input.parse_input_event(k)
	yield(esperar(0.1), "completed")
	var k2: InputEventKey = k.duplicate()
	k2.pressed = false
	Input.parse_input_event(k2)


## A bola passando num sensor (A S D F G = Z X C V B).
func bola(zona: String) -> void:
	var teclas := {"Z": KEY_A, "X": KEY_S, "C": KEY_D, "V": KEY_F, "B": KEY_G}
	yield(_tecla(teclas[zona]), "completed")


## Uma ficha no moedeiro (tecla 5). Depois espera um pouco: a mesma tecla
## de novo em menos de 120 ms é repique do contato e não conta.
func ficha() -> void:
	yield(_tecla(KEY_5), "completed")
	yield(esperar(0.2), "completed")


func voltar_atracao() -> void:
	principal._atracao()
	yield(esperar(0.6), "completed")


## Espera a 1ª jogada e confere quem joga.
func conferir_partida(onde: String, quem: Array) -> void:
	if not yield(esperar_estado("PRONTO", 40.0), "completed"):
		erro("%s: não chegou na 1ª jogada" % onde)
		return
	var lista := []
	for j in principal.placar.jogadores:
		lista.append(j["personagem"])
	if quem.empty():
		if lista.size() != 1:
			erro("%s: placar %s" % [onde, str(lista)])
		else:
			print("BOLA OK %s (sorteou: %s)" % [onde, lista[0]])
	elif lista != quem:
		erro("%s: placar %s (esperava %s)" % [onde, str(lista), str(quem)])
	else:
		print("BOLA OK %s %s" % [onde, str(lista)])


## A espera: trava aberta ou fechada e o que o botão amarelo pede.
func conferir_espera(onde: String, aberta: bool, texto: String, sub := "") -> void:
	var hud = principal.hud
	if ArduinoBridge.porta_quer != aberta:
		erro("%s: trava %s" % [onde, "fechada" if aberta else "aberta"])
	if hud._aperte.text != texto:
		erro("%s: botão '%s' (esperava '%s')" % [onde, hud._aperte.text, texto])
	if sub != "" and hud._aperte_sub.text != sub:
		erro("%s: embaixo '%s' (esperava '%s')" % [onde, hud._aperte_sub.text, sub])


func _rodar() -> void:
	for c in ["modo_livre", "creditos_por_partida"]:
		_antes[c] = Ajustes.valor("jogo", c)
	Ajustes.definir("jogo", "modo_livre", true)
	Ajustes.definir("jogo", "creditos_por_partida", 1)
	Ajustes.creditos = 0
	var t := 0.0
	while principal._preparando and t < 180.0:
		yield(get_tree(), "idle_frame")
		t += get_process_delta_time()
	yield(voltar_atracao(), "completed")
	var hud = principal.hud

	# ================================================ MODO LIVRE (sem trava)
	# ------------------------------------------------ 1 bola na direita = MIA
	conferir_espera("livre", true, "ROLE A BOLA!", "ESQUERDA = BOB  ·  DIREITA = MIA")
	yield(foto("livre_espera"), "completed")
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
	yield(foto("livre_jogadores"), "completed")
	if not yield(esperar_estado("PERSONAGEM", 9.0), "completed"):
		erro("1 bola não foi para a escolha do amigo")
	else:
		yield(esperar(0.3), "completed")
		if principal._destaque != 1:
			erro("bola na direita não escolheu a Mia (destaque %d)" % principal._destaque)
		yield(foto("livre_mia_pela_direita"), "completed")
		# outra bola depois de escolhido não troca
		yield(bola("Z"), "completed")
		yield(esperar(0.2), "completed")
		if principal._destaque != 1:
			erro("a bola depois da escolha trocou o amigo")
		yield(conferir_partida("livre 1 jogador pela direita", ["mia"]), "completed")
	yield(voltar_atracao(), "completed")

	# ------------------------------------------------ 2 bolas = BOB x MIA
	yield(bola("C"), "completed")
	if not yield(esperar_estado("JOGADORES", 0.6), "completed"):
		erro("bola no meio não começou")
	yield(esperar(2.0), "completed")
	yield(bola("X"), "completed")
	yield(esperar(0.3), "completed")
	if principal._escolha_n != 2:
		erro("a 2ª bola não fez 2 jogadores")
	yield(conferir_partida("livre 2 bolas", ["bob", "mia"]), "completed")
	if _estado() == "PRONTO":
		# fim de jogo: a porta continua aberta e a bola começa outra
		principal._fim_de_jogo()
		yield(esperar(0.5), "completed")
		if not ArduinoBridge.porta_quer:
			erro("livre: porta fechou no fim de jogo")
		yield(bola("C"), "completed")
		yield(esperar(0.3), "completed")
		if _estado() != "FIM":
			erro("bola logo no começo do fim de jogo já começou")
		yield(esperar(2.6), "completed")
		var ap = hud._fim.find_node("aperte", true, false)
		if ap == null or not str(ap.text).begins_with("ROLE A BOLA"):
			erro("fim de jogo sem 'ROLE A BOLA' (%s)" % ("" if ap == null else ap.text))
		yield(bola("Z"), "completed")
		if not yield(esperar_estado("JOGADORES", 0.6), "completed"):
			erro("a bola no fim de jogo não começou outra")
		else:
			print("BOLA OK fim de jogo (livre)")
	yield(voltar_atracao(), "completed")

	# ------------------------------------------------ bola no meio: escolhe pela esquerda
	yield(bola("C"), "completed")
	if not yield(esperar_estado("PERSONAGEM", 9.0), "completed"):
		erro("bola no meio: não foi para a escolha do amigo")
	else:
		yield(esperar(0.6), "completed")
		if principal._destaque != -1:
			erro("bola no meio já escolheu (destaque %d)" % principal._destaque)
		yield(foto("livre_meio_escolha"), "completed")
		yield(esperar(1.2), "completed")
		yield(bola("X"), "completed")
		yield(esperar(0.2), "completed")
		if principal._destaque != 0:
			erro("bola na esquerda não escolheu o Bob")
		yield(conferir_partida("livre meio e depois esquerda", ["bob"]), "completed")
	yield(voltar_atracao(), "completed")

	# ------------------------------------------------ bola no meio e mais nada: sorteio
	yield(bola("C"), "completed")
	if not yield(esperar_estado("PERSONAGEM", 9.0), "completed"):
		erro("sorteio: não foi para a escolha do amigo")
	else:
		t = 0.0
		while principal._destaque < 0 and t < 14.0:
			yield(get_tree(), "idle_frame")
			t += get_process_delta_time() / max(Engine.time_scale, 0.01)
		if principal._destaque < 0:
			erro("sem bola o jogo não sorteou")
		else:
			print("SORTEIO em %.1f s" % t)
			yield(foto("livre_sorteio"), "completed")
		yield(conferir_partida("livre sorteio", []), "completed")
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

	# ================================================ MODO FICHAS
	Ajustes.definir("jogo", "modo_livre", false)
	Ajustes.creditos = 0
	yield(voltar_atracao(), "completed")
	# ------------------------------------------------ sem ficha: trava fechada
	conferir_espera("sem ficha", false, "INSIRA FICHA")
	yield(foto("fichas_sem_ficha"), "completed")
	yield(bola("C"), "completed")
	yield(esperar(0.5), "completed")
	if _estado() != "ATRACAO":
		erro("sem ficha: a bola começou")
	# ------------------------------------------------ 1 ficha = 1 jogador (lado escolhe)
	yield(ficha(), "completed")
	yield(esperar(0.3), "completed")
	conferir_espera("1 ficha", true, "ROLE A BOLA!", "ESQUERDA = BOB  ·  DIREITA = MIA")
	yield(foto("fichas_1_ficha"), "completed")
	yield(bola("V"), "completed")
	yield(esperar(0.3), "completed")
	if _estado() == "JOGADORES":
		erro("1 ficha: mostrou 'QUANTOS VÃO JOGAR?'")
	if not yield(esperar_estado("PERSONAGEM", 1.0), "completed"):
		erro("1 ficha: a bola não foi para a escolha do amigo")
	elif principal._destaque != 1:
		erro("1 ficha: bola na direita não escolheu a Mia")
	yield(conferir_partida("1 ficha pela direita", ["mia"]), "completed")
	if Ajustes.creditos != 0:
		erro("1 ficha: sobrou crédito (%d)" % Ajustes.creditos)
	yield(voltar_atracao(), "completed")
	conferir_espera("ficha gasta", false, "INSIRA FICHA")
	# ------------------------------------------------ 2 fichas = BOB x MIA
	yield(ficha(), "completed")
	yield(ficha(), "completed")
	yield(esperar(0.3), "completed")
	conferir_espera("2 fichas", true, "ROLE A BOLA!", "2 FICHAS: BOB x MIA!")
	cartao = hud._jog_cartoes[1].get_node("vezes")
	if cartao.text != "2 FICHAS":
		erro("cartão dos 2 jogadores no modo fichas: '%s'" % cartao.text)
	yield(foto("fichas_2_fichas"), "completed")
	yield(bola("Z"), "completed")
	if not yield(esperar_estado("JOGADORES", 0.6), "completed"):
		erro("2 fichas: a bola não começou")
	elif principal._escolha_n != 2:
		erro("2 fichas: não foram 2 jogadores")
	yield(conferir_partida("2 fichas", ["bob", "mia"]), "completed")
	if Ajustes.creditos != 0:
		erro("2 fichas: sobrou crédito (%d)" % Ajustes.creditos)
	yield(voltar_atracao(), "completed")
	# ------------------------------------------------ 3 fichas: sobra 1 para a próxima
	for i in 3:
		yield(ficha(), "completed")
	yield(bola("C"), "completed")
	yield(conferir_partida("3 fichas (2 jogadores)", ["bob", "mia"]), "completed")
	if Ajustes.creditos != 1:
		erro("3 fichas: créditos %d (esperava 1)" % Ajustes.creditos)
	if _estado() == "PRONTO":
		principal._fim_de_jogo()
		yield(esperar(2.8), "completed")
		if not ArduinoBridge.porta_quer:
			erro("fim com ficha sobrando: trava fechou")
		yield(bola("B"), "completed")
		if not yield(esperar_estado("PERSONAGEM", 1.0), "completed"):
			erro("fim com ficha sobrando: a bola não começou 1 jogador")
		else:
			yield(conferir_partida("ficha que sobrou", ["mia"]), "completed")
	# ------------------------------------------------ fim sem ficha: fecha; a ficha abre
	if _estado() == "PRONTO":
		principal._fim_de_jogo()
		yield(esperar(2.8), "completed")
		if ArduinoBridge.porta_quer:
			erro("fim sem ficha: trava aberta")
		var ap2 = hud._fim.find_node("aperte", true, false)
		if ap2 == null or not str(ap2.text).begins_with("INSIRA FICHA"):
			erro("fim sem ficha: '%s'" % ("" if ap2 == null else ap2.text))
		yield(foto("fichas_fim_sem_ficha"), "completed")
		yield(bola("C"), "completed")
		yield(esperar(0.3), "completed")
		if _estado() != "FIM":
			erro("fim sem ficha: a bola começou")
		yield(ficha(), "completed")
		yield(esperar(0.3), "completed")
		if not ArduinoBridge.porta_quer:
			erro("ficha no fim de jogo: a trava não abriu")
		yield(bola("Z"), "completed")
		if not yield(esperar_estado("PERSONAGEM", 1.0), "completed"):
			erro("ficha no fim de jogo: a bola não começou")
		elif principal._destaque != 0:
			erro("ficha no fim de jogo: bola na esquerda não escolheu o Bob")
		else:
			print("BOLA OK ficha no fim de jogo")
	yield(voltar_atracao(), "completed")

	for c in _antes:
		Ajustes.definir("jogo", c, _antes[c])
	Ajustes.creditos = 0
	yield(esperar(0.5), "completed")
	if erros == 0:
		print("INICIO BOLA OK")
	else:
		print("INICIO BOLA COM %d ERROS" % erros)
	get_tree().quit()
