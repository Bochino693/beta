extends Node

## ROTEIRO DE TESTE AUTOMÁTICO (só no PC, não vai no APK).
## godot3 --path . -- --roteiro=<pasta_das_fotos> [--jogadas=C,X,Z...] [--jogadores=1|2]
## Joga sozinho: atração -> START -> escolha -> jogadas -> fim, tirando fotos.
## (Godot 3: toda espera daqui SEMPRE espera ao menos um quadro, para o
## `yield(..., "completed")` de quem chama funcionar.)

var pasta := "user://roteiro"
var jogadas := ["C", "X", "V", "C", "Z", "C", "B", "C", "C", "X", "C", "C"]
var jogadores := 1
var principal: Node
var n_foto := 0
var poucas := false
var _rodadas_antes = null
var terminou := false


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	for a in OS.get_cmdline_args():
		if a.begins_with("--roteiro="):
			pasta = a.substr(10)
		elif a.begins_with("--jogadas="):
			jogadas = Array(a.substr(10).split(","))
		elif a == "--poucas":
			poucas = true
		elif a.begins_with("--jogadores="):
			jogadores = int(a.substr(12))
		elif a.begins_with("--rodadas="):
			_rodadas_antes = Ajustes.valor("jogo", "rodadas")
			Ajustes.definir("jogo", "rodadas", int(a.substr(10)))
		elif a.begins_with("--resultados="):
			var f: Array = Jogada.forcar()
			f.clear()
			for x in a.substr(13).split(","):
				f.append(int(x))
	Directory.new().make_dir_recursive(pasta)
	principal = get_parent()
	_rodar()


func _estado() -> String:
	return principal.E.keys()[principal.estado]


func foto(nome: String) -> void:
	if poucas and not nome.begins_with("desempate") and not (nome in ["atracao", "escolha_robo", "pronto_0", "rolando_1", "pinos_1", "resultado_1", "reacao_1",
			"maquina_1", "maquina_b_1", "maquina_c_1", "depois_1", "fim", "fim_2", "fim_desempate", "fim_recorde", "foto_sorria", "foto_contagem", "foto_pronta", "pronto_1"]):
		yield(get_tree(), "idle_frame")
		return
	yield(VisualServer, "frame_post_draw")
	var img := get_viewport().get_texture().get_data()
	img.flip_y()
	n_foto += 1
	img.save_png("%s/%02d_%s.png" % [pasta, n_foto, nome])
	var niveis := ""
	for b in principal.personagens:
		var p = principal.personagens[b]
		if p.visible and p.has_method("nivel"):
			niveis += "  %s=%s(%.2f)" % [b, p.nivel(), p.tamanho_na_tela()]
	print("FOTO ", nome, "  estado=", _estado(), "  desenhos=", Performance.get_monitor(Performance.RENDER_DRAW_CALLS_IN_FRAME),
		"  vertices=", Performance.get_monitor(Performance.RENDER_VERTICES_IN_FRAME), niveis)


## Espera `seg` segundos de verdade (a câmera lenta e a velocidade do jogo
## não contam).
func esperar(seg: float) -> void:
	var t := 0.0
	while true:
		yield(get_tree(), "idle_frame")
		t += get_process_delta_time() / max(Engine.time_scale, 0.01)
		if t >= seg:
			return


func esperar_estado(nome: String, limite := 30.0) -> bool:
	var t := 0.0
	yield(get_tree(), "idle_frame")
	while _estado() != nome:
		yield(get_tree(), "idle_frame")
		t += get_process_delta_time() / max(Engine.time_scale, 0.01)
		if t > limite:
			print("TEMPO ESGOTADO esperando ", nome, " (está em ", _estado(), ")")
			return false
	return true


func esperar_sair_de(nome: String, limite := 10.0) -> void:
	var t := 0.0
	yield(get_tree(), "idle_frame")
	while _estado() == nome and t < limite:
		yield(get_tree(), "idle_frame")
		t += get_process_delta_time() / max(Engine.time_scale, 0.01)


func esperar_pronto_ou_fim(limite := 60.0) -> bool:
	var t := 0.0
	yield(get_tree(), "idle_frame")
	while not (_estado() in ["PRONTO", "FIM"]):
		yield(get_tree(), "idle_frame")
		t += get_process_delta_time() / max(Engine.time_scale, 0.01)
		if t > limite:
			print("TEMPO ESGOTADO esperando PRONTO (está em ", _estado(), ")")
			return false
	return true


## A jogada liberada (a câmera assentou e o ROLE A BOLA! apareceu)?
func esperar_liberada(limite := 6.0) -> bool:
	var t := 0.0
	yield(get_tree(), "idle_frame")
	while not principal._liberada:
		yield(get_tree(), "idle_frame")
		t += get_process_delta_time() / max(Engine.time_scale, 0.01)
		if t > limite or _estado() != "PRONTO":
			return false
	return true


func apertar(acao: String) -> void:
	var teclas := {"input_start": KEY_1, "input_z": KEY_A, "input_x": KEY_S, "input_c": KEY_D, "input_v": KEY_F, "input_b": KEY_G, "input_credit": KEY_5}
	var k := InputEventKey.new()
	k.scancode = teclas.get(acao, KEY_1)
	k.physical_scancode = k.scancode
	k.pressed = true
	Input.parse_input_event(k)
	yield(esperar(0.1), "completed")
	var k2: InputEventKey = k.duplicate()
	k2.pressed = false
	Input.parse_input_event(k2)


## DESEMPATE: fotos do aviso de empate, da troca para a pista que faltava
## e da faixa da rodada extra (e as fases sorteadas da partida).
func _vigiar_desempate() -> void:
	while not terminou:
		yield(get_tree(), "idle_frame")
		if principal.placar.desempate:
			break
	if terminou:
		return
	print("DESEMPATE: fases ", principal._temas_partida, "  cenário agora ", principal.mundo.tema,
		"  pontos %d x %d" % [principal.placar.total(0), principal.placar.total(1)])
	for par in [[0.7, "desempate_empate"], [1.0, "desempate_duelo"], [0.9, "desempate_extra"],
			[1.0, "desempate_extra_b"], [2.0, "desempate_pista"], [1.5, "desempate_faixa"]]:
		yield(esperar(par[0]), "completed")
		yield(foto(par[1]), "completed")
	print("DESEMPATE: cenário da rodada extra ", principal.mundo.tema, "  rodada ", principal.placar.rodada_atual + 1,
		" de ", principal.placar.rodadas)


## --empatar: depois da última bola das rodadas normais, iguala os pontos
## da Mia aos do Bob (a física nem sempre repete o resultado pedido) — para
## testar o desempate com qualquer número de rodadas.
func _forcar_empate() -> void:
	while not terminou:
		yield(get_tree(), "idle_frame")
		var pl = principal.placar
		if pl.desempate or pl.jogadores.size() < 2 or pl.jogadores[1]["rodadas"].size() < pl.rodadas:
			continue
		var r: int = pl.rodadas - 1
		var bolas: Array = pl.jogadores[1]["rodadas"][r]
		var soma := 0
		for b in bolas:
			soma += int(b)
		if pl.rodada_atual == r and pl.jogador_atual == 1 and (soma >= 10 or bolas.size() >= pl.tentativas) \
				and int(pl.jogadores[1]["pontos"]) != int(pl.jogadores[0]["pontos"]):
			print("EMPATE FORÇADO: Mia %d -> %d" % [pl.jogadores[1]["pontos"], pl.jogadores[0]["pontos"]])
			pl.jogadores[1]["pontos"] = pl.jogadores[0]["pontos"]
			principal.hud.atualizar_placar(pl)


func _rodar() -> void:
	# (anota os sons tocados: no fim, quantos de ambiente de cada fase)
	Sons.registrar = true
	_vigiar_desempate()
	if OS.get_cmdline_args().has("--empatar"):
		_forcar_empate()
	yield(esperar(1.4), "completed")
	yield(foto("abertura"), "completed")
	yield(esperar_estado("ATRACAO"), "completed")
	yield(esperar(1.5), "completed")
	yield(foto("atracao"), "completed")
	yield(esperar(1.0), "completed")
	yield(apertar("input_start"), "completed")
	yield(esperar(0.6), "completed")
	yield(foto("quantos_jogadores"), "completed")
	if jogadores == 2:
		yield(apertar("input_start"), "completed")
	else:
		yield(esperar_estado("PERSONAGEM"), "completed")
		yield(esperar(1.6), "completed")
		yield(foto("escolha_robo"), "completed")
		yield(apertar("input_v"), "completed")
		yield(esperar(0.8), "completed")
		yield(foto("escolha_mia"), "completed")
		yield(apertar("input_start"), "completed")
		yield(esperar(0.7), "completed")
		yield(foto("escolhido"), "completed")
	if yield(esperar_estado("FOTO", 6.0), "completed"):
		yield(esperar(1.3), "completed")
		yield(foto("foto_sorria"), "completed")
		yield(esperar(1.5), "completed")
		yield(foto("foto_contagem"), "completed")
		yield(esperar(1.6), "completed")
		yield(foto("foto_pronta"), "completed")
	var i := 0
	while i < jogadas.size():
		if not yield(esperar_pronto_ou_fim(), "completed"):
			continue
		if _estado() == "FIM":
			break
		var z: String = jogadas[i]
		var tecla: String = {"Z": "input_z", "X": "input_x", "C": "input_c", "V": "input_v", "B": "input_b"}[z]
		# TRAVA: apertar ANTES do ROLE A BOLA! não pode valer (nem depois)
		if not principal._liberada:
			yield(apertar(tecla), "completed")
		if not yield(esperar_liberada(), "completed"):
			print("ERRO TRAVA: a jogada não foi liberada (estado ", _estado(), ")")
			continue
		yield(esperar(0.6), "completed")
		if _estado() != "PRONTO" or not principal._liberada:
			print("ERRO TRAVA: jogada de antes do ROLE A BOLA! valeu (estado ", _estado(), ")")
		else:
			print("TRAVA OK %d" % i)
		if i < 3:
			yield(foto("pronto_%d" % i), "completed")
		yield(apertar(tecla), "completed")
		i += 1
		if i <= 3:
			yield(esperar(0.55), "completed")
			yield(foto("arremesso_%d" % i), "completed")
			yield(esperar(0.7), "completed")
			yield(foto("soltou_%d" % i), "completed")
			yield(esperar(0.8), "completed")
			yield(foto("rolando_%d" % i), "completed")
			yield(esperar(0.9), "completed")
			yield(foto("pinos_%d" % i), "completed")
			yield(esperar(1.0), "completed")
			yield(foto("resultado_%d" % i), "completed")
			# rolar de novo com a bola ainda na pista: não vale
			yield(apertar(tecla), "completed")
			# máquina lenta (teste): espera a bola terminar antes do replay
			yield(esperar_sair_de("ROLANDO", 12.0), "completed")
			if yield(esperar_estado("REPLAY", 4.0), "completed"):
				yield(esperar(0.9), "completed")
				yield(foto("replay_a_%d" % i), "completed")
				yield(esperar(1.3), "completed")
				yield(foto("replay_b_%d" % i), "completed")
				yield(esperar(1.6), "completed")
				yield(foto("replay_c_%d" % i), "completed")
				yield(esperar_estado("RESULTADO", 10.0), "completed")
			yield(esperar(1.0), "completed")
			yield(foto("reacao_%d" % i), "completed")
			yield(esperar(1.2), "completed")
			yield(foto("reacao_b_%d" % i), "completed")
			yield(esperar(1.0), "completed")
			yield(foto("maquina_%d" % i), "completed")
			yield(esperar(1.0), "completed")
			yield(foto("maquina_b_%d" % i), "completed")
			yield(esperar(1.0), "completed")
			yield(foto("maquina_c_%d" % i), "completed")
			yield(esperar(1.3), "completed")
			yield(foto("depois_%d" % i), "completed")
	yield(esperar_estado("FIM", 60.0), "completed")
	if principal.placar.desempate:
		yield(esperar(2.9), "completed")
		yield(foto("fim_desempate"), "completed")
		yield(esperar(1.4), "completed")
		yield(foto("fim_recorde"), "completed")
	print("FIM: pontos ", principal.placar.total(0), " x ", (principal.placar.total(1) if principal.placar.jogadores.size() > 1 else -1),
		"  vencedor ", principal.placar.vencedor(), "  desempate ", principal.placar.desempate, "  fases ", principal._temas_partida)
	yield(esperar(3.8), "completed")
	yield(foto("fim"), "completed")
	yield(esperar(2.0), "completed")
	yield(foto("fim_2"), "completed")
	if _rodadas_antes != null:
		Ajustes.definir("jogo", "rodadas", _rodadas_antes)
	var amb := {}
	for r in Sons.registro:
		if str(r[1]).begins_with("amb_"):
			amb[r[1]] = int(amb.get(r[1], 0)) + 1
	print("SONS DE AMBIENTE: ", amb)
	print("ROTEIRO OK")
	terminou = true
	if not OS.get_cmdline_args().has("--sem-sair"):
		get_tree().quit()
