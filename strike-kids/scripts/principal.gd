extends Node

## STRIKE KIDS — CONTROLE DO JOGO
##
## Estados: ABERTURA -> ATRACAO (demo) -> JOGADORES (1 ou 2) -> PERSONAGEM
## (1 jogador escolhe Bob ou Mia) -> FOTO (câmera da máquina, se tiver) ->
## a partida (PRONTO -> ARREMESSO -> ROLANDO -> RESULTADO, com REPLAY no
## strike) -> FIM -> ATRACAO.
##
## As 5 jogadas vêm dos sensores (placa Zero Delay: input_z .. input_b).
## Teclado no PC: A S D F G = sensores, 1/Espaço = START, 5 = crédito,
## 9 = configuração. Também dá para clicar/tocar nas 5 luzes da tela.

enum E { ABERTURA, ATRACAO, JOGADORES, PERSONAGEM, PRONTO, ARREMESSO, ROLANDO, RESULTADO, REPLAY, FIM, DEMO, FOTO, TESTE }

const Z_INICIO := 3.15
const X_MAO := 0.28            # a mão direita fica 0,28 m à direita do corpo
const MESMA_BOLA_MS := 1200
const VALIDADE_PENDENTE_MS := 10000
const CENA_OPERADOR := "res://cenas/operador.tscn"
## tempo da tela "QUANTOS VÃO JOGAR?" (START de novo dentro dele = 2 jogadores)
const TEMPO_JOGADORES := 4.0
## pódios da escolha do personagem e da foto (Bob à esquerda, Mia à direita)
const PODIOS := [Vector3(-0.62, 0, 2.5), Vector3(0.62, 0, 2.5)]
## a vista da espera: a pista de frente, como a criança vê da máquina
const POS_PISTA := Vector3(0.0, 1.05, 2.2)
const ALVO_PISTA := Vector3(0.0, 0.18, Mundo.Z_PINO1 + 0.6)

var estado := E.ABERTURA
var vp: SubViewport
var cam: CameraCine
var mundo: Mundo
var pinos: Pinos
var maquina: Maquina
var bola: Bola
var efeitos: Efeitos
var hud: Hud
var medidor: Medidor
var _resultado_teste: Label
var personagens := {}
var placar := Placar.new()
var jogada: Jogada
var demo := false
var _seq := 0
var _pular := false
var _pendente := ""
var _pendente_ms := 0
var _ultima_jogada_ms := -100000
var _inativo := 0.0
var _modal_inativo := 0.0
var _ativo := "bob"
var _plateia := "mia"
var _em_pe_antes: Array[int] = []
var _t_jogada := 0.0
var _t_impacto := -1.0
var _deck_cam := false
var _cam_baixa := false
var _gravando := false
var _gravacao := []
var _replay_t := 0.0
var _replay_ativo := false
var _replay_inicio := 0.0
var _replay_fim := 0.0
var _replay_alvo: Node3D
var _replay_rastro := 0.0
var _lenta: Tween
## passos da física por segundo (o do project.godot, lido ao abrir); a câmera
## lenta só diminui quantos passos acontecem por segundo, nunca o tamanho
var _passos_fisica := 120
var _escolha_n := 1
var _escolha_t := 0.0
var _destaque := 0
var _fim_t := 0.0
var _demo_t := 0.0
var _demo_vez := 0
var _ultimo_som_pino := 0
var _tema_base := -1          # cada partida começa num cenário diferente
var _qualidade := "media"
## resolução da imagem 3D: fator automático (0,6 a 1) sobre o LADO_3D
var _fator := 1.0
var _adaptar := true
var _fps_t0 := 0
var _fps_q := 0
var _fps_ruins := 0
var _mouse_parado := 0.0

## Lado menor da IMAGEM 3D, em pixels, em cada qualidade. O 3D é desenhado
## nesse tamanho fixo e ESTICADO SOZINHO até a tela inteira (TV Box 4K ou
## 1080p, PC, monitor em pé) — a interface continua nítida por cima.
## Se a placa de vídeo não segurar 60 quadros, o fator abaixa sozinho.
const LADO_3D := {"alta": 1440, "media": 640, "baixa": 540}


func _ready() -> void:
	randomize()
	_passos_fisica = int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 120))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_qualidade = str(Ajustes.valor("video", "qualidade"))
	if OS.has_environment("STRIKE_QUALIDADE"):
		_qualidade = OS.get_environment("STRIKE_QUALIDADE")
	if _qualidade == "auto":
		# o TESTE DE DESEMPENHO do menu do operador já mediu esta máquina?
		var medida := str(Ajustes.valor("video", "qualidade_auto"))
		if medida in ["alta", "media", "baixa"]:
			_qualidade = medida
		else:
			_qualidade = "alta" if OS.get_name() != "Android" else "media"
	Materiais.contornos_ligados = _qualidade != "baixa"
	for a in OS.get_cmdline_user_args():
		# testes e vídeos: resolução fixa (a máquina de teste é lenta)
		if a.begins_with("--roteiro") or a.begins_with("--video") or a.begins_with("--instantes") or a.begins_with("--replay-teste"):
			_adaptar = false
	_montar_3d()
	hud = Hud.new()
	add_child(hud)
	hud.montar(vp.get_texture())
	medidor = Medidor.new(self)
	hud.add_child(medidor)
	if OS.get_cmdline_user_args().has("--medidor"):
		medidor.mostrar(true)
	# (testes) roda o TESTE DE DESEMPENHO do menu do operador logo depois da abertura
	if OS.get_cmdline_user_args().has("--teste-desempenho"):
		Ajustes.definir("video", "testar", true)
	# prepara os shaders de tudo enquanto a marca cobre a tela
	var aq := Aquecer.new()
	add_child(aq)
	aq.preparar(vp, hud)
	hud.toque_sensor.connect(_jogada_recebida)
	Tela.mudou.connect(_tela_mudou)
	_tela_mudou(Tela.tamanho())
	ArduinoBridge.send_led("MENU")
	_ligar_roteiro_de_teste()
	_abertura()


## Teste automático (PC): godot --path . -- --roteiro=pasta
func _ligar_roteiro_de_teste() -> void:
	if OS.get_cmdline_user_args().has("--desempenho") and ResourceLoader.exists("res://tools/testes/desempenho.gd"):
		add_child(load("res://tools/testes/desempenho.gd").new())
	if OS.get_cmdline_user_args().has("--benchmark") and ResourceLoader.exists("res://tools/testes/benchmark.gd"):
		add_child(load("res://tools/testes/benchmark.gd").new())
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--replay-teste") and ResourceLoader.exists("res://tools/testes/replay_teste.gd"):
			add_child(load("res://tools/testes/replay_teste.gd").new())
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--roteiro") and ResourceLoader.exists("res://tools/testes/roteiro.gd"):
			add_child(load("res://tools/testes/roteiro.gd").new())
			return
		if a.begins_with("--video") and ResourceLoader.exists("res://tools/testes/video.gd"):
			add_child(load("res://tools/testes/video.gd").new())
			return
		if a.begins_with("--instantes") and ResourceLoader.exists("res://tools/testes/instantes.gd"):
			add_child(load("res://tools/testes/instantes.gd").new())
			return


# ================================================================ montagem
func _montar_3d() -> void:
	vp = SubViewport.new()
	# (o Godot liga a interpolação da física em toda SubViewport; aqui ela
	# fica desligada e só bola, pinos e máquina ligam — Tela.gd explica)
	vp.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_qualidade_viewport()
	vp.positional_shadow_atlas_size = 0
	add_child(vp)
	mundo = Mundo.new()
	vp.add_child(mundo)
	mundo.construir()
	mundo.aplicar_qualidade(_qualidade)
	pinos = Pinos.new()
	vp.add_child(pinos)
	pinos.montar()
	pinos.batida.connect(_batida_pino)
	maquina = Maquina.new()
	vp.add_child(maquina)
	maquina.montar(pinos)
	maquina.som.connect(_som_maquina)
	bola = Bola.new()
	vp.add_child(bola)
	bola.guardar()
	bola.bateu.connect(_bola_bateu)
	bola.recolhida.connect(_bola_recolhida)
	mundo.bola = bola
	efeitos = Efeitos.new()
	vp.add_child(efeitos)
	for nome in ["bob", "mia"]:
		var p := Personagem.new()
		vp.add_child(p)
		p.montar(nome)
		p.soltou_bola.connect(_soltou_bola)
		p.som.connect(_som_personagem)
		personagens[nome] = p
	cam = CameraCine.new()
	vp.add_child(cam)
	cam.current = true
	_replay_alvo = Node3D.new()
	vp.add_child(_replay_alvo)


## Antisserrilhado e nível de detalhe conforme a qualidade:
##   alta  (PC): MSAA 4x, malhas no detalhe máximo;
##   media (TV Box): sem MSAA, simplifica as malhas de longe mais cedo;
##   baixa (TV Box fraca): sem MSAA, malhas bem simplificadas.
func _qualidade_viewport() -> void:
	# MSAA só no PC: na TV Box ele pesa ~30% do quadro (a imagem esticada já
	# suaviza os serrilhados)
	vp.msaa_3d = Viewport.MSAA_4X if _qualidade == "alta" else Viewport.MSAA_DISABLED
	vp.mesh_lod_threshold = {"alta": 1.0, "media": 2.0, "baixa": 4.0}.get(_qualidade, 2.0)
	vp.anisotropic_filtering_level = Viewport.ANISOTROPY_4X if _qualidade == "alta" else Viewport.ANISOTROPY_DISABLED


## Tamanho da imagem 3D: o lado menor da tela, limitado pelo LADO_3D da
## qualidade e pelo fator automático; a imagem é esticada até a tela.
func _tela_mudou(_t: Vector2) -> void:
	var f := Vector2(Tela.tamanho_fisico())
	var menor := minf(f.x, f.y)
	var lado := minf(menor, float(LADO_3D.get(_qualidade, 720))) * _fator
	var k := lado / maxf(menor, 1.0)
	vp.size = Vector2i(maxi(64, int(round(f.x * k))), maxi(64, int(round(f.y * k))))
	if hud:
		hud.layout()


# ================================================================ entrada
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo() and (event as InputEventKey).keycode == KEY_F3:
		medidor.alternar()
		return
	if event is InputEventMouseMotion:
		_mouse_parado = 0.0
		if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if ArcadeControls.eh_config(event):
		get_viewport().set_input_as_handled()
		_parar_lenta()
		get_tree().change_scene_to_file.call_deferred(CENA_OPERADOR)
		return
	if ArcadeControls.eh_credito(event):
		Ajustes.adicionar_credito()
		Sons.tocar("moeda", 0.65)
		_atualizar_atracao()
		return
	if ArcadeControls.eh_start(event):
		_start()
		return
	var z := ArcadeControls.tecla_jogada(event)
	if z != "":
		_jogada_recebida(_zona(z))


func _zona(tecla: String) -> String:
	# ArcadeControls devolve Z X C V B (as mesmas letras das zonas)
	return tecla


func _start() -> void:
	_inativo = 0.0
	if _modal_inativo > 0.0:
		_fechar_inatividade()
		return
	match estado:
		E.TESTE:
			if _resultado_teste != null:
				(_resultado_teste.get_meta("fundo") as Node).queue_free()
				_resultado_teste = null
				_atracao()
		E.ABERTURA, E.ATRACAO, E.DEMO:
			if Ajustes.pode_comecar():
				_escolher_jogadores()
			else:
				hud.texto_grande("INSIRA FICHA", Color("#FFF6A8"), 1.0, 0.55)
		E.JOGADORES:
			# como no Dragon Bowling: o 2º START = 2 jogadores (mostra e já começa)
			if _escolha_n == 1:
				_escolha_n = 2
				_escolha_t = minf(_escolha_t, 1.1)
				Sons.tocar("selecao")
				ArduinoBridge.send_led("RED")
		E.PERSONAGEM:
			_confirmar_personagem()
		E.FIM:
			if _fim_t > 2.5 and Ajustes.pode_comecar():
				_escolher_jogadores()


func _jogada_recebida(zona: String) -> void:
	_inativo = 0.0
	if _modal_inativo > 0.0:
		_fechar_inatividade()
	match estado:
		E.PRONTO:
			_arremessar(zona)
		E.PERSONAGEM:
			if zona in ["Z", "X"]:
				_marcar_destaque(0)
			elif zona in ["V", "B"]:
				_marcar_destaque(1)
			else:
				_confirmar_personagem()
		E.ATRACAO, E.DEMO, E.ABERTURA:
			# rolar a bola no menu também convida a jogar
			hud.sensor_acendeu(zona)
			Sons.tocar("selecao")
		E.ARREMESSO, E.ROLANDO, E.RESULTADO, E.REPLAY:
			if Time.get_ticks_msec() - _ultima_jogada_ms < MESMA_BOLA_MS:
				return
			_pendente = zona
			_pendente_ms = Time.get_ticks_msec()
			_pular = true


# ================================================================ abertura e atração
func _abertura() -> void:
	estado = E.ABERTURA
	var s := _novo_seq()
	hud.atracao(false)
	hud.mostrar_sensores(false)
	hud.mostrar_placar(false)
	mundo.aplicar_tema("parque")
	maquina.instantaneo()
	# os bichinhos entram depois (na atração)
	for nome in personagens:
		(personagens[nome] as Personagem).visible = false
	# 1) ABERTURA DE BOLICHE: a bola com o alvo da Lazer & Sport rola pela
	# pista (câmera colada nela, faixas de cinema)...
	bola.vestir("alvo")
	bola.fogo(false)
	hud.tarjas(true)
	cam.corte(Vector3(0.16, 0.3, 1.45), Vector3(0.0, 0.14, -10.0), 26, 30)
	if not await _esperar(0.5, s, false):
		return
	Jogada.forcar = [10]
	var j := Jogada.planejar("C", pinos.em_pe(), true, "facil", true)
	var origem := Vector3(j.origem_x, Bola.RAIO + 0.04, 0.35)
	var dir := Vector3(j.alvo_x, Bola.RAIO, Mundo.Z_PINO1) - origem
	dir.y = 0.0
	bola.lancar(origem, dir.normalized() * j.velocidade, j.efeito)
	pinos.soltar_todos()
	Sons.tocar("whoosh", 0.6)
	cam.seguir(bola, Vector3(0.14, 0.3, 1.3), Vector3(0.0, 0.06, -3.0), 28, 32, 7.0)
	var t := 0.0
	while bola.global_position.z > Mundo.Z_PINO1 + 0.32 and t < 3.0:
		await get_tree().process_frame
		if s != _seq:
			Sons.rolando(false)
			return
		t += get_process_delta_time()
		Sons.rolando(true, bola.velocidade())
		mundo.bola_z = -bola.global_position.z
		# os pinos fazem cara de medo quando a bola chega
		if bola.global_position.z < Mundo.Z_PINO1 + 3.3:
			pinos.susto(bola.global_position)
	Sons.rolando(false)
	# 2) ...STRIKE em câmera lenta, vista de lado (de cima da canaleta, por
	# dentro das paredes da caçapa)
	cam.corte(Vector3(0.6, 0.36, Mundo.Z_PINO1 + 1.2), Vector3(-0.12, 0.27, Mundo.Z_PINO1 - 0.45), 40, 44)
	cam.tremer(0.05, 0.4)
	Sons.tocar("pinos_queda", 0.9)
	_camera_lenta(0.3, 1.3)
	if not await _esperar(1.0, s, false):
		return
	# 3) LAZER & SPORT GAMES apresenta (por cima do strike)
	Sons.tocar("strike", 0.75)
	hud.flash(Color.WHITE, 0.45, 0.3)
	hud.marca(true, false, true)
	_atrasado_som(0.1, "brilho")
	_atrasado_som(0.6, "pop")
	efeitos.estrelas(Vector3(0, 0.6, Mundo.Z_PINO1 - 0.3), 30)
	cam.ir(Vector3(0.0, 1.25, Mundo.Z_PINO1 + 4.6), Vector3(0.0, 1.0, Mundo.Z_PINO1 - 1.0), 46, 44, 0.8)
	if not await _esperar(2.7, s, false):
		return
	hud.marca(false)
	hud.tarjas(false)
	# 4) voo até a atração: pinos de pé, os bichinhos chegam, STRIKE KIDS
	hud.flash(Color.WHITE, 0.6, 0.35)
	bola.guardar()
	bola.vestir("bob")
	mundo.bola_z = 100.0
	maquina.instantaneo()
	for nome in personagens:
		(personagens[nome] as Personagem).visible = true
	_posicionar_atracao()
	Sons.musica("musica_menu")
	cam.trilho([
		[Vector3(0, 4, Mundo.Z_PINO1 + 5.0), Vector3(0, 0.4, Mundo.Z_PINO1), 0.0],
		[Vector3(0.0, 3.3, 0.6), Vector3(0, 0.6, -4), 1.3],
		[Vector3(0, 1.4, 5.6), Vector3(0, 0.75, 1.6), 1.2],
	], 52, 40)
	if not await _esperar(2.4, s):
		return
	hud.flash(Color.WHITE, 0.6)
	Sons.tocar("brilho")
	_atracao()
	if bool(Ajustes.valor("video", "testar")):
		Ajustes.definir("video", "testar", false)
		_teste_desempenho()


## TESTE DE DESEMPENHO (pedido no menu do operador): 20 s pelas vistas mais
## pesadas; mostra a média de quadros por segundo e a qualidade recomendada.
func _teste_desempenho() -> void:
	estado = E.TESTE
	_novo_seq()
	hud.atracao(false)
	_posicionar_atracao()
	var r: Dictionary = await medidor.testar()
	_resultado_teste = r["cartaz"]
	mundo.aplicar_tema(Temas.ORDEM[0])


func _atracao() -> void:
	estado = E.ATRACAO
	demo = false
	Sons.mudo_demo = false
	Sons.atualizar_volume()
	_novo_seq()
	_limpar()
	hud.marca(false, true)
	hud.tela_fim(false)
	hud.jogadores(false)
	hud.selecao(false)
	hud.etapa(0)
	hud.inatividade(false)
	_modal_inativo = 0.0
	bola.guardar()
	maquina.instantaneo()
	_posicionar_atracao()
	_atualizar_atracao()
	Sons.musica("musica_menu")
	cam.orbitar(Vector3(0, 0.75, 1.6), 4.4, 0.9, 0.35, 40, 46, 0.75)
	ArduinoBridge.send_led("MENU")
	_demo_t = 0.0


func _posicionar_atracao() -> void:
	var t: Personagem = personagens["bob"]
	var r: Personagem = personagens["mia"]
	t.posicionar(Vector3(-0.6, 0, 1.6), 0)
	r.posicionar(Vector3(0.6, 0, 1.6), 0)
	t.segurar_bola(false)
	r.segurar_bola(false)
	t.jatos(false)
	r.jatos(false)
	t.olhar_alvo = null
	r.olhar_alvo = null
	# à vontade: respiram, acenam, olham em volta, dançam um pouquinho
	t.ocioso(true)
	r.ocioso(true)
	t.expressao("feliz")
	r.expressao("feliz")


func _atualizar_atracao() -> void:
	if estado not in [E.ATRACAO, E.DEMO, E.ABERTURA]:
		return
	var r1 := Ajustes.recorde(1)
	var txt := ""
	if int(r1.get("pontos", 0)) > 0:
		txt = "RECORDE: %d PONTOS (%s)" % [int(r1["pontos"]), str(r1.get("quem", "")).to_upper()]
	var cred := "MODO LIVRE" if Ajustes.modo_livre() else "CRÉDITOS: %d" % Ajustes.creditos
	hud.atracao(true, txt, cred, Fotos.foto_recorde(1), Classificacao.lista().slice(0, 3))


# ================================================================ escolha
func _escolher_jogadores() -> void:
	estado = E.JOGADORES
	_novo_seq()
	_limpar()
	demo = false
	maquina.instantaneo()
	Sons.tocar("start")
	Sons.mudo_demo = false
	Sons.atualizar_volume()
	hud.marca(false, true)
	hud.atracao(false)
	hud.tela_fim(false)
	hud.etapa(1)
	# a câmera pode ter sido ligada depois: procura de novo antes da foto
	Fotos.procurar_agora()
	_escolha_n = 1
	_escolha_t = TEMPO_JOGADORES
	ArduinoBridge.send_led("MENU")
	bola.guardar()
	_parar_lenta()


func _confirmar_jogadores() -> void:
	hud.jogadores(false)
	if _escolha_n == 2:
		_comecar(["bob", "mia"])
	else:
		_escolher_personagem()


func _escolher_personagem() -> void:
	estado = E.PERSONAGEM
	_novo_seq()
	hud.etapa(2)
	_escolha_t = 8.0
	var t: Personagem = personagens["bob"]
	var r: Personagem = personagens["mia"]
	_subir_nos_podios()
	t.tocar("acenar", 0.3, true)
	r.tocar("parado", 0.3, true)
	cam.ir(Vector3(0, 1.05, 6.1), Vector3(0, 0.78, 2.5), 32, 52, 3.0)
	_marcar_destaque(0)


func _marcar_destaque(i: int) -> void:
	if i != _destaque:
		Sons.tocar("selecao")
	_destaque = i
	var t: Personagem = personagens["bob"]
	var r: Personagem = personagens["mia"]
	t.tocar("acenar" if i == 0 else "parado", 0.25)
	r.tocar("acenar" if i == 1 else "parado", 0.25)
	t.destaque(0.12 if i == 0 else 0.0)
	r.destaque(0.12 if i == 1 else 0.0)
	mundo.podios(true, PODIOS, i)
	_escolha_t = max(_escolha_t, 3.0)


## Bob e Mia em cima dos pódios (escolha e foto).
func _subir_nos_podios() -> void:
	mundo.podios(true, PODIOS, -1)
	(personagens["bob"] as Personagem).posicionar(PODIOS[0] + Vector3(0, Mundo.ALTURA_PODIO, 0), 0)
	(personagens["mia"] as Personagem).posicionar(PODIOS[1] + Vector3(0, Mundo.ALTURA_PODIO, 0), 0)


## Frente de cada pódio na tela (as placas com os nomes ficam logo abaixo).
func _pes_na_tela() -> Array:
	var r := []
	var f := hud.size / Vector2(vp.size)
	for p in PODIOS:
		r.append(cam.unproject_position(p + Vector3(0, 0, 0.45)) * f)
	return r


func _atrasado_som(t: float, nome: String) -> void:
	get_tree().create_timer(t).timeout.connect(func(): Sons.tocar(nome))


func _confirmar_personagem() -> void:
	if estado != E.PERSONAGEM:
		return
	estado = E.RESULTADO
	var s := _novo_seq()
	var escolhido := "bob" if _destaque == 0 else "mia"
	var outro := "mia" if _destaque == 0 else "bob"
	hud.selecao(false)
	Sons.tocar("escolha")
	(personagens[escolhido] as Personagem).tocar("escolhido", 0.15, true)
	(personagens[outro] as Personagem).tocar("feliz", 0.2, true)
	hud.flash(Color.WHITE, 0.4)
	efeitos.estrelas((personagens[escolhido] as Personagem).global_position + Vector3(0, 1.2, 0), 26)
	if not await _esperar(1.5, s):
		return
	personagens["bob"].destaque(0.0)
	personagens["mia"].destaque(0.0)
	_comecar([escolhido])


# ================================================================ partida
func _comecar(lista: Array) -> void:
	Ajustes.gastar_creditos()
	Ajustes.contar("partidas")
	placar.comecar(lista, Ajustes.rodadas(), Ajustes.tentativas())
	mundo.definir_protecao(Ajustes.protecao_canaleta())
	maquina.instantaneo()
	_tema_base = (_tema_base + 1) % Temas.ORDEM.size()
	Fotos.limpar_partida()
	if Fotos.pronta() and bool(Ajustes.valor("jogo", "foto")):
		if not await _sessao_de_fotos(lista):
			return
	hud.configurar_placar(lista)
	hud.atualizar_placar(placar)
	Sons.musica("musica_jogo")
	hud.sequencia(0)
	_vez(true)


## "SORRIA!": cada jogador tira uma foto com a câmera da máquina (3, 2, 1).
func _sessao_de_fotos(lista: Array) -> bool:
	estado = E.FOTO
	var s := _novo_seq()
	hud.etapa(3)
	Fotos.ligar()
	var t: Personagem = personagens["bob"]
	var r: Personagem = personagens["mia"]
	_subir_nos_podios()
	t.destaque(0.0)
	r.destaque(0.0)
	cam.ir(Vector3(0, 1.05, 6.1), Vector3(0, 0.78, 2.5), 32, 52, 3.0)
	for i in lista.size():
		var p: String = lista[i]
		var a: Personagem = personagens[p]
		mundo.podios(true, PODIOS, 0 if p == "bob" else 1)
		var sub := "olhe para a câmera da máquina!"
		if lista.size() > 1:
			sub = "quem joga com %s %s: olhe para a câmera!" % ["o" if p == "bob" else "a", "BOB" if p == "bob" else "MIA"]
		a.tocar("acenar", 0.2, true)
		hud.foto_tela(true, Fotos.ao_vivo(), p, "SORRIA!", sub)
		Sons.tocar("vez")
		if not await _esperar(1.9, s, false):
			return false
		for n in [3, 2, 1]:
			hud.foto_contagem(n)
			Sons.tocar("tique", 0.9, 1.0 + (3 - n) * 0.15)
			if not await _esperar(0.85, s, false):
				return false
		hud.foto_contagem(0)
		hud.flash(Color.WHITE, 0.95, 0.45)
		Sons.tocar("brilho")
		Sons.tocar("pop", 0.8, 0.8)
		var foto: Texture2D = await Fotos.tirar("j%d" % i)
		if s != _seq:
			return false
		hud.foto_pronta(foto, p)
		a.tocar("feliz", 0.2, true)
		a.expressao("empolgado")
		if not await _esperar(1.5, s, false):
			return false
	hud.foto_tela(false)
	Fotos.desligar()
	mundo.podios(false)
	return true


func _tema_da_rodada() -> String:
	return Temas.ORDEM[(maxi(_tema_base, 0) + placar.rodada_atual) % Temas.ORDEM.size()]


## Começo da vez de um jogador (ou da próxima bola dele).
func _vez(nova_rodada: bool) -> void:
	estado = E.RESULTADO
	var s := _novo_seq()
	_pular = false
	_ativo = placar.atual()["personagem"]
	_plateia = "mia" if _ativo == "bob" else "bob"
	mundo.podios(false)
	hud.etapa(0)
	var a: Personagem = personagens[_ativo]
	var p: Personagem = personagens[_plateia]
	a.jatos(false)
	p.jatos(false)
	a.destaque(0.0)
	p.destaque(0.0)
	a.posicionar(Vector3(-X_MAO, 0, Z_INICIO), 180)
	a.segurar_bola(true)
	mundo.guardar_retorno()
	a.tocar("pronto", 0.15, true)
	a.expressao("feliz")
	a.olhar_alvo = null
	var lado := 1.0 if _ativo == "bob" else -1.0
	p.posicionar(Vector3(lado * 1.85, 0, 1.0), 180 - lado * 38)
	p.tocar("torcida" if placar.jogadores.size() == 1 else "parado", 0.2, true)
	p.olhar_alvo = null
	hud.mostrar_placar(true)
	hud.atualizar_placar(placar)
	hud.mostrar_mapa(pinos.em_pe())
	hud.mostrar_sensores(true)
	hud.sequencia(int(placar.atual()["seguidos"]))
	bola.fogo(int(placar.atual()["seguidos"]) >= 2)
	var comeco := placar.rodada_atual == 0 and placar.jogador_atual == 0
	if nova_rodada and (_tema_da_rodada() != mundo.tema or comeco):
		# cenário novo: clarão, troca e um passeio de câmera pelo lugar
		var tema := _tema_da_rodada()
		hud.flash(Color.WHITE, 0.95, 0.6)
		mundo.aplicar_tema(tema)
		Sons.tocar("brilho")
		Sons.tocar("whoosh", 0.6)
		hud.anunciar_cenario(tema, 1.7)
		# passeio pelo cenário que termina na PISTA DE FRENTE (a vista da
		# espera): o mascote só aparece depois que a bola for jogada
		cam.trilho([
			[Vector3(-2.6, 4.6, Mundo.Z_PINO1 + 1.0), Vector3(0, 2.2, Mundo.Z_FUNDO - 3.0), 0.0],
			[Vector3(2.2, 3.4, -5.0), Vector3(0, 1.4, Mundo.Z_FUNDO), 1.4],
			[POS_PISTA, ALVO_PISTA, 1.3],
		], 34, 40)
		if not await _esperar(2.9, s, false):
			return
	elif nova_rodada:
		_plano_pista(false)
	if nova_rodada:
		var artigo := "DO" if _ativo == "bob" else "DA"
		var sub := "RODADA %d" % (placar.rodada_atual + 1)
		hud.faixa(_ativo, "VEZ %s %s!" % [artigo, _ativo.to_upper()], sub, Fotos.foto("j%d" % placar.jogador_atual))
		Sons.tocar("vez")
		ArduinoBridge.send_led("BLUE" if _ativo == "bob" else "RED")
		if not await _esperar(1.6, s, false):
			return
	_pronto()


## Esperando a jogada: a PISTA DE FRENTE, como a criança vê da máquina —
## pinos lá no fim, nada na frente. O mascote fica fora do quadro e só
## aparece depois que o sensor dispara (corte para ele arremessando).
func _plano_pista(corte := false) -> void:
	if corte:
		cam.corte(POS_PISTA, ALVO_PISTA, 34, 40)
	else:
		cam.ir(POS_PISTA, ALVO_PISTA, 34, 40, 2.6)


func _pronto() -> void:
	estado = E.PRONTO
	_novo_seq()
	_pular = false
	_inativo = 0.0
	_plano_pista()
	hud.convite(true)
	ArduinoBridge.send_led("IDLE")
	var a: Personagem = personagens[_ativo]
	a.expressao("concentrado")
	# jogada que chegou enquanto a pista não estava pronta
	if _pendente != "" and Time.get_ticks_msec() - _pendente_ms < VALIDADE_PENDENTE_MS:
		var z := _pendente
		_pendente = ""
		await get_tree().create_timer(0.35).timeout
		if estado == E.PRONTO:
			_arremessar(z)
	_pendente = ""


func _arremessar(zona: String) -> void:
	if estado != E.PRONTO and estado != E.DEMO:
		return
	if Time.get_ticks_msec() - _ultima_jogada_ms < MESMA_BOLA_MS:
		return
	_ultima_jogada_ms = Time.get_ticks_msec()
	_novo_seq()
	estado = E.ARREMESSO
	hud.sensor_acendeu(zona)
	hud.convite(false)
	_em_pe_antes = pinos.em_pe()
	var primeira := placar.bola_atual == 0 if not demo else true
	jogada = Jogada.planejar(zona, _em_pe_antes, primeira and _em_pe_antes.size() == 10, Ajustes.dificuldade(), Ajustes.protecao_canaleta())
	var a: Personagem = personagens[_ativo]
	# passo para o lado: a bola sai na linha do sensor
	var x_corpo: float = clamp(jogada.origem_x - X_MAO, -0.85, 0.55)
	var tw := create_tween()
	tw.tween_property(a, "base:origin:x", x_corpo, 0.45).set_trans(Tween.TRANS_SINE)
	a.tocar("arremesso", 0.12, true)
	# corte seco da pista para o mascote arremessando
	cam.corte(a.global_position + Vector3(1.15, 2.05, 3.3), a.global_position + Vector3(-0.35, 0.05, -7.0), 50, 40)
	cam.seguir(a, Vector3(1.15, 2.05, 3.3), Vector3(-0.35, 0.05, -7.0), 50, 40, 3.0)
	Sons.tocar("whoosh", 0.5)


func _soltou_bola(pos: Vector3) -> void:
	if estado != E.ARREMESSO:
		return
	var a: Personagem = personagens[_ativo]
	bola.vestir(_ativo)
	# a bola segue a linha planejada (a mesma da calibração): passa por
	# origem_x na linha de falta (z = 0,35) e vai até alvo_x nos pinos
	var z0 := minf(pos.z, 0.45)
	var u := (0.35 - z0) / (0.35 - Mundo.Z_PINO1)
	var origem := Vector3(lerpf(jogada.origem_x, jogada.alvo_x, u), Bola.RAIO + 0.04, z0)
	var alvo := Vector3(jogada.alvo_x, Bola.RAIO, Mundo.Z_PINO1)
	var dir := (alvo - origem)
	dir.y = 0
	dir = dir.normalized()
	bola.lancar(origem, dir * jogada.velocidade, jogada.efeito)
	pinos.soltar_todos()
	estado = E.ROLANDO
	_t_jogada = 0.0
	_t_impacto = -1.0
	_deck_cam = false
	_gravacao.clear()
	_gravando = true
	mundo.acender_pista(true)
	a.tocar("assistindo", 0.25)
	a.olhar_alvo = bola.global_position
	var p: Personagem = personagens[_plateia]
	p.tocar("torcida", 0.2)
	# primeiro por cima (a câmera não atravessa o personagem), depois desce
	cam.seguir(bola, Vector3(0.5, 2.1, 3.6), Vector3(0, 0.0, -5.0), 50, 40, 3.0)
	_cam_baixa = false
	Sons.tocar("start", 0.35, 1.4)


## A bola entrou na caçapa do fundo: barulhinho do túnel e, um pouco
## depois, ela aparece no retorno de bolas, perto de quem joga.
func _bola_recolhida() -> void:
	if estado in [E.ABERTURA, E.TESTE]:
		return
	Sons.tocar("whoosh", 0.45, 0.55)
	var nome := _ativo
	get_tree().create_timer(1.3).timeout.connect(func():
		mundo.retorno_bola(Bola.material(nome))
		Sons.tocar("pop", 0.55, 0.5))


func _process(delta: float) -> void:
	_medir_fps(delta)
	# PC em tela cheia: a setinha do mouse some sozinha quando ninguém mexe
	_mouse_parado += delta
	if _mouse_parado > 2.5 and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	match estado:
		E.ROLANDO:
			_rolando(delta)
		E.PRONTO:
			_contar_inatividade(delta)
		E.JOGADORES:
			_escolha_t -= delta
			hud.jogadores(true, _escolha_n, _escolha_t / TEMPO_JOGADORES, int(ceil(_escolha_t)))
			if _escolha_t <= 0.0:
				_confirmar_jogadores()
		E.PERSONAGEM:
			_escolha_t -= delta
			hud.selecao(true, _destaque, "ROLE A BOLA PARA ESCOLHER SEU AMIGO\nbola no MEIO ou START confirma   (%d)" % int(ceil(_escolha_t)), _pes_na_tela())
			if _escolha_t <= 0.0:
				_confirmar_personagem()
		E.ATRACAO:
			_demo_t += delta
			if bool(Ajustes.valor("jogo", "demo")) and _demo_t > 9.0:
				_demo_t = 0.0
				_jogada_demo()
		E.FIM:
			_fim_t += delta
			var resta := int(ceil(16.0 - _fim_t))
			hud.fim_contagem(max(resta, 0))
			if _fim_t > 16.0:
				_atracao()
	if _replay_ativo:
		_rodar_replay(delta)
	for nome in personagens:
		var p: Personagem = personagens[nome]
		if p.olhar_alvo != null and bola.visible:
			p.olhar_alvo = bola.global_position


func _rolando(_delta: float) -> void:
	var b := bola.global_position
	mundo.bola_z = -b.z
	Sons.rolando(b.z > Mundo.Z_PINO1 - 0.5, bola.velocidade())
	for nome in personagens:
		(personagens[nome] as Personagem).olhar_alvo = b
	if b.z < Mundo.Z_PINO1 + 3.3:
		pinos.susto(b)
	# câmera: desce para perseguir a bola, depois vai para os pinos
	if not _cam_baixa and b.z < -2.5:
		_cam_baixa = true
		cam.seguir(bola, Vector3(0.0, 0.85, 2.5), Vector3(0, 0.05, -4.5), 52, 40, 2.8)
	if not _deck_cam and b.z < Mundo.Z_PINO1 + 4.6:
		_deck_cam = true
		cam.ir(Vector3(b.x * 0.25 + 0.32, 0.9, Mundo.Z_PINO1 + 3.0), Vector3(0, 0.16, Mundo.Z_PINO1 - 0.5), 38, 36, 3.2)
	# impacto
	if _t_impacto < 0.0 and b.z < Mundo.Z_PINO1 + 0.22 and abs(b.x) < Mundo.MEIA_LARGURA:
		_impacto(b)
	var fim := false
	if _t_impacto >= 0.0:
		var dt := _t_jogada - _t_impacto
		fim = dt > 2.8 or (dt > 1.4 and pinos.todos_parados())
	elif b.z < Mundo.Z_FIM_DECK - 0.4 or b.y < -0.5:
		fim = _t_jogada > 0.5
	if _t_jogada > 7.5:
		fim = true
	if fim:
		_finalizar_jogada()


func _impacto(b: Vector3) -> void:
	_t_impacto = _t_jogada
	var cheio := absf(b.x) < 0.2 and _em_pe_antes.size() >= 6
	var forte := 8 if cheio else 3
	cam.tremer(0.03 + forte * 0.005, 0.4)
	cam.soco(3.5 if cheio else 1.8)
	efeitos.poeira(Vector3(b.x, 0.05, b.z), 1.0 + forte * 0.08)
	if cheio:
		Sons.tocar("pinos_queda", 0.9)
	if jogada.strike_provavel:
		mundo.lampadas(1)
		_camera_lenta(0.4, 0.5)


## Câmera lenta que ENTRA e SAI suave (sem tranco de velocidade): desce
## até `escala` em 0,08 s, segura e volta ao normal em 0,3 s.
func _camera_lenta(escala: float, dur_real: float) -> void:
	_parar_lenta()
	_lenta = create_tween().set_ignore_time_scale(true)
	_lenta.tween_method(_ritmo, 1.0, escala, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_lenta.tween_interval(maxf(dur_real - 0.08, 0.0))
	_lenta.tween_method(_ritmo, escala, 1.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## Ritmo do tempo SEM mudar a física: o passo da física continua sempre de
## 1/120 s (o mesmo da calibração das jogadas — o resultado não muda);
## na câmera lenta ela só dá MENOS passos por segundo (0,4 = 48 por
## segundo) e a interpolação deixa a imagem lisa.
func _ritmo(v: float) -> void:
	var passos := clampi(int(round(float(_passos_fisica) * v)), 12, _passos_fisica)
	Engine.physics_ticks_per_second = passos
	Engine.time_scale = float(passos) / float(_passos_fisica)


func _parar_lenta() -> void:
	if _lenta != null and _lenta.is_valid():
		_lenta.kill()
	_lenta = null
	_ritmo(1.0)


## O relógio da jogada anda junto com a FÍSICA (120 passos por segundo, já
## com a câmera lenta aplicada): cada quadro gravado tem o seu próprio
## instante. (Se o relógio fosse o da tela, a 60 QPS dois passos de física
## ficavam com o mesmo horário e o replay saía picotado.)
func _physics_process(delta: float) -> void:
	if estado == E.ROLANDO:
		_t_jogada += delta
	if _gravando:
		_gravacao.append({"t": _t_jogada, "b": bola.global_transform, "p": pinos.foto(), "v": bola.visible})


func _finalizar_jogada() -> void:
	estado = E.RESULTADO
	var s := _novo_seq()
	_gravando = false
	_parar_lenta()
	Sons.rolando(false)
	mundo.acender_pista(false)
	mundo.lampadas(0)
	var derrubados := pinos.caidos_desde(_em_pe_antes)
	var n := derrubados.size()
	var festa_pinos := pinos.reagir()
	hud.mostrar_mapa(pinos.em_pe())
	var a: Personagem = personagens[_ativo]
	var p: Personagem = personagens[_plateia]
	a.olhar_alvo = null
	p.olhar_alvo = null
	var res := {"tipo": "normal", "pontos": n * Placar.PONTOS_PINO, "fim_rodada": false}
	if not demo:
		res = placar.registrar(n)
		hud.atualizar_placar(placar)
	else:
		if n == _em_pe_antes.size() and n == 10:
			res["tipo"] = "strike"
		elif n == 0:
			res["tipo"] = "zero"
	var tipo: String = res["tipo"]
	var sobrou := pinos.em_pe().size()
	match tipo:
		"strike":
			hud.flash(Color("#FFF6A8"), 0.75)
			hud.letreiro("strike", "", 1.9)
			Sons.tocar("strike")
			Sons.tocar("torcida", 0.8)
			ArduinoBridge.send_led("STRIKE")
			if not demo:
				var ft: Texture2D = Fotos.foto("j%d" % placar.jogador_atual)
				if ft != null:
					hud.foto_destaque(ft, Hud.COR_BOB if _ativo == "bob" else Hud.COR_MIA, 1.4)
			efeitos.estrelas(Vector3(0, 0.6, Mundo.Z_PINO1 - 0.4), 40, 1.3)
			efeitos.confete(Vector3(0, 0.3, Mundo.Z_PINO1 + 1.5), 1.6, 90)
			mundo.lampadas(1)
		"spare":
			hud.flash(Color("#C9F7FF"), 0.55)
			hud.letreiro("spare", "", 1.7)
			Sons.tocar("spare")
			Sons.tocar("torcida", 0.6)
			ArduinoBridge.send_led("SPARE")
			efeitos.estrelas(Vector3(0, 0.6, Mundo.Z_PINO1 - 0.4), 28)
			mundo.lampadas(2)
		"zero":
			hud.letreiro("ops", "", 1.5)
			Sons.tocar("ops", 0.75)
			ArduinoBridge.send_led("MISS")
		_:
			var nome := "boa"
			if n >= 7:
				nome = "super" if randf() < 0.5 else "uau"
			elif sobrou == 1:
				nome = "quase"
			hud.letreiro(nome, "%d %s!" % [n, "PINO" if n == 1 else "PINOS"], 1.5)
			Sons.tocar("boa")
			ArduinoBridge.send_led("NORMAL")
			if n >= 5:
				efeitos.estrelas(Vector3(0, 0.5, Mundo.Z_PINO1 - 0.3), 16, 0.8)
	if not demo and int(res["pontos"]) > 0:
		hud.pontos_voando(int(res["pontos"]), placar.jogador_atual)
	if tipo == "strike":
		Ajustes.contar("strikes")
		var seguidos := int(placar.atual()["seguidos"]) if not demo else 0
		if seguidos >= 2:
			hud.sequencia(seguidos)
			get_tree().create_timer(1.0).timeout.connect(func():
				if estado == E.RESULTADO or estado == E.REPLAY:
					hud.letreiro("pegando_fogo", "%d STRIKES SEGUIDOS!" % seguidos, 1.6, 0.55)
					Sons.tocar("brilho"))
	# replay do strike
	if tipo == "strike" and bool(Ajustes.valor("jogo", "replay_strike")) and _gravacao.size() > 20:
		if not await _esperar(1.5, s, false):
			return
		await _replay()
		if s != _seq:
			return
	else:
		# se sobrou pino comemorando, a câmera fica um pouco mais nos pinos
		if not await _esperar(1.6 if festa_pinos > 0 else 1.1, s):
			return
	# reação do personagem (câmera bem de frente)
	var pa := a.global_position
	if tipo == "strike":
		# ele vai voar: plano mais aberto e mais alto para caber o voo inteiro
		cam.ir(pa + Vector3(0.45, 1.35, -3.6), pa + Vector3(0, 1.2, 0), 44, 34, 3.0)
	else:
		cam.ir(pa + Vector3(0.35, 0.9, -2.3), pa + Vector3(0, 0.72, 0), 36, 30, 3.5)
	match tipo:
		"strike":
			a.tocar("comemora_strike", 0.15, true)
			p.tocar("feliz", 0.2, true)
			efeitos.confete(pa + Vector3(0, 2.0, -0.6), 1.2, 70)
		"spare":
			a.tocar("feliz", 0.15, true)
			p.tocar("feliz", 0.2, true)
		"zero":
			a.tocar("triste", 0.15, true)
			p.tocar("acenar", 0.2, true)
		_:
			if sobrou == 1:
				a.tocar("quase", 0.15, true)
			else:
				a.tocar("feliz", 0.15, true)
	var espera := 2.6 if tipo == "strike" else 1.8
	if not await _esperar(espera, s):
		return
	if demo:
		_fim_demo()
		return
	var proximo := placar.avancar(bool(res["fim_rodada"]))
	bola.guardar()
	if proximo == "fim":
		_fim_de_jogo()
		return
	# a máquina de pinos: barra varre os caídos, a mesa recoloca / desce rack novo
	_plano_maquina()
	if proximo == "bola":
		maquina.reposicionar()
	else:
		maquina.rack_novo()
	if not await _esperar(0.3, s, false):
		return
	while maquina.trabalhando:
		if not await _esperar(0.1, s, false):
			return
	hud.mostrar_mapa(pinos.em_pe())
	_vez(proximo == "rodada")


## Câmera de frente para os pinos, baixinha, para ver a máquina trabalhar.
func _plano_maquina() -> void:
	cam.corte(Vector3(0.55, 0.62, Mundo.Z_PINO1 + 2.5), Vector3(0, 0.5, Mundo.Z_PINO1 - 0.45), 40, 40)
	cam.ir(Vector3(-0.35, 0.72, Mundo.Z_PINO1 + 2.2), Vector3(0, 0.5, Mundo.Z_PINO1 - 0.45), 40, 40, 0.4)


# ================================================================ replay
## Câmera lenta do replay: a MESMA jogada (cada passo da física gravado),
## mais devagar — um pouco mais lenta em volta da batida, sempre suave.
const REPLAY_VEL := 0.45
const REPLAY_VEL_BATIDA := 0.27
const REPLAY_ANTES := 0.8
const REPLAY_DEPOIS := 1.6
## o rastro de arco-íris ganha um ponto a cada 1/60 s da jogada (igual ao jogo)
const REPLAY_RASTRO := 1.0 / 60.0


func _replay() -> void:
	estado = E.REPLAY
	var s := _seq
	hud.modo_replay(true)
	Sons.tocar("whoosh")
	pinos.prender_todos()
	pinos.interpolar(false)
	pinos.reviver()
	bola.freeze = true
	_replay_inicio = maxf(float(_gravacao[0]["t"]), _t_impacto - REPLAY_ANTES)
	_replay_fim = minf(_t_impacto + REPLAY_DEPOIS, float(_gravacao[-1]["t"]))
	_replay_t = _replay_inicio
	# o rastro já começa comprido (como estava na jogada nesse instante)
	_replay_rastro = maxf(float(_gravacao[0]["t"]), _replay_inicio - 27.0 * REPLAY_RASTRO)
	_replay_ativo = true
	bola.replay(true)
	_mostrar_quadro(_replay_t)
	bola.acender(0.8)
	# 1) câmera rasante colada na bola (corte seco, como na TV)
	cam.corte(_replay_alvo.global_position + Vector3(0.42, 0.16, 0.75), _replay_alvo.global_position + Vector3(-0.1, 0.08, -1.2), 40, 46)
	cam.seguir(_replay_alvo, Vector3(0.42, 0.16, 0.75), Vector3(-0.1, 0.08, -1.2), 40, 46, 12.0)
	while _replay_ativo and _replay_t < _t_impacto - 0.12:
		await get_tree().process_frame
		if s != _seq:
			return
	# 2) no impacto: lateral, baixinho, câmera bem lenta
	cam.corte(Vector3(0.5, 0.32, Mundo.Z_PINO1 + 1.1), Vector3(-0.05, 0.24, Mundo.Z_PINO1 - 0.35), 40, 48)
	cam.orbitar(Vector3(0, 0.24, Mundo.Z_PINO1 - 0.4), 1.55, 0.1, -0.3, 40, 48)
	while _replay_ativo and _replay_t < _t_impacto:
		await get_tree().process_frame
		if s != _seq:
			return
	# a batida: som (mais grave, em câmera lenta) junto com a imagem
	cam.tremer(0.02, 0.5)
	Sons.tocar("pinos_queda", 0.8, 0.85)
	while _replay_ativo and _replay_t < _t_impacto + 0.65:
		await get_tree().process_frame
		if s != _seq:
			return
	# 3) abre o plano: a explosão de pinos
	cam.ir(Vector3(-0.2, 1.3, Mundo.Z_PINO1 + 2.1), Vector3(0, 0.25, Mundo.Z_PINO1 - 0.6), 44, 46, 1.6)
	while _replay_ativo:
		await get_tree().process_frame
		if s != _seq:
			return
	bola.acender(0.0)
	bola.replay(false)
	pinos.interpolar(true)
	Sons.rolando(false)
	pinos.reagir()
	hud.modo_replay(false)
	hud.mostrar_placar(true)
	hud.mostrar_sensores(true)
	if s == _seq:
		estado = E.RESULTADO


func _vel_replay(t: float) -> float:
	return lerpf(REPLAY_VEL_BATIDA, REPLAY_VEL, smoothstep(0.08, 0.75, absf(t - _t_impacto)))


func _rodar_replay(delta: float) -> void:
	var vel := 3.0 if _pular else _vel_replay(_replay_t)
	_replay_t = minf(_replay_t + delta * vel, _replay_fim)
	bola.replay_ritmo(vel)
	# o rastro: pontos nos mesmos instantes da jogada de verdade
	while _replay_rastro + REPLAY_RASTRO <= _replay_t:
		_replay_rastro += REPLAY_RASTRO
		var q := _quadro(_replay_rastro, false)
		if q["v"]:
			bola.marcar_rastro((q["b"] as Transform3D).origin)
	var antes := bola.global_position
	var dt_jogada := delta * vel
	_mostrar_quadro(_replay_t)
	# o barulho da bola rolando, mais grave (câmera lenta)
	if dt_jogada > 0.0:
		var v := bola.global_position.distance_to(antes) / dt_jogada
		Sons.rolando(bola.visible and bola.global_position.z > Mundo.Z_PINO1 - 0.5, v * vel)
	if _replay_t < _t_impacto + 0.1:
		pinos.susto(bola.global_position)
	if _replay_t >= _replay_fim:
		_replay_ativo = false
		# termina exatamente como ficou de verdade
		bola.global_transform = _gravacao[-1]["b"]
		bola.visible = bool(_gravacao[-1]["v"])
		pinos.aplicar_foto(_gravacao[-1]["p"])


## Põe a bola e os pinos como estavam no instante t da jogada.
func _mostrar_quadro(t: float) -> void:
	var q := _quadro(t, true)
	var tb: Transform3D = q["b"]
	bola.global_transform = tb
	bola.visible = bool(q["v"])
	_replay_alvo.global_position = tb.origin
	pinos.aplicar_foto(q["p"])


## O instante t da gravação, interpolado entre os dois passos de física
## vizinhos (posição e giro). com_pinos = false: só a bola (rastro).
func _quadro(t: float, com_pinos: bool) -> Dictionary:
	var n := _gravacao.size()
	# busca binária: último quadro com tempo <= t
	var lo := 0
	var hi := n - 1
	while lo < hi:
		var m := (lo + hi + 1) >> 1
		if float(_gravacao[m]["t"]) <= t:
			lo = m
		else:
			hi = m - 1
	var f0: Dictionary = _gravacao[lo]
	var f1: Dictionary = _gravacao[mini(lo + 1, n - 1)]
	var t0 := float(f0["t"])
	var t1 := float(f1["t"])
	var u := clampf((t - t0) / (t1 - t0), 0.0, 1.0) if t1 > t0 else 0.0
	var r := {"b": (f0["b"] as Transform3D).interpolate_with(f1["b"], u), "v": f0["v"]}
	if com_pinos:
		var p0: Array = f0["p"]
		var p1: Array = f1["p"]
		var foto := []
		foto.resize(p0.size())
		for k in p0.size():
			foto[k] = (p0[k] as Transform3D).interpolate_with(p1[k], u)
		r["p"] = foto
	return r


# ================================================================ fim de jogo
func _fim_de_jogo() -> void:
	estado = E.FIM
	_novo_seq()
	_fim_t = 0.0
	hud.mostrar_placar(false)
	hud.mostrar_sensores(false)
	Sons.musica("musica_fim")
	Sons.tocar("fim")
	ArduinoBridge.send_led("MENU")
	var dados := {"jogadores": [], "vencedor": placar.vencedor(), "recorde": false}
	var melhor := 0
	var melhor_i := 0
	var quem := ""
	for i in placar.jogadores.size():
		var j: Dictionary = placar.jogadores[i]
		dados["jogadores"].append({"personagem": j["personagem"], "pontos": j["pontos"], "estrelas": placar.estrelas(i),
			"strikes": j["strikes"], "spares": j["spares"], "foto": Fotos.foto("j%d" % i)})
		if int(j["pontos"]) > melhor:
			melhor = int(j["pontos"])
			melhor_i = i
			quem = j["personagem"]
	if Ajustes.registrar_pontos(placar.jogadores.size(), melhor, quem) and melhor > 0:
		var caminho := Fotos.salvar_recorde("j%d" % melhor_i, placar.jogadores.size())
		if caminho != "":
			Ajustes.definir_foto_recorde(placar.jogadores.size(), caminho)
		dados["recorde"] = true
		dados["recorde_valor"] = melhor
		get_tree().create_timer(3.3).timeout.connect(func(): Sons.tocar("recorde"))
	# classificação do dia, com a foto de cada um
	var entradas := []
	for i in placar.jogadores.size():
		var j: Dictionary = placar.jogadores[i]
		entradas.append({"pontos": j["pontos"], "personagem": j["personagem"],
			"chave_foto": "j%d" % i if Fotos.foto("j%d" % i) != null else ""})
	var posicoes := Classificacao.registrar(entradas)
	for i in posicoes.size():
		dados["jogadores"][i]["posicao"] = posicoes[i]
	dados["classificacao"] = Classificacao.lista()
	hud.tela_fim(true, dados)
	# personagens no "pódio"
	var t: Personagem = personagens["bob"]
	var r: Personagem = personagens["mia"]
	bola.guardar()
	t.segurar_bola(false)
	r.segurar_bola(false)
	t.olhar_alvo = null
	r.olhar_alvo = null
	t.posicionar(Vector3(-0.62, 0, 2.3), 0)
	r.posicionar(Vector3(0.62, 0, 2.3), 0)
	var venc: int = dados["vencedor"]
	var jogou_bob := false
	var jogou_mia := false
	for j in placar.jogadores:
		if j["personagem"] == "bob":
			jogou_bob = true
		else:
			jogou_mia = true
	if placar.jogadores.size() == 2 and venc >= 0:
		var ganhador: Personagem = personagens[placar.jogadores[venc]["personagem"]]
		var outro: Personagem = r if ganhador == t else t
		ganhador.tocar("vitoria", 0.3, true)
		ganhador.jatos(true)
		ganhador.expressao("empolgado")
		outro.tocar("feliz", 0.3, true)
	else:
		for pp in [t, r]:
			pp.ocioso(true)
		var protagonista: Personagem = t if jogou_bob and not jogou_mia else (r if jogou_mia and not jogou_bob else null)
		if protagonista and placar.estrelas(0) >= 2:
			protagonista.tocar("vitoria", 0.3, true)
			protagonista.jatos(true)
	cam.ir(Vector3(0, 1.35, 6.6), Vector3(0, 1.1, 2.3), 40, 44, 2.0)
	efeitos.confete(Vector3(0, 3.2, 2.3), 2.2, 160)
	efeitos.fogos(Vector3(0, 3.8, -2.0), 7)


# ================================================================ demo
func _jogada_demo() -> void:
	estado = E.DEMO
	demo = true
	Sons.mudo_demo = not bool(Ajustes.valor("som", "som_na_demo"))
	Sons.atualizar_volume()
	var s := _novo_seq()
	_ativo = "bob" if _demo_vez % 2 == 0 else "mia"
	_plateia = "mia" if _ativo == "bob" else "bob"
	_demo_vez += 1
	maquina.instantaneo()
	var a: Personagem = personagens[_ativo]
	var p: Personagem = personagens[_plateia]
	a.ocioso(false)
	p.ocioso(false)
	a.posicionar(Vector3(-X_MAO, 0, Z_INICIO), 180)
	a.segurar_bola(true)
	a.tocar("pronto", 0.1, true)
	var lado := 1.0 if _ativo == "bob" else -1.0
	p.posicionar(Vector3(lado * 1.85, 0, 1.0), 180 - lado * 38)
	p.tocar("torcida", 0.2, true)
	_plano_pista(true)
	if not await _esperar(1.6, s, false):
		return
	var zonas := ["C", "C", "X", "V", "C", "Z", "B", "C"]
	_ultima_jogada_ms = -100000
	estado = E.DEMO
	_arremessar(zonas[randi() % zonas.size()])


func _fim_demo() -> void:
	demo = false
	_atracao()
	# a atração vai mostrando os 4 cenários
	hud.flash(Color.WHITE, 0.8, 0.5)
	mundo.aplicar_tema(Temas.proximo(mundo.tema))


# ================================================================ inatividade
func _contar_inatividade(delta: float) -> void:
	if demo:
		return
	if _modal_inativo > 0.0:
		_modal_inativo -= delta
		hud.inatividade(true, int(ceil(_modal_inativo)))
		if _modal_inativo <= 0.0:
			hud.inatividade(false)
			_fim_de_jogo()
		return
	_inativo += delta
	if _inativo > float(Ajustes.valor("jogo", "tempo_inatividade")):
		_modal_inativo = 10.0
		Sons.tocar("tique")


func _fechar_inatividade() -> void:
	_modal_inativo = 0.0
	_inativo = 0.0
	hud.inatividade(false)


# ================================================================ sons do mundo
func _batida_pino(pos: Vector3, forca: float) -> void:
	if estado == E.REPLAY:
		return
	var agora := Time.get_ticks_msec()
	if agora - _ultimo_som_pino < 35:
		return
	_ultimo_som_pino = agora
	Sons.tocar("pino_batida", clamp(forca / 4.0, 0.25, 1.0), randf_range(0.9, 1.15))
	if forca > 2.5:
		efeitos.poeira(pos, 0.5)


func _bola_bateu(corpo: Node, vel: float) -> void:
	if corpo is StaticBody3D and corpo.name == "fisica" and vel > 0.8:
		Sons.tocar("boing", clamp(vel / 6.0, 0.4, 1.0))
		cam.tremer(0.012, 0.15)


func _som_maquina(nome: String) -> void:
	if estado == E.ATRACAO or demo:
		return
	match nome:
		"varrer":
			Sons.tocar("whoosh", 0.45, 0.7)
		"mesa":
			Sons.tocar("whoosh", 0.25, 1.3)
		"pousar":
			Sons.tocar("pinos_queda", 0.3, 1.25)
			Sons.tocar("pop", 0.4, 0.9)
		"barra":
			Sons.tocar("tique", 0.35, 0.7)


func _som_personagem(nome: String) -> void:
	match nome:
		"passo":
			Sons.tocar("tique", 0.25, randf_range(0.8, 1.0))
		"palma":
			Sons.tocar("pop", 0.6, randf_range(1.1, 1.3))
		"jato":
			Sons.tocar("start", 0.7, 0.9)


# ================================================================ utilidades
## Interrompe o que estiver acontecendo (demo, replay, câmera lenta...).
func _limpar() -> void:
	_replay_ativo = false
	if maquina:
		maquina.instantaneo()
	if pinos:
		pinos.interpolar(true)
	_gravando = false
	_parar_lenta()
	Sons.rolando(false)
	mundo.acender_pista(false)
	mundo.lampadas(0)
	bola.acender(0.0)
	bola.fogo(false)
	bola.guardar()
	hud.modo_replay(false)
	hud.inatividade(false)
	hud.foto_tela(false)
	Fotos.desligar()
	mundo.podios(false)
	_modal_inativo = 0.0
	hud.marca(false, true)
	for nome in personagens:
		var p: Personagem = personagens[nome]
		p.visible = true
		p.ocioso(false)
		p.jatos(false)
		p.destaque(0.0)
		p.olhar_alvo = null
		p.segurar_bola(false)


## Segurar um botão 10 s abre a configuração dos botões — só na atração.
func pode_configurar() -> bool:
	return estado == E.ATRACAO or estado == E.ABERTURA


func _novo_seq() -> int:
	_seq += 1
	_pular = false
	return _seq


## Espera `t` segundos (de tela, mesmo em câmera lenta); volta false se a
## sequência foi cancelada. pulavel: um sensor acionado encurta a espera.
func _esperar(t: float, s: int, pulavel := true) -> bool:
	var passou := 0.0
	while passou < t:
		await get_tree().process_frame
		if s != _seq:
			return false
		passou += get_process_delta_time() / maxf(Engine.time_scale, 0.01)
		if pulavel and _pular:
			_pular = false
			break
	return s == _seq


## RODAR LISO: a cada 2,5 s mede os quadros por segundo de verdade (relógio,
## não o tempo do jogo). Abaixo de ~52 duas vezes seguidas, a imagem 3D
## fica um pouco menor (até 60%); se ainda assim não der, e a qualidade for
## "auto", desce um nível (alta -> média -> baixa). Não volta a subir no
## meio do jogo (nada de imagem "pulando").
func _medir_fps(_delta: float) -> void:
	if not _adaptar:
		return
	var agora := Time.get_ticks_msec()
	if _fps_t0 == 0 or estado == E.ABERTURA:
		_fps_t0 = agora
		_fps_q = Engine.get_process_frames()
		return
	if agora - _fps_t0 < 2500:
		return
	var fps := float(Engine.get_process_frames() - _fps_q) * 1000.0 / float(agora - _fps_t0)
	_fps_t0 = agora
	_fps_q = Engine.get_process_frames()
	var hz := DisplayServer.screen_get_refresh_rate()
	var alvo := clampf(hz if hz > 0.0 else 60.0, 30.0, 60.0)
	if fps >= alvo * 0.87:
		_fps_ruins = 0
		return
	_fps_ruins += 1
	if _fps_ruins < 2:
		return
	_fps_ruins = 0
	if _fator > 0.65:
		_fator = maxf(0.6, _fator - 0.1)
		_tela_mudou(Tela.tamanho())
		print("Imagem 3D menor: %d%% (%d quadros/s)" % [int(_fator * 100), int(fps)])
	elif str(Ajustes.valor("video", "qualidade")) == "auto" and _qualidade != "baixa":
		_qualidade = "media" if _qualidade == "alta" else "baixa"
		_fator = 1.0
		mundo.aplicar_qualidade(_qualidade)
		_qualidade_viewport()
		_tela_mudou(Tela.tamanho())
		print("Qualidade automática: ", _qualidade, " (", int(fps), " quadros/s)")
