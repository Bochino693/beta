extends Control

## MENU DO OPERADOR (botão de configuração da máquina: R2 da Zero Delay,
## que no modo teclado manda a tecla 9 — igual ao Dragon Bowling).
##
## Navegação com os próprios sensores/botões da máquina:
##   X (meio-esquerda) = sobe        V (meio-direita) = desce
##   Z (esquerda)      = diminui     B (direita)      = aumenta
##   C (centro) ou START = escolher  Configuração     = voltar ao jogo
## No PC também valem as setas, Enter e Esc.

const JOGO := "res://cenas/principal.tscn"
const BOTOES := "res://cenas/configuracao_botoes.tscn"

## [rótulo, seção, chave, tipo, opções]
const ITENS := [
	["Rodadas por jogador", "jogo", "rodadas", "int", [1, 10]],
	["Bolas por rodada", "jogo", "tentativas", "int", [1, 3]],
	["Dificuldade", "jogo", "dificuldade", "lista", ["facil", "normal", "dificil"]],
	["Para-choques nas canaletas", "jogo", "protecao_canaleta", "bool", []],
	["Replay do strike", "jogo", "replay_strike", "bool", []],
	["Demonstração na tela inicial", "jogo", "demo", "bool", []],
	["Modo livre (sem ficha)", "jogo", "modo_livre", "bool", []],
	["Foto das crianças (câmera)", "jogo", "foto", "bool", []],
	["Giro da câmera", "jogo", "camera_giro", "lista", [0, 90, 180, 270]],
	["Espelhar a câmera", "jogo", "camera_espelho", "bool", []],
	["Fichas por partida", "jogo", "creditos_por_partida", "int", [1, 5]],
	["Tempo sem jogar até o aviso (s)", "jogo", "tempo_inatividade", "int", [20, 180]],
	["Volume da música", "som", "musica", "vol", []],
	["Volume dos efeitos", "som", "efeitos", "vol", []],
	["Som na demonstração", "som", "som_na_demo", "bool", []],
	["Qualidade gráfica", "video", "qualidade", "lista", ["auto", "alta", "media", "baixa"]],
	["Giro da tela", "tela", "giro", "lista", [1, -1, 0]],
	["> TESTE DOS SENSORES", "", "teste", "acao", []],
	["> TESTE DA CÂMERA", "", "camera", "acao", []],
	["> CONFIGURAR BOTÕES DA PLACA", "", "botoes", "acao", []],
	["> ZERAR RECORDES", "", "recordes", "acao", []],
	["> RESTAURAR PADRÃO DE FÁBRICA", "", "padrao", "acao", []],
	["> VOLTAR AO JOGO", "", "voltar", "acao", []],
]
const NOMES := {"facil": "FÁCIL", "normal": "NORMAL", "dificil": "DIFÍCIL", "auto": "AUTOMÁTICA", "alta": "ALTA",
	"media": "MÉDIA", "baixa": "BAIXA", 1: "1 (topo à esquerda)", -1: "-1 (topo à direita)", 0: "0 (sem giro)",
	90: "90°", 180: "180°", 270: "270°"}

var _sel := 0
var _linhas: Array[Label] = []
var _fonte: Font
var _info: Label
var _teste := false
var _teste_contagem := [0, 0, 0, 0, 0]
var _teste_rotulo: Label
var _camera := false
var _camera_tela: TextureRect
var u := 1.0


func _ready() -> void:
	Tela.cobrir(self)
	_fonte = load("res://fontes/fredoka_700.ttf")
	var T := Tela.tamanho()
	u = min(T.x, T.y) / 1080.0
	var fundo := ColorRect.new()
	fundo.color = Color(0.03, 0.09, 0.22)
	fundo.size = T
	add_child(fundo)
	var titulo := _rotulo("STRIKE KIDS · OPERADOR", Vector2(0, 40 * u), 58 * u, Color("#FFD43B"))
	titulo.size.x = T.x
	# logo Lazer & Sport no canto
	var marca := TextureRect.new()
	marca.texture = load("res://ui/marca/lazer_sport.png")
	marca.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	marca.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	marca.size = Vector2(150, 100) * u
	marca.position = Vector2(T.x - 170 * u, 18 * u)
	add_child(marca)
	var esp: float = min(68.0 * u, (T.y - 420 * u) / ITENS.size())
	var y := 150 * u
	for i in ITENS.size():
		var l := _rotulo("", Vector2(60 * u, y), min(34 * u, esp * 0.55), Color.WHITE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.size.x = T.x - 120 * u
		_linhas.append(l)
		y += esp
	_info = _rotulo("", Vector2(0, T.y - 250 * u), 26 * u, Color(1, 1, 1, 0.75))
	_info.size = Vector2(T.x, 220 * u)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_teste_rotulo = _rotulo("", Vector2(0, T.y * 0.35), 54 * u, Color.WHITE)
	_teste_rotulo.size = Vector2(T.x, 500 * u)
	_teste_rotulo.visible = false
	_camera_tela = TextureRect.new()
	_camera_tela.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_camera_tela.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_camera_tela.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var lado: float = minf(T.x * 0.8, T.y * 0.5)
	_camera_tela.size = Vector2(lado, lado)
	_camera_tela.position = Vector2((T.x - lado) / 2, T.y * 0.3)
	_camera_tela.visible = false
	add_child(_camera_tela)
	Fotos.mudou.connect(_atualizar)
	_atualizar()


func _rotulo(texto: String, pos: Vector2, tam: float, cor: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.position = pos
	l.size = Vector2(Tela.tamanho().x, tam * 1.5)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var ls := LabelSettings.new()
	ls.font = _fonte
	ls.font_size = int(tam)
	ls.font_color = cor
	ls.outline_size = int(tam * 0.18)
	ls.outline_color = Color("#0B1F45")
	l.label_settings = ls
	add_child(l)
	return l


func _valor_texto(item: Array) -> String:
	if item[3] == "acao":
		return ""
	var v = Ajustes.valor(item[1], item[2]) if item[1] != "tela" else Tela.giro
	match item[3]:
		"bool":
			return "SIM" if bool(v) else "NÃO"
		"vol":
			return "%d" % int(round(float(v) * 10.0))
		"lista":
			return str(NOMES.get(v, str(v)))
	return str(v)


func _atualizar() -> void:
	for i in ITENS.size():
		var item: Array = ITENS[i]
		var l := _linhas[i]
		var v := _valor_texto(item)
		l.text = ("▶ " if i == _sel else "   ") + str(item[0]) + ("" if v == "" else ":   " + v)
		l.label_settings.font_color = Color("#FFD43B") if i == _sel else Color(1, 1, 1, 0.85)
	_info.text = "X sobe · V desce · Z diminui · B aumenta · C/START escolhe · CONFIGURAÇÃO volta\n" + \
		"Partidas: %d   ·   Strikes: %d   ·   Moedas: %d   ·   Arduino: %s\nCâmera: %s" % [Ajustes.contador("partidas"),
		Ajustes.contador("strikes"), Ajustes.contador("moedas"), ArduinoBridge.status, Fotos.texto_status()]


func _input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed():
		ArcadeControls.eh_da_placa(event)
		return
	get_viewport().set_input_as_handled()
	var cmd := ""
	if ArcadeControls.eh_config(event):
		cmd = "sair"
	elif ArcadeControls.eh_start(event):
		cmd = "ok"
	else:
		var z := ArcadeControls.tecla_jogada(event)
		cmd = {"X": "sobe", "V": "desce", "Z": "menos", "B": "mais", "C": "ok"}.get(z, "")
		if _teste and z != "":
			var i := ["Z", "X", "C", "V", "B"].find(z)
			_teste_contagem[i] += 1
			_mostrar_teste(z)
			return
	if cmd == "" and event is InputEventKey:
		cmd = {KEY_UP: "sobe", KEY_DOWN: "desce", KEY_LEFT: "menos", KEY_RIGHT: "mais", KEY_ENTER: "ok", KEY_ESCAPE: "sair"}.get((event as InputEventKey).keycode, "")
	if cmd == "":
		return
	if _camera and (cmd == "menos" or cmd == "mais"):
		# no teste da câmera, Z / B giram a imagem (câmera montada de lado)
		var g := (int(Ajustes.valor("jogo", "camera_giro")) + (90 if cmd == "mais" else 270)) % 360
		Ajustes.definir("jogo", "camera_giro", g)
		Sons.tocar("selecao")
		return
	if _teste or _camera:
		if cmd == "sair" or cmd == "ok":
			_teste = false
			_camera = false
			_teste_rotulo.visible = false
			_teste_rotulo.position.y = Tela.tamanho().y * 0.35
			_teste_rotulo.size.y = 500 * u
			_camera_tela.visible = false
			Fotos.desligar(2.0)
			for l in _linhas:
				l.visible = true
		return
	match cmd:
		"sobe":
			_sel = (_sel - 1 + ITENS.size()) % ITENS.size()
		"desce":
			_sel = (_sel + 1) % ITENS.size()
		"menos":
			_mudar(-1)
		"mais":
			_mudar(1)
		"ok":
			_acao()
		"sair":
			get_tree().change_scene_to_file.call_deferred(JOGO)
	_atualizar()


func _mudar(d: int) -> void:
	var item: Array = ITENS[_sel]
	var v = Ajustes.valor(item[1], item[2]) if item[1] != "tela" else Tela.giro
	match item[3]:
		"int":
			v = clampi(int(v) + d, item[4][0], item[4][1])
		"bool":
			v = not bool(v)
		"vol":
			v = clampf(snappedf(float(v) + d * 0.1, 0.1), 0.0, 1.0)
		"lista":
			var op: Array = item[4]
			v = op[(op.find(v) + d + op.size()) % op.size()]
		_:
			return
	if item[1] == "tela":
		Ajustes.definir("tela", "giro", v)
		Tela.definir_giro(int(v))
		get_tree().reload_current_scene.call_deferred()
		return
	Ajustes.definir(item[1], item[2], v)
	if item[2] == "foto":
		Fotos.iniciar()
	Sons.atualizar_volume()
	Sons.tocar("selecao")


func _acao() -> void:
	var item: Array = ITENS[_sel]
	if item[3] != "acao":
		_mudar(1)
		return
	match item[2]:
		"teste":
			_teste = true
			for l in _linhas:
				l.visible = false
			_teste_rotulo.visible = true
			_mostrar_teste("")
		"camera":
			_camera = true
			for l in _linhas:
				l.visible = false
			_teste_rotulo.visible = true
			if Fotos.ligar():
				_camera_tela.texture = Fotos.ao_vivo()
				_camera_tela.visible = true
				_teste_rotulo.position.y = 40 * u
				_teste_rotulo.size.y = Tela.tamanho().y * 0.25
				_teste_rotulo.text = "TESTE DA CÂMERA\n%s\nZ / B giram a imagem · START sai" % Fotos.nome_camera
			else:
				_teste_rotulo.text = "TESTE DA CÂMERA\n\nCâmera: %s\n\nConfira o cabo USB da câmera e se a\nTV Box mostra a câmera no Android.\n\nSTART ou CONFIGURAÇÃO para sair" % Fotos.texto_status()
		"botoes":
			get_tree().change_scene_to_file.call_deferred(BOTOES)
		"recordes":
			Ajustes.zerar_recordes()
			Sons.tocar("pop")
		"padrao":
			Ajustes.restaurar_padrao()
			Sons.tocar("pop")
		"voltar":
			get_tree().change_scene_to_file.call_deferred(JOGO)


func _mostrar_teste(ultimo: String) -> void:
	var nomes := ["ESQUERDA (Z)", "MEIO-ESQ. (X)", "CENTRO (C)", "MEIO-DIR. (V)", "DIREITA (B)"]
	var txt := "TESTE DOS SENSORES\nrole a bola em cada posição\n\n"
	for i in 5:
		txt += "%s%s:  %d\n" % ["▶ " if ["Z", "X", "C", "V", "B"][i] == ultimo else "", nomes[i], _teste_contagem[i]]
	txt += "\nSTART ou CONFIGURAÇÃO para sair"
	_teste_rotulo.text = txt
	if ultimo != "":
		Sons.tocar("selecao")
