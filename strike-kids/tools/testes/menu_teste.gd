extends Node

## MENU DO OPERADOR SEM TRAVAR: abre e fecha o menu por cima do jogo e mede
## cada quadro (e quanto cada passo levou).
##   godot --path . --resolution 1080x1920 res://tools/testes/menu_teste.tscn -- --janela=1080x1920
## (na resolução da TV Box: é para ela que as letras já vêm desenhadas)
## A máquina de teste não tem placa de vídeo: desenha o 3D por software
## (~1 s por quadro, variando ±100 ms) e isso esconde qualquer tranco. Aqui
## o 3D não é desenhado (o jogo continua rodando por baixo, só a imagem 3D
## fica parada): os quadros ficam rápidos e o EXTRA da troca de tela
## (montar o menu, a tela de espera, os textos) aparece.

var falhas := 0
var _ult := 0
var _quadros: Array = []
var _medindo := false
var _jogo: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().process_frame.connect(_quadro)
	RenderingServer.frame_pre_draw.connect(_sem_3d)
	_rodar.call_deferred()


## Logo antes de desenhar cada quadro: a imagem 3D não é desenhada (fechar o
## menu a liga de novo no meio do quadro; aqui ela é desligada antes).
func _sem_3d() -> void:
	if _jogo != null and _jogo.vp.render_target_update_mode != SubViewport.UPDATE_DISABLED:
		_jogo.vp.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _quadro() -> void:
	var agora := Time.get_ticks_usec()
	if _medindo:
		_quadros.append(float(agora - _ult) / 1000.0)
	_ult = agora


func _mediana(v: Array) -> float:
	if v.is_empty():
		return 0.0
	var c := v.duplicate()
	c.sort()
	return c[c.size() / 2]


func checar(ok: bool, texto: String) -> void:
	print(("OK    " if ok else "FALHA ") + texto)
	if not ok:
		falhas += 1


func esperar(seg: float) -> void:
	await get_tree().create_timer(seg, true, false, true).timeout


func _medir(nome: String, f: Callable) -> void:
	var t0 := Time.get_ticks_usec()
	f.call()
	print("  %s: %.1f ms" % [nome, float(Time.get_ticks_usec() - t0) / 1000.0])


func _rodar() -> void:
	reparent(get_tree().root)
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://cenas/principal.tscn")
	await esperar(0.5)
	var p := get_tree().current_scene
	while p.E.keys()[p.estado] != "ATRACAO":
		await get_tree().process_frame
	await esperar(2.0)
	_jogo = p
	await esperar(1.5)
	for vez in 3:
		print("== vez %d" % (vez + 1))
		# quadros normais do jogo (a máquina de teste não tem placa de vídeo:
		# o 3D já é lento aqui; o que conta é o EXTRA da troca de tela)
		_quadros.clear()
		_medindo = true
		await esperar(1.0)
		var normal := _mediana(_quadros)
		_quadros.clear()
		_medir("abrir_menu", func(): p.abrir_menu(p.CENA_OPERADOR))
		await esperar(1.0)
		var menu := _mediana(_quadros)
		var extra_abrir: float = _quadros.slice(0, 3).max() - maxf(menu, normal)
		print("  quadros: jogo %.1f ms, menu %.1f ms; ao abrir %s" % [normal, menu, str(_quadros.slice(0, 4))])
		_quadros.clear()
		_medir("fechar_menu", func(): p.fechar_menu())
		await esperar(1.5)
		var extra_fechar: float = _quadros.slice(0, 3).max() - normal
		print("  ao fechar %s" % str(_quadros.slice(0, 4)))
		_medindo = false
		checar(extra_abrir < 25.0 and extra_fechar < 25.0, "vez %d: abre e fecha sem travar (extra %.0f / %.0f ms)" % [vez + 1, extra_abrir, extra_fechar])
		await esperar(2.0)
	print("MENU_TESTE %s" % ("OK" if falhas == 0 else "FALHOU"))
	get_tree().quit(0 if falhas == 0 else 1)
