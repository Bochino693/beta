extends Node

## O ARDUINO DA MÁQUINA (firmware em arduino/strike_kids), pelo cabo USB da
## TV Box (plugin StrikeSerial, addons/StrikeSerial):
##   * os 5 SENSORES da pista (S1 = esquerda ... S5 = direita) viram as
##     mesmas jogadas Z X C V B da placa Zero Delay;
##   * o botão de CONFIGURAÇÃO entra e sai do menu do operador;
##   * START e FICHA, se estiverem ligados no Arduino (a Zero Delay também
##     continua valendo, com o teclado);
##   * a TRAVA da porta das bolas: fechada na espera, ABRE depois do START,
##     FECHA no fim da partida (e sozinha, no Arduino, se o jogo sumir);
##   * a fita de LED (mesmos comandos de antes: MENU, STRIKE, SPARE...).
##
## Protocolo (linhas de texto, 9600):
##   Arduino -> jogo: OLA:STRIKE_KIDS:1, PONG:STRIKE_KIDS:1, S:1..S:5, CFG,
##     START, FICHA, SENS:00100 (ao vivo, no teste), PORTA:ABERTA/FECHADA,
##     CAL:OK:HHHHH, INFO:..., AVISO:SEM_JOGO
##   jogo -> Arduino: PING, PORTA:ABRE, PORTA:FECHA, PORTA?, SENS?, TESTE:1,
##     TESTE:0, CALIBRA, INFO?, MENU, IDLE, STRIKE...
## O firmware antigo só de LEDs (DRAGON_BOWLING) também conecta (só LEDs).
##
## No PC não tem Arduino: o teclado faz tudo (A S D F G = sensores, 1 =
## START, 9 = configuração).

signal mudou
signal sensor(n: int)

const BAUD := 9600
const PING_MS := 2000
const SEM_RESPOSTA_MS := 6500
const APRESENTAR_MS := 6000      # abriu: espera o OLA/PONG (o Uno reinicia ~2 s)
const PROCURAR_MS := 1500
const PEDIR_DE_NOVO_MS := 30000
const LED_COMMANDS := ["MENU", "BLUE", "RED", "IDLE", "NORMAL", "STRIKE", "SPARE", "MISS", "OFF"]
## S1..S5, da esquerda para a direita (as mesmas ações da Zero Delay)
const ACOES_SENSOR := ["input_z", "input_x", "input_c", "input_v", "input_b"]

var status := "Iniciando USB..."
var connected := false
var device := ""
var tipo := ""                 # chip USB: ch340, cdc, ftdi, cp210x
var firmware := ""             # STRIKE_KIDS:1 (ou DRAGON_BOWLING:1, o antigo só de LEDs)
var info := ""                 # resposta do INFO?
var calibracao := ""           # resposta do CALIBRA (CAL:OK:HHHHH)
var sensores := ""             # estado ao vivo (só no teste): "00100", 1 = bola no sensor
var contagem := [0, 0, 0, 0, 0]
var porta_aberta := false      # o que o Arduino confirmou (no jeito do jogo)
var porta_quer := false        # o que o jogo pediu
var _plugin: Object
var _fase := "procurando"      # procurando | abrindo | apresentando | conectado
var _candidatos: Array[String] = []
var _falhou := {}              # nome -> ms (não tenta de novo logo)
var _desde := 0
var _ultimo_rx := 0
var _ultimo_ping := 0
var _ultima_procura := 0
var _pedido_ms := -1000000
var _pediu_na_abertura := false
var _janelas_ok := false       # na espera ou no menu: pode abrir janela do Android
var _teste := false
var _led_state := "MENU"
var _last_led_sent := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	match _fase:
		"procurando":
			if agora - _ultima_procura >= PROCURAR_MS:
				_ultima_procura = agora
				_procurar(agora)
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
			else:
				if agora - _ultimo_rx > SEM_RESPOSTA_MS:
					_perdeu("o Arduino parou de responder")
				elif agora - _ultimo_ping >= PING_MS:
					_ultimo_ping = agora
					_send("PING")


func _procurar(agora: int) -> void:
	var lista := str(_plugin.call("listar"))
	var com_permissao: Array[String] = []
	var sem_permissao: Array[String] = []
	for linha in lista.split("\n", false):
		var p := linha.split("|")
		if p.size() < 4:
			continue
		if agora - int(_falhou.get(p[0], -100000)) < 15000:
			continue
		if p[3] == "1":
			com_permissao.append(p[0])
		else:
			sem_permissao.append(p[0])
	if not com_permissao.is_empty():
		device = com_permissao[0]
		tipo = _tipo_de(lista, device)
		_fase = "abrindo"
		_desde = agora
		_set_status("Arduino: abrindo o USB (%s)..." % tipo)
		_plugin.call("abrir", device, BAUD)
		return
	if not sem_permissao.is_empty():
		_set_status("Arduino no USB: aceite a janela do Android (marque \"Usar por padrão\")")
		_pedir_permissao(sem_permissao[0], agora)
		return
	if lista.strip_edges() == "":
		_set_status("Arduino não encontrado: confira o cabo USB")


const NOMES_CHIP := {"ch34x": "CH340", "cdc": "USB original", "ftdi": "FTDI", "cp210x": "CP2102"}


func _tipo_de(lista: String, nome: String) -> String:
	for linha in lista.split("\n", false):
		var p := linha.split("|")
		if p.size() >= 3 and p[0] == nome:
			return str(NOMES_CHIP.get(p[2], p[2]))
	return "?"


## A janela de permissão USB do Android: uma vez logo no começo (a máquina
## não joga sem os sensores) e depois só na espera ou no menu, a cada 30 s.
func _pedir_permissao(nome: String, agora: int) -> void:
	if bool(_plugin.call("permissao_pendente")):
		return
	var livre := _janelas_ok or not _pediu_na_abertura
	if not livre or agora - _pedido_ms < PEDIR_DE_NOVO_MS:
		return
	# a janela da câmera vem primeiro (uma janela do Android por vez)
	if Fotos.status == "sem_permissao" and agora < 12000:
		return
	_pediu_na_abertura = true
	_pedido_ms = agora
	_plugin.call("pedir_permissao", nome)


## A tela de espera (atração) e o menu do operador chamam isto: ali pode
## aparecer a janela do Android.
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
	_last_led_sent = ""
	_fase = "procurando"
	_ultima_procura = Time.get_ticks_msec()
	if estava:
		mudou.emit()


func _receber(linha: String, agora: int) -> void:
	if linha == "":
		return
	_ultimo_rx = agora
	if linha.begins_with("OLA:") or linha.begins_with("PONG:") or linha.begins_with("READY:"):
		var fw := linha.substr(linha.find(":") + 1)
		if not connected or fw != firmware:
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
			sensor.emit(n)
		return
	match linha:
		"CFG":
			_pulsar("input_teste")
		"START":
			_pulsar("input_start")
		"FICHA":
			_pulsar("input_credit")
		"PORTA:ABERTA", "PORTA:FECHADA":
			var aberta := linha == "PORTA:ABERTA"
			porta_aberta = aberta != bool(Ajustes.valor("arduino", "porta_invertida"))
			mudou.emit()
		_:
			if linha.begins_with("SENS:"):
				sensores = linha.substr(5)
				if bool(Ajustes.valor("arduino", "sensores_invertidos")):
					sensores = sensores.reverse()
				mudou.emit()
			elif linha.begins_with("CAL:"):
				calibracao = linha
				mudou.emit()
			elif linha.begins_with("INFO:"):
				info = linha.substr(5)
				mudou.emit()


func _conectou(fw: String) -> void:
	connected = true
	firmware = fw
	_fase = "conectado"
	_falhou.clear()
	if fw.begins_with("STRIKE_KIDS"):
		_set_status("Arduino conectado (%s): sensores, botão e porta OK" % tipo)
		_enviar_porta()
		_send("TESTE:1" if _teste else "TESTE:0")
		_send("INFO?")
	else:
		_set_status("Arduino com o firmware ANTIGO (só LEDs): grave o arduino/strike_kids")
	_send(_led_state)
	_last_led_sent = _led_state
	mudou.emit()


## Uma jogada/botão do Arduino vira a mesma ação da placa Zero Delay
## (aperta e solta, com a marca "arduino" que o ArcadeControls aceita).
func _pulsar(acao: String) -> void:
	var ev := InputEventAction.new()
	ev.action = acao
	ev.pressed = true
	ev.set_meta("arduino", true)
	Input.parse_input_event(ev)
	get_tree().create_timer(0.06, true, false, true).timeout.connect(_soltar.bind(acao))


func _soltar(acao: String) -> void:
	var ev := InputEventAction.new()
	ev.action = acao
	ev.pressed = false
	ev.set_meta("arduino", true)
	Input.parse_input_event(ev)


# ================================================================ porta
## O jogo pede a porta aberta (depois do START) ou fechada (espera, fim,
## menu). Vale também se o Arduino conectar depois: ele recebe ao conectar.
func porta(abrir: bool) -> void:
	if abrir == porta_quer and connected:
		return
	porta_quer = abrir
	_enviar_porta()


## O operador trocou "porta invertida": manda de novo, do jeito certo.
func reenviar_porta() -> void:
	_enviar_porta()


func _enviar_porta() -> void:
	if not completo():
		return
	var abre := porta_quer != bool(Ajustes.valor("arduino", "porta_invertida"))
	_send("PORTA:ABRE" if abre else "PORTA:FECHA")


## Teste dos sensores (menu): o Arduino manda o estado ao vivo.
func modo_teste(sim: bool) -> void:
	_teste = sim
	if sim:
		contagem = [0, 0, 0, 0, 0]
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
		mudou.emit()


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
	if _plugin != null:
		_plugin.call("fechar")
