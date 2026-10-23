extends Node

## A TELA DO JOGO — RESPONSIVA.
##
## O jogo se adapta a qualquer tela, em pé ou deitada, sem esticar:
##   * monitor em pé ligado no HDMI deitado (a máquina de boliche): a imagem
##     inteira é girada 90° (giro 1 ou -1);
##   * TV deitada, PC, celular: sem giro (giro 0), o layout se reorganiza.
##
## O lado menor da tela vale sempre 1080 unidades. Em pé, 1080 x (1920 ou
## o que a proporção der); deitada, (1920...) x 1080.
##
## Sentido do giro (Ajustes do operador ou `strike/tela/giro` no
## project.godot; variável de ambiente STRIKE_GIRO no PC):
##   1  = topo do jogo na ESQUERDA do HDMI
##  -1  = topo do jogo na DIREITA do HDMI
##   0  = sem giro
##
## Os scripts sempre usam `Tela.tamanho()` (o tamanho lógico, já em pé se
## girado) e `Tela.cobrir(no)`, nunca o tamanho da janela.

signal mudou(tamanho)

const LADO_MENOR := 1080.0

var giro := 0
var _tamanho := Vector2(1080, 1920)
var _fisico := Vector2(1080, 1920)


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	# INTERPOLAÇÃO DA FÍSICA: a física anda 60 passos por segundo; a tela,
	# 60, 75, 144... Só o que é movido PELA FÍSICA (bola, pinos, máquina de
	# pinos) liga a interpolação e aparece sempre no lugar certo do instante
	# do quadro — liso em qualquer monitor. Todo o resto (câmera, bichinhos,
	# telas), que anda a cada quadro, fica desligado.
	# (Godot 3: `get_tree().root.x = ...` tentaria regravar o root — por variável)
	var raiz := get_tree().root
	raiz.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_janela_de_teste()
	giro = _giro_configurado()
	get_tree().root.connect("size_changed", self, "_aplicar")
	_aplicar()


## O jogo abre em TELA CHEIA (project.godot). Para testar no PC numa
## janela: godot --path . -- --janela=540x960
func _janela_de_teste() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("--janela="):
			var p = a.substr(9).split("x")
			OS.window_fullscreen = false
			if p.size() == 2:
				OS.window_size = Vector2(int(p[0]), int(p[1]))
				OS.center_window()
			return


func _giro_configurado() -> int:
	if OS.has_environment("STRIKE_GIRO"):
		return Compat.iclamp(int(OS.get_environment("STRIKE_GIRO")), -1, 1)
	var ajuste := _ler_ajuste_giro()
	if ajuste != 99:
		return ajuste
	if OS.get_name() != "Android":
		return 0
	return int(Compat.config("strike/tela/giro", 1))


## O operador pode trocar o giro na tela de ajustes (sem gerar outro APK).
func _ler_ajuste_giro() -> int:
	var cfg := ConfigFile.new()
	if cfg.load("user://ajustes.cfg") != OK:
		return 99
	return int(cfg.get_value("tela", "giro", 99))


func definir_giro(novo: int) -> void:
	giro = Compat.iclamp(novo, -1, 1)
	_aplicar()


func tamanho() -> Vector2:
	return _tamanho


func em_pe() -> bool:
	return _tamanho.y >= _tamanho.x


## Tamanho em pixels reais da imagem do jogo (já em pé, se girada).
func tamanho_fisico() -> Vector2:
	return _fisico


func retangulo() -> Rect2:
	return Rect2(Vector2.ZERO, _tamanho)


## Faz um Control cobrir a tela do jogo inteira.
func cobrir(no: Control) -> void:
	no.set_anchors_preset(Control.PRESET_TOP_LEFT)
	no.rect_position = Vector2.ZERO
	no.rect_size = _tamanho


## Converte um ponto da janela (ex.: toque do mouse) para coordenadas do jogo.
func janela_para_jogo(p: Vector2) -> Vector2:
	return get_tree().root.global_canvas_transform.affine_inverse() * p


var _aplicando := false


func _aplicar() -> void:
	if _aplicando:
		return
	var janela := get_tree().root
	# Godot 3: o tamanho de verdade da janela (o do Viewport raiz já vem
	# esticado pelo set_screen_stretch)
	var real := OS.window_size
	if real.x <= 0 or real.y <= 0:
		return
	_aplicando = true
	var w := real.x
	var h := real.y
	if giro != 0:
		var t := w
		w = h
		h = t
	_fisico = Vector2(int(w), int(h))
	if w <= h:
		_tamanho = Vector2(LADO_MENOR, round(LADO_MENOR * h / w))
	else:
		_tamanho = Vector2(round(LADO_MENOR * w / h), LADO_MENOR)
	# Godot 3: esticar as telas 2D = set_screen_stretch (modo 2D, sem manter
	# proporção: o tamanho lógico já tem a proporção da tela)
	if giro == 0:
		get_tree().set_screen_stretch(SceneTree.STRETCH_MODE_2D, SceneTree.STRETCH_ASPECT_IGNORE, _tamanho)
		janela.global_canvas_transform = Transform2D.IDENTITY
	else:
		get_tree().set_screen_stretch(SceneTree.STRETCH_MODE_2D, SceneTree.STRETCH_ASPECT_IGNORE, Vector2(_tamanho.y, _tamanho.x))
		if giro > 0:
			# (x, y) do jogo -> (y, largura_jogo - x) na tela
			janela.global_canvas_transform = Transform2D(Vector2(0, -1), Vector2(1, 0), Vector2(0, _tamanho.x))
		else:
			# (x, y) do jogo -> (altura_jogo - y, x) na tela
			janela.global_canvas_transform = Transform2D(Vector2(0, 1), Vector2(-1, 0), Vector2(_tamanho.y, 0))
	_aplicando = false
	emit_signal("mudou", _tamanho)


## Ao fechar o jogo: as tarefas em segundo plano terminam e o que ficou
## guardado nos estados estáticos (Compat.estado: texturas, shaders...) sai
## ANTES de a placa de vídeo ser desligada (senão o Godot 3 fecha com erro).
func _exit_tree() -> void:
	Tarefas.esperar_todas()
	if Engine.has_meta("compat_estados"):
		Engine.remove_meta("compat_estados")
