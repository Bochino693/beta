extends Node

## O ARDUINO DA MÁQUINA (firmware em arduino/1_RELE_principal - relé/servo,
## a principal - ou arduino/2_PONTE_H - ponte H; o jogo é o mesmo para os dois),
## pelo cabo USB da TV Box (plugin StrikeSerial, addons/StrikeSerial):
##   * os 5 SENSORES da pista (S1 = esquerda ... S5 = direita) viram as
##     mesmas jogadas Z X C V B da placa Zero Delay;
##   * o botão de CONFIGURAÇÃO entra e sai do menu do operador;
##   * START e FICHA, se estiverem ligados no Arduino (a Zero Delay também
##     continua valendo, com o teclado);
##   * a PORTA das bolas (relé de pulso, relé de nível, servo ou ponte H);
##   * a fita de LED (mesmos comandos de antes: MENU, STRIKE, SPARE...).
##
## A PORTA, UMA REGRA SÓ (quem decide é o jogo, em principal.gd):
##   MODO LIVRE: sempre ABERTA.
##   MODO FICHAS: FECHADA sem crédito; o crédito ABRE; fica aberta a partida
##   inteira; no fim FECHA se não sobrou crédito; com crédito sobrando e
##   ninguém jogando por muito tempo, FECHA (menu: "Fechar a trava sem jogar").
## Daqui o pedido só sai para o Arduino quando MUDA e fica firme por
## PORTA_FIRME_MS (abre+fecha no mesmo instante não viram dois pulsos do
## relé). Sem a confirmação do Arduino (PORTA:ABERTA / PORTA:FECHADA) o
## pedido é repetido a cada PORTA_REENVIO_MS — repetir não dá pulso: o
## Arduino só pulsa quando a posição pedida é diferente da que ele lembra.
## Antes de o jogo decidir a porta pela primeira vez (ele ainda montando),
## nada é mandado: ligar a máquina não mexe no relé.
##
## Protocolo (linhas de texto, 9600):
##   Arduino -> jogo: OLA:STRIKE_KIDS:5, PONG:STRIKE_KIDS:5, S:1..S:5, CFG,
##     START, FICHA:<n> (firmware 5; o 3 mandava só FICHA), SENS:00100 (ao
##     vivo, no teste), PORTA:ABERTA/FECHADA, CAL:OK:HHHHH, INFO:...,
##     PONTE:TEMPO:1500:FC:0, AVISO:SEM_JOGO, AVISO:PORTA_TRAVOU (o fim de
##     curso não chegou)
##   jogo -> Arduino: PING, FICHAS:SYNC, FICHA:OK:<n>, PORTA:ABRE,
##     PORTA:FECHA, PORTA?, PORTA:ACERTA, SENS?, TESTE:1, TESTE:0, CALIBRA,
##     INFO?, PONTE:TEMPO:<ms>, PONTE:FC:<0|1>, PONTE?, MENU, IDLE, STRIKE...
## FICHAS QUE NÃO SE PERDEM (firmware 5): o Arduino guarda cada ficha na
## EEPROM e manda FICHA:<n> até o jogo responder FICHA:OK:<n>. Ficha posta
## com a TV Box ainda ligando chega assim que o jogo conecta. O mesmo <n>
## repetido (a confirmação se perdeu) não conta duas vezes.
## PONTE H da porta (firmware 3+): o tempo do motor e o fim de curso vêm do
## menu do operador ("Porta: tempo do motor", "Porta: fim de curso"); o jogo
## manda ao conectar (antes da porta) e a cada mudança, e o Arduino guarda
## na EEPROM (vale já ao ligar, antes de o jogo abrir).
## O firmware antigo só de LEDs (DRAGON_BOWLING) também conecta (só LEDs).
##
## No PC não tem Arduino: o teclado faz tudo (A S D F G = sensores, 1 =
## START, 9 = configuração).
##
## PERMISSÃO USB SÓ NA PRIMEIRA VEZ: a janela do Android ("Permitir que o
## Strike Kids acesse o USB?") é pedida UMA vez por Arduino (guardado em
## user://permissoes.cfg), na tela de espera ou na INSTALAÇÃO (a primeira
## vez que o jogo abre), com o aviso na tela para marcar "Sempre abrir"
## (Usar por padrão). Marcado, o Android dá a permissão sozinho a cada boot
## (e ainda abre o jogo quando o Arduino aparece no USB): nada mais aparece.
## Depois disso o jogo nunca mais pede sozinho - na máquina sem controle
## remoto uma janela sem ninguém para responder deixaria o jogo parado atrás
## dela. Só o operador pede de novo, nos testes do Arduino no menu.
## TV SEM "SEMPRE" (Android de TV): com o serviço "Strike Kids: abrir ao
## ligar e Arduino" ligado (Ajustes > Acessibilidade, uma vez só), o jogo
## pede a CADA VEZ que liga e o serviço aperta OK sozinho na hora.

signal mudou
signal sensor(n)
## aviso na tela do jogo antes da janela de permissão do Android ("" = some)
signal janela_android(texto)

const BAUD := 9600
const PING_MS := 2000
const SEM_RESPOSTA_MS := 6500
const APRESENTAR_MS := 6000      # abriu: espera o OLA/PONG (o Uno reinicia ~2 s)
const PROCURAR_MS := 1500
const PERMISSOES := "user://permissoes.cfg"
const JANELA_MAX_MS := 25000
const ESPERA_JANELA_ANDROID_MS := 800    # (8.6) o jogo pede NA HORA: a janela dele é a que tem o "SEMPRE"
const PEDIDO_AUTO_MS := 15000            # com o serviço ligado: pede de novo a cada 15 s até ter
const PORTA_FIRME_MS := 250              # o pedido da porta fica firme isto antes de sair
const PORTA_REENVIO_MS := 2500           # sem confirmação: repete (não dá pulso a mais)
const DICA_USB := "MARQUE \"SEMPRE\" (USAR POR PADRÃO) E TOQUE EM OK\nfica salvo para sempre: o Arduino nunca mais pergunta"
const LED_COMMANDS := ["MENU", "BLUE", "RED", "IDLE", "NORMAL", "STRIKE", "SPARE", "MISS", "OFF"]
## S1..S5, da esquerda para a direita (as mesmas ações da Zero Delay)
const ACOES_SENSOR := ["input_z", "input_x", "input_c", "input_v", "input_b"]

var status := "Iniciando USB..."
var connected := false
var device := ""
var tipo := ""                 # chip USB: ch340, cdc, ftdi, cp210x
var firmware := ""             # STRIKE_KIDS:5 (ou DRAGON_BOWLING:1, o antigo só de LEDs)
var info := ""                 # resposta do INFO?
var calibracao := ""           # resposta do CALIBRA (CAL:OK:HHHHH)
var sensores := ""             # estado ao vivo (só no teste): "00100", 1 = bola no sensor
var contagem := [0, 0, 0, 0, 0]
## quantas vezes o Arduino mandou cada um (a tela de teste do menu mostra:
## serve para conferir a ligação do moedeiro no A2 e do START no A1)
var botoes := {"FICHA": 0, "START": 0, "CFG": 0}
var porta_aberta := false      # o que o Arduino confirmou (no jeito do jogo)
var porta_quer := false        # o que o jogo pediu
var porta_pulsos := 0          # mudanças de porta mandadas desde que o jogo abriu (teste da porta)
var aviso := ""                # último AVISO: do Arduino (PORTA_TRAVOU...); a porta chegou = ""
var ponte := ""                # o que o Arduino usa na ponte H: "TEMPO:1500:FC:0" ("" = não disse)
var _plugin: Object
var _fase := "procurando"      # procurando | abrindo | apresentando | conectado
var _candidatos: Array = []
var _falhou := {}              # nome -> ms (não tenta de novo logo)
var _desde := 0
var _ultimo_rx := 0
var _ultimo_ping := 0
var _ultima_procura := 0
var _janelas_ok := false       # na espera ou no menu: pode abrir janela do Android
var _pedir_agora := false      # o operador pediu a janela (testes do Arduino no menu)
var _janela_ate := 0           # a janela do Android está aberta (até este ms)
var _visto_sem_permissao := {} # nome do aparelho -> ms em que apareceu no USB sem permissão
var _auto_ok_cache := false    # o serviço "Strike Kids: abrir ao ligar e Arduino" está ligado?
var _auto_ok_visto := -100000  # (ms da última consulta)
var _pedido_auto := -100000    # ms do último pedido feito com o serviço ligado
var _pedidos_auto := 0         # quantos pedidos com o serviço ligado desde que o jogo abriu
var _pedido_sessao := {}       # Arduinos já pedidos desde que o jogo abriu (um pedido por vez que abre)
var _teste := false
var _led_state := "MENU"
var _last_led_sent := ""
# a porta: o jogo já decidiu? o que foi mandado por último (-1 = nada)
var _porta_decidida := false
var _porta_mudou_ms := 0
var _porta_enviada := -1
var _porta_envio_ms := 0
var _porta_reenvios := 0
var _modo_enviado := ""          # MODO:LIVRE / MODO:FICHAS que o Arduino já sabe
const PORTA_REENVIOS_MAX := 3   # (a ponte H travada não fica tentando para sempre)
# fichas do firmware 5: o número da última contada (-1 = nenhuma ainda)
var _ultima_ficha := -1


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	if OS.get_name() != "Android":
		_set_status("Arduino: no PC o teclado faz tudo (A S D F G = sensores, 1 = START, 9 = configuração)")
		return
	if not Engine.has_singleton("StrikeSerial"):
		_set_status("Arduino: este APK não tem o plugin USB (StrikeSerial) — use o APK pronto ou o GERAR_APK")
		return
	_plugin = Engine.get_singleton("StrikeSerial")
	_ultima_procura = -PROCURAR_MS


func tem_plugin() -> bool:
	return _plugin != null


## Firmware novo (sensores, botão e porta) conectado?
func completo() -> bool:
	return connected and firmware.begins_with("STRIKE_KIDS")


func _process(_delta: float) -> void:
	if _plugin == null:
		return
	var agora := Time.get_ticks_msec()
	if _janela_ate > 0 and agora >= _janela_ate:
		_fechou_janela()
	match _fase:
		"procurando":
			if agora - _ultima_procura >= PROCURAR_MS and not _procurando:
				_ultima_procura = agora
				_procurar_sem_parar(agora)
		"abrindo":
			var e := str(_plugin.call("estado"))
			if e == "aberta":
				_fase = "apresentando"
				_desde = agora
				_ultimo_ping = agora - 1000
				_set_status("Arduino: conversando com %s..." % tipo)
			elif e == "erro" or e == "fechada" or agora - _desde > 8000:
				_falha(str(_plugin.call("erro")) if e == "erro" else "não abriu")
		"apresentando", "conectado":
			var e := str(_plugin.call("estado"))
			if e != "aberta":
				_perdeu(str(_plugin.call("erro")))
				return
			var texto := str(_plugin.call("ler"))
			if texto != "":
				for linha in texto.split("\n", false):
					_receber(linha.strip_edges(), agora)
			if _fase == "apresentando":
				if agora - _ultimo_ping >= 500:
					_ultimo_ping = agora
					_send("PING")
				if agora - _desde > APRESENTAR_MS:
					_falha("o aparelho não respondeu como Arduino do Strike Kids")
			elif _fase == "conectado":
				if agora - _ultimo_rx > SEM_RESPOSTA_MS:
					_perdeu("o Arduino parou de responder")
					return
				if agora - _ultimo_ping >= PING_MS:
					_ultimo_ping = agora
					_send("PING")
				_andar_porta(agora)


## Na TV Box a lista do USB vem do Android (pode levar alguns ms numa TV
## Box fraca): é feita numa linha de trabalho separada, sem parar o jogo.
var _procurando := false


func _procurar_sem_parar(agora: int) -> void:
	if OS.get_name() != "Android":
		_procurar(agora)
		return
	_procurando = true
	Tarefas.rodar(self, "_listar_usb", [_plugin])


## (linha de trabalho) A lista do USB; a resposta volta para o quadro do
## jogo em _lista_chegou. Godot 3: sem lambda.
func _listar_usb(plugin: Object) -> void:
	var lista := str(plugin.call("listar"))
	call_deferred("_lista_chegou", lista)


func _lista_chegou(lista: String) -> void:
	_procurando = false
	if _plugin != null and _fase == "procurando":
		_procurar(Time.get_ticks_msec(), lista if lista != "" else " ")


func _procurar(agora: int, lista := "") -> void:
	if lista == "":
		lista = str(_plugin.call("listar"))
	var com_permissao: Array = []
	var sem_permissao: Array = []
	for linha in lista.split("\n", false):
		var p: PoolStringArray = linha.split("|")
		if p.size() < 4:
			continue
		if agora - int(_falhou.get(p[0], -100000)) < 15000:
			continue
		if p[3] == "1":
			com_permissao.append(p[0])
		else:
			sem_permissao.append(p[0])
	if not com_permissao.empty():
		device = com_permissao[0]
		tipo = _tipo_de(lista, device)
		_fase = "abrindo"
		_desde = agora
		_set_status("Arduino: abrindo o USB (%s)..." % tipo)
		_plugin.call("abrir", device, BAUD)
		return
	if not sem_permissao.empty():
		var chave := _chave_de(lista, sem_permissao[0])
		if _auto_ok_ligado():
			_set_status("Arduino no USB: pedindo ao Android (o serviço do Strike Kids aceita sozinho)")
		elif _ja_pediu(chave) and not _pedir_agora and not janela_aberta():
			_set_status("Arduino no USB sem permissão: no menu, TESTE DOS SENSORES pede de novo (marque \"Sempre abrir\")")
		else:
			_set_status("Arduino no USB: aceite a janela do Android (marque \"Sempre abrir\" / \"Usar por padrão\")")
		_pedir_permissao(sem_permissao[0], chave, agora)
		return
	if lista.strip_edges() == "":
		_set_status("Arduino não encontrado: confira o cabo USB")
		# nada no USB: procura com menos pressa
		_ultima_procura = agora + 1500


const NOMES_CHIP := {"ch34x": "CH340", "cdc": "USB original", "ftdi": "FTDI", "cp210x": "CP2102"}


## vendor:produto do aparelho
func _chave_de(lista: String, nome: String) -> String:
	for linha in lista.split("\n", false):
		var p: PoolStringArray = linha.split("|")
		if p.size() >= 2 and p[0] == nome:
			return p[1]
	return nome


func _tipo_de(lista: String, nome: String) -> String:
	for linha in lista.split("\n", false):
		var p: PoolStringArray = linha.split("|")
		if p.size() >= 3 and p[0] == nome:
			return str(NOMES_CHIP.get(p[2], p[2]))
	return "?"


## A janela de permissão USB do Android: UMA vez por Arduino, sozinha, na
## tela de espera; depois, só quando o operador pede (menu, instalação).
func _pedir_permissao(nome: String, chave: String, agora: int) -> void:
	# (8.6) O JOGO PEDE NA HORA, COMO ATÉ A 7.x: a janela do JOGO ("Permitir
	# que o Strike Kids acesse...") é a que tem o "SEMPRE" / "Usar por padrão"
	# nesta TV - a do encaixe (do sistema) vem sem ele. Marcado uma vez, o
	# Android guarda: a cada boot ele mesmo dá a permissão (StrikeArduinoAtivo,
	# directBootAware) e nenhuma janela aparece mais. A janela do jogo fica
	# por cima da do encaixe; a de baixo pode ser OK ou CANCELAR.
	if not _visto_sem_permissao.has(nome):
		_visto_sem_permissao = {nome: agora}
	if not _pedir_agora and agora - int(_visto_sem_permissao[nome]) < ESPERA_JANELA_ANDROID_MS:
		return
	if bool(_plugin.call("permissao_pendente")) or janela_aberta() or Fotos.janela_aberta():
		return   # uma janela do Android por vez
	if _pedir_agora:
		_pedir_agora = false
	elif _auto_ok_ligado() and Ajustes.instalacao_feita():
		# O SERVIÇO APERTA OK SOZINHO (Ajustes > Acessibilidade > "Strike Kids:
		# abrir ao ligar e Arduino"): o jogo pede a CADA VEZ que a TV liga, sem
		# ninguém no controle - o Android pergunta, o serviço aceita na hora e
		# o Arduino conecta. (Se a janela do encaixe ficou escondida atrás do
		# jogo, este pedido a traz de novo.)
		# (no máximo 4 vezes cada vez que o jogo abre: se o serviço não
		# conseguiu, o jogo não fica abrindo janela para sempre)
		if agora - _pedido_auto < PEDIDO_AUTO_MS or _pedidos_auto >= 4:
			return
		_pedido_auto = agora
		_pedidos_auto += 1
		_janela_ate = agora + JANELA_MAX_MS
		_timer_real(0.1).connect("timeout", self, "_abrir_janela_usb", [nome])
		return
	elif not _janelas_ok or _pedido_sessao.has(chave):
		return
	else:
		# UM PEDIDO CADA VEZ QUE O JOGO ABRE (a TV não guarda o aceite: sem
		# o "Sempre", cada vez que liga ela pergunta de novo). Logo depois de
		# instalar o jogo já pede - antes esperava a TV desligar e ligar.
		_pedido_sessao[chave] = true
	_marcar_pedido(chave)
	_janela_ate = agora + JANELA_MAX_MS
	# a janela do Android congela a imagem do jogo: o aviso entra antes
	emit_signal("janela_android", DICA_USB)
	_timer_real(0.6).connect("timeout", self, "_abrir_janela_usb", [nome])


## Godot 3: sem lambda (o timer chama este).
func _abrir_janela_usb(nome: String) -> void:
	if _plugin != null:
		_plugin.call("pedir_permissao", nome)


## Um timer de tempo REAL (Godot 3: o SceneTreeTimer anda com o
## Engine.time_scale da câmera lenta e não tem ignore_time_scale).
func _timer_real(segundos: float) -> SceneTreeTimer:
	return get_tree().create_timer(segundos * Engine.time_scale, true)


## O operador pediu (testes do Arduino no menu, instalação): a janela abre já.
func pedir_permissao_agora() -> void:
	if _plugin == null or connected:
		return
	_pedir_agora = true
	_ultima_procura = -PROCURAR_MS


## O serviço de acessibilidade do jogo (aperta OK na janela do USB) está
## ligado? (consulta o Android a cada 5 s no máximo)
func _auto_ok_ligado() -> bool:
	if _plugin == null or not _plugin.has_method("auto_ok_ligado"):
		return false
	var agora := Time.get_ticks_msec()
	if agora - _auto_ok_visto >= 5000:
		_auto_ok_visto = agora
		_auto_ok_cache = bool(_plugin.call("auto_ok_ligado"))
	return _auto_ok_cache


func janela_aberta() -> bool:
	return _janela_ate > 0 and Time.get_ticks_msec() < _janela_ate


## O Arduino está no USB sem permissão? (a instalação pede a janela)
func sem_permissao() -> bool:
	return _plugin != null and not connected and not _visto_sem_permissao.empty() and _fase == "procurando"


func _fechou_janela() -> void:
	if _janela_ate > 0:
		_janela_ate = 0
		# a resposta da janela vale já: procura de novo sem esperar
		_ultima_procura = -PROCURAR_MS
		emit_signal("janela_android", "")


func _notification(what: int) -> void:
	# o jogo voltou para a frente: a janela do Android fechou
	if what == NOTIFICATION_WM_FOCUS_IN or what == NOTIFICATION_APP_RESUMED:
		_fechou_janela()


var _pedidos_salvos: ConfigFile


func _ja_pediu(chave: String) -> bool:
	if _pedidos_salvos == null:
		_pedidos_salvos = ConfigFile.new()
		_pedidos_salvos.load(PERMISSOES)
	return bool(_pedidos_salvos.get_value("usb", chave, false))


func _marcar_pedido(chave: String) -> void:
	_ja_pediu(chave)
	_pedidos_salvos.set_value("usb", chave, true)
	_pedidos_salvos.save(PERMISSOES)


## A tela de espera (atração) e o menu do operador chamam isto: ali pode
## aparecer a janela do Android (só a primeira, que nunca foi pedida).
func na_espera(sim := true) -> void:
	_janelas_ok = sim


func _falha(motivo: String) -> void:
	_falhou[device] = Time.get_ticks_msec()
	_plugin.call("fechar")
	_set_status("Arduino: %s" % motivo)
	_desconectar()


func _perdeu(motivo: String) -> void:
	_plugin.call("fechar")
	_set_status("Arduino desconectado (%s): procurando de novo" % (motivo if motivo != "" else "sem resposta"))
	_desconectar()


func _desconectar() -> void:
	var estava := connected
	connected = false
	firmware = ""
	sensores = ""
	ponte = ""
	info = ""
	_last_led_sent = ""
	_porta_enviada = -1
	_modo_enviado = ""
	_fase = "procurando"
	_ultima_procura = Time.get_ticks_msec()
	if estava:
		emit_signal("mudou")


func _receber(linha: String, agora: int) -> void:
	if linha == "":
		return
	_ultimo_rx = agora
	if linha.begins_with("OLA:") or linha.begins_with("PONG:") or linha.begins_with("READY:"):
		var fw := linha.substr(linha.find(":") + 1)
		# OLA = o Arduino acabou de LIGAR. Se ele reiniciou sozinho com o USB
		# aberto (ruído do motor, queda de tensão), voltou sem o teste/LEDs e
		# sem saber quem é o jogo: manda tudo de novo, como numa conexão.
		if not connected or fw != firmware or linha.begins_with("OLA:"):
			_conectou(fw)
		return
	if not connected:
		return
	if linha.begins_with("S:"):
		var n := int(linha.substr(2))
		if n >= 1 and n <= 5:
			if bool(Ajustes.valor("arduino", "sensores_invertidos")):
				n = 6 - n
			contagem[n - 1] += 1
			_pulsar(ACOES_SENSOR[n - 1])
			emit_signal("sensor", n)
		return
	if linha.begins_with("FICHA:"):
		_ficha_numerada(linha.substr(6))
		return
	match linha:
		"CFG":
			botoes["CFG"] += 1
			_pulsar("input_teste")
		"START":
			botoes["START"] += 1
			_pulsar("input_start")
		"FICHA":
			# (firmware 3 e 4: a ficha sem número)
			_contar_ficha()
		"PORTA:ABERTA", "PORTA:FECHADA":
			var aberta := linha == "PORTA:ABERTA"
			porta_aberta = aberta != bool(Ajustes.valor("arduino", "porta_invertida"))
			aviso = ""
			emit_signal("mudou")
		_:
			if linha.begins_with("SENS:"):
				sensores = linha.substr(5)
				if bool(Ajustes.valor("arduino", "sensores_invertidos")):
					sensores = _ao_contrario(sensores)
				emit_signal("mudou")
			elif linha.begins_with("CAL:"):
				calibracao = linha
				emit_signal("mudou")
			elif linha.begins_with("INFO:"):
				info = linha.substr(5)
				emit_signal("mudou")
			elif linha.begins_with("PONTE:"):
				ponte = linha.substr(6)
				emit_signal("mudou")
			elif linha.begins_with("AVISO:"):
				aviso = linha.substr(6)
				if aviso == "SEM_JOGO":
					# o jogo ficou parado tempo demais e o Arduino fechou a
					# porta: o pedido do jogo vai de novo
					_porta_enviada = -1
				emit_signal("mudou")


## FICHA:<n> (firmware 5): confirma SEMPRE (o Arduino repete até ouvir o
## FICHA:OK) e conta cada número uma vez só.
func _ficha_numerada(numero: String) -> void:
	if not numero.is_valid_integer():
		return
	var n := int(numero)
	_send("FICHA:OK:%d" % n)
	if n == _ultima_ficha:
		return   # a mesma de novo: a confirmação anterior se perdeu
	_ultima_ficha = n
	_contar_ficha()


func _contar_ficha() -> void:
	botoes["FICHA"] += 1
	_pulsar("input_credit")
	emit_signal("mudou")


## Godot 3: String não tem reverse().
static func _ao_contrario(s: String) -> String:
	var r := ""
	for i in range(s.length() - 1, -1, -1):
		r += s[i]
	return r


func _conectou(fw: String) -> void:
	_fechou_janela()
	connected = true
	firmware = fw
	_fase = "conectado"
	_falhou.clear()
	_visto_sem_permissao.clear()
	if fw.begins_with("STRIKE_KIDS"):
		_set_status("Arduino conectado (%s): sensores, botão e porta OK" % tipo)
		ponte = ""
		# quem é o jogo, antes de tudo: as fichas da fila já podem vir
		_send("FICHAS:SYNC")
		enviar_ponte()   # antes da porta: ela já anda no tempo/fim de curso do menu
		# a porta (e o modo) vão pelo _andar_porta (só o que o jogo já decidiu)
		_porta_enviada = -1
		_modo_enviado = ""
		_send("TESTE:1" if _teste else "TESTE:0")
		_send("INFO?")
		_send("PORTA?")
	else:
		_set_status("Arduino com o firmware ANTIGO (só LEDs): grave o arduino 1_RELE_principal (ou 2_PONTE_H)")
	_send(_led_state)
	_last_led_sent = _led_state
	emit_signal("mudou")


## Uma jogada/botão do Arduino vira a mesma ação da placa Zero Delay
## (aperta e solta, com a marca "arduino" que o ArcadeControls aceita).
func _pulsar(acao: String) -> void:
	var ev := InputEventAction.new()
	ev.action = acao
	ev.pressed = true
	ev.set_meta("arduino", true)
	Input.parse_input_event(ev)
	_timer_real(0.06).connect("timeout", self, "_soltar", [acao])


func _soltar(acao: String) -> void:
	var ev := InputEventAction.new()
	ev.action = acao
	ev.pressed = false
	ev.set_meta("arduino", true)
	Input.parse_input_event(ev)


# ================================================================ porta
## O jogo diz como quer a porta (aberta ou fechada). Pode chamar quantas
## vezes quiser, com o mesmo valor ou trocando: só o que ficar FIRME sai
## para o Arduino (_andar_porta), e só quando for diferente do que já foi.
func porta(abrir: bool) -> void:
	if _porta_decidida and abrir == porta_quer:
		return
	_porta_decidida = true
	porta_quer = abrir
	_porta_mudou_ms = Time.get_ticks_msec()
	emit_signal("mudou")


## O operador trocou "porta invertida": manda de novo, do jeito certo.
func reenviar_porta() -> void:
	_porta_enviada = -1
	_porta_mudou_ms = Time.get_ticks_msec()


## (a cada quadro, conectado) O pedido da porta para o Arduino:
##   1. o jogo ainda não decidiu: nada (ligar a máquina não mexe no relé);
##   2. pedido novo: espera ficar firme e manda UMA vez;
##   3. mandou e o Arduino não confirmou: repete de tempos em tempos (a
##      linha pode ter se perdido; repetir não dá pulso a mais).
func _andar_porta(agora: int) -> void:
	if not _porta_decidida or not completo():
		return
	# o MODO vai antes da porta (firmware 7: no modo livre o vigia do
	# Arduino nunca fecha a porta - nem com o jogo parado ou a TV em espera)
	var modo := "MODO:LIVRE" if Ajustes.modo_livre() else "MODO:FICHAS"
	if modo != _modo_enviado:
		_modo_enviado = modo
		_send(modo)
	var quer := 1 if porta_quer else 0
	if quer != _porta_enviada:
		if agora - _porta_mudou_ms >= PORTA_FIRME_MS:
			if _porta_enviada >= 0:
				porta_pulsos += 1
			_porta_reenvios = 0
			_enviar_porta(agora)
	elif porta_aberta != porta_quer and agora - _porta_envio_ms >= PORTA_REENVIO_MS \
			and _porta_reenvios < PORTA_REENVIOS_MAX and aviso != "PORTA_TRAVOU":
		_porta_reenvios += 1
		_enviar_porta(agora)


func _enviar_porta(agora: int) -> void:
	_porta_enviada = 1 if porta_quer else 0
	_porta_envio_ms = agora
	var abre := porta_quer != bool(Ajustes.valor("arduino", "porta_invertida"))
	_send("PORTA:ABRE" if abre else "PORTA:FECHA")


## Relé de PULSO: a porta de verdade está ao contrário do que o jogo mostra
## (mexeram nela com a mão, o Arduino foi gravado com ela aberta). O Arduino
## troca só a lembrança dele, sem pulso — e então dá o pulso que deixa a
## porta como o jogo quer.
func acertar_porta() -> bool:
	if not rele_de_pulso():
		return false
	_send("PORTA:ACERTA")
	_porta_envio_ms = Time.get_ticks_msec()
	return true


## A versão do firmware (STRIKE_KIDS:5 -> 5; 0 = sem Arduino ou o antigo).
func versao() -> int:
	if not completo():
		return 0
	return int(firmware.substr(firmware.find(":") + 1))


## O Arduino é o da versão do RELÉ/SERVO (arduino/1_RELE_principal, sem ponte H):
## ignora o tempo do motor e o fim de curso.
func sem_ponte() -> bool:
	return completo() and info.find(":PONTE_H=0:") >= 0


## O relé da porta é de PULSO (firmware 5, RELE_PULSO 1): um pulso troca a
## porta de posição.
func rele_de_pulso() -> bool:
	return completo() and info.find(":PULSO=1") >= 0


## A ponte H como o menu do operador escolheu, no jeito da resposta do
## Arduino ("TEMPO:1500:FC:0").
func ponte_pedida() -> String:
	return "TEMPO:%d:FC:%d" % [int(Ajustes.valor("arduino", "porta_tempo")),
		1 if bool(Ajustes.valor("arduino", "porta_fim_de_curso")) else 0]


## O tempo do motor e o fim de curso (menu do operador) para o Arduino, que
## guarda na EEPROM e responde PONTE:TEMPO:...:FC:... (o do relé ignora).
func enviar_ponte() -> void:
	if not completo():
		return
	_send("PONTE:TEMPO:%d" % int(Ajustes.valor("arduino", "porta_tempo")))
	_send("PONTE:FC:%d" % (1 if bool(Ajustes.valor("arduino", "porta_fim_de_curso")) else 0))


## Teste dos sensores (menu): o Arduino manda o estado ao vivo.
func modo_teste(sim: bool) -> void:
	_teste = sim
	if sim:
		contagem = [0, 0, 0, 0, 0]
		botoes = {"FICHA": 0, "START": 0, "CFG": 0}
	if completo():
		_send("TESTE:1" if sim else "TESTE:0")


## Calibrar (com a pista VAZIA): o nível de agora de cada sensor vira o
## "sem bola" — serve para sensor normalmente fechado ou aberto.
func calibrar() -> bool:
	if not completo():
		return false
	calibracao = ""
	_send("CALIBRA")
	return true


func relatorio() -> String:
	var t := "Arduino: %s\nfirmware: %s   chip: %s\n" % [status, firmware if firmware != "" else "-", tipo if tipo != "" else "-"]
	if info != "":
		t += "info: %s\n" % info
	if _plugin != null:
		t += str(_plugin.call("relatorio"))
	return t


func _set_status(message: String) -> void:
	if message != status:
		status = message
		emit_signal("mudou")


func _send(line: String) -> void:
	if _plugin != null and _fase in ["apresentando", "conectado"]:
		_plugin.call("escrever", line)


func send_led(command: String) -> void:
	if not LED_COMMANDS.has(command):
		return
	_led_state = command
	if connected and _last_led_sent != command:
		_send(command)
		_last_led_sent = command


func _exit_tree() -> void:
	Tarefas.esperar_todas()
	if _plugin != null:
		_plugin.call("fechar")
