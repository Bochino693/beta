extends Node
## FOTOS DA TELA NO MODO FICHAS SEM CRÉDITO (só no PC, não vai no APK).
##   godot3 --path . -- --tela-fichas=<pasta>
## Tira: a espera parada, a bola rolada sem crédito e a ficha entrando - para
## conferir os textos (nada repetido na tela).
var principal: Node
var pasta := "user://tela_fichas"
var n := 0
var _livre_antes := true


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	for a in OS.get_cmdline_args():
		if a.begins_with("--tela-fichas="):
			pasta = a.substr(14)
	principal = get_parent()
	_rodar()


func _estado() -> String:
	return principal.E.keys()[principal.estado]


func esperar(seg: float) -> void:
	var t0 := OS.get_ticks_msec()
	while OS.get_ticks_msec() - t0 < seg * 1000.0:
		yield(get_tree(), "idle_frame")


func foto(nome: String) -> void:
	yield(VisualServer, "frame_post_draw")
	var img := get_viewport().get_texture().get_data()
	img.flip_y()
	n += 1
	img.save_png("%s/%02d_%s.png" % [pasta, n, nome])
	print("FOTO ", nome, " (", _estado(), ")")


func apertar(acao: String) -> void:
	var ev := InputEventAction.new()
	ev.action = acao
	ev.pressed = true
	ev.set_meta("arduino", true)
	Input.parse_input_event(ev)
	yield(get_tree().create_timer(0.06, true), "timeout")
	var s := InputEventAction.new()
	s.action = acao
	s.pressed = false
	s.set_meta("arduino", true)
	Input.parse_input_event(s)


func _rodar() -> void:
	_livre_antes = Ajustes.modo_livre()
	Ajustes.definir("jogo", "modo_livre", false)
	Ajustes.zerar_creditos()
	var t := 0
	while not (_estado() in ["ATRACAO", "DEMO"]) and t < 1200:
		yield(get_tree(), "idle_frame")
		t += 1
	yield(esperar(3.0), "completed")
	yield(foto("espera_sem_credito"), "completed")
	yield(apertar("input_c"), "completed")
	yield(esperar(0.35), "completed")
	yield(foto("bola_sem_credito"), "completed")
	yield(esperar(2.5), "completed")
	yield(apertar("input_credit"), "completed")
	yield(esperar(0.6), "completed")
	yield(foto("com_1_credito"), "completed")
	# os cartões de quantos jogam (modo livre: 1 BOLA / 2 BOLAS)
	Ajustes.definir("jogo", "modo_livre", true)
	principal._porta_da_espera()
	yield(esperar(1.0), "completed")
	yield(foto("espera_livre"), "completed")
	yield(apertar("input_c"), "completed")
	yield(esperar(1.2), "completed")
	yield(foto("cartoes_livre"), "completed")
	Ajustes.definir("jogo", "modo_livre", _livre_antes)
	yield(esperar(0.3), "completed")
	get_tree().quit()
