extends Control

## MENU DO OPERADOR: o botão de CONFIGURAÇÃO da máquina (no Arduino, ou o
## R2 da Zero Delay / tecla 9) entra aqui, e apertado de novo volta ao jogo.
## Aqui se testa tudo: os sensores (ao vivo), a porta (trava), a câmera.
##
## Navegação com os próprios sensores/botões da máquina:
##   X (meio-esquerda) = sobe        V (meio-direita) = desce
##   Z (esquerda)      = diminui     B (direita)      = aumenta
##   C (centro) ou START = escolher  Configuração     = voltar ao jogo
## Pelo CONTROLE REMOTO da TV Box: setas (cima/baixo andam, esquerda/direita
## mudam o valor), OK escolhe, VOLTAR (ou MENU) sai. No PC: setas, Enter e Esc.
##
## O menu abre POR CIMA do jogo pausado (Principal.abrir_menu): nada do
## jogo é desmontado, e sair dele é na hora.
##
## ABRIR O JOGO AO LIGAR A TV: o jogo vira a TELA INICIAL do Android (o
## plugin StrikeSerial, InicioDaTv): a TV abre o jogo ao ligar na tomada,
## pelo controle e a cada HOME. SAIR PARA A TELA DA TV abre o início da
## própria TV (ajustes, outros apps); um HOME volta ao jogo.

const JOGO := "res://cenas/principal.tscn"
const BOTOES := "res://cenas/configuracao_botoes.tscn"
## Godot 3: sem LabelSettings — o Compat monta a fonte de cada tamanho pelo nome
const FONTE := "fredoka_700"

## [rótulo, seção, chave, tipo, opções]
const ITENS := [
	["Rodadas por jogador", "jogo", "rodadas", "int", [1, 10]],
	["Bolas por rodada", "jogo", "tentativas", "int", [1, 3]],
	["Dificuldade", "jogo", "dificuldade", "lista", ["facil", "normal", "dificil"]],
	["Velocidade do jogo", "jogo", "velocidade", "lista", [100, 115, 130, 145, 160]],
	["Para-choques nas canaletas", "jogo", "protecao_canaleta", "bool", []],
	["Replay do strike", "jogo", "replay_strike", "bool", []],
	["Demonstração na tela inicial", "jogo", "demo", "bool", []],
	["Modo livre (sem ficha e sem trava)", "jogo", "modo_livre", "bool", []],
	["Foto das crianças (câmera)", "jogo", "foto", "bool", []],
	["Giro da câmera", "jogo", "camera_giro", "lista", [0, 90, 180, 270]],
	["Espelhar a câmera", "jogo", "camera_espelho", "bool", []],
	["Fichas por jogador", "jogo", "creditos_por_partida", "int", [1, 5]],
	["Tempo sem jogar até o aviso (s)", "jogo", "tempo_inatividade", "int", [20, 180]],
	["Volume da música", "som", "musica", "vol", []],
	["Volume dos efeitos", "som", "efeitos", "vol", []],
	["Som na demonstração", "som", "som_na_demo", "bool", []],
	["Qualidade gráfica", "video", "qualidade", "lista", ["auto", "alta", "media", "baixa"]],
	["Cenário (fundo)", "video", "cenario", "lista", ["leve", "completo"]],
	["Detalhes extras (vento, enfeites, borboletas)", "video", "detalhes", "bool", []],
	["Cenário 3D (auto = alivia sozinho)", "video", "cenario3d", "lista", ["auto", "alto", "leve"]],
	["Resolução da imagem (TV Box)", "video", "resolucao", "lista", ["auto", "720p", "900p", "1080p", "tela"]],
	["Quadros por segundo", "video", "qps", "lista", ["auto", "60", "30"]],
	["Desenho da tela", "video", "desenho", "lista", ["auto", "direto", "imagem"]],
	["Antisserrilhado da tela (ao reabrir)", "video", "antisserrilhado", "bool", []],
	["Nitidez do 3D (só no desenho imagem)", "video", "nitidez", "lista", ["auto", "100%", "90%", "80%", "70%"]],
	["Mostrar desempenho na tela (QPS)", "video", "medidor", "bool", []],
	["> TESTE DE DESEMPENHO (20 s)", "", "desempenho", "acao", []],
	["Giro da tela", "tela", "giro", "lista", [1, -1, 0]],
	["> TESTE DOS SENSORES", "", "teste", "acao", []],
	["> CALIBRAR SENSORES (pista vazia)", "", "calibrar", "acao", []],
	["Sensores invertidos (direita/esquerda)", "arduino", "sensores_invertidos", "bool", []],
	["> TESTE DA PORTA (trava das bolas)", "", "porta", "acao", []],
	["Porta invertida", "arduino", "porta_invertida", "bool", []],
	["Porta: tempo do motor (ponte H sem fim de curso)", "arduino", "porta_tempo", "lista",
		[500, 800, 1000, 1200, 1500, 2000, 2500, 3000, 4000, 5000, 6000, 8000, 10000]],
	["Porta: fim de curso (micro-switch A3/A4)", "arduino", "porta_fim_de_curso", "bool", []],
	["> TESTE DA CÂMERA", "", "camera", "acao", []],
	["> CONFIGURAR BOTÕES DA PLACA", "", "botoes", "acao", []],
	["> ABRIR O JOGO AO LIGAR A TV", "", "inicio", "acao", []],
	["> SAIR PARA A TELA DA TV (ajustes, outros apps)", "", "sair_tv", "acao", []],
	["> ZERAR RECORDES", "", "recordes", "acao", []],
	["> RESTAURAR PADRÃO DE FÁBRICA", "", "padrao", "acao", []],
	["> VOLTAR AO JOGO", "", "voltar", "acao", []],
]
const NOMES := {"facil": "FÁCIL", "normal": "NORMAL", "dificil": "DIFÍCIL", "auto": "AUTOMÁTICA", "alta": "ALTA",
	"media": "MÉDIA", "baixa": "BAIXA", "leve": "LEVE (TV Box)", "completo": "COMPLETO",
	"direto": "DIRETO NA TELA (rápido)", "720p": "720p (mais leve)", "900p": "900p", "1080p": "1080p (Full HD)",
	"tela": "A DA PRÓPRIA TELA", "60": "60 (o mais liso)", "30": "30 TRAVADOS (uniforme)", "imagem": "IMAGEM 3D (compatível)", 1: "1 (topo à esquerda)", -1: "-1 (topo à direita)", 0: "0 (sem giro)",
	90: "90°", 180: "180°", 270: "270°", 100: "100% (tempo real)", 115: "115%", 130: "130% (padrão)", 145: "145%",
	160: "160%"}

var _sel := 0
var _linhas: Array = []
var _info: Label
var _teste := false
var _teste_contagem := [0, 0, 0, 0, 0]
var _teste_rotulo: Label
var _camera := false
var _camera_tela: TextureRect
var _camera_ms := 0
var _camera_t := 0.0
var _porta := false            # teste da porta
var _calibrando := false       # calibração dos sensores
var _inicio := false           # abrir o jogo ao ligar a TV
var _inicio_estado := ""       # "jogo", "escolher", "outra|Nome" ("" = fora da TV Box)
var _inicio_passo := "-"       # o que a última escolha abriu ("-" = nenhuma ainda)
var _topo := 0                 # rolagem da lista (tela deitada)
var _visiveis := 0
var _esp := 0.0
var u := 1.0


func _ready() -> void:
	_montar()
	# Godot 3: sem Callable, a conexão é pelo nome do método
	Fotos.connect("mudou", self, "_atualizar")
	ArduinoBridge.connect("mudou", self, "_arduino_mudou")
	# no menu a porta das bolas fica fechada; aqui pode aparecer a janela
	# de permissão USB do Arduino
	ArduinoBridge.porta(false)
	ArduinoBridge.na_espera(true)
	_inicio_estado = tela_inicial()
	_atualizar()


## De volta ao jogo (depois da escolha da tela inicial ou da tela da TV):
## confere de novo se a TV já abre o jogo sozinha.
func _notification(what: int) -> void:
	if what != MainLoop.NOTIFICATION_WM_FOCUS_IN or _linhas.empty():
		return
	_inicio_estado = tela_inicial()
	if _inicio:
		_mostrar_inicio()
	else:
		_atualizar()


## A TV abre o jogo sozinha ao ligar? "jogo" (o jogo é a tela inicial),
## "escolher" (o Android ainda pergunta), "outra|Nome" ou "" (fora da TV Box).
static func tela_inicial() -> String:
	if not Engine.has_singleton("StrikeSerial"):
		return ""
	return str(Engine.get_singleton("StrikeSerial").tela_inicial())


func _montar() -> void:
	Tela.cobrir(self)
	var T: Vector2 = Tela.tamanho()
	u = min(T.x, T.y) / 1080.0
	var fundo := ColorRect.new()
	fundo.color = Color(0.03, 0.09, 0.22)
	fundo.rect_size = T
	add_child(fundo)
	var titulo := _rotulo("STRIKE KIDS · OPERADOR", Vector2(0, 40 * u), 58 * u, Color("#FFD43B"))
	titulo.rect_size.x = T.x
	# a lista inteira se couber; senão, uma janela que rola com a seleção
	var area: float = T.y - 420 * u
	_esp = clamp(area / ITENS.size(), 44.0 * u, 68.0 * u)
	_visiveis = Compat.imin(ITENS.size(), int(area / _esp))
	for i in ITENS.size():
		var l := _rotulo("", Vector2(60 * u, 150 * u), min(34 * u, _esp * 0.55), Color.white)
		l.align = Label.ALIGN_LEFT
		l.rect_size.x = T.x - 120 * u
		_linhas.append(l)
	_info = _rotulo("", Vector2(0, T.y - 250 * u), 26 * u, Color(1, 1, 1, 0.75))
	_info.rect_size = Vector2(T.x, 220 * u)
	_info.autowrap = true
	_teste_rotulo = _rotulo("", Vector2(0, T.y * 0.35), 54 * u, Color.white)
	_teste_rotulo.rect_size = Vector2(T.x, 500 * u)
	_teste_rotulo.autowrap = true
	_teste_rotulo.visible = false
	_camera_tela = TextureRect.new()
	_camera_tela.expand = true
	_camera_tela.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Godot 3: o filtro linear é da textura (ver _camera_ao_vivo), não do nó
	var lado: float = min(T.x * 0.8, T.y * 0.5)
	_camera_tela.rect_size = Vector2(lado, lado)
	_camera_tela.rect_position = Vector2((T.x - lado) / 2, T.y * 0.3)
	_camera_tela.visible = false
	add_child(_camera_tela)


## A tela girou (giro da tela mudou): monta o menu de novo no tamanho novo.
func _remontar() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_linhas.clear()
	_topo = 0
	_montar()
	_atualizar()


## Volta ao jogo (que ficou pausado por baixo do menu).
func _sair() -> void:
	var jogo: Node = get_tree().current_scene
	if jogo != null and jogo != self and jogo.has_method("fechar_menu"):
		jogo.fechar_menu()
	else:
		get_tree().call_deferred("change_scene", JOGO)


func _rotulo(texto: String, pos: Vector2, tam: float, cor: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.rect_position = pos
	l.rect_size = Vector2(Tela.tamanho().x, tam * 1.5)
	l.align = Label.ALIGN_CENTER
	l.valign = Label.VALIGN_CENTER
	Compat.estilo_rotulo(l, FONTE, int(tam), cor, Compat.contorno_g4(int(tam * 0.18)), Color("#0B1F45"))
	add_child(l)
	return l


func _valor_texto(item: Array) -> String:
	if item[3] == "acao":
		if item[2] == "inicio" and _inicio_estado != "":
			return "SIM" if _inicio_estado == "jogo" else "NÃO"
		return ""
	var v = Ajustes.valor(item[1], item[2]) if item[1] != "tela" else Tela.giro
	if item[2] == "cenario":
		v = Ajustes.cenario()
	if item[2] == "porta_tempo" or item[2] == "porta_fim_de_curso":
		# só a ponte H usa; o Arduino do relé (arduino/1_RELE_principal) ignora
		var t := _segundos(int(v)) if item[2] == "porta_tempo" else ("SIM" if bool(v) else "NÃO")
		return t + (" · relé: não usa" if ArduinoBridge.sem_ponte() else "")
	match item[3]:
		"bool":
			return "SIM" if bool(v) else "NÃO"
		"vol":
			return "%d" % int(round(float(v) * 10.0))
		"lista":
			return str(NOMES.get(v, str(v)))
	return str(v)


## 1500 -> "1,5 s"
static func _segundos(ms: int) -> String:
	var t := "%d" % (ms / 1000)
	if ms % 1000 != 0:
		t += ",%d" % ((ms % 1000) / 100)
	return t + " s"


func _atualizar() -> void:
	if _sel < _topo:
		_topo = _sel
	elif _sel >= _topo + _visiveis:
		_topo = _sel - _visiveis + 1
	var em_teste := _teste or _camera or _porta or _calibrando or _inicio
	for i in ITENS.size():
		var item: Array = ITENS[i]
		var l: Label = _linhas[i]
		var v := _valor_texto(item)
		var j: int = i - _topo
		l.visible = not em_teste and j >= 0 and j < _visiveis
		l.rect_position.y = 150 * u + j * _esp
		# Godot 3: as fontes do jogo não têm ▶ ● ○ (o Godot 4 achava nas fontes
		# do sistema) — aqui e no teste dos sensores vão » • –
		l.text = ("» " if i == _sel else "   ") + str(item[0]) + ("" if v == "" else ":   " + v)
		Compat.cor_rotulo(l, Color("#FFD43B") if i == _sel else Color(1, 1, 1, 0.85))
	var rolar := ""
	if _visiveis < ITENS.size():
		rolar = "   (%d de %d)" % [_sel + 1, ITENS.size()]
	_info.text = "X sobe · V desce · Z diminui · B aumenta · C/START escolhe · CONFIGURAÇÃO volta%s\n" % rolar + \
		"Controle da TV Box: setas andam e mudam · OK escolhe · VOLTAR sai\n" + \
		"Partidas: %d   ·   Strikes: %d   ·   Moedas: %d\n%s\nCâmera: %s\n%s" % [Ajustes.contador("partidas"),
		Ajustes.contador("strikes"), Ajustes.contador("moedas"), ArduinoBridge.status, Fotos.texto_status(),
		texto_aparelho()]


## Qual é o aparelho (para saber qual TV Box é — a TX9, por exemplo, sai
## com chips diferentes): modelo, sistema, placa de vídeo, núcleos e memória.
## Godot 3: sem OS.get_memory_info() nem OS.get_version() — a memória total
## vem do /proc/meminfo e a versão do Android do /system/build.prop. O que
## não muda é lido uma vez só (o menu atualiza a cada mudança do Arduino).
static func texto_aparelho() -> String:
	var e: Dictionary = Compat.estado("operador")
	if not e.has("aparelho"):
		var sistema := OS.get_name()
		var versao := _ler_campo("/system/build.prop", "ro.build.version.release=")
		if versao != "":
			sistema += " " + versao
		var placa := VisualServer.get_video_adapter_name()
		var fabricante := VisualServer.get_video_adapter_vendor()
		if fabricante != "" and placa.findn(fabricante) < 0:
			placa = fabricante + " " + placa   # "ARM Mali-450 MP"
		var gles := "OpenGL ES 2.0" if OS.get_current_video_driver() == OS.VIDEO_DRIVER_GLES2 else "OpenGL ES 3.0"
		var gb := float(_ler_campo("/proc/meminfo", "MemTotal:").to_int()) / 1048576.0   # kB -> GB
		e["aparelho"] = "Aparelho: %s · %s · %s · %s · %d núcleos%s" % [OS.get_model_name(), sistema, placa, gles,
			OS.get_processor_count(), " · %.1f GB" % gb if gb > 0.0 else ""]
	# memória usada pelo jogo: só as versões de teste (debug) do Godot contam
	var mb: int = OS.get_static_memory_usage() / 1048576
	return str(e["aparelho"]) + (" · jogo usa %d MB" % mb if mb > 0 else "")


## O valor da linha que começa com `prefixo` num arquivo do sistema (vazio
## se não houver). Linha a linha: os arquivos do /proc dizem tamanho 0.
static func _ler_campo(caminho: String, prefixo: String) -> String:
	var f := File.new()
	if not f.file_exists(caminho) or f.open(caminho, File.READ) != OK:
		return ""
	var valor := ""
	while not f.eof_reached():
		var linha := f.get_line().strip_edges()
		if linha.begins_with(prefixo):
			valor = linha.substr(prefixo.length()).strip_edges()
			break
	f.close()
	return valor


func _arduino_mudou() -> void:
	if _teste:
		_mostrar_teste("")
	elif _porta:
		_mostrar_porta()
	elif _calibrando:
		_mostrar_calibracao()
	else:
		_atualizar()


func _input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed():
		ArcadeControls.eh_da_placa(event)
		return
	get_tree().set_input_as_handled()
	var cmd := ""
	if ArcadeControls.eh_config(event):
		cmd = "sair"
	elif ArcadeControls.eh_start(event):
		cmd = "ok"
	else:
		var z: String = ArcadeControls.tecla_jogada(event)
		cmd = {"X": "sobe", "V": "desce", "Z": "menos", "B": "mais", "C": "ok"}.get(z, "")
		if _teste and z != "":
			var i: int = ["Z", "X", "C", "V", "B"].find(z)
			_teste_contagem[i] += 1
			_mostrar_teste(z)
			return
	if cmd == "" and event is InputEventKey:
		# teclado do PC e CONTROLE REMOTO da TV Box (no Android: setas = D-pad,
		# OK = Enter, VOLTAR = Back, e a tecla MENU)
		cmd = {KEY_UP: "sobe", KEY_DOWN: "desce", KEY_LEFT: "menos", KEY_RIGHT: "mais",
			KEY_ENTER: "ok", KEY_KP_ENTER: "ok", KEY_ESCAPE: "sair", KEY_BACK: "sair",
			KEY_MENU: "sair"}.get((event as InputEventKey).scancode, "")
	if cmd != "":
		comando(cmd)


## Um comando do menu (dos botões da máquina, do teclado ou do controle
## remoto da TV Box — o VOLTAR do Android chega pelo Principal).
func comando(cmd: String) -> void:
	if _camera and (cmd == "menos" or cmd == "mais"):
		# no teste da câmera, Z / B giram a imagem (câmera montada de lado)
		var g := (int(Ajustes.valor("jogo", "camera_giro")) + (90 if cmd == "mais" else 270)) % 360
		Ajustes.definir("jogo", "camera_giro", g)
		Sons.tocar("selecao")
		return
	if _porta and cmd == "ok":
		# teste da porta: C ou START abre/fecha; CONFIGURAÇÃO sai
		ArduinoBridge.porta(not ArduinoBridge.porta_quer)
		Sons.tocar("selecao")
		_mostrar_porta()
		return
	if _inicio and cmd == "ok" and _inicio_estado != "" and _inicio_estado != "jogo":
		# OK: abre a escolha da tela inicial do Android
		_inicio_passo = str(Engine.get_singleton("StrikeSerial").escolher_tela_inicial())
		Sons.tocar("selecao")
		_mostrar_inicio()
		return
	if _teste or _camera or _porta or _calibrando or _inicio:
		if cmd == "sair" or cmd == "ok":
			_sair_do_teste()
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
			_sair()
			return
	_atualizar()


func _mudar(d: int) -> void:
	var item: Array = ITENS[_sel]
	var v = Ajustes.valor(item[1], item[2]) if item[1] != "tela" else Tela.giro
	if item[2] == "cenario":
		v = Ajustes.cenario()
	match item[3]:
		"int":
			v = Compat.iclamp(int(v) + d, item[4][0], item[4][1])
		"bool":
			v = not bool(v)
		"vol":
			v = clamp(stepify(float(v) + d * 0.1, 0.1), 0.0, 1.0)
		"lista":
			var op: Array = item[4]
			v = op[(op.find(v) + d + op.size()) % op.size()]
		_:
			return
	if item[1] == "tela":
		Ajustes.definir("tela", "giro", v)
		Tela.definir_giro(int(v))
		Sons.tocar("selecao")
		_remontar()
		return
	Ajustes.definir(item[1], item[2], v)
	if item[2] == "foto":
		Fotos.iniciar()
		if bool(v):
			Fotos.pedir_permissao_agora()
	if item[2] == "porta_invertida":
		ArduinoBridge.reenviar_porta()
	if item[2] == "porta_tempo" or item[2] == "porta_fim_de_curso":
		ArduinoBridge.enviar_ponte()
	Sons.atualizar_volume()
	Sons.tocar("selecao")


func _acao() -> void:
	var item: Array = ITENS[_sel]
	if item[3] != "acao":
		_mudar(1)
		return
	match item[2]:
		"teste":
			ArduinoBridge.pedir_permissao_agora()
			_teste = true
			_teste_contagem = [0, 0, 0, 0, 0]
			_entrar_no_teste()
			ArduinoBridge.modo_teste(true)
			_mostrar_teste("")
		"calibrar":
			ArduinoBridge.pedir_permissao_agora()
			_calibrando = true
			_entrar_no_teste()
			ArduinoBridge.calibrar()
			_mostrar_calibracao()
		"porta":
			ArduinoBridge.pedir_permissao_agora()
			_porta = true
			_entrar_no_teste()
			ArduinoBridge.porta(false)
			_mostrar_porta()
		"camera":
			_camera = true
			_entrar_no_teste()
			# confere a câmera e pede de novo a permissão que faltar (o jogo
			# sozinho só pede uma vez na vida)
			Fotos.pedir_permissao_agora()
			Fotos.na_espera()
			_camera_ms = Time.get_ticks_msec()
			if Fotos.ligar():
				_camera_ao_vivo()
			else:
				_camera_relatorio("")
		"botoes":
			var jogo: Node = get_tree().current_scene
			if jogo != null and jogo != self and jogo.has_method("abrir_menu"):
				jogo.abrir_menu(load(BOTOES))
			else:
				get_tree().call_deferred("change_scene", BOTOES)
		"inicio":
			_inicio = true
			_inicio_passo = "-"
			_inicio_estado = tela_inicial()
			_entrar_no_teste()
			_mostrar_inicio()
		"sair_tv":
			if Engine.has_singleton("StrikeSerial"):
				Engine.get_singleton("StrikeSerial").sair_para_tv()
			else:
				_inicio = true
				_entrar_no_teste()
				_mostrar_inicio()
		"desempenho":
			# volta ao jogo e roda o teste
			Ajustes.definir("video", "testar", true)
			_sair()
		"recordes":
			Ajustes.zerar_recordes()
			Sons.tocar("pop")
		"padrao":
			Ajustes.restaurar_padrao()
			ArduinoBridge.enviar_ponte()   # a ponte H volta ao de fábrica também
			ArduinoBridge.reenviar_porta()
			Sons.tocar("pop")
		"voltar":
			_sair()


func _entrar_no_teste() -> void:
	for l in _linhas:
		l.visible = false
	_teste_rotulo.visible = true
	_teste_rotulo.text = ""
	Compat.tamanho_rotulo(_teste_rotulo, int(42 * u))
	_teste_rotulo.rect_position = Vector2(40 * u, 120 * u)
	_teste_rotulo.rect_size = Vector2(Tela.tamanho().x - 80 * u, Tela.tamanho().y - 400 * u)


func _sair_do_teste() -> void:
	if _teste:
		ArduinoBridge.modo_teste(false)
	if _porta:
		ArduinoBridge.porta(false)
	_teste = false
	_camera = false
	_porta = false
	_calibrando = false
	_inicio = false
	_teste_rotulo.visible = false
	_teste_rotulo.text = ""
	_teste_rotulo.rect_position = Vector2(0, Tela.tamanho().y * 0.35)
	_teste_rotulo.rect_size = Vector2(Tela.tamanho().x, 500 * u)
	Compat.tamanho_rotulo(_teste_rotulo, int(54 * u))
	_camera_tela.visible = false
	Fotos.desligar(2.0)
	_atualizar()


## As últimas linhas do relatório do Arduino (USB, chip, firmware), para
## quando ele não está conectado.
func _relatorio_arduino() -> String:
	var linhas: PoolStringArray = ArduinoBridge.relatorio().split("\n")
	# Godot 3: o slice tem o fim incluído e não há String.join
	return PoolStringArray(Compat.fatia(linhas, 0, 12)).join("\n")


## Teste da porta: o que o jogo pediu e o que o Arduino confirmou.
func _mostrar_porta() -> void:
	var t := "TESTE DA PORTA (trava das bolas)\n\n"
	if ArduinoBridge.completo():
		var pedida: String = "ABERTA" if ArduinoBridge.porta_quer else "FECHADA"
		var confirmada: String = "ABERTA" if ArduinoBridge.porta_aberta else "FECHADA"
		t += "Porta: %s\n" % pedida
		t += ("(o Arduino confirmou)" if confirmada == pedida else "(esperando o Arduino...)") + "\n\n"
		if ArduinoBridge.aviso == "PORTA_TRAVOU":
			t += "A PORTA NÃO CHEGOU: confira o motor, a ponte H e o fim de curso\n\n"
		t += _texto_ponte() + "\n\n"
		t += "C ou START: abre / fecha\nCONFIGURAÇÃO: sai (a porta fecha)\n\n"
		t += "Abriu quando devia fechar? Ligue \"Porta invertida\" no menu\n(ponte H com fim de curso: inverta os fios do motor)."
	else:
		Compat.tamanho_rotulo(_teste_rotulo, int(30 * u))
		t += "SEM O ARDUINO\n%s\n\n%s\n\nCONFIGURAÇÃO ou START sai" % [ArduinoBridge.status, _relatorio_arduino()]
	_teste_rotulo.text = t


## A porta como o Arduino está usando: a versão do RELÉ (arduino/1_RELE_principal,
## confirma na hora) ou a da PONTE H (o tempo e o fim de curso do menu).
func _texto_ponte() -> String:
	if ArduinoBridge.versao() < 3:
		return "Firmware antigo (versão %d): grave o Arduino da pasta arduino/1_RELE_principal (relé)\nou da arduino/2_PONTE_H (ponte H)" % ArduinoBridge.versao()
	if ArduinoBridge.sem_ponte():
		return "Arduino do RELÉ/SERVO (sem ponte H): confirma a porta na hora\n(\"tempo do motor\" e \"fim de curso\" são só da ponte H)"
	var fc := bool(Ajustes.valor("arduino", "porta_fim_de_curso"))
	var t := "Ponte H: anda até o FIM DE CURSO (A3 aberta, A4 fechada)" if fc else \
		"Ponte H: anda %s (\"Porta: tempo do motor\")" % _segundos(int(Ajustes.valor("arduino", "porta_tempo")))
	if ArduinoBridge.ponte != "" and ArduinoBridge.ponte != ArduinoBridge.ponte_pedida():
		t += "\n(mandando ao Arduino...)"
	return t


## Abrir o jogo ao ligar a TV: se o jogo já é a tela inicial do Android e,
## se não, como escolher (OK abre a escolha do Android).
func _mostrar_inicio() -> void:
	Compat.tamanho_rotulo(_teste_rotulo, int(30 * u))
	var t := "ABRIR O JOGO AO LIGAR A TV\n\n"
	if _inicio_estado == "":
		t += "Só na TV Box (Android).\n\nCONFIGURAÇÃO ou START sai"
	elif _inicio_estado == "jogo":
		t += "PRONTO! A TV abre o STRIKE KIDS sozinha: ligando na tomada,\n" + \
			"pelo controle remoto (volta da espera) e a cada HOME.\n\n" + \
			"Para usar a TV (ajustes, outros apps): > SAIR PARA A TELA DA TV,\n" + \
			"ou HOME 5 vezes seguidas no controle remoto. Um HOME volta ao jogo.\n\n" + \
			"CONFIGURAÇÃO ou START sai"
	else:
		var nome := _inicio_estado.substr(6) if _inicio_estado.begins_with("outra|") else ""
		if nome != "":
			t += "AINDA NÃO: hoje a TV abre \"%s\".\n\n" % nome
		else:
			t += "AINDA NÃO: o Android ainda pergunta qual é a tela inicial.\n\n"
		t += "Aperte OK: na janela do Android escolha STRIKE KIDS e marque SEMPRE\n" + \
			"(ou: HOME no controle remoto > STRIKE KIDS > SEMPRE).\n"
		if nome != "":
			t += "Abriu a página do \"%s\"? Aperte LIMPAR PADRÕES (Abrir por padrão),\n" % nome + \
				"volte e aperte HOME > STRIKE KIDS > SEMPRE.\n"
		if _inicio_passo == "":
			t += "\nEsta TV não abriu nenhuma escolha: faça pelo PC, com o adb (veja o LEIA-ME).\n"
		t += "\nCONFIGURAÇÃO sai"
	_teste_rotulo.text = t


## Calibração: com a pista vazia, o nível de cada sensor vira o "sem bola".
func _mostrar_calibracao() -> void:
	var t := "CALIBRAR SENSORES\n\n"
	if not ArduinoBridge.completo():
		Compat.tamanho_rotulo(_teste_rotulo, int(30 * u))
		t += "SEM O ARDUINO\n%s\n\n%s\n\nCONFIGURAÇÃO ou START sai" % [ArduinoBridge.status, _relatorio_arduino()]
	elif ArduinoBridge.calibracao.begins_with("CAL:OK:"):
		var niveis: String = ArduinoBridge.calibracao.substr(7)
		t += "PRONTO! Sem bola cada sensor fica em:\n"
		for i in Compat.imin(5, niveis.length()):
			t += "S%d: %s\n" % [i + 1, "ALTO (aciona em baixo)" if niveis[i] == "H" else "BAIXO (aciona em alto)"]
		t += "\nRole a bola no TESTE DOS SENSORES para conferir.\nCONFIGURAÇÃO ou START sai"
	else:
		t += "Calibrando... deixe a pista VAZIA\n(nenhuma bola na frente dos sensores)"
	_teste_rotulo.text = t


## Teste da câmera: a imagem ao vivo (Z / B giram).
func _camera_ao_vivo() -> void:
	var imagem: Texture = Fotos.ao_vivo()
	# Godot 3: o filtro linear (imagem esticada sem serrilhado) é uma
	# marca da textura, não do TextureRect
	if imagem != null:
		imagem.flags = imagem.flags | Texture.FLAG_FILTER
	_camera_tela.texture = imagem
	_camera_tela.visible = true
	Compat.tamanho_rotulo(_teste_rotulo, int(54 * u))
	_teste_rotulo.rect_position.y = 40 * u
	_teste_rotulo.rect_size.y = Tela.tamanho().y * 0.25
	_teste_rotulo.text = "TESTE DA CÂMERA\n%s\nZ / B giram a imagem · START sai" % Fotos.nome_camera


## Teste da câmera sem imagem: o que o Android enxerga e o que o jogo tentou.
func _camera_relatorio(aviso: String) -> void:
	_camera_tela.visible = false
	var linhas: PoolStringArray = Fotos.relatorio().split("\n")
	var rel := PoolStringArray(Compat.fatia(linhas, 0, 18)).join("\n")
	Compat.tamanho_rotulo(_teste_rotulo, int(30 * u))
	_teste_rotulo.rect_position.y = 30 * u
	_teste_rotulo.rect_size.y = Tela.tamanho().y - 60 * u
	_teste_rotulo.text = "TESTE DA CÂMERA%s\n\nCâmera: %s\n\n%s\n\nSTART ou CONFIGURAÇÃO para sair" % [aviso, Fotos.texto_status(), rel]


func _process(delta: float) -> void:
	if not _camera:
		return
	_camera_t += delta
	if _camera_t < 1.0:
		return
	_camera_t = 0.0
	if Fotos.tem_imagem():
		if not _camera_tela.visible:
			_camera_ao_vivo()
	elif Time.get_ticks_msec() - _camera_ms > 6000 and Fotos.pronta():
		# 6 s ligada e nenhuma imagem: mostra o porquê (atualiza a cada 1 s)
		_camera_relatorio(" - SEM IMAGEM AINDA")


func _mostrar_teste(ultimo: String) -> void:
	var nomes := ["S1 ESQUERDA (Z)", "S2 MEIO-ESQ. (X)", "S3 CENTRO (C)", "S4 MEIO-DIR. (V)", "S5 DIREITA (B)"]
	var ao_vivo: String = ArduinoBridge.sensores
	var txt := "TESTE DOS SENSORES\nrole a bola (ou passe a mão) em cada um\n\n"
	for i in 5:
		var agora := ""
		if ao_vivo.length() == 5:
			agora = "   • BOLA" if ao_vivo[i] == "1" else "   – livre"
		txt += "%s%s:  %d%s\n" % ["» " if ["Z", "X", "C", "V", "B"][i] == ultimo else "", nomes[i], _teste_contagem[i], agora]
	if ArduinoBridge.completo():
		txt += "\nArduino conectado: • aparece enquanto a bola tapa o sensor."
	else:
		txt += "\nSem o Arduino (contando os botões da placa).\n%s" % ArduinoBridge.status
	txt += "\nSTART ou CONFIGURAÇÃO para sair"
	_teste_rotulo.text = txt
	if ultimo != "":
		Sons.tocar("selecao")
