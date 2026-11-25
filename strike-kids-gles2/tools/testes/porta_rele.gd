extends Node

## TESTE DA TRAVA (RELÉ DE PULSO), DAS FICHAS E DO MENU, COM O JOGO DE VERDADE
## (só no PC, não vai no APK): um Arduino de mentira no lugar do plugin USB,
## com a mesma lógica do firmware 5 (um pulso troca a porta, fila de fichas,
## vigia do jogo), contando CADA pulso do relé.
##   godot3 --path . -- --porta-rele=<caso>
## casos (o modo do jogo e como a porta ficou guardada no Arduino ao ligar):
##   livre_aberta    liga e joga no modo livre: NENHUM pulso
##   livre_fechada   modo livre com a porta fechada: UM pulso (abre) e só
##   fichas_aberta   modo fichas sem crédito com a porta aberta: UM pulso (fecha)
##   fichas_fechada  modo fichas sem crédito: nenhum pulso ao ligar; depois o
##                   roteiro inteiro - ficha abre, partida, fim fecha, crédito
##                   parado fecha, START abre, menu do operador, teste da
##                   porta, zerar créditos, Arduino reiniciando, ficha
##                   repetida, ficha junto com o fim da partida
## Imprime "PORTA RELE OK <caso>" no fim (ou as linhas "ERRO ...").


## O Arduino de mentira: os mesmos métodos do plugin StrikeSerial.
class ArduinoDeMentira extends Reference:
	const FIRME_MS := 150
	const PULSO_MS := 200
	const DESCANSO_MS := 1000
	const SEM_JOGO_MS := 30000
	var aberto := false
	var com_permissao := true
	var pedidos_permissao := 0
	var rx := ""
	var recebidos := []        # tudo o que o jogo mandou
	var pulsos := 0
	var diario := []           # "ms abre|fecha"
	var rele_aberta := false   # a posição guardada (EEPROM)
	var pedida := false
	var pedido_em := 0
	var pulso_ate := 0
	var descanso_ate := 0
	var porta_logica := false
	var jogo_falou := false
	var ultimo_cmd := 0
	var sync := false
	var fila := []             # números das fichas ainda não confirmadas
	var proxima := 0
	var avisada_em := -100000
	var ola_em := 0
	var reinicios := 0
	var perder_proximo_ok := false   # a confirmação da ficha se perde uma vez

	func listar() -> String:
		return "/dev/bus/usb/001/002|1A86:7523|ch34x|%s|USB Serial\n" % ("1" if com_permissao else "0")

	func permissao_pendente() -> bool:
		return false

	func pedir_permissao(_nome) -> String:
		pedidos_permissao += 1
		return "pedido"

	func abrir(_nome, _baud) -> void:
		aberto = true
		reiniciar()   # o Uno reinicia quando o jogo abre o USB

	func reiniciar() -> void:
		reinicios += 1
		sync = false
		jogo_falou = false
		pedida = rele_aberta
		porta_logica = rele_aberta
		pulso_ate = 0
		descanso_ate = 0
		avisada_em = -100000
		ola_em = Time.get_ticks_msec() + 40

	func estado() -> String:
		return "aberta" if aberto else "fechada"

	func erro() -> String:
		return ""

	func fechar() -> void:
		aberto = false

	func relatorio() -> String:
		return ""

	func ficha() -> void:
		fila.append(proxima)
		proxima += 1

	func escrever(linha: String) -> bool:
		recebidos.append(linha)
		var agora := Time.get_ticks_msec()
		ultimo_cmd = agora
		jogo_falou = true
		if linha == "PING":
			rx += "PONG:STRIKE_KIDS:5\n"
		elif linha == "PORTA:ABRE" or linha == "PORTA:FECHA":
			var abrir := linha == "PORTA:ABRE"
			porta_logica = abrir
			if abrir != pedida:
				pedida = abrir
				pedido_em = agora
			if abrir == rele_aberta:
				rx += "PORTA:ABERTA\n" if abrir else "PORTA:FECHADA\n"
		elif linha == "PORTA?":
			rx += "PORTA:ABERTA\n" if rele_aberta else "PORTA:FECHADA\n"
		elif linha == "PORTA:ACERTA":
			rele_aberta = not rele_aberta
			pedido_em = agora
			rx += "PORTA:ABERTA\n" if rele_aberta else "PORTA:FECHADA\n"
		elif linha == "FICHAS:SYNC":
			sync = true
			avisada_em = -100000
		elif linha.begins_with("FICHA:OK:"):
			if perder_proximo_ok:
				perder_proximo_ok = false
			elif not fila.empty() and int(linha.substr(9)) == int(fila[0]):
				fila.pop_front()
				avisada_em = -100000
		elif linha == "INFO?":
			rx += "INFO:STRIKE_KIDS:5:LEDS=1:SERVO=0:RELE=8:PONTE_H=0:REPOUSO=HHHHH:PULSO=1:FILA=%d\n" % fila.size()
		return true

	func ler() -> String:
		var agora := Time.get_ticks_msec()
		if ola_em > 0 and agora >= ola_em:
			ola_em = 0
			rx += "OLA:STRIKE_KIDS:5\n"
		# o relé de pulso (o tickRele do firmware)
		if pulso_ate > 0:
			if agora >= pulso_ate:
				pulso_ate = 0
				descanso_ate = agora + DESCANSO_MS
		elif agora >= descanso_ate and pedida != rele_aberta and agora - pedido_em >= FIRME_MS:
			pulso_ate = agora + PULSO_MS
			rele_aberta = pedida
			pulsos += 1
			diario.append("%d %s" % [agora, "abre" if pedida else "fecha"])
			rx += "PORTA:ABERTA\n" if porta_logica else "PORTA:FECHADA\n"
		# fichas
		if sync and not fila.empty() and agora - avisada_em >= 500:
			avisada_em = agora
			rx += "FICHA:%d\n" % int(fila[0])
		# vigia do jogo
		if jogo_falou and porta_logica and agora - ultimo_cmd > SEM_JOGO_MS:
			porta_logica = false
			if pedida:
				pedida = false
				pedido_em = agora
			rx += "AVISO:SEM_JOGO\n"
		var t := rx
		rx = ""
		return t


var caso := "fichas_fechada"
var principal: Node
var ard: ArduinoDeMentira
var erros := 0
var _antes := {}


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	for a in OS.get_cmdline_args():
		if a.begins_with("--porta-rele="):
			caso = a.substr(13)
	principal = get_parent()
	for chave in ["modo_livre", "creditos_por_partida", "fechar_sem_jogar", "demo"]:
		_antes[chave] = Ajustes.valor("jogo", chave)
	# o modo do jogo e a porta guardada no Arduino, ANTES de o jogo montar
	Ajustes.definir("jogo", "modo_livre", caso.begins_with("livre"))
	Ajustes.definir("jogo", "creditos_por_partida", 1)
	Ajustes.definir("jogo", "fechar_sem_jogar", 3)
	Ajustes.definir("jogo", "demo", false)
	Ajustes.zerar_creditos()
	ard = ArduinoDeMentira.new()
	ard.rele_aberta = caso.ends_with("aberta")
	ArduinoBridge._plugin = ard
	# (a permissão USB "já pedida" de outras rodadas do teste não vale)
	ArduinoBridge._pedidos_salvos = ConfigFile.new()
	ArduinoBridge._fase = "procurando"
	ArduinoBridge._ultima_procura = -100000
	_rodar()


func _estado() -> String:
	return principal.E.keys()[principal.estado]


func erro(txt: String) -> void:
	erros += 1
	print("ERRO ", txt, "  (estado ", _estado(), ", pulsos ", ard.pulsos, " ", ard.diario, ")")


func esperar(seg: float) -> void:
	var fim := Time.get_ticks_msec() + int(seg * 1000.0)
	while Time.get_ticks_msec() < fim:
		yield(get_tree(), "idle_frame")


func esperar_estado(nome: String, limite := 30.0) -> bool:
	var fim := Time.get_ticks_msec() + int(limite * 1000.0)
	yield(get_tree(), "idle_frame")
	while _estado() != nome:
		yield(get_tree(), "idle_frame")
		if Time.get_ticks_msec() > fim:
			return false
	return true


## A porta assenta (pedido firme + pulso + descanso) e confere a conta.
func conferir(onde: String, pulsos: int, aberta: bool) -> void:
	yield(esperar(2.2), "completed")
	if ard.pulsos != pulsos:
		erro("%s: %d pulsos (esperado %d)" % [onde, ard.pulsos, pulsos])
	elif ard.rele_aberta != aberta:
		erro("%s: porta %s (esperado %s)" % [onde, "aberta" if ard.rele_aberta else "fechada", "aberta" if aberta else "fechada"])
	elif ArduinoBridge.porta_aberta != aberta:
		erro("%s: o jogo acha a porta %s" % [onde, "aberta" if ArduinoBridge.porta_aberta else "fechada"])
	else:
		print("PORTA OK %-46s pulsos=%d  %s" % [onde, ard.pulsos, "ABERTA" if aberta else "FECHADA"])


func apertar(acao: String) -> void:
	# (como o ArduinoBridge: o START e a configuração do próprio Arduino)
	ArduinoBridge._pulsar(acao)
	yield(esperar(0.25), "completed")


func ficha() -> void:
	ard.ficha()
	yield(esperar(0.4), "completed")


func _rodar() -> void:
	var livre := caso.begins_with("livre")
	# ---------------------------------------------------------------- ligando
	# o jogo ainda montando (a capa): o Arduino conecta e NADA mexe no relé
	var t0 := Time.get_ticks_msec()
	while principal._preparando and Time.get_ticks_msec() - t0 < 240000:
		yield(get_tree(), "idle_frame")
	if principal._preparando:
		erro("a capa não saiu")
	print("capa saiu em %.1f s; Arduino %s" % [(Time.get_ticks_msec() - t0) / 1000.0, "conectado" if ArduinoBridge.completo() else "NÃO conectou"])
	# (se o jogo montou mais depressa que a conexão, espera ela)
	t0 = Time.get_ticks_msec()
	while not ArduinoBridge.completo() and Time.get_ticks_msec() - t0 < 10000:
		yield(get_tree(), "idle_frame")
	if not ArduinoBridge.completo():
		erro("o Arduino de mentira não conectou: " + ArduinoBridge.status)
	if not "FICHAS:SYNC" in ard.recebidos:
		erro("o jogo não mandou FICHAS:SYNC")
	# a espera decide a porta: livre = aberta, fichas sem crédito = fechada
	var quer := livre
	var n := 0 if ard.rele_aberta == quer else 1
	yield(conferir("ligou (%s)" % caso, n, quer), "completed")
	# ... e fica assim: 12 s de espera sem um pulso
	yield(esperar(12.0), "completed")
	yield(conferir("12 s de espera", n, quer), "completed")

	# ---------------------------------------------------------------- menu
	# entrar e sair do menu do operador não dá pulso
	yield(apertar("input_teste"), "completed")
	yield(esperar(1.0), "completed")
	if not principal.menu_aberto():
		erro("o menu do operador não abriu")
	yield(conferir("menu aberto", n, quer), "completed")
	yield(apertar("input_teste"), "completed")
	yield(esperar(1.0), "completed")
	if principal.menu_aberto():
		erro("o menu do operador não fechou")
	yield(conferir("menu fechado", n, quer), "completed")

	if caso != "fichas_fechada":
		# modo livre: uma partida começa e termina sem pulso
		if livre:
			principal._escolher_jogadores()
			yield(esperar(1.0), "completed")
			yield(conferir("partida no modo livre", n, true), "completed")
			principal._fim_de_jogo()
			yield(conferir("fim da partida no modo livre", n, true), "completed")
			principal._atracao()
			yield(conferir("de volta à espera", n, true), "completed")
		_acabar()
		return

	# ---------------------------------------------------------------- fichas
	# 1 ficha: UM pulso abre
	yield(ficha(), "completed")
	if Ajustes.creditos != 1:
		erro("a ficha não contou (%d)" % Ajustes.creditos)
	yield(conferir("1 ficha: abre", 1, true), "completed")
	# 2a ficha: nada
	yield(ficha(), "completed")
	if Ajustes.creditos != 2:
		erro("a 2a ficha não contou (%d)" % Ajustes.creditos)
	yield(conferir("2a ficha: sem pulso", 1, true), "completed")
	# a partida começa (2 fichas = 2 jogadores) e a porta fica aberta
	yield(apertar("input_start"), "completed")
	yield(esperar(1.5), "completed")
	if _estado() in ["ATRACAO", "ABERTURA", "DEMO"]:
		erro("o START com crédito não começou")
	yield(conferir("partida começando", 1, true), "completed")
	if not yield(esperar_estado("PRONTO", 60.0), "completed"):
		erro("a partida não chegou na primeira jogada")
	if Ajustes.creditos != 0:
		erro("a partida não gastou as 2 fichas (%d)" % Ajustes.creditos)
	yield(conferir("jogando", 1, true), "completed")
	# o menu do operador no meio da partida: sem pulso (e a partida acaba)
	yield(apertar("input_teste"), "completed")
	yield(esperar(1.0), "completed")
	yield(conferir("menu no meio da partida", 1, true), "completed")
	yield(apertar("input_teste"), "completed")
	# saiu do menu para a espera, sem crédito: UM pulso fecha
	yield(conferir("fim (sem crédito): fecha", 2, false), "completed")

	# ---------------------------------------------------------------- fim com crédito
	yield(ficha(), "completed")
	yield(ficha(), "completed")
	yield(ficha(), "completed")
	yield(conferir("3 fichas: abre", 3, true), "completed")
	principal._escolher_jogadores()
	yield(esperar(0.5), "completed")
	principal._comecar(["bob", "mia"])   # gasta 2, sobra 1
	yield(esperar(0.5), "completed")
	principal._fim_de_jogo()
	if Ajustes.creditos != 1:
		erro("devia sobrar 1 crédito (%d)" % Ajustes.creditos)
	yield(conferir("fim com crédito sobrando: fica aberta", 3, true), "completed")
	principal._atracao()
	yield(conferir("espera com crédito", 3, true), "completed")

	# ---------------------------------------------------------------- crédito parado
	# ninguém joga: passado o tempo do menu (3 min), UM pulso fecha
	principal._espera_paga_t = Ajustes.fechar_sem_jogar() - 1.0
	yield(conferir("crédito parado: fecha", 4, false), "completed")
	if Ajustes.creditos != 1:
		erro("o crédito parado sumiu (%d)" % Ajustes.creditos)
	if not principal._trava_dormiu:
		erro("a trava não ficou marcada como fechada pela espera")
	yield(esperar(6.0), "completed")
	yield(conferir("continua fechada", 4, false), "completed")
	# outra ficha acorda: UM pulso abre
	yield(ficha(), "completed")
	yield(conferir("ficha acorda a trava", 5, true), "completed")
	# de novo parado; agora o START acorda e a partida começa
	principal._espera_paga_t = Ajustes.fechar_sem_jogar() - 1.0
	yield(conferir("crédito parado de novo: fecha", 6, false), "completed")
	yield(apertar("input_start"), "completed")
	yield(conferir("START acorda e começa", 7, true), "completed")
	if _estado() in ["ATRACAO", "ABERTURA", "DEMO"]:
		erro("o START com a trava fechada pela espera não começou")
	# (a partida gasta o crédito: de volta à espera sem crédito, fecha)
	principal._atracao()
	yield(conferir("partida largada sem crédito: fecha", 8, false), "completed")
	yield(ficha(), "completed")
	yield(conferir("ficha: abre", 9, true), "completed")

	# ---------------------------------------------------------------- menu: zerar e teste da porta
	var cred := Ajustes.creditos
	if cred < 1:
		erro("devia ter crédito para zerar (%d)" % cred)
	yield(apertar("input_teste"), "completed")
	yield(esperar(1.0), "completed")
	var menu = principal._menu
	if menu == null:
		erro("o menu não abriu para zerar os créditos")
	else:
		# TESTE DA PORTA: entrar não dá pulso; cada OK troca; sair volta
		menu._sel = _item(menu, "porta")
		menu.comando("ok")
		yield(conferir("teste da porta: entrou (sem pulso)", 9, true), "completed")
		menu.comando("ok")
		yield(conferir("teste da porta: fecha", 10, false), "completed")
		menu.comando("ok")
		yield(conferir("teste da porta: abre", 11, true), "completed")
		menu.comando("ok")
		yield(conferir("teste da porta: fecha", 12, false), "completed")
		# ACERTAR: o Arduino passa a lembrar "aberta" e dá o pulso que fecha
		menu.comando("mais")
		yield(conferir("teste da porta: acertar", 13, false), "completed")
		menu.comando("sair")
		yield(conferir("teste da porta: saiu (volta aberta)", 14, true), "completed")
		# ZERAR CRÉDITOS
		menu._sel = _item(menu, "creditos")
		menu.comando("ok")
		if Ajustes.creditos != 0:
			erro("ZERAR CRÉDITOS não zerou (%d)" % Ajustes.creditos)
		else:
			print("ZERAR CRÉDITOS OK (%d -> 0)" % cred)
		yield(conferir("zerou no menu: ainda sem pulso", 14, true), "completed")
	yield(apertar("input_teste"), "completed")
	# saiu do menu sem crédito: fecha
	yield(conferir("saiu do menu sem crédito: fecha", 15, false), "completed")

	# ---------------------------------------------------------------- ficha junto com o fim
	yield(ficha(), "completed")
	yield(conferir("ficha: abre", 16, true), "completed")
	principal._escolher_jogadores()
	yield(esperar(0.3), "completed")
	principal._comecar(["bob"])
	yield(esperar(0.3), "completed")
	# o fim da partida e a ficha nova no mesmo instante: fecha+abre se anulam
	principal._fim_de_jogo()
	ard.ficha()
	yield(conferir("fim + ficha juntos: sem pulso", 16, true), "completed")
	principal._atracao()
	yield(esperar(0.5), "completed")

	# ---------------------------------------------------------------- Arduino reinicia
	# (ruído, a luz piscou): volta lembrando a porta, o jogo manda tudo de
	# novo e não sai pulso nenhum
	var sync_antes: int = ard.recebidos.count("FICHAS:SYNC")
	ard.reiniciar()
	yield(conferir("o Arduino reiniciou", 16, true), "completed")
	if ard.recebidos.count("FICHAS:SYNC") != sync_antes + 1:
		erro("depois do reinício o jogo não mandou FICHAS:SYNC de novo")

	# ---------------------------------------------------------------- ficha repetida
	# a confirmação se perde: o Arduino repete o mesmo número e o jogo conta UMA vez
	cred = Ajustes.creditos
	ard.perder_proximo_ok = true
	ard.ficha()
	yield(esperar(2.0), "completed")
	if Ajustes.creditos != cred + 1:
		erro("ficha repetida: %d créditos (esperado %d)" % [Ajustes.creditos, cred + 1])
	elif not ard.fila.empty():
		erro("ficha repetida: ficou na fila")
	else:
		print("FICHA REPETIDA OK (contou uma vez)")
	# 10 fichas seguidas: 10 créditos
	cred = Ajustes.creditos
	for _i in 10:
		ard.ficha()
		yield(esperar(0.12), "completed")
	yield(esperar(6.5), "completed")
	if Ajustes.creditos != cred + 10 or not ard.fila.empty():
		erro("10 fichas seguidas: %d créditos (esperado %d), fila %d" % [Ajustes.creditos, cred + 10, ard.fila.size()])
	else:
		print("10 FICHAS SEGUIDAS OK")
	yield(conferir("depois das fichas", 16, true), "completed")

	# ---------------------------------------------------------------- sem permissão
	# o Arduino perde a permissão USB: o jogo pede de novo sozinho, na espera
	ArduinoBridge._perdeu("teste")
	ard.com_permissao = false
	yield(esperar(14.0), "completed")
	if ard.pedidos_permissao < 1:
		erro("sem permissão USB: o jogo não pediu sozinho")
	else:
		print("PERMISSÃO USB PEDIDA SOZINHA OK (%d)" % ard.pedidos_permissao)
	ard.com_permissao = true
	yield(esperar(6.0), "completed")
	if not ArduinoBridge.completo():
		erro("com a permissão de volta o Arduino não conectou")
	yield(conferir("reconectou", 16, true), "completed")
	_acabar()


func _item(menu, chave: String) -> int:
	for i in menu.ITENS.size():
		if menu.ITENS[i][2] == chave:
			return i
	erro("item do menu não encontrado: " + chave)
	return 0


func _acabar() -> void:
	for chave in _antes:
		Ajustes.definir("jogo", chave, _antes[chave])
	Ajustes.zerar_creditos()
	yield(esperar(0.5), "completed")
	print("pulsos: ", ard.diario)
	if erros == 0:
		print("PORTA RELE OK ", caso)
	else:
		print("PORTA RELE COM %d ERROS %s" % [erros, caso])
	get_tree().quit()
