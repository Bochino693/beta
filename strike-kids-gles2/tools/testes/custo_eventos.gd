extends Node
## MEDE O TRANCO DE CADA EVENTO DO ARDUINO (só no PC, não vai no APK).
##   godot3 --path . -- --custo-eventos
## Modo fichas, na espera: FICHA, FICHA, depois a BOLA (começa a partida),
## e na partida as bolas das jogadas. Para cada evento grava o tempo de
## cada quadro do segundo seguinte e escreve o PIOR quadro e quanto o
## evento custou dentro dele (o que o _input/_receber do jogo fez na hora).
## No fim: "CUSTO EVENTOS: pior quadro X ms" e a linha de cada evento.

var principal: Node
var _ultimo_us := 0
var _quadros := []     # [ms do quadro, rótulo]
var _rotulo := ""
var _gravando := false


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	principal = get_parent()
	# o trabalho do processador em cada quadro: do fim do desenho anterior ao
	# começo do próximo desenho (física + scripts + entrada), sem limite de
	# quadros por segundo (a espera do limite não entra na conta)
	VisualServer.connect("frame_post_draw", self, "_depois_do_desenho")
	VisualServer.connect("frame_pre_draw", self, "_antes_do_desenho")
	_rodar()


func _process(_d: float) -> void:
	Engine.target_fps = 0


func _depois_do_desenho() -> void:
	_ultimo_us = OS.get_ticks_usec()


func _antes_do_desenho() -> void:
	if _gravando and _ultimo_us > 0:
		_quadros.append([(OS.get_ticks_usec() - _ultimo_us) / 1000.0, _estado()])


func _estado() -> String:
	return principal.E.keys()[principal.estado]


func esperar(seg: float) -> void:
	var t0 := OS.get_ticks_msec()
	while OS.get_ticks_msec() - t0 < seg * 1000.0:
		yield(get_tree(), "idle_frame")


func _apertar(acao: String) -> float:
	var ev := InputEventAction.new()
	ev.action = acao
	ev.pressed = true
	ev.set_meta("arduino", true)
	var t0 := OS.get_ticks_usec()
	# como o ArduinoBridge faz: o evento entra na fila de entrada do Godot
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	var custo := (OS.get_ticks_usec() - t0) / 1000.0
	var solta := InputEventAction.new()
	solta.action = acao
	solta.pressed = false
	solta.set_meta("arduino", true)
	get_tree().create_timer(0.06, true).connect("timeout", Input, "parse_input_event", [solta])
	return custo


func _medir(rotulo: String, acao: String, seg := 1.2) -> void:
	_quadros.clear()
	_rotulo = rotulo
	_gravando = true
	var custo := _apertar(acao)
	yield(esperar(seg), "completed")
	_gravando = false
	var pior := 0.0
	var soma := 0.0
	for q in _quadros:
		pior = max(pior, q[0])
		soma += q[0]
	var media := soma / max(_quadros.size(), 1)
	if OS.has_environment("CUSTO_QUADROS"):
		var idx := []
		for i in _quadros.size():
			idx.append(i)
		var qs := _quadros
		idx.sort_custom(self, "_maior")
		_ordem = qs
		var linha := ""
		for k in min(4, idx.size()):
			linha += "#%d %.1fms(%s)  " % [idx[k], qs[idx[k]][0], qs[idx[k]][1]]
		print("   piores: ", linha)
	print("EVENTO %-28s no evento %6.2f ms | pior CPU %6.2f ms | media CPU %5.2f ms | estado %s" % [rotulo, custo, pior, media, _estado()])
	_piores.append(pior)


var _piores := []
var _ordem := []


func _maior(a, b) -> bool:
	return _quadros[a][0] > _quadros[b][0]


var _livre_antes := true


func _rodar() -> void:
	_livre_antes = Ajustes.modo_livre()
	Ajustes.definir("jogo", "modo_livre", false)
	Ajustes.zerar_creditos()
	# espera a atração (a demonstração já rodando)
	var t := 0
	while not (_estado() in ["ATRACAO", "DEMO"]) and t < 900:
		yield(get_tree(), "idle_frame")
		t += 1
	yield(esperar(4.0), "completed")
	# o quadro normal, sem evento (referência)
	_quadros.clear()
	_rotulo = "nada"
	_gravando = true
	yield(esperar(1.2), "completed")
	_gravando = false
	var ref := 0.0
	for q in _quadros:
		ref = max(ref, q[0])
	print("EVENTO %-28s pior CPU %6.2f ms" % ["(sem evento, referencia)", ref])
	# as partes da ficha, uma por uma (microssegundos, média de 20)
	var hud = principal.hud
	for nome in ["layout", "modo_espera", "atualizar_atracao", "adicionar_credito", "porta_da_espera", "som"]:
		var t0 := OS.get_ticks_usec()
		for k in 20:
			match nome:
				"layout": hud.layout()
				"modo_espera":
					hud._modo_espera = ""
					hud.modo_espera("pago1" if k % 2 == 0 else "ficha")
				"atualizar_atracao": principal._atualizar_atracao()
				"adicionar_credito": Ajustes.adicionar_credito()
				"porta_da_espera": principal._porta_da_espera()
				"som": Sons.tocar("moeda", 0.65)
		print("PARTE %-20s %7.3f ms" % [nome, (OS.get_ticks_usec() - t0) / 20000.0])
	if OS.has_environment("CUSTO_PARTES2"):
		var pr = principal
		var cand := {
			"estrelas": funcref(self, "_p_estrelas"),
			"flash": funcref(self, "_p_flash"),
			"selecao_on": funcref(self, "_p_sel_on"),
			"selecao_off": funcref(self, "_p_sel_off"),
			"tocar_anim": funcref(self, "_p_anim"),
			"placar_comecar": funcref(self, "_p_placar"),
			"configurar_placar": funcref(self, "_p_conf_placar"),
			"atualizar_placar": funcref(self, "_p_atu_placar"),
			"pedir_roupas": funcref(self, "_p_roupas"),
			"maquina_instantaneo": funcref(self, "_p_maquina"),
			"musica_jogo": funcref(self, "_p_musica"),
			"som_escolha": funcref(self, "_p_som"),
			"hud_etapa": funcref(self, "_p_etapa"),
			"hud_sequencia": funcref(self, "_p_sequencia"),
			"limpar": funcref(self, "_p_limpar"),
			"fotos_preparar": funcref(self, "_p_fotos"),
			"roupa_de_sempre": funcref(self, "_p_roupa_sempre"),
			"sortear_temas": funcref(self, "_p_temas"),
			"atracao_off": funcref(self, "_p_atracao_off"),
			"tela_fim_off": funcref(self, "_p_fim_off"),
			"bola_guardar": funcref(self, "_p_bola"),
			"escolher_personagem": funcref(self, "_p_esc_pers"),
			"vez_nova_rodada": funcref(self, "_p_vez"),
		}
		for nome in cand:
			for vez in 2:
				var t0 := OS.get_ticks_usec()
				cand[nome].call_func()
				print("PARTE2 %-20s vez %d  %7.3f ms" % [nome, vez + 1, (OS.get_ticks_usec() - t0) / 1000.0])
				yield(get_tree(), "idle_frame")
		get_tree().quit()
		return
	Ajustes.zerar_creditos()
	principal._porta_da_espera()
	yield(esperar(1.0), "completed")
	yield(_medir("ficha 1", "input_credit"), "completed")
	yield(_medir("ficha 2", "input_credit"), "completed")
	yield(_medir("bola no meio (comeca)", "input_c", 2.5), "completed")
	# a partida: uma bola por vez quando a pista pede
	for i in 6:
		var espera := 0
		while _estado() != "PRONTO" and espera < 1500:
			yield(get_tree(), "idle_frame")
			espera += 1
		if _estado() != "PRONTO":
			break
		yield(esperar(0.3), "completed")
		yield(_medir("jogada %d" % (i + 1), ["input_x", "input_c", "input_v"][i % 3], 6.0), "completed")
	var pior := 0.0
	for p in _piores:
		pior = max(pior, p)
	print("CUSTO EVENTOS: pior quadro %.2f ms (referencia sem evento %.2f ms)" % [pior, ref])
	Ajustes.definir("jogo", "modo_livre", _livre_antes)
	yield(esperar(0.5), "completed")
	get_tree().quit()


func _p_estrelas() -> void:
	principal.efeitos.estrelas(Vector3(0, 1.2, 2.0), 26)
func _p_flash() -> void:
	principal.hud.flash(Color.white, 0.4)
func _p_sel_on() -> void:
	principal.hud.selecao(true, 0, "teste", principal._pes_na_tela())
func _p_sel_off() -> void:
	principal.hud.selecao(false)
func _p_anim() -> void:
	principal.personagens["bob"].tocar("escolhido", 0.15, true)
func _p_placar() -> void:
	principal.placar.comecar(["bob"], Ajustes.rodadas(), Ajustes.tentativas())
func _p_conf_placar() -> void:
	principal.hud.configurar_placar(["bob"])
func _p_atu_placar() -> void:
	principal.hud.atualizar_placar(principal.placar)
func _p_roupas() -> void:
	principal._pedir_roupas("espaco")
func _p_maquina() -> void:
	principal.maquina.instantaneo()
func _p_musica() -> void:
	Sons.musica("musica_jogo" if Sons._musica_atual != "musica_jogo" else "musica_menu")
func _p_som() -> void:
	Sons.tocar("escolha")
func _p_etapa() -> void:
	principal.hud.etapa(3)
func _p_sequencia() -> void:
	principal.hud.sequencia(0)
func _p_limpar() -> void:
	principal._limpar()
func _p_fotos() -> void:
	Fotos.preparar()
func _p_roupa_sempre() -> void:
	principal._roupa_de_sempre()
func _p_temas() -> void:
	principal._sortear_temas(Ajustes.rodadas() + 1)
func _p_atracao_off() -> void:
	principal.hud.atracao(false)
func _p_fim_off() -> void:
	principal.hud.tela_fim(false)
func _p_bola() -> void:
	principal.bola.guardar()
func _p_esc_pers() -> void:
	principal._escolher_personagem()
func _p_vez() -> void:
	principal.placar.comecar(["bob"], Ajustes.rodadas(), Ajustes.tentativas())
	var t0 := OS.get_ticks_usec()
	principal._vez(true)
	print("   (so o _vez) %.3f ms" % ((OS.get_ticks_usec() - t0) / 1000.0))
