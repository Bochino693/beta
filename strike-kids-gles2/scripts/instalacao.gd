extends Node

## INSTALAÇÃO DA TV BOX - UMA VEZ SÓ, COM ALGUÉM APERTANDO OK.
##
## Na primeira vez que o jogo abre na TV Box aparece o convite "PRIMEIRA
## INSTALAÇÃO: aperte OK no controle remoto". Com o OK, uma janela do Android
## por vez, cada uma com o aviso na tela do que tocar:
##   1. CÂMERA (a foto das crianças);
##   2. NOTIFICAÇÕES (Android 13+: o aviso que abre o jogo ao ligar, na TV
##      que não deixa abrir direto);
##   3. ARDUINO no USB: "Sempre abrir" / "Usar por padrão" - o Android dá a
##      permissão sozinho a cada boot e ainda abre o jogo;
##   4. SOBREPOR A OUTROS APPS (Android 10+, se a TV tiver a página): o jogo
##      abre ao ligar mesmo sem ser a tela inicial;
##   5. TELA INICIAL: STRIKE KIDS + SEMPRE - a TV liga direto no jogo, sem
##      nem carregar o lançador dela;
##   6. ABRIR AO LIGAR E ARDUINO (acessibilidade): o serviço "Strike Kids:
##      abrir ao ligar e Arduino" abre o jogo a cada vez que a TV liga (as
##      TVs com Android de TV não aceitam outro app como tela inicial e
##      bloqueiam o abrir ao ligar comum), traz o jogo de volta quando o
##      lançador da TV aparece e aperta OK na janela do USB (sem "Sempre").
## O que já está permitido é pulado. No fim fica guardado: NUNCA MAIS aparece
## sozinho (o menu do operador roda de novo: "> INSTALAÇÃO").
## Ninguém apertou OK em 60 s (a TV Box já está no cliente, sem controle):
## o convite some e nenhuma janela do Android abre - o jogo segue normal.

signal acabou

const PASSOS := ["camera", "notificacoes", "arduino", "sobrepor", "inicio", "auto_ok"]
## a instalação mudou (7.9: o passo 6): a TV que já tinha feito convida de
## novo UMA vez (o que já está feito é pulado)
const VERSAO := 2
const CONVITE_S := 120.0
const ESPERA_ARDUINO_S := 25.0
const JANELA_MAX_S := 90.0
const NOTIFICACOES := "android.permission.POST_NOTIFICATIONS"
const DICAS := {
	"camera": "1/6  CÂMERA: na janela do Android toque em PERMITIR\n(a foto das crianças no placar)",
	"notificacoes": "2/6  NOTIFICAÇÕES: toque em PERMITIR\n(o aviso que abre o jogo quando a TV liga)",
	"arduino": "3/6  ARDUINO: marque \"SEMPRE ABRIR\" (USAR POR PADRÃO) e toque em OK\nassim o Arduino funciona sozinho a cada vez que a TV liga",
	"arduino_conectar": "3/6  ARDUINO: conecte o cabo USB do Arduino na TV Box agora\n(na janela que aparecer marque \"SEMPRE ABRIR\" e OK)",
	"sobrepor": "4/6  Ligue \"PERMITIR SOBREPOR A OUTROS APPS\" para o STRIKE KIDS\ne aperte VOLTAR no controle",
	"inicio": "5/6  TELA INICIAL: escolha STRIKE KIDS e toque em SEMPRE\na TV passa a ligar direto no jogo",
	"auto_ok": "6/6  ARDUINO DIRETO E ABRIR AO LIGAR (uma vez só)\nAPERTE OK: na tela que abrir, LIGUE \"STRIKE KIDS: ABRIR AO LIGAR E ARDUINO\",\nconfirme e aperte VOLTAR (\"configuração restrita\"? Ajustes > Apps > Strike Kids > permitir)",
}

var hud: Node
var forcado := false            # o operador pediu (menu): sem o convite
var _plugin: Object
var _fase := "convite"          # convite | dica | janela | pausa | fim
var _passo := -1
var _t := 0.0
var _saiu_da_frente := false
var _ok_passo := false        # passo 6: espera o OK do controle (para dar tempo de ler)


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	if Engine.has_singleton("StrikeSerial"):
		_plugin = Engine.get_singleton("StrikeSerial")
	if forcado:
		_proximo()
	elif _so_falta_auto_ok():
		# a TV perguntou do Arduino de novo: o motivo e o que fazer, claro
		_aviso("A TV PERGUNTA DO ARDUINO TODA VEZ QUE LIGA?\nAPERTE OK NO CONTROLE e ligue \"STRIKE KIDS: ABRIR AO LIGAR E ARDUINO\"\n(uma vez só: a TV nunca mais pergunta e liga direto no jogo)")
	else:
		_aviso("PRIMEIRA INSTALAÇÃO DO STRIKE KIDS\naperte OK no controle remoto para liberar a câmera, o Arduino\ne o jogo abrindo sozinho ao ligar a TV (uma vez só)")


## Falta a instalação nesta TV Box? (só no Android, só a primeira vez)
static func falta() -> bool:
	if OS.get_name() != "Android":
		return false
	return int(Ajustes.valor("android", "instalacao_versao")) < VERSAO


## Só falta o serviço (o resto já foi permitido)?
func _so_falta_auto_ok() -> bool:
	for p in PASSOS:
		if p != "auto_ok" and _precisa(p):
			return false
	return _precisa("auto_ok")


## Já está tudo permitido (instalado pelo PC, com o adb - GERAR_APK -TelaInicial)?
## Então a instalação nem convida: fica feita, em silêncio.
static func nada_falta() -> bool:
	var plugin: Object = Engine.get_singleton("StrikeSerial") if Engine.has_singleton("StrikeSerial") else null
	for p in PASSOS:
		if _precisa_com(p, plugin):
			return false
	return true


func _aviso(texto: String) -> void:
	if hud != null:
		hud.aviso_android(texto)


func _input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if _fase == "dica" and _passo >= 0 and PASSOS[_passo] == "auto_ok":
		if event is InputEventKey and (event as InputEventKey).scancode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			get_tree().set_input_as_handled()
			_ok_passo = true
		return
	if _fase != "convite":
		return
	# só o controle remoto ou um teclado (quem pode responder às janelas
	# do Android) - a bola e o START da máquina seguem para o jogo
	if event is InputEventKey and (event as InputEventKey).scancode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		get_tree().set_input_as_handled()
		Sons.tocar("selecao")
		_proximo()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_FOCUS_OUT or what == NOTIFICATION_APP_PAUSED:
		_saiu_da_frente = true
	elif (what == NOTIFICATION_WM_FOCUS_IN or what == NOTIFICATION_APP_RESUMED) and _fase == "janela" and _saiu_da_frente:
		# a janela do Android fechou: o próximo passo, depois de um respiro
		_fase = "pausa"
		_t = 0.0


func _process(delta: float) -> void:
	_t += delta / max(Engine.time_scale, 0.01)
	match _fase:
		"convite":
			if _t > CONVITE_S:
				# ninguém aqui: nada de janela do Android (tenta na próxima vez)
				_acabar(false)
		"dica":
			if PASSOS[_passo] == "arduino" and not ArduinoBridge.sem_permissao():
				if ArduinoBridge.connected or _t > ESPERA_ARDUINO_S:
					_proximo()   # conectou (ou ninguém conectou): segue
				return
			if PASSOS[_passo] == "auto_ok":
				# (o texto fica até o OK: quem instala lê o que fazer)
				if _ok_passo:
					_abrir_janela()
				elif _t > 90.0:
					_proximo()
				return
			if _t > 1.4:
				_abrir_janela()
		"janela":
			# (a janela do Arduino e a da câmera têm o próprio aviso)
			if _t > JANELA_MAX_S or (_t > 4.0 and not _saiu_da_frente):
				_proximo()
		"pausa":
			if _t > 1.0:
				_proximo()


func _proximo() -> void:
	while true:
		_passo += 1
		if _passo >= PASSOS.size():
			_aviso("PRONTO! A TV BOX ESTÁ INSTALADA\no jogo abre sozinho ao ligar e não pergunta mais nada")
			_fase = "fim"
			get_tree().create_timer(4.0, true).connect("timeout", self, "_acabar", [true])
			return
		if _precisa(PASSOS[_passo]):
			break
	_fase = "dica"
	_t = 0.0
	_saiu_da_frente = false
	var p: String = PASSOS[_passo]
	if p == "arduino" and not ArduinoBridge.sem_permissao():
		_aviso(DICAS["arduino_conectar"])
	else:
		_aviso(DICAS[p])


func _precisa(p: String) -> bool:
	return _precisa_com(p, _plugin)


static func _precisa_com(p: String, plugin: Object) -> bool:
	match p:
		"camera":
			return bool(Ajustes.valor("jogo", "foto")) and not OS.get_granted_permissions().has(Fotos.PERMISSAO)
		"notificacoes":
			var api := int(plugin.call("api")) if plugin != null and plugin.has_method("api") else 0
			return api >= 33 and not OS.get_granted_permissions().has(NOTIFICACOES)
		"arduino":
			return ArduinoBridge.tem_plugin() and not ArduinoBridge.connected
		"sobrepor":
			return plugin != null and "sobrepor" in str(plugin.call("falta_ao_ligar"))
		"inicio":
			return plugin != null and "inicio" in str(plugin.call("falta_ao_ligar"))
		"auto_ok":
			return plugin != null and plugin.has_method("auto_ok_ligado") and not bool(plugin.call("auto_ok_ligado"))
	return false


func _abrir_janela() -> void:
	_fase = "janela"
	_t = 0.0
	match PASSOS[_passo]:
		"camera":
			Fotos.pedir_permissao_agora()
		"notificacoes":
			OS.request_permission(NOTIFICACOES)
		"arduino":
			ArduinoBridge.pedir_permissao_agora()
		"sobrepor":
			if str(_plugin.call("pedir_sobrepor")) == "":
				_proximo()   # a TV não tem essa página
		"inicio":
			var r := str(_plugin.call("escolher_tela_inicial"))
			if r == "" or r == "ja":
				_proximo()
		"auto_ok":
			if str(_plugin.call("pedir_auto_ok")) == "":
				_proximo()   # a TV não tem a página


func _acabar(feita: bool) -> void:
	if feita:
		Ajustes.definir("android", "instalacao_feita", true)
		# (o ARDUINO DIRETO é o que importa: sem ele ligado, a próxima vez que
		# o jogo abrir convida de novo - só com o OK do controle)
		if not _precisa_com("auto_ok", _plugin):
			Ajustes.definir("android", "instalacao_versao", VERSAO)
	_aviso("")
	_fase = "fim"
	emit_signal("acabou")
	queue_free()
