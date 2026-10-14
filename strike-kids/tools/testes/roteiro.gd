extends Node

## ROTEIRO DE TESTE AUTOMÁTICO (só no PC, não vai no APK).
## godot --path . -- --roteiro=<pasta_das_fotos> [--jogadas=C,X,Z...] [--jogadores=1|2]
## Joga sozinho: atração -> START -> escolha -> jogadas -> fim, tirando fotos.

var pasta := "user://roteiro"
var jogadas := ["C", "X", "V", "C", "Z", "C", "B", "C", "C", "X", "C", "C"]
var jogadores := 1
var principal: Node
var n_foto := 0
var poucas := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--roteiro="):
			pasta = a.substr(10)
		elif a.begins_with("--jogadas="):
			jogadas = Array(a.substr(10).split(","))
		elif a == "--poucas":
			poucas = true
		elif a.begins_with("--jogadores="):
			jogadores = int(a.substr(12))
		elif a.begins_with("--resultados="):
			Jogada.forcar = Array(a.substr(13).split(",")).map(func(x): return int(x))
	DirAccess.make_dir_recursive_absolute(pasta)
	principal = get_parent()
	_rodar()


func foto(nome: String) -> void:
	if poucas and not (nome in ["atracao", "escolha_robo", "pronto_0", "rolando_1", "pinos_1", "resultado_1", "reacao_1",
			"maquina_1", "maquina_b_1", "maquina_c_1", "depois_1", "fim"]):
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	n_foto += 1
	img.save_png("%s/%02d_%s.png" % [pasta, n_foto, nome])
	print("FOTO ", nome, "  estado=", principal.E.keys()[principal.estado])


func esperar(seg: float) -> void:
	await get_tree().create_timer(seg, true, false, true).timeout


func esperar_estado(nome: String, limite := 30.0) -> bool:
	var t := 0.0
	while principal.E.keys()[principal.estado] != nome:
		await get_tree().process_frame
		t += get_process_delta_time()
		if t > limite:
			print("TEMPO ESGOTADO esperando ", nome, " (está em ", principal.E.keys()[principal.estado], ")")
			return false
	return true


func apertar(acao: String) -> void:
	var ev := InputEventAction.new()
	ev.action = acao
	ev.pressed = true
	var k := InputEventKey.new()
	var teclas := {"input_start": KEY_1, "input_z": KEY_A, "input_x": KEY_S, "input_c": KEY_D, "input_v": KEY_F, "input_b": KEY_G, "input_credit": KEY_5}
	k.physical_keycode = teclas.get(acao, KEY_1)
	k.keycode = k.physical_keycode
	k.pressed = true
	Input.parse_input_event(k)
	await get_tree().create_timer(0.1).timeout
	var k2 := k.duplicate()
	k2.pressed = false
	Input.parse_input_event(k2)


func _rodar() -> void:
	await esperar(1.4)
	await foto("abertura")
	await esperar_estado("ATRACAO")
	await esperar(1.5)
	await foto("atracao")
	await esperar(1.0)
	await apertar("input_start")
	await esperar(0.6)
	await foto("quantos_jogadores")
	if jogadores == 2:
		await apertar("input_start")
	else:
		await esperar_estado("PERSONAGEM")
		await esperar(1.6)
		await foto("escolha_robo")
		await apertar("input_v")
		await esperar(0.8)
		await foto("escolha_mia")
		await apertar("input_start")
		await esperar(0.7)
		await foto("escolhido")
	var i := 0
	while i < jogadas.size():
		if not await esperar_estado("PRONTO", 40.0):
			if principal.E.keys()[principal.estado] == "FIM":
				break
			continue
		await esperar(0.5)
		if i < 3:
			await foto("pronto_%d" % i)
		var z: String = jogadas[i]
		await apertar({"Z": "input_z", "X": "input_x", "C": "input_c", "V": "input_v", "B": "input_b"}[z])
		i += 1
		if i <= 3:
			await esperar(0.55)
			await foto("arremesso_%d" % i)
			await esperar(0.7)
			await foto("soltou_%d" % i)
			await esperar(0.8)
			await foto("rolando_%d" % i)
			await esperar(0.9)
			await foto("pinos_%d" % i)
			await esperar(1.0)
			await foto("resultado_%d" % i)
			if await esperar_estado("REPLAY", 2.5):
				await esperar(0.9)
				await foto("replay_a_%d" % i)
				await esperar(1.3)
				await foto("replay_b_%d" % i)
				await esperar(1.6)
				await foto("replay_c_%d" % i)
				await esperar_estado("RESULTADO", 10.0)
			await esperar(1.0)
			await foto("reacao_%d" % i)
			await esperar(1.2)
			await foto("reacao_b_%d" % i)
			await esperar(1.0)
			await foto("maquina_%d" % i)
			await esperar(1.0)
			await foto("maquina_b_%d" % i)
			await esperar(1.0)
			await foto("maquina_c_%d" % i)
			await esperar(1.3)
			await foto("depois_%d" % i)
	await esperar_estado("FIM", 60.0)
	await esperar(3.8)
	await foto("fim")
	await esperar(2.0)
	await foto("fim_2")
	print("ROTEIRO OK")
	get_tree().quit()
