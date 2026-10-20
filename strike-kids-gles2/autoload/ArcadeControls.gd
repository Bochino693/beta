extends Node

## OS COMANDOS DO JOGO VÊM DA PLACA ZERO DELAY E/OU DO ARDUINO.
## (Os sensores, o botão de configuração e o START/ficha ligados no Arduino
## chegam como as mesmas ações — ver ArduinoBridge.)
##
## Sem mapeamento gravado, vale o Input Map do projeto: as teclas da Zero
## Delay no modo teclado (1/Espaço = STR, A = quadrado, S = X, D = bolinha,
## F = triângulo, G = R1, 5 = SELECT, 9 = configuração) e os botões de
## joystick como o Godot 3 os numera no ANDROID (TV Box) — os mesmos do
## Dragon Bowling (também Godot 3) na mesma máquina:
##   X = 0, bolinha = 1, quadrado = 2, triângulo = 3, R1 = 5, R2 = 7,
##   L3 = 8, SELECT = 10, START = 11.
## (A edição Godot 4 numera diferente — SELECT 4, START 6, L3 7, R1 10,
## R2 16 —, mas os BOTÕES são os mesmos; um mapeamento gravado por ela é
## traduzido ao carregar.)
## As ações "ui_*" do Godot (ENTER, setas, botão 0) são desligadas.
##
## MAPEAMENTO GRAVADO NA TV BOX. O Android numera os botões da placa de
## outro jeito que o Windows. Na tela de CONFIGURAÇÃO (L3, ou segurar
## qualquer botão da placa por 5 segundos no menu) o jogo pede um botão
## de cada vez, na sequência, e grava em user://controles_zero_delay.cfg.
## A placa vale do jeito que ela se apresentar ao Android: como joystick
## (botão) ou, no modo teclado, como tecla. Só teclas ligadas a uma ação
## do jogo contam; nenhuma outra tecla faz nada.

const ARQUIVO := "user://controles_zero_delay.cfg"

## A sequência do assistente: ação, nome na tela.
const SEQUENCIA: Array = [
	["input_start", "STR  ·  START"],
	["input_z", "QUADRADO  ·  JOGADA ESQUERDA"],
	["input_x", "X  ·  MEIO ESQUERDO"],
	["input_c", "BOLINHA  ·  CENTRO"],
	["input_v", "TRIÂNGULO  ·  MEIO DIREITO"],
	["input_b", "R1  ·  JOGADA DIREITA"],
	["input_credit", "SELECT  ·  CRÉDITO"],
	["input_teste", "R2  ·  CONFIGURAÇÃO"],
]
## Os primeiros são obrigatórios; SELECT e L3 podem ser pulados (a
## máquina pode não ter esses botões ligados).
const OBRIGATORIOS := 6

const JOGADAS := {
	"input_z": "Z",
	"input_x": "X",
	"input_c": "C",
	"input_v": "V",
	"input_b": "B",
}

## Segurar qualquer botão da placa por este tempo no menu abre a
## configuração — a saída de emergência se o mapeamento estiver errado.
## Longo de propósito: segurar um botão não pode disparar nada por acaso.
const SEGURAR_PARA_CONFIGURAR_MS := 10000
const CENA_CONFIGURACAO := "res://cenas/configuracao_botoes.tscn"
const CENA_MENU := "res://cenas/principal.tscn"
## R2 da Zero Delay (Godot 3 no Android; era 16 no Godot 4). Abre o menu
## do operador em qualquer tela, mesmo com um mapeamento antigo gravado (de
## quando a configuração era o L3), a não ser que o R2 tenha virado outra
## ação.
const BOTAO_R2 := 7

## O mapeamento gravado pela edição Godot 4 (o arquivo sem "formato/godot")
## usa a numeração dela: ao carregar, cada botão vira o mesmo botão físico
## no Godot 3 e cada tecla especial o código do Godot 3 (letras e números
## são iguais nos dois).
const BOTOES_DO_GODOT4 := {4: 10, 5: 16, 6: 11, 7: 8, 8: 9, 9: 4, 10: 5,
	11: 12, 12: 13, 13: 14, 14: 15, 15: 6, 16: 7}
const TECLA_ESPECIAL_GODOT4 := 1 << 22
const TECLA_ESPECIAL_GODOT3 := 1 << 24

## Godot 3.6 no Android: o joystick sem mapeamento próprio usa o "Default
## Android Gamepad", que não tem L2/R2 como botão (nem o direcional e os
## botões extras) — a placa que manda o R2 como botão ficava muda. Ele
## ganha este mapeamento: o mesmo, mais esses botões (R2 = 7, L2 = 6,
## direcional 12 a 15, os números do Godot 3).
const MAPA_ANDROID := "a:b0,b:b1,x:b2,y:b3,back:b4,guide:b5,start:b6,leftstick:b7,rightstick:b8,leftshoulder:b9,rightshoulder:b10,dpup:b11,dpdown:b12,dpleft:b13,dpright:b14,lefttrigger:b15,righttrigger:b16,misc1:b17,paddle1:b18,paddle2:b19,paddle3:b20,paddle4:b21,touchpad:b22,leftx:a0,lefty:a1,rightx:a2,righty:a3,lefttrigger:a4,righttrigger:a5,dpup:h0.1,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,platform:Android"

var mapeamento_gravado := false
var _segurado_desde := {}

## Proteção de clique (ver eh_da_placa).
const INTERVALO_MINIMO_MS := 120
var _abaixados := {}
var _ultimo_clique := {}
var _evento_visto: InputEvent = null
var _veredito_visto := false


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	_desligar_acoes_de_interface()
	_carregar()
	if OS.get_name() == "Android":
		Input.connect("joy_connection_changed", self, "_joystick_mudou")
		for aparelho in Input.get_connected_joypads():
			_completar_mapa(aparelho)


## As ações "ui_*" vêm de fábrica ligadas a ENTER, espaço, setas e ao
## botão 0 de qualquer joystick. Sem elas, nenhum botão aciona a
## interface por baixo do jogo.
func _desligar_acoes_de_interface() -> void:
	for acao in InputMap.get_actions():
		if str(acao).begins_with("ui_"):
			InputMap.action_erase_events(acao)


func _joystick_mudou(aparelho: int, ligado: bool) -> void:
	if ligado:
		call_deferred("_completar_mapa", aparelho)


## (Android) O joystick ligado sem mapeamento próprio ganha o MAPA_ANDROID.
func _completar_mapa(aparelho: int) -> void:
	if Input.is_joy_known(aparelho):
		return
	var guid := Input.get_joy_guid(aparelho)
	if guid == "":
		return
	var nome := Input.get_joy_name(aparelho).replace(",", " ")
	Input.add_joy_mapping("%s,%s,%s" % [guid, nome, MAPA_ANDROID], true)


## Um código por ação: >= 0 é botão de joystick; "tecla:<código>" é tecla.
func _carregar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(ARQUIVO) != OK:
		# (Godot 3: o R2 entra também sem mapeamento gravado — o Input Map do
		# projeto pode não ter o número dele no Godot 3)
		_garantir_r2({})
		return
	var do_godot4 := not cfg.has_section_key("formato", "godot")
	var botoes := {}
	for item in SEQUENCIA:
		var acao: String = item[0]
		if cfg.has_section_key("botoes", acao):
			var codigo = cfg.get_value("botoes", acao)
			botoes[acao] = _do_godot4(str(codigo)) if do_godot4 else codigo
	if not botoes.empty():
		_aplicar(botoes)
		mapeamento_gravado = true
	_garantir_r2(botoes)


## Um código gravado pela edição Godot 4, com os números do Godot 3.
static func _do_godot4(codigo: String) -> String:
	if codigo.begins_with("tecla:"):
		var tecla := int(codigo.substr(6))
		if tecla & TECLA_ESPECIAL_GODOT4 and tecla < TECLA_ESPECIAL_GODOT4 * 2:
			tecla = (tecla & ~TECLA_ESPECIAL_GODOT4) | TECLA_ESPECIAL_GODOT3
		return "tecla:%d" % tecla
	var botao := int(codigo.trim_prefix("botao:"))
	return "botao:%d" % int(BOTOES_DO_GODOT4.get(botao, botao))


func gravar(botoes: Dictionary) -> void:
	var cfg := ConfigFile.new()
	for acao in botoes:
		cfg.set_value("botoes", acao, botoes[acao])
	# marca de que os números são os do Godot 3 (ver BOTOES_DO_GODOT4)
	cfg.set_value("formato", "godot", 3)
	cfg.save(ARQUIVO)
	_aplicar(botoes)
	mapeamento_gravado = true
	_garantir_r2(botoes)


func _garantir_r2(botoes: Dictionary) -> void:
	var codigo_r2 := "botao:%d" % BOTAO_R2
	for acao in botoes:
		if acao != "input_teste" and str(botoes[acao]) == codigo_r2:
			return
	for ev in InputMap.get_action_list("input_teste"):
		if ev is InputEventJoypadButton and ev.button_index == BOTAO_R2:
			return
	var r2 := InputEventJoypadButton.new()
	r2.device = -1
	r2.button_index = BOTAO_R2
	InputMap.action_add_event("input_teste", r2)


func _aplicar(botoes: Dictionary) -> void:
	for acao in botoes:
		var codigo = botoes[acao]
		if not InputMap.has_action(acao):
			InputMap.add_action(acao, 0.2)
		InputMap.action_erase_events(acao)
		var texto := str(codigo)
		if texto.begins_with("tecla:"):
			var tecla := int(texto.substr(6))
			var ev := InputEventKey.new()
			ev.physical_scancode = tecla
			InputMap.action_add_event(acao, ev)
		else:
			var ev := InputEventJoypadButton.new()
			ev.device = -1
			ev.button_index = int(texto.trim_prefix("botao:"))
			InputMap.action_add_event(acao, ev)


## Código gravável de um evento: "botao:N" (joystick) ou "tecla:N";
## vazio se o evento não é botão nem tecla.
static func codigo_do_evento(event: InputEvent) -> String:
	if event is InputEventJoypadButton:
		return "botao:%d" % int(event.button_index)
	if event is InputEventKey:
		var k := event as InputEventKey
		var fisica := int(k.physical_scancode) if k.physical_scancode != 0 else int(k.scancode)
		if fisica != 0:
			return "tecla:%d" % fisica
	return ""


static func texto_do_codigo(codigo: String) -> String:
	if codigo.begins_with("tecla:"):
		return "TECLA %s" % OS.get_scancode_string(int(codigo.substr(6)))
	return "BOTÃO %d" % int(codigo.trim_prefix("botao:"))


func texto_de(acao: String) -> String:
	var partes := []
	for ev in InputMap.get_action_list(acao):
		var t := ""
		if ev is InputEventJoypadButton:
			t = "BOTÃO %d" % int(ev.button_index)
		elif ev is InputEventKey:
			# (o Input Map do projeto tem cada tecla pelo código físico e pelo
			# comum: aparece uma vez só)
			var tecla: int = ev.physical_scancode if ev.physical_scancode != 0 else ev.scancode
			t = "TECLA %s" % OS.get_scancode_string(tecla)
		if t != "" and not t in partes:
			partes.append(t)
	return PoolStringArray(partes).join(" / ") if not partes.empty() else "-"


## É um botão da placa? A Zero Delay chega como joystick OU, no modo
## teclado, como teclas (1 = STR, A S D F G = jogadas, 5, 9...). Tecla só
## vale se estiver ligada a uma ação do jogo: as do controle remoto (setas,
## OK, voltar) não estão, então não fazem nada.
##
## CADA APERTO É UM CLIQUE. Um botão só vale de novo depois de ser SOLTO:
## segurar o START (ou qualquer botão/sensor) não repete o comando — nem a
## repetição automática do teclado, nem uma placa que reenvia o "apertado"
## sem soltar. Um repique do contato (apertar de novo em menos de
## INTERVALO_MINIMO_MS) também não conta.
func eh_da_placa(event: InputEvent) -> bool:
	# sensores e botões que vêm do ARDUINO (ArduinoBridge): ele já filtra o
	# repique e manda um aperto por bola/botão
	if event is InputEventAction and event.has_meta("arduino"):
		return true
	if event.is_echo():
		return false
	if not (event is InputEventJoypadButton or event is InputEventKey):
		return false
	# O mesmo evento passa por vários nós (menu, jogo, este): decide uma vez.
	if event == _evento_visto:
		return _veredito_visto
	var codigo := codigo_do_evento(event)
	var valido := true
	if event.is_pressed():
		var agora := Time.get_ticks_msec()
		if _abaixados.has(codigo):
			valido = false   # ainda segurado: não é um clique novo
		elif agora - int(_ultimo_clique.get(codigo, -100000)) < INTERVALO_MINIMO_MS:
			valido = false   # repique do contato
		_abaixados[codigo] = true
		if valido:
			_ultimo_clique[codigo] = agora
	else:
		_abaixados.erase(codigo)
	_evento_visto = event
	_veredito_visto = valido
	return valido


## A tecla/botão apertado não faz nada no jogo (serve para avisar o
## operador de que a configuração precisa ser feita).
func sem_funcao(event: InputEvent) -> bool:
	if not eh_da_placa(event) or not event.is_pressed():
		return false
	for item in SEQUENCIA:
		if event.is_action(item[0]):
			return false
	return true


func eh_start(event: InputEvent) -> bool:
	return eh_da_placa(event) and event.is_action_pressed("input_start")


func eh_config(event: InputEvent) -> bool:
	return eh_da_placa(event) and event.is_action_pressed("input_teste")


func eh_credito(event: InputEvent) -> bool:
	return eh_da_placa(event) and event.is_action_pressed("input_credit")


func tecla_jogada(event: InputEvent) -> String:
	if not eh_da_placa(event):
		return ""
	for acao in JOGADAS:
		if event.is_action_pressed(acao):
			return JOGADAS[acao]
	return ""


## Qualquer botão da placa conta como "alguém está jogando".
func eh_atividade(event: InputEvent) -> bool:
	return eh_da_placa(event) and event.is_pressed()


# ----------------------------------------------------- saída de emergência
## Segurar um botão da placa (ou, se a placa estiver no modo teclado, uma
## tecla dela) por 10 s no menu abre a configuração.
func _input(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton or event is InputEventKey):
		return
	if event.is_echo():
		return
	# Registra aperto/soltura de todo botão, mesmo quando a cena atual não
	# pergunta nada (abertura, transição): senão um botão solto nessa hora
	# ficaria "segurado" e o próximo clique dele seria ignorado.
	eh_da_placa(event)
	var chave := codigo_do_evento(event)
	if chave == "":
		return
	if event.is_pressed():
		if not _segurado_desde.has(chave):
			_segurado_desde[chave] = Time.get_ticks_msec()
	else:
		_segurado_desde.erase(chave)


func _process(_delta: float) -> void:
	if _segurado_desde.empty():
		return
	var cena = get_tree().current_scene
	if cena == null or cena.filename != CENA_MENU or (cena.has_method("pode_configurar") and not cena.pode_configurar()):
		# Fora do menu não conta: um aperto esquecido não pode abrir a
		# configuração assim que o menu voltar.
		_segurado_desde.clear()
		return
	var agora := Time.get_ticks_msec()
	for chave in _segurado_desde:
		if agora - int(_segurado_desde[chave]) >= SEGURAR_PARA_CONFIGURAR_MS:
			_segurado_desde.clear()
			if cena.has_method("abrir_menu"):
				# por cima do jogo pausado (nada é desmontado)
				cena.call_deferred("abrir_menu", load(CENA_CONFIGURACAO))
			else:
				get_tree().call_deferred("change_scene", CENA_CONFIGURACAO)
			return
