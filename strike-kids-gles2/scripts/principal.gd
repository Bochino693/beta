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

enum E { ABERTURA, ATRACAO, JOGADORES, PERSONAGEM, PRONTO, ARREMESSO, ROLANDO, RESULTADO, REPLAY, FIM, DEMO, FOTO, TESTE, OPERADOR }

const Z_INICIO := 3.15
const X_MAO := 0.28            # a mão direita fica 0,28 m à direita do corpo
const MESMA_BOLA_MS := 1200
const VALIDADE_PENDENTE_MS := 10000
## menus que abrem POR CIMA do jogo pausado (nada é desmontado)
const CENA_OPERADOR := preload("res://cenas/operador.tscn")
const CENA_BOTOES := preload("res://cenas/configuracao_botoes.tscn")
## tempo da tela "QUANTOS VÃO JOGAR?" (START de novo dentro dele = 2 jogadores)
const TEMPO_JOGADORES := 4.0
## pódios da escolha do personagem e da foto (Bob à esquerda, Mia à direita)
const PODIOS := [Vector3(-0.62, 0, 2.5), Vector3(0.62, 0, 2.5)]
## a vista da espera: a pista de frente, como a criança vê da máquina
const POS_PISTA := Vector3(0.0, 1.05, 2.2)
const ALVO_PISTA := Vector3(0.0, 0.18, Medidas.Z_PINO1 + 0.6)

var estado = E.ABERTURA
## DESENHO DIRETO NA TELA (o normal): o 3D e a interface vão direto para a
## tela da TV, numa passada só, na resolução da TV e com o antisserrilhado
## 4x da própria tela (tools/android/TelaNitida). Na Mali-400/450 cada
## passada de tela inteira custa caro (a placa tem pouca memória rápida):
## com o 3D numa imagem separada, o quadro passava por quatro — o 3D, a
## cópia do antisserrilhado, a imagem com a interface e a cópia final para
## a TV — e o 3D ainda tinha de descer para 720-864 px (imagem fosca).
## Modo "imagem" (o compatível, no menu do operador): o 3D numa imagem
## separada (vp), com a resolução automática de 720 a 1080 px.
var _direto := true
var vp: Viewport
## onde fica tudo o que é 3D (a vp, ou o nó Mundo3D no desenho direto)
var raiz_3d: Node
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
var _em_pe_antes: Array = []
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
var _replay_alvo: Spatial
var _replay_rastro := 0.0
## câmera lenta em andamento (no relógio de verdade): escala, quanto dura
## (segundos de verdade) e quando começou (ms); < 0 = parada
var _lenta_escala := 1.0
var _lenta_dur := 0.0
var _lenta_t0 := -1
## passos da física por segundo (o do project.godot, lido ao abrir); a câmera
## lenta só diminui quantos passos acontecem por segundo, nunca o tamanho
var _passos_fisica := 60
## VELOCIDADE DO JOGO (menu do operador): 1,3 = tudo 30% mais rápido que o
## tempo real — bola, pinos, bichinhos, câmera e as esperas entre as jogadas
var _velocidade := 1.0
var _escolha_n := 1
var _escolha_t := 0.0
var _destaque := 0
var _fim_t := 0.0
var _demo_t := 0.0
var _camera_t := 0.0
var _demo_vez := 0
var _ultimo_som_pino := 0
## as fases (cenários) de cada rodada desta partida, sorteadas no START
var _temas_partida: Array = []
var _temas_prontos := false
## a roupinha do Bob e da Mia em cada fase (tools/modelos/roupas.py)
const ROUPA_DO_TEMA := {"mar": "pirata", "dinos": "dino", "espaco": "astronauta", "parque": "parque"}
var _qualidade := "media"
## resolução da imagem 3D: fator (2/3 a 100%) sobre o LADO_3D — automático
## (desce se a máquina não segura 60 quadros e VOLTA A SUBIR quando sobra
## folga) ou travado pelo operador ("Nitidez do 3D" no menu)
var _fator := 1.0
var _adaptar := true
var _fps_t0 := 0
var _fps_q := 0
var _fps_ruins := 0
var _fps_bons := 0
var _teto := 1.0            # fator que já se mostrou pesado demais...
var _teto_ate := 0          # ...até esta hora (ms): não tenta subir acima dele
var _fator_salvar := false  # fator novo a gravar (na atração: gravar no meio do jogo trava)
var _qualidade_salvar := false  # idem, a qualidade que o automático escolheu
## RITMO DOS QUADROS (para achar travadinhas, não só a média): quadros que
## passaram do tempo e, no PC, quanto a placa de vídeo levou para desenhar
var _q_ultimo := 0
var _q_lentos := 0
var _gpu_ms := 0.0
var _gpu_n := 0
var _mede_placa := false
var _alvo_qps := 60.0       # quadros por segundo da tela (lido a cada medida, não a cada quadro)
## QUADROS POR SEGUNDO ("Quadros por segundo" no menu): 60, ou 30 TRAVADOS
## na batida da TV. A TV Box que não segura 60 na hora da jogada (o
## processador: física das batidas, bichinhos, desenhos) mostrava 40-55
## quadros desiguais — a imagem "engasga" mesmo com a média boa. Travado
## em 30 (cada quadro na tela por 2 batidas da TV, o vSyncCount = 2 do
## Unity; plugin StrikeSerial, QuadrosDaTv.java), o movimento fica
## uniforme do começo ao fim e a física (interpolada) é a mesma.
## Automático: começa em 60 e, se em dois trechos seguidos de 10 s de
## jogada mais de 10% dos quadros atrasarem, trava em 30 (e guarda).
const QPS_JANELA := 600
var _qps := 60
var _qps_auto := false
var _qj_ultimo := 0
var _qj_quadros := 0
var _qj_atrasos := 0
var _qj_ruins := 0
## troca de resolução (ou de qualidade) decidida, esperando um clarão de
## tela para acontecer: refazer as imagens da placa de vídeo dá um tranco,
## e escondido no clarão branco ninguém vê
var _fator_pendente := -1.0
var _qualidade_pendente := ""
var _mouse_parado := 0.0
## menu do operador / configuração dos botões aberto por cima do jogo
var _menu: Control = null
## o 3D está parado atrás do modal de jogadores (_congelar_3d)
var _parado_3d := false
## MSAA conferido na abertura (algumas placas e drivers de PC devolvem a
## imagem 3D PRETA com o MSAA da OpenGL ES 2.0): quadros 3D já desenhados
## e se ele precisou ser desligado
var _quadros_3d := 0
var _msaa_quebrado := false
var _camada_menu: CanvasLayer
var _antes_menu := {}
var _medidor_antes := false
## preparando os desenhos por trás da capa de carregamento (aquecer.gd): a
## abertura e os controles esperam
var _preparando := true
## FÔLEGO DA FÍSICA (máquina fraca): quando a jogada pesa e os quadros
## demoram, o Godot faz cada vez mais passos de física por quadro (até 8)
## para alcançar o relógio — e cada quadro demora ainda mais: a jogada
## engasga. Nas jogadas, se a física está tomando boa parte do quadro, os
## passos ficam em no máximo PASSOS_MAX por quadro: numa máquina que não dá
## conta a jogada anda um pouquinho mais devagar, mas lisa; com folga, volta
## sozinho ao normal (no PC e numa TV Box que segura 60 quadros, nada muda).
## O passo da física continua o mesmo (o da tabela de jogadas).
const PASSOS_MAX := 4.0
var _folego := 1.0
var _quadro_us := 0
var _quadro_med := 1.0 / 60.0
var _fis_ini_us := 0
var _fis_med := 0.0

## Lado menor da IMAGEM 3D, em pixels, em cada qualidade (nunca maior que a
## própria tela), vezes o fator automático (de 2/3 a 1). Edição OpenGL ES
## 2.0 (Mali-400/450): na TV Box o 3D vai de 720 px (o mínimo) até a
## resolução da tela, 1080, com antisserrilhado 4x (quase de graça nessa
## placa): o fator sobe sozinho enquanto a placa segura 60 quadros e
## desce se não segurar. Esticar 720 até 1080 deixava a imagem fosca.
const LADO_3D := {"alta": 1080, "media": 1080, "baixa": 720}
const FATOR_MIN := 0.667
## a primeira vez numa TV Box (antes de medir): começa no meio (864 px)
const FATOR_INICIAL_TV := 0.8


func _ready() -> void:
	randomize()
	_passos_fisica = int(Compat.config("physics/common/physics_fps", 60))
	_velocidade = Ajustes.velocidade()
	_ritmo(1.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_qualidade = _qualidade_escolhida()
	Materiais.definir_contornos(_qualidade != "baixa")
	_resolucao_da_tv()
	_qps_do_operador()
	_direto = _desenho_direto()
	_ler_nitidez()
	_montar_3d()
	hud = Hud.new()
	add_child(hud)
	hud.montar(null if _direto else vp.get_texture())
	medidor = Medidor.new(self)
	hud.add_child(medidor)
	if OS.get_cmdline_args().has("--medidor"):
		medidor.mostrar(true)
	# (testes) roda o TESTE DE DESEMPENHO do menu do operador logo depois da abertura
	if OS.get_cmdline_args().has("--teste-desempenho"):
		Ajustes.definir("video", "testar", true)
	# prepara os desenhos de tudo por trás de uma capa igual à imagem de
	# abertura da TV Box; a abertura começa quando terminar
	var aq := Aquecer.new()
	add_child(aq)
	aq.preparar(vp if vp else get_viewport(), hud, efeitos.materiais(), self)
	aq.connect("pronto", self, "_preparado", [], CONNECT_ONESHOT)
	# a tela do jogo (3D e interface) fica parada e escondida enquanto as
	# amostras compilam aos poucos (desenhada já no 1º quadro, compilava
	# tudo de uma vez); volta no ensaio geral
	_mostrar_3d(false)
	hud.visible = false
	# a tabela de jogadas (quase 4 mil linhas): lida agora, com a imagem de
	# abertura na tela, e não na primeira bola
	Jogada.preparar()
	hud.connect("toque_sensor", self, "_jogada_recebida")
	# o aviso "marque Sempre abrir / toque em Permitir" antes das janelas do Android
	ArduinoBridge.connect("janela_android", hud, "aviso_android")
	Fotos.connect("janela_android", hud, "aviso_android")
	Tela.connect("mudou", self, "_tela_mudou")
	_tela_mudou(Tela.tamanho())
	ArduinoBridge.send_led("MENU")
	_camada_menu = CanvasLayer.new()
	_camada_menu.layer = 20
	_camada_menu.pause_mode = Node.PAUSE_MODE_PROCESS
	add_child(_camada_menu)
	_ligar_roteiro_de_teste()


func _preparado() -> void:
	_preparando = false
	# (o ensaio geral já ligou; garantido, se a preparação acabou sem ele)
	_mostrar_3d(true)
	hud.visible = true
	_abertura()


## ENSAIO GERAL da preparação (aquecer.gd), por baixo da capa: a tela do
## jogo volta a ser desenhada e aparece, de verdade e por um instante, tudo
## o que tem desenho próprio e só viria depois — os 4 cenários, a bola de
## fogo com o rastro, estrelas, confete, poeira, fogos, pinos tontos, os
## jatos dos bichinhos e a logo (hud). Fase 0 começa, 1 metade, 2 limpa (a
## abertura arruma o resto).
func ensaio(fase: int) -> void:
	hud.ensaio(fase)
	match fase:
		0:
			_mostrar_3d(true)
			hud.visible = true
			var alvo := Vector3(0.0, 0.3, -1.2)
			cam.corte(Vector3(0.0, 1.1, 1.8), alvo, 50, 50)
			bola.vestir("bob")
			bola.fogo(true)
			bola.ensaio(Vector3(0.1, Bola.RAIO, -0.8))
			efeitos.estrelas(alvo, 8)
			efeitos.poeira(alvo, 0.6)
			efeitos.puf(alvo)
			efeitos.confete(alvo + Vector3(0, 0.6, 0), 0.8, 16)
			efeitos.fogos(alvo + Vector3(0, 0.8, 0), 1)
			pinos.pino(1).ficar_tonto()
			for nome in personagens:
				(personagens[nome] as Personagem).jatos(true)
			_ensaiar_cenarios()
		2:
			bola.fogo(false)
			bola.guardar()
			efeitos.limpar()
			pinos.repor_todos()
			for nome in personagens:
				(personagens[nome] as Personagem).jatos(false)


## Cada cenário aparece por dois quadros (as partículas e o céu de cada um).
func _ensaiar_cenarios() -> void:
	for t in Temas.ORDEM:
		mundo.aplicar_tema(t)
		for i in 2:
			yield(get_tree(), "idle_frame")
		if not _preparando:
			return
	mundo.aplicar_tema(Temas.ORDEM[0])


## Qualidade gráfica valendo: a do operador (ou STRIKE_QUALIDADE nos
## testes); "auto" = a medida pelo TESTE DE DESEMPENHO, ou alta no PC e
## média na TV Box.
func _qualidade_escolhida() -> String:
	var q := str(Ajustes.valor("video", "qualidade"))
	if OS.has_environment("STRIKE_QUALIDADE"):
		q = OS.get_environment("STRIKE_QUALIDADE")
	if q == "auto":
		if _qualidade_salvar:
			return _qualidade   # o automático acabou de escolher (grava na tela de espera)
		var medida := str(Ajustes.valor("video", "qualidade_auto"))
		if medida in ["alta", "media", "baixa"]:
			q = medida
		else:
			q = _qualidade_inicial_pc() if OS.get_name() != "Android" else "media"
	return q


## Primeira vez no PC (antes de o jogo medir a máquina): placa de vídeo
## integrada (Intel, AMD "Radeon Graphics" do processador) começa na MÉDIA
## — sem o brilho (glow) e com o 3D até 1080 —, placa dedicada na ALTA. O
## automático ajusta daí (e guarda o que escolheu).
func _qualidade_inicial_pc() -> String:
	var nome := VisualServer.get_video_adapter_name().to_lower()
	var marca := VisualServer.get_video_adapter_vendor().to_lower()
	if "intel" in marca or "intel" in nome:
		return "media"
	var amd := marca.begins_with("ati") or "amd" in marca or "advanced micro devices" in marca or "radeon" in nome
	if amd and not " rx " in nome + " " and ("radeon(tm) graphics" in nome or "radeon graphics" in nome or
			"vega 3" in nome or "vega 6" in nome or "vega 8" in nome or "vega 10" in nome or "vega 11" in nome):
		return "media"
	return "alta"


## NITIDEZ: automática (começa do último fator bom desta máquina) ou fixa.
func _ler_nitidez() -> void:
	var nitidez := str(Ajustes.valor("video", "nitidez"))
	_adaptar = nitidez == "auto"
	if _adaptar:
		var guardado := float(Ajustes.valor("video", "fator_1080"))
		if guardado <= 0.0:
			guardado = FATOR_INICIAL_TV if OS.get_name() == "Android" else 1.0
		_fator = clamp(guardado, FATOR_MIN, 1.0)
	else:
		_fator = clamp(float(nitidez.trim_suffix("%")) / 100.0, FATOR_MIN, 1.0)
	for a in OS.get_cmdline_args():
		# testes e vídeos: resolução fixa e cheia (a máquina de teste é lenta)
		if a.begins_with("--roteiro") or a.begins_with("--video") or a.begins_with("--instantes") or a.begins_with("--replay-teste"):
			_adaptar = false
			_fator = 1.0
	if _direto:
		# o 3D sai na resolução da própria tela (o automático só mexe na qualidade)
		_fator = 1.0


## Teste automático (PC): godot --path . -- --roteiro=pasta
func _ligar_roteiro_de_teste() -> void:
	if OS.get_cmdline_args().has("--desempenho") and ResourceLoader.exists("res://tools/testes/desempenho.gd"):
		add_child(load("res://tools/testes/desempenho.gd").new())
	if OS.get_cmdline_args().has("--benchmark") and ResourceLoader.exists("res://tools/testes/benchmark.gd"):
		add_child(load("res://tools/testes/benchmark.gd").new())
		return
	for a in OS.get_cmdline_args():
		if a.begins_with("--replay-teste") and ResourceLoader.exists("res://tools/testes/replay_teste.gd"):
			add_child(load("res://tools/testes/replay_teste.gd").new())
		if a.begins_with("--glifos") and ResourceLoader.exists("res://tools/testes/glifos.gd"):
			add_child(load("res://tools/testes/glifos.gd").new())
	for a in OS.get_cmdline_args():
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
	var r := get_tree().root
	# no direto o 3D vai no mundo da própria tela (a janela): o Godot o
	# desenha antes da interface, na mesma passada; com a imagem 3D
	# separada, a janela só tem a interface
	r.usage = Viewport.USAGE_3D_NO_EFFECTS if _direto else Viewport.USAGE_2D_NO_SAMPLING
	r.hdr = false
	r.shadow_atlas_size = 0
	if not _direto:
		r.msaa = Viewport.MSAA_DISABLED
	if _na_tela_da_tv():
		# a janela é desenhada direto na tela da TV: sem a imagem dela e sem
		# a cópia final (no Godot 3 com OpenGL ES 2.0, por padrão, a janela é
		# desenhada numa imagem e copiada inteira para a tela a cada quadro)
		r.render_direct_to_screen = true
	var lugar: Node
	if _direto:
		lugar = Spatial.new()
		lugar.name = "Mundo3D"
		add_child(lugar)
	else:
		vp = Viewport.new()
		# (o Godot liga a interpolação da física em toda Viewport; aqui ela
		# fica desligada e só bola, pinos e máquina ligam — Tela.gd explica)
		vp.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		vp.own_world = true
		vp.render_target_update_mode = Viewport.UPDATE_ALWAYS
		# Godot 3: a imagem de uma Viewport sai de cabeça para baixo na tela
		# sem isto; OpenGL ES 2.0 não tem HDR
		vp.render_target_v_flip = true
		vp.hdr = false
		vp.usage = Viewport.USAGE_3D
		vp.transparent_bg = false
		vp.shadow_atlas_size = 0
		add_child(vp)
		lugar = vp
	raiz_3d = lugar
	_qualidade_viewport()
	mundo = Mundo.new()
	lugar.add_child(mundo)
	mundo.construir()
	mundo.aplicar_qualidade(_qualidade)
	pinos = Pinos.new()
	lugar.add_child(pinos)
	pinos.montar()
	pinos.connect("batida", self, "_batida_pino")
	maquina = Maquina.new()
	lugar.add_child(maquina)
	maquina.montar(pinos)
	maquina.connect("som", self, "_som_maquina")
	maquina.connect("alcapao", self, "_alcapao_maquina")
	bola = Bola.new()
	lugar.add_child(bola)
	bola.guardar()
	bola.connect("bateu", self, "_bola_bateu")
	bola.connect("recolhida", self, "_bola_recolhida")
	mundo.bola = bola
	efeitos = Efeitos.new()
	lugar.add_child(efeitos)
	for nome in ["bob", "mia"]:
		var p := Personagem.new()
		lugar.add_child(p)
		p.montar(nome)
		p.connect("soltou_bola", self, "_soltou_bola")
		p.connect("som", self, "_som_personagem")
		personagens[nome] = p
	cam = CameraCine.new()
	lugar.add_child(cam)
	cam.current = true
	_replay_alvo = Spatial.new()
	lugar.add_child(_replay_alvo)


## RESOLUÇÃO DA IMAGEM NA TV BOX ("Resolução da imagem" no menu): como os
## jogos do Unity fazem no Android, o jogo desenha numa imagem menor que a
## tela e a própria TV Box estica até a tela inteira, no hardware de vídeo
## — de graça para a placa, sem passada nenhuma a mais (plugin StrikeSerial,
## TelaDaTv.java). Automática: 720 linhas na Mali-400/450 (menos da metade
## dos pixels de 1080, com o antisserrilhado 4x da placa) e até 1080 nas
## outras (TV 4K não desenha em 4K). Vale na hora e fica guardada: das
## próximas vezes o Android já abre o jogo assim.
func _resolucao_da_tv() -> void:
	if Engine.has_singleton("StrikeSerial"):
		Engine.get_singleton("StrikeSerial").definir_tela(linhas_da_tv())


## Os quadros por segundo do menu do operador (no automático, o que ele já
## mediu nesta TV Box). Escolher 60 de propósito esquece a medida.
func _qps_do_operador() -> void:
	var q := str(Ajustes.valor("video", "qps"))
	if q == "60" and int(Ajustes.valor("video", "qps_medido")) != 0:
		Ajustes.definir("video", "qps_medido", 0)
	_qps_auto = q == "auto"
	_qj_quadros = 0
	_qj_atrasos = 0
	_qj_ruins = 0
	_definir_qps(30 if q == "30" or (_qps_auto and int(Ajustes.valor("video", "qps_medido")) == 30) else 60)


func _definir_qps(q: int) -> void:
	_qps = q
	if Engine.has_singleton("StrikeSerial"):
		# na TV Box quem segura o ritmo é a própria tela (sem o relógio do Godot)
		Engine.get_singleton("StrikeSerial").definir_quadros(1 if q >= 60 else 2)
		Engine.target_fps = 0
	else:
		Engine.target_fps = 0 if q >= 60 else q


## (automático) mede as jogadas: quadros que passaram de 1,5 vez o tempo
## de um quadro de 60.
func _medir_jogada() -> void:
	var agora := Time.get_ticks_usec()
	var antes := _qj_ultimo
	_qj_ultimo = agora
	if not _qps_auto or _qps < 60 or antes == 0 or _preparando or _menu != null:
		return
	if not estado in [E.ARREMESSO, E.ROLANDO, E.RESULTADO, E.DEMO]:
		return
	_qj_quadros += 1
	if agora - antes > 25000:
		_qj_atrasos += 1
	if _qj_quadros < QPS_JANELA:
		return
	var parte := float(_qj_atrasos) / float(_qj_quadros)
	_qj_ruins = _qj_ruins + 1 if parte > 0.1 else 0
	_qj_quadros = 0
	_qj_atrasos = 0
	if _qj_ruins >= 2:
		_definir_qps(30)
		Ajustes.definir("video", "qps_medido", 30)
		print("Quadros automáticos: 30 travados (%d%% dos quadros atrasados a 60)" % int(parte * 100.0))


## Quantas linhas a imagem do jogo tem na TV Box (0 = as da própria tela).
func linhas_da_tv() -> int:
	match str(Ajustes.valor("video", "resolucao")):
		"720p":
			return 720
		"900p":
			return 900
		"1080p":
			return 1080
		"tela":
			return 0
	var placa := VisualServer.get_video_adapter_name().to_lower()
	for utgard in ["mali-4", "mali-3", "mali-2"]:
		if utgard in placa:
			return 720
	return 1080


## Desenho direto ou com a imagem 3D separada: o do operador ("Desenho da
## tela" no menu; STRIKE_DESENHO nos testes). Automático = direto, a não
## ser que o jogo já tenha visto esta máquina sem fôlego nele, mesmo na
## qualidade baixa (então liga na imagem separada, que desce até 720 px).
func _desenho_direto() -> bool:
	var d := str(Ajustes.valor("video", "desenho"))
	if OS.has_environment("STRIKE_DESENHO"):
		d = OS.get_environment("STRIKE_DESENHO")
	if d == "auto":
		d = "imagem" if str(Ajustes.valor("video", "desenho_medido")) == "imagem" else "direto"
	return d != "imagem"


## Na TV Box o desenho direto vai mesmo direto para a tela (sem a imagem
## da janela). No PC (testes), a janela continua com a imagem dela: as
## fotos dos testes são tiradas dela (STRIKE_TELA_DIRETA=1: como na TV Box).
func _na_tela_da_tv() -> bool:
	return OS.get_name() == "Android" or OS.has_environment("STRIKE_TELA_DIRETA")


## O 3D aparece na tela ou não: na imagem separada, ela para de ser
## desenhada (a última fica na tela); no direto, a câmera sai de cena e
## nada de 3D é desenhado.
func _mostrar_3d(sim: bool) -> void:
	if _direto:
		if sim:
			cam.make_current()
		else:
			cam.clear_current(false)
	else:
		vp.render_target_update_mode = Viewport.UPDATE_ALWAYS if sim else Viewport.UPDATE_DISABLED


## Tamanho da imagem 3D em pixels (no direto, o da própria tela).
func tamanho_3d() -> Vector2:
	return Tela.tamanho_fisico() if _direto else vp.size


## (Testes no PC) a imagem 3D deste quadro: a da imagem separada ou, no
## direto, a da janela (quem pede esconde a interface antes).
func foto_3d() -> Image:
	if vp:
		return vp.get_texture().get_data()
	var img := get_viewport().get_texture().get_data()
	img.flip_y()
	return img


## (Testes no PC) sem antisserrilhado: o llvmpipe devolve a imagem preta
## com o MSAA da OpenGL ES 2.0.
func sem_msaa() -> void:
	_msaa_quebrado = true
	_qualidade_viewport()


## Para o painel de desempenho e o teste: como o 3D está sendo desenhado.
func descricao_3d() -> String:
	var t := tamanho_3d()
	if _direto:
		var tv := ""
		if Engine.has_singleton("StrikeSerial"):
			var partes: PoolStringArray = str(Engine.get_singleton("StrikeSerial").tela()).split("|")
			if partes.size() == 2 and partes[0] != partes[1]:
				tv = " (a TV Box estica até %s)" % partes[0]
		return "3D direto na tela %dx%d%s" % [t.x, t.y, tv]
	return "3D em imagem %dx%d (%d%%)" % [t.x, t.y, int(round(_fator * 100.0))]


## Antisserrilhado conforme a qualidade: MSAA 4x (na Mali-400/450 o 4x é
## o modo da própria placa, resolvido dentro dela: bordas lisas quase de
## graça); na baixa, 2x. No desenho direto na TV Box é o da própria tela
## (4x, escolhido ao abrir o jogo: tools/android/TelaNitida); no PC, o da
## imagem da janela.
func _qualidade_viewport() -> void:
	var msaa: int = Viewport.MSAA_2X if _qualidade == "baixa" else Viewport.MSAA_4X
	if _msaa_quebrado:
		msaa = Viewport.MSAA_DISABLED
	if not _direto:
		vp.msaa = msaa
	elif not _na_tela_da_tv():
		# no PC com desenho por software (llvmpipe, dos testes) o MSAA da
		# janela não chega na imagem: nem tenta
		if "llvmpipe" in VisualServer.get_video_adapter_name().to_lower():
			msaa = Viewport.MSAA_DISABLED
		# (Godot 3: `get_tree().root.msaa = ...` tentaria regravar o root)
		var janela := get_tree().root
		janela.msaa = msaa


## Uma vez, na abertura (depois de alguns quadros 3D): a imagem 3D veio
## inteira PRETA? Então o MSAA não funciona nesta placa — desliga (o jogo
## segue com a imagem certa, só sem o antisserrilhado). (Só com a imagem
## 3D separada: no direto, a imagem da tela já vem com a interface.)
func _conferir_msaa() -> void:
	if _direto or _preparando or _quadros_3d < 0 or _parado_3d or _menu != null or vp.msaa == Viewport.MSAA_DISABLED:
		return
	_quadros_3d += 1
	if _quadros_3d < 12:
		return
	_quadros_3d = -1
	var img := vp.get_texture().get_data()
	if img == null or img.is_empty():
		return
	img.lock()
	var acesos := 0
	for i in 8:
		for j in 8:
			var c := img.get_pixel(int((i + 0.5) * img.get_width() / 8.0), int((j + 0.5) * img.get_height() / 8.0))
			if c.r + c.g + c.b > 0.004:
				acesos += 1
	img.unlock()
	if acesos == 0:
		_msaa_quebrado = true
		vp.msaa = Viewport.MSAA_DISABLED
		print("MSAA desligado: com ele a placa de vídeo devolveu a imagem 3D preta")


## Tamanho da imagem 3D: o lado menor da tela, limitado pelo LADO_3D da
## qualidade e pelo fator automático; a imagem é esticada até a tela.
func _tela_mudou(_t: Vector2) -> void:
	if _direto:
		# o 3D na resolução da própria tela; com a TV de pé ligada deitada,
		# a câmera gira a imagem (a interface gira pelo Tela.gd)
		cam.giro_tela = Tela.giro
		if hud:
			hud.layout()
		return
	var f: Vector2 = Tela.tamanho_fisico()
	var menor: float = min(f.x, f.y)
	var lado: float = min(menor, float(LADO_3D.get(_qualidade, 720))) * _fator
	var k: float = lado / max(menor, 1.0)
	vp.size = Vector2(Compat.imax(64, int(round(f.x * k))), Compat.imax(64, int(round(f.y * k))))
	if _parado_3d and _menu == null:
		# 3D parado atrás do modal: a imagem do tamanho novo sai uma vez
		vp.render_target_update_mode = Viewport.UPDATE_ONCE
	if hud:
		hud.layout()
		# imagem 3D menor que a tela, no PC: realce de bordas ao esticar
		var m := hud.tela3d.material as ShaderMaterial
		if m:
			m.set_shader_param("nitidez", 0.5 if _qualidade == "alta" and k < 0.97 else 0.0)


# ================================================================ entrada
func _input(event: InputEvent) -> void:
	if _preparando:
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo() and (event as InputEventKey).scancode == KEY_F3:
		medidor.alternar()
		return
	if event is InputEventMouseMotion:
		_mouse_parado = 0.0
		if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if ArcadeControls.eh_config(event) or _tecla_menu(event):
		get_tree().set_input_as_handled()
		call_deferred("abrir_menu", CENA_OPERADOR)
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
				_escolha_t = min(_escolha_t, 1.1)
				Sons.tocar("selecao")
				ArduinoBridge.send_led("RED")
		E.PERSONAGEM:
			_confirmar_personagem()
		E.FIM:
			if _fim_t > 2.5 and Ajustes.pode_comecar():
				_escolher_jogadores()


func _jogada_recebida(zona: String) -> void:
	if _preparando:
		return
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
	ArduinoBridge.porta(false)
	var s := _novo_seq()
	hud.atracao(false)
	hud.mostrar_sensores(false)
	hud.mostrar_placar(false)
	mundo.aplicar_tema(Temas.ORDEM[0])
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
	if not yield(_esperar(0.5, s, false), "completed"):
		return
	# o strike da abertura entra na FRENTE da lista (que os testes e o vídeo
	# de divulgação usam para pedir os resultados deles) sem apagá-la
	Jogada.forcar().push_front(10)
	var j := Jogada.planejar("C", pinos.em_pe(), true, "facil", true)
	var origem := Vector3(j.origem_x, Bola.RAIO + 0.04, 0.35)
	var dir := Vector3(j.alvo_x, Bola.RAIO, Medidas.Z_PINO1) - origem
	dir.y = 0.0
	bola.lancar(origem, dir.normalized() * j.velocidade, j.efeito)
	pinos.soltar_todos()
	Sons.tocar("whoosh", 0.6)
	cam.seguir(bola, Vector3(0.14, 0.3, 1.3), Vector3(0.0, 0.06, -3.0), 28, 32, 7.0)
	var t := 0.0
	while bola.global_translation.z > Medidas.Z_PINO1 + 0.32 and t < 3.0:
		yield(get_tree(), "idle_frame")
		if s != _seq:
			Sons.rolando(false)
			return
		t += get_process_delta_time()
		Sons.rolando(true, bola.velocidade())
		mundo.bola_z = -bola.global_translation.z
		# os pinos fazem cara de medo quando a bola chega
		if bola.global_translation.z < Medidas.Z_PINO1 + 3.3:
			pinos.susto(bola.global_translation)
	Sons.rolando(false)
	# 2) ...STRIKE em câmera lenta, vista de lado (de cima da canaleta, por
	# dentro das paredes da caçapa)
	cam.corte(Vector3(0.6, 0.36, Medidas.Z_PINO1 + 1.2), Vector3(-0.12, 0.27, Medidas.Z_PINO1 - 0.45), 40, 44)
	cam.tremer(0.05, 0.4)
	Sons.tocar("pinos_queda", 0.9)
	_camera_lenta(0.3, 1.3)
	if not yield(_esperar(1.0, s, false), "completed"):
		return
	# 3) LAZER & SPORT GAMES apresenta (por cima do strike)
	Sons.tocar("strike", 0.75)
	hud.flash(Color.white, 0.45, 0.3)
	hud.marca(true, false, true)
	_atrasado_som(0.1, "brilho")
	_atrasado_som(0.6, "pop")
	efeitos.estrelas(Vector3(0, 0.6, Medidas.Z_PINO1 - 0.3), 30)
	cam.ir(Vector3(0.0, 1.25, Medidas.Z_PINO1 + 4.6), Vector3(0.0, 1.0, Medidas.Z_PINO1 - 1.0), 46, 44, 0.8)
	if not yield(_esperar(2.7, s, false), "completed"):
		return
	hud.marca(false)
	hud.tarjas(false)
	# 4) voo até a atração: pinos de pé, os bichinhos chegam, STRIKE KIDS
	hud.flash(Color.white, 0.6, 0.35)
	bola.guardar()
	bola.vestir("bob")
	mundo.bola_z = 100.0
	maquina.instantaneo()
	for nome in personagens:
		(personagens[nome] as Personagem).visible = true
	_posicionar_atracao()
	Sons.musica("musica_menu")
	cam.trilho([
		[Vector3(0, 4, Medidas.Z_PINO1 + 5.0), Vector3(0, 0.4, Medidas.Z_PINO1), 0.0],
		[Vector3(0.0, 3.3, 0.6), Vector3(0, 0.6, -4), 1.3],
		[Vector3(0, 1.4, 5.6), Vector3(0, 0.75, 1.6), 1.2],
	], 52, 40)
	if not yield(_esperar(2.4, s), "completed"):
		return
	hud.flash(Color.white, 0.6)
	Sons.tocar("brilho")
	_atracao()
	_no_clarao()
	if bool(Ajustes.valor("video", "testar")):
		Ajustes.definir("video", "testar", false)
		_teste_desempenho()


## TESTE DE DESEMPENHO (pedido no menu do operador): 20 s pelas vistas mais
## pesadas; mostra a média de quadros por segundo e a qualidade recomendada.
func _teste_desempenho() -> void:
	estado = E.TESTE
	ArduinoBridge.porta(false)
	_novo_seq()
	hud.atracao(false)
	_posicionar_atracao()
	var r = medidor.testar()
	if r is GDScriptFunctionState:
		r = yield(r, "completed")
	if r.empty():
		return   # o menu do operador abriu no meio do teste
	_resultado_teste = r["cartaz"]
	mundo.aplicar_tema(Temas.ORDEM[0])


func _atracao() -> void:
	estado = E.ATRACAO
	if _qualidade_salvar:
		_qualidade_salvar = false
		if str(Ajustes.valor("video", "qualidade")) == "auto":
			Ajustes.definir("video", "qualidade_auto", _qualidade)
	if _fator_salvar:
		_fator_salvar = false
		Ajustes.definir("video", "fator_1080", stepify(_fator, 0.01))
	# a porta das bolas fica FECHADA na espera; o Arduino pode pedir a
	# permissão USB aqui (janela do Android só na espera)
	ArduinoBridge.porta(false)
	ArduinoBridge.na_espera(true)
	demo = false
	Sons.mudo_demo = false
	Sons.atualizar_volume()
	_novo_seq()
	_limpar()
	_roupa_de_sempre()
	hud.marca(false, true)
	hud.tela_fim(false)
	hud.jogadores(false)
	_congelar_3d(false)
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
	_camera_t = 0.0
	Fotos.desligar(0.5)
	Fotos.na_espera()


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
	if not (estado in [E.ATRACAO, E.DEMO, E.ABERTURA]):
		return
	var r1 := Ajustes.recorde(1)
	var txt := ""
	if int(r1.get("pontos", 0)) > 0:
		txt = "RECORDE: %d PONTOS (%s)" % [int(r1["pontos"]), str(r1.get("quem", "")).to_upper()]
	var cred := "MODO LIVRE" if Ajustes.modo_livre() else "CRÉDITOS: %d" % Ajustes.creditos
	hud.atracao(true, txt, cred, Fotos.foto_recorde(1), Compat.fatia(Classificacao.lista(), 0, 3))


# ================================================================ escolha
func _escolher_jogadores() -> void:
	estado = E.JOGADORES
	# START valeu: a porta das bolas ABRE (a criança já escolhe o amigo
	# rolando a bola)
	ArduinoBridge.porta(true)
	ArduinoBridge.na_espera(false)
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
	_congelar_3d(true)
	# a câmera pode ter sido ligada depois: procura de novo e já liga, para
	# a imagem estar pronta quando chegar o "SORRIA!"
	Fotos.preparar()
	_escolha_n = 1
	_escolha_t = TEMPO_JOGADORES
	ArduinoBridge.send_led("MENU")
	bola.guardar()
	_parar_lenta()
	# escolha e fotos com a roupa de sempre; as fases já saem no sorteio e a
	# roupinha da 1ª vai carregando em segundo plano enquanto escolhem
	_roupa_de_sempre()
	_sortear_temas(Ajustes.rodadas())
	_temas_prontos = true
	_pedir_roupas(_temas_partida[0])


func _confirmar_jogadores() -> void:
	hud.jogadores(false)
	_congelar_3d(false)
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
	(personagens["bob"] as Personagem).posicionar(PODIOS[0] + Vector3(0, Medidas.ALTURA_PODIO, 0), 0)
	(personagens["mia"] as Personagem).posicionar(PODIOS[1] + Vector3(0, Medidas.ALTURA_PODIO, 0), 0)


## Frente de cada pódio na tela (as placas com os nomes ficam logo abaixo).
func _pes_na_tela() -> Array:
	var r := []
	for p in PODIOS:
		r.append(na_tela(p + Vector3(0, 0, 0.45)))
	return r


## Onde um ponto do mundo 3D aparece na tela do jogo (na medida da
## interface, já em pé se a tela é girada).
func na_tela(p: Vector3) -> Vector2:
	var s := cam.unproject_position(p)
	if _direto:
		return get_tree().root.global_canvas_transform.affine_inverse() * s
	return s * hud.rect_size / Vector2(vp.size)


func _atrasado_som(t: float, nome: String) -> void:
	get_tree().create_timer(t).connect("timeout", Sons, "tocar", [nome])


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
	hud.flash(Color.white, 0.4)
	efeitos.estrelas((personagens[escolhido] as Personagem).global_translation + Vector3(0, 1.2, 0), 26)
	if not yield(_esperar(1.5, s), "completed"):
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
	if not _temas_prontos or _temas_partida.size() != Compat.imax(Ajustes.rodadas(), 1):
		_sortear_temas(Ajustes.rodadas())
		_pedir_roupas(_temas_partida[0])
	_temas_prontos = false
	Fotos.limpar_partida()
	# uma foto por jogador (1 jogador = 1 foto, 2 jogadores = 2 fotos)
	if Fotos.pode_fotografar():
		if not yield(_sessao_de_fotos(lista), "completed"):
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
		if not yield(_esperar(1.9, s, false, false), "completed"):
			return false
		for n in [3, 2, 1]:
			hud.foto_contagem(n)
			Sons.tocar("tique", 0.9, 1.0 + (3 - n) * 0.15)
			if not yield(_esperar(0.85, s, false, false), "completed"):
				return false
		hud.foto_contagem(0)
		hud.flash(Color.white, 0.95, 0.45)
		Sons.tocar("brilho")
		Sons.tocar("pop", 0.8, 0.8)
		var foto = Fotos.tirar("j%d" % i)
		if foto is GDScriptFunctionState:
			foto = yield(foto, "completed")
		if s != _seq:
			return false
		hud.foto_pronta(foto, p)
		a.tocar("feliz", 0.2, true)
		a.expressao("empolgado")
		if not yield(_esperar(1.5, s, false), "completed"):
			return false
	hud.foto_tela(false)
	Fotos.desligar()
	mundo.podios(false)
	return true


## A fase (cenário) da rodada atual, do sorteio da partida.
func _tema_da_rodada() -> String:
	if _temas_partida.empty():
		return mundo.tema
	return _temas_partida[Compat.iclamp(placar.rodada_atual, 0, _temas_partida.size() - 1)]


## FASES SORTEADAS: a fase de cada rodada sai num sorteio — todas aparecem
## antes de alguma se repetir, e nunca a mesma duas rodadas seguidas.
func _sortear_temas(n: int) -> void:
	_temas_partida.clear()
	var antes := ""
	var usados := {}
	for i in Compat.imax(n, 1):
		var opcoes: Array = []
		for t in Temas.ORDEM:
			if t != antes and not usados.has(t):
				opcoes.append(t)
		if opcoes.empty():
			usados.clear()
			for t in Temas.ORDEM:
				if t != antes:
					opcoes.append(t)
		var t: String = Compat.sorteia(opcoes)
		_temas_partida.append(t)
		usados[t] = true
		antes = t


# ================================================================ roupinhas das fases
## Bob e Mia com a roupinha da fase (pirata no mar, dinossaurinho na selva,
## astronauta no espaço, boné de hélice no parque). "" = a roupa de sempre.
func _vestir(tema: String) -> void:
	var r: String = ROUPA_DO_TEMA.get(tema, "")
	for nome in personagens:
		(personagens[nome] as Personagem).trocar_roupa(r)


## Começa a carregar (em segundo plano) a roupinha de uma fase que vem aí.
func _pedir_roupas(tema: String) -> void:
	var r: String = ROUPA_DO_TEMA.get(tema, "")
	for nome in personagens:
		(personagens[nome] as Personagem).pedir_roupa(r)


## Roupa de sempre (tela de início, escolha, fotos): se alguém ainda está de
## roupinha, troca escondido num clarão; o que ficou carregado sem uso sai
## da memória.
func _roupa_de_sempre() -> void:
	var trocar := false
	for nome in personagens:
		var p: Personagem = personagens[nome]
		p.soltar_pedidos()
		if p.roupa != "":
			trocar = true
	if trocar:
		hud.flash(Color.white, 0.6, 0.35)
		_vestir("")


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
		hud.flash(Color.white, 0.95, 0.6)
		mundo.aplicar_tema(tema)
		_vestir(tema)
		# a roupinha da próxima fase já vai carregando durante esta rodada
		if placar.rodada_atual + 1 < _temas_partida.size():
			_pedir_roupas(_temas_partida[placar.rodada_atual + 1])
		_no_clarao()
		Sons.tocar("brilho")
		Sons.tocar("whoosh", 0.6)
		hud.anunciar_cenario(tema, 1.7)
		# passeio pelo cenário que termina na PISTA DE FRENTE (a vista da
		# espera): o mascote só aparece depois que a bola for jogada
		cam.trilho([
			[Vector3(-2.6, 4.6, Medidas.Z_PINO1 + 1.0), Vector3(0, 2.2, Medidas.Z_FUNDO - 3.0), 0.0],
			[Vector3(2.2, 3.4, -5.0), Vector3(0, 1.4, Medidas.Z_FUNDO), 1.4],
			[POS_PISTA, ALVO_PISTA, 1.3],
		], 34, 40)
		if not yield(_esperar(2.9, s, false), "completed"):
			return
	elif nova_rodada:
		_plano_pista(false)
	if nova_rodada:
		var artigo := "DO" if _ativo == "bob" else "DA"
		var sub := "RODADA %d" % (placar.rodada_atual + 1)
		hud.faixa(_ativo, "VEZ %s %s!" % [artigo, _ativo.to_upper()], sub, Fotos.foto("j%d" % placar.jogador_atual))
		Sons.tocar("vez")
		ArduinoBridge.send_led("BLUE" if _ativo == "bob" else "RED")
		if not yield(_esperar(1.6, s, false), "completed"):
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
		yield(get_tree().create_timer(0.35), "timeout")
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
	cam.corte(a.global_translation + Vector3(1.15, 2.05, 3.3), a.global_translation + Vector3(-0.35, 0.05, -7.0), 50, 40)
	cam.seguir(a, Vector3(1.15, 2.05, 3.3), Vector3(-0.35, 0.05, -7.0), 50, 40, 3.0)
	Sons.tocar("whoosh", 0.5)


func _soltou_bola(pos: Vector3) -> void:
	if estado != E.ARREMESSO:
		return
	var a: Personagem = personagens[_ativo]
	bola.vestir(_ativo)
	# a bola segue a linha planejada (a mesma da calibração): passa por
	# origem_x na linha de falta (z = 0,35) e vai até alvo_x nos pinos
	var z0 := min(pos.z, 0.45)
	var u := (0.35 - z0) / (0.35 - Medidas.Z_PINO1)
	var origem := Vector3(lerp(jogada.origem_x, jogada.alvo_x, u), Bola.RAIO + 0.04, z0)
	var alvo := Vector3(jogada.alvo_x, Bola.RAIO, Medidas.Z_PINO1)
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
	a.olhar_alvo = bola.global_translation
	# primeiro por cima (a câmera não atravessa o personagem), depois desce
	cam.seguir(bola, Vector3(0.5, 2.1, 3.6), Vector3(0, 0.0, -5.0), 50, 40, 3.0)
	_cam_baixa = false
	# o resto no quadro seguinte: tudo no mesmo quadro dava um tranco na TV
	# Box bem na hora em que a bola sai da mão
	_no_proximo_quadro("_depois_de_soltar", [_seq, a])


func _depois_de_soltar(s: int, a: Personagem) -> void:
	if s != _seq:
		return
	a.tocar("assistindo", 0.25)
	(personagens[_plateia] as Personagem).tocar("torcida", 0.2)
	Sons.tocar("start", 0.35, 1.4)


## A bola entrou na caçapa do fundo: barulhinho do túnel e, um pouco
## depois, ela aparece no retorno de bolas, perto de quem joga.
func _bola_recolhida() -> void:
	if estado in [E.ABERTURA, E.TESTE]:
		return
	Sons.tocar("whoosh", 0.45, 0.55)
	get_tree().create_timer(1.3).connect("timeout", self, "_bola_no_retorno", [_ativo])


func _bola_no_retorno(nome: String) -> void:
	mundo.retorno_bola(Bola.material(nome))
	Sons.tocar("pop", 0.55, 0.5)


func _process(delta: float) -> void:
	_medir_jogada()
	_medir_fps(delta)
	_folego_da_fisica()
	_andar_lenta()
	_conferir_msaa()
	# as contagens da tela andam em segundos de verdade
	var real := _delta_real()
	# PC em tela cheia: a setinha do mouse some sozinha quando ninguém mexe
	_mouse_parado += real
	if _mouse_parado > 2.5 and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	match estado:
		E.ROLANDO:
			_rolando(delta)
		E.PRONTO:
			_contar_inatividade(real)
		E.JOGADORES:
			_escolha_t -= real
			hud.jogadores(true, _escolha_n, _escolha_t / TEMPO_JOGADORES, int(ceil(_escolha_t)))
			if _escolha_t <= 0.0:
				_confirmar_jogadores()
		E.PERSONAGEM:
			_escolha_t -= real
			hud.selecao(true, _destaque, "ROLE A BOLA PARA ESCOLHER SEU AMIGO\nbola no MEIO ou START confirma   (%d)" % int(ceil(_escolha_t)), _pes_na_tela())
			if _escolha_t <= 0.0:
				_confirmar_personagem()
		E.ATRACAO:
			_demo_t += real
			# a câmera (permissão, webcam ligada depois) é conferida aqui, na espera
			_camera_t += real
			if _camera_t > 6.0:
				_camera_t = 0.0
				Fotos.na_espera()
			if bool(Ajustes.valor("jogo", "demo")) and _demo_t > 9.0:
				_demo_t = 0.0
				_jogada_demo()
		E.FIM:
			_fim_t += real
			var resta := int(ceil(16.0 - _fim_t))
			hud.fim_contagem(max(resta, 0))
			if _fim_t > 16.0:
				_atracao()
	if _replay_ativo:
		_rodar_replay(delta)
	for nome in personagens:
		var p: Personagem = personagens[nome]
		if p.olhar_alvo != null and bola.visible:
			p.olhar_alvo = bola.global_translation


func _rolando(_delta: float) -> void:
	var b := bola.global_translation
	mundo.bola_z = -b.z
	Sons.rolando(b.z > Medidas.Z_PINO1 - 0.5, bola.velocidade())
	for nome in personagens:
		(personagens[nome] as Personagem).olhar_alvo = b
	if b.z < Medidas.Z_PINO1 + 3.3:
		pinos.susto(b)
	# câmera: desce para perseguir a bola, depois vai para os pinos
	if not _cam_baixa and b.z < -2.5:
		_cam_baixa = true
		cam.seguir(bola, Vector3(0.0, 0.85, 2.5), Vector3(0, 0.05, -4.5), 52, 40, 2.8)
	if not _deck_cam and b.z < Medidas.Z_PINO1 + 4.6:
		_deck_cam = true
		cam.ir(Vector3(b.x * 0.25 + 0.32, 0.9, Medidas.Z_PINO1 + 3.0), Vector3(0, 0.16, Medidas.Z_PINO1 - 0.5), 38, 36, 3.2)
	# impacto
	if _t_impacto < 0.0 and b.z < Medidas.Z_PINO1 + 0.22 and abs(b.x) < Medidas.MEIA_LARGURA:
		_impacto(b)
	var fim := false
	if _t_impacto >= 0.0:
		var dt := _t_jogada - _t_impacto
		fim = dt > 2.8 or (dt > 1.4 and pinos.todos_parados())
	elif b.z < Medidas.Z_FIM_DECK - 0.4 or b.y < -0.5:
		fim = _t_jogada > 0.5
	if _t_jogada > 7.5:
		fim = true
	if fim:
		_finalizar_jogada()


func _impacto(b: Vector3) -> void:
	_t_impacto = _t_jogada
	var cheio := abs(b.x) < 0.2 and _em_pe_antes.size() >= 6
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
## até `escala` em 0,08 s, segura e volta ao normal em 0,3 s (a duração
## encurta junto com a velocidade do jogo).
func _camera_lenta(escala: float, dur_real: float) -> void:
	_parar_lenta()
	_lenta_escala = escala
	_lenta_dur = max(dur_real / _velocidade - 0.08, 0.0)
	_lenta_t0 = Time.get_ticks_msec()
	_andar_lenta()


## A cada quadro: em que ponto da câmera lenta estamos (relógio de verdade).
func _andar_lenta() -> void:
	if _lenta_t0 < 0:
		return
	var t := float(Time.get_ticks_msec() - _lenta_t0) / 1000.0
	var v := 1.0
	if t < 0.08:
		v = lerp(1.0, _lenta_escala, sin(t / 0.08 * PI * 0.5))
	elif t < 0.08 + _lenta_dur:
		v = _lenta_escala
	elif t < 0.38 + _lenta_dur:
		var u := (t - 0.08 - _lenta_dur) / 0.3
		v = lerp(_lenta_escala, 1.0, 1.0 - cos(u * PI * 0.5))
	else:
		_lenta_t0 = -1
	_ritmo(v)


## Ritmo do tempo SEM mudar a física: o passo da física continua sempre de
## 1/60 s (o mesmo da calibração das jogadas — o resultado não muda). O
## jogo mais rápido (velocidade 1,3) dá MAIS passos por segundo (78); a
## câmera lenta dá MENOS (0,4 = 31 por segundo) e a interpolação deixa a
## imagem lisa.
func _ritmo(v: float) -> void:
	var normal := float(_passos_fisica) * _velocidade * _folego
	var passos := Compat.iclamp(int(round(normal * v)), 12, int(round(normal)))
	Engine.iterations_per_second = passos
	Engine.time_scale = float(passos) / float(_passos_fisica)


func _parar_lenta() -> void:
	_lenta_t0 = -1
	_ritmo(1.0)


## A cada quadro: quanto o quadro e a física dele levaram (média) e, nas
## jogadas, quantos passos por quadro a máquina aguenta (ver PASSOS_MAX).
func _folego_da_fisica() -> void:
	var agora := Time.get_ticks_usec()
	var dt := 1.0 / 60.0
	if _quadro_us > 0:
		dt = clamp(float(agora - _quadro_us) / 1000000.0, 0.001, 0.25)
	_quadro_us = agora
	var fis := 0.0
	if _fis_ini_us > 0:
		fis = clamp(float(agora - _fis_ini_us) / 1000000.0, 0.0, dt)
	_fis_ini_us = 0
	_quadro_med = lerp(_quadro_med, dt, 0.15)
	_fis_med = lerp(_fis_med, fis, 0.15)
	var alvo := 1.0
	if not _preparando and estado in [E.ABERTURA, E.ARREMESSO, E.ROLANDO, E.RESULTADO]:
		var por_quadro := float(_passos_fisica) * _velocidade * _quadro_med
		if por_quadro > PASSOS_MAX and _fis_med > 0.4 * _quadro_med:
			alvo = clamp(PASSOS_MAX / por_quadro, 0.6, 1.0)
	var novo := move_toward(_folego, alvo, 0.5 * dt)
	if abs(novo - _folego) > 0.0001:
		_folego = novo
		if _lenta_t0 < 0 and _menu == null:
			_ritmo(1.0)


## O relógio da jogada anda junto com a FÍSICA (60 passos por segundo, já
## com a câmera lenta aplicada): cada quadro gravado tem o seu próprio
## instante. (Se o relógio fosse o da tela, a 60 QPS dois passos de física
## ficavam com o mesmo horário e o replay saía picotado.)
func _physics_process(delta: float) -> void:
	if _fis_ini_us == 0:
		_fis_ini_us = Time.get_ticks_usec()   # 1º passo de física do quadro
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
			mundo.lampadas(1)
			_no_proximo_quadro("_festa_strike", [s, placar.jogador_atual, _ativo])
		"spare":
			hud.flash(Color("#C9F7FF"), 0.55)
			hud.letreiro("spare", "", 1.7)
			Sons.tocar("spare")
			Sons.tocar("torcida", 0.6)
			ArduinoBridge.send_led("SPARE")
			mundo.lampadas(2)
			_no_proximo_quadro("_festa_spare", [s])
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
				efeitos.estrelas(Vector3(0, 0.5, Medidas.Z_PINO1 - 0.3), 16, 0.8)
	if not demo and int(res["pontos"]) > 0:
		hud.pontos_voando(int(res["pontos"]), placar.jogador_atual)
	if tipo == "strike":
		Ajustes.contar("strikes")
		var seguidos := int(placar.atual()["seguidos"]) if not demo else 0
		if seguidos >= 2:
			hud.sequencia(seguidos)
			get_tree().create_timer(1.0).connect("timeout", self, "_aviso_seguidos", [seguidos])
	# replay do strike
	if tipo == "strike" and bool(Ajustes.valor("jogo", "replay_strike")) and _gravacao.size() > 20:
		if not yield(_esperar(1.5, s, false), "completed"):
			return
		var rp = _replay()
		if rp is GDScriptFunctionState:
			yield(rp, "completed")
		if s != _seq:
			return
	else:
		# se sobrou pino comemorando, a câmera fica um pouco mais nos pinos
		if not yield(_esperar(1.6 if festa_pinos > 0 else 1.1, s), "completed"):
			return
	# reação do personagem (câmera bem de frente)
	var pa := a.global_translation
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
	if not yield(_esperar(espera, s), "completed"):
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
	# (o alçapão só abre se esta bola derrubou algum pino)
	if proximo == "bola":
		maquina.reposicionar(n > 0)
	else:
		maquina.rack_novo(n > 0)
	if not yield(_esperar(0.3, s, false), "completed"):
		return
	while maquina.trabalhando:
		if not yield(_esperar(0.1, s, false), "completed"):
			return
	hud.mostrar_mapa(pinos.em_pe())
	_vez(proximo == "rodada")


func _festa_strike(s: int, jogador: int, ativo: String) -> void:
	if s != _seq:
		return
	if not demo:
		var ft: Texture = Fotos.foto("j%d" % jogador)
		if ft != null:
			hud.foto_destaque(ft, Hud.COR_BOB if ativo == "bob" else Hud.COR_MIA, 1.4)
	efeitos.estrelas(Vector3(0, 0.6, Medidas.Z_PINO1 - 0.4), 40, 1.3)
	efeitos.confete(Vector3(0, 0.3, Medidas.Z_PINO1 + 1.5), 1.6, 90)


func _festa_spare(s: int) -> void:
	if s == _seq:
		efeitos.estrelas(Vector3(0, 0.6, Medidas.Z_PINO1 - 0.4), 28)


func _aviso_seguidos(seguidos: int) -> void:
	if estado == E.RESULTADO or estado == E.REPLAY:
		hud.letreiro("pegando_fogo", "%d STRIKES SEGUIDOS!" % seguidos, 1.6, 0.55)
		Sons.tocar("brilho")


## Câmera de frente para os pinos, baixinha, para ver a máquina trabalhar.
func _plano_maquina() -> void:
	cam.corte(Vector3(0.55, 0.62, Medidas.Z_PINO1 + 2.5), Vector3(0, 0.5, Medidas.Z_PINO1 - 0.45), 40, 40)
	cam.ir(Vector3(-0.35, 0.72, Medidas.Z_PINO1 + 2.2), Vector3(0, 0.5, Medidas.Z_PINO1 - 0.45), 40, 40, 0.4)


## O ALÇAPÃO do fosso: corta para o fosso visto de cima (por cima da parede
## da direita, atrás da mesa) enquanto os pinos caem; depois volta para a
## mesa repondo os pinos.
func _alcapao_maquina(abrindo: bool) -> void:
	# o poço sem fundo: as faixas das paredes correm para cima na queda
	var m: ShaderMaterial = mundo.mat_poco
	if abrindo:
		m.set_shader_param("rolar", 0.0)
		var t := create_tween()
		t.tween_property(m, "shader_param/rolar", 6.0, 2.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if estado != E.RESULTADO:
		return
	if abrindo:
		cam.corte(Vector3(0.98, 1.08, Medidas.ALCAPAO_Z0 - 0.15), Vector3(-0.12, -0.45, Medidas.ALCAPAO_Z1 + 0.75), 56, 56)
		cam.ir(Vector3(0.9, 1.0, Medidas.ALCAPAO_Z0 - 0.25), Vector3(-0.1, -0.55, Medidas.ALCAPAO_Z1 + 0.8), 56, 56, 1.0)
	else:
		_plano_maquina()


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
	bola.mode = RigidBody.MODE_STATIC
	_replay_inicio = max(float(_gravacao[0]["t"]), _t_impacto - REPLAY_ANTES)
	_replay_fim = min(_t_impacto + REPLAY_DEPOIS, float(_gravacao.back()["t"]))
	_replay_t = _replay_inicio
	# o rastro já começa comprido (como estava na jogada nesse instante)
	_replay_rastro = max(float(_gravacao[0]["t"]), _replay_inicio - 27.0 * REPLAY_RASTRO)
	_replay_ativo = true
	bola.replay(true)
	_mostrar_quadro(_replay_t)
	bola.acender(0.8)
	# 1) câmera rasante colada na bola (corte seco, como na TV)
	cam.corte(_replay_alvo.global_translation + Vector3(0.42, 0.16, 0.75), _replay_alvo.global_translation + Vector3(-0.1, 0.08, -1.2), 40, 46)
	cam.seguir(_replay_alvo, Vector3(0.42, 0.16, 0.75), Vector3(-0.1, 0.08, -1.2), 40, 46, 12.0)
	while _replay_ativo and _replay_t < _t_impacto - 0.12:
		yield(get_tree(), "idle_frame")
		if s != _seq:
			return
	# 2) no impacto: lateral, baixinho, câmera bem lenta
	cam.corte(Vector3(0.5, 0.32, Medidas.Z_PINO1 + 1.1), Vector3(-0.05, 0.24, Medidas.Z_PINO1 - 0.35), 40, 48)
	cam.orbitar(Vector3(0, 0.24, Medidas.Z_PINO1 - 0.4), 1.55, 0.1, -0.3, 40, 48)
	while _replay_ativo and _replay_t < _t_impacto:
		yield(get_tree(), "idle_frame")
		if s != _seq:
			return
	# a batida: som (mais grave, em câmera lenta) junto com a imagem
	cam.tremer(0.02, 0.5)
	Sons.tocar("pinos_queda", 0.8, 0.85)
	while _replay_ativo and _replay_t < _t_impacto + 0.65:
		yield(get_tree(), "idle_frame")
		if s != _seq:
			return
	# 3) abre o plano: a explosão de pinos
	cam.ir(Vector3(-0.2, 1.3, Medidas.Z_PINO1 + 2.1), Vector3(0, 0.25, Medidas.Z_PINO1 - 0.6), 44, 46, 1.6)
	while _replay_ativo:
		yield(get_tree(), "idle_frame")
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
	return lerp(REPLAY_VEL_BATIDA, REPLAY_VEL, smoothstep(0.08, 0.75, abs(t - _t_impacto)))


func _rodar_replay(delta: float) -> void:
	var vel := 3.0 if _pular else _vel_replay(_replay_t)
	_replay_t = min(_replay_t + delta * vel, _replay_fim)
	bola.replay_ritmo(vel)
	# o rastro: pontos nos mesmos instantes da jogada de verdade
	while _replay_rastro + REPLAY_RASTRO <= _replay_t:
		_replay_rastro += REPLAY_RASTRO
		var q := _quadro(_replay_rastro, false)
		if q["v"]:
			bola.marcar_rastro((q["b"] as Transform).origin)
	var antes := bola.global_translation
	var dt_jogada := delta * vel
	_mostrar_quadro(_replay_t)
	# o barulho da bola rolando, mais grave (câmera lenta)
	if dt_jogada > 0.0:
		var v := bola.global_translation.distance_to(antes) / dt_jogada
		Sons.rolando(bola.visible and bola.global_translation.z > Medidas.Z_PINO1 - 0.5, v * vel)
	if _replay_t < _t_impacto + 0.1:
		pinos.susto(bola.global_translation)
	if _replay_t >= _replay_fim:
		_replay_ativo = false
		# termina exatamente como ficou de verdade
		var ultimo: Dictionary = _gravacao.back()
		bola.global_transform = ultimo["b"]
		bola.visible = bool(ultimo["v"])
		pinos.aplicar_foto(ultimo["p"])


## Põe a bola e os pinos como estavam no instante t da jogada.
func _mostrar_quadro(t: float) -> void:
	var q := _quadro(t, true)
	var tb: Transform = q["b"]
	bola.global_transform = tb
	bola.visible = bool(q["v"])
	_replay_alvo.global_translation = tb.origin
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
	var f1: Dictionary = _gravacao[Compat.imin(lo + 1, n - 1)]
	var t0 := float(f0["t"])
	var t1 := float(f1["t"])
	var u := clamp((t - t0) / (t1 - t0), 0.0, 1.0) if t1 > t0 else 0.0
	var r := {"b": (f0["b"] as Transform).interpolate_with(f1["b"], u), "v": f0["v"]}
	if com_pinos:
		var p0: Array = f0["p"]
		var p1: Array = f1["p"]
		var foto := []
		foto.resize(p0.size())
		for k in p0.size():
			foto[k] = (p0[k] as Transform).interpolate_with(p1[k], u)
		r["p"] = foto
	return r


# ================================================================ fim de jogo
func _fim_de_jogo() -> void:
	estado = E.FIM
	# fim da partida: a porta FECHA (as bolas da última jogada voltam e ficam)
	ArduinoBridge.porta(false)
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
		get_tree().create_timer(3.3).connect("timeout", Sons, "tocar", ["recorde"])
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
	if not yield(_esperar(1.6, s, false), "completed"):
		return
	var zonas := ["C", "C", "X", "V", "C", "Z", "B", "C"]
	_ultima_jogada_ms = -100000
	estado = E.DEMO
	_arremessar(zonas[randi() % zonas.size()])


func _fim_demo() -> void:
	demo = false
	_atracao()
	# a atração vai mostrando os 4 cenários
	hud.flash(Color.white, 0.8, 0.5)
	mundo.aplicar_tema(Temas.proximo(mundo.tema))
	_no_clarao()


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
	Sons.tocar("pino_batida", clamp(forca / 4.0, 0.25, 1.0), rand_range(0.9, 1.15))
	if forca > 2.5:
		efeitos.poeira(pos, 0.5)


func _bola_bateu(corpo: Node, vel: float) -> void:
	if corpo is StaticBody and corpo.name == "fisica" and vel > 0.8:
		Sons.tocar("boing", clamp(vel / 6.0, 0.4, 1.0))
		cam.tremer(0.012, 0.15)


## as notas (semitons acima do Sol) da cascata de pinos caindo no alçapão
const ESCALA_QUEDA := [0, 2, 4, 7, 9, 12, 14, 16, 19, 21]


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
		"alcapao":
			Sons.tocar("tique", 0.4, 0.5)
			Sons.tocar("boing", 0.18, 0.8)
		_:
			if nome.begins_with("queda_"):
				# cada pino que cai: uma notinha de xilofone (a escala sobe,
				# pentatônica: soa bonito mesmo encavalada) e um assobio
				var i := int(nome.substr(6))
				var nota: int = ESCALA_QUEDA[Compat.imin(i, ESCALA_QUEDA.size() - 1)]
				Sons.tocar("plim", 0.5, pow(2.0, nota / 12.0))
				Sons.tocar("fiu", 0.28, rand_range(0.92, 1.12))


func _som_personagem(nome: String) -> void:
	match nome:
		"passo":
			Sons.tocar("tique", 0.25, rand_range(0.8, 1.0))
		"palma":
			Sons.tocar("pop", 0.6, rand_range(1.1, 1.3))
		"jato":
			Sons.tocar("start", 0.7, 0.9)


# ================================================================ menu do operador
## MENU POR CIMA DO JOGO: o botão de CONFIGURAÇÃO abre o menu do operador
## (ou a configuração dos botões) por cima do jogo PAUSADO — nada é
## desmontado, a imagem 3D só para de ser desenhada. Entrar e sair é na
## hora, sem travar. Só o "Cenário (fundo)", a qualidade BAIXA (sem
## contornos) e virar a tela de pé/deitada pedem montar o jogo de novo.
func abrir_menu(cena: PackedScene) -> void:
	if _menu != null:
		# troca de menu (operador -> configuração dos botões)
		_menu.queue_free()
	else:
		_novo_seq()           # o que estava acontecendo para (demo, jogada, replay...)
		_parar_lenta()
		# o menu anda no tempo de verdade
		Engine.time_scale = 1.0
		Engine.iterations_per_second = _passos_fisica
		Sons.rolando(false)
		_gravando = false
		estado = E.OPERADOR
		_antes_menu = _ajustes_que_remontam()
		_medidor_antes = bool(Ajustes.valor("video", "medidor"))
		get_tree().paused = true
		_mostrar_3d(false)
		hud.visible = false
	_menu = cena.instance()
	_camada_menu.add_child(_menu)


## Saída do menu: o jogo volta na hora para a tela de espera (ou roda o
## TESTE DE DESEMPENHO, se foi o pedido).
func fechar_menu() -> void:
	if _menu == null:
		return
	# (Godot 3: dois Dictionary só são "iguais" se forem o MESMO — compara o conteúdo)
	if _ajustes_que_remontam().hash() != _antes_menu.hash():
		# o mundo é montado de outro jeito: monta de novo, com aviso na tela
		_menu.set_process_input(false)
		_aviso_remontar()
		yield(get_tree(), "idle_frame")
		yield(get_tree(), "idle_frame")
		get_tree().paused = false
		get_tree().reload_current_scene()
		return
	_menu.queue_free()
	_menu = null
	_resolucao_da_tv()
	_qps_do_operador()
	hud.visible = true
	_mostrar_3d(true)
	get_tree().paused = false
	_fps_t0 = 0
	# ajustes que valem na hora
	_velocidade = Ajustes.velocidade()
	_ritmo(1.0)
	var q := _qualidade_escolhida()
	if q != _qualidade:
		_qualidade = q
		mundo.aplicar_qualidade(_qualidade)
		_qualidade_viewport()
	_ler_nitidez()
	_tela_mudou(Tela.tamanho())
	if bool(Ajustes.valor("video", "medidor")) != _medidor_antes:
		medidor.mostrar(bool(Ajustes.valor("video", "medidor")))
	if _resultado_teste != null:
		(_resultado_teste.get_meta("fundo") as Node).queue_free()
		_resultado_teste = null
	# a abertura pode ter ficado pela metade
	hud.tarjas(false)
	hud.marca(false, true)
	bola.fogo(false)
	bola.vestir("bob")
	mundo.bola_z = 100.0
	hud.flash(Color.white, 0.5, 0.3)
	_no_clarao()
	if bool(Ajustes.valor("video", "testar")):
		Ajustes.definir("video", "testar", false)
		_atracao()
		_teste_desempenho()
	else:
		_atracao()


func menu_aberto() -> bool:
	return _menu != null


## O que muda a MONTAGEM do jogo (e não dá para trocar com ele montado).
func _ajustes_que_remontam() -> Dictionary:
	return {"cenario": Ajustes.cenario_leve(), "contornos": _qualidade_escolhida() != "baixa", "em_pe": Tela.em_pe(),
		"direto": _desenho_direto()}


func _aviso_remontar() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color(0.03, 0.09, 0.22)
	Tela.cobrir(fundo)
	_camada_menu.add_child(fundo)
	var l := Label.new()
	Tela.cobrir(l)
	l.text = "APLICANDO OS AJUSTES...\naguarde um instante"
	l.align = Label.ALIGN_CENTER
	l.valign = Label.VALIGN_CENTER
	Compat.estilo_rotulo(l, "fredoka_700", 54, Color("#FFD43B"), Compat.contorno_g4(10), Color("#0B1F45"))
	fundo.add_child(l)


# ================================================================ utilidades
## Tecla MENU do controle remoto da TV Box: abre o menu do operador.
func _tecla_menu(event: InputEvent) -> bool:
	return event is InputEventKey and event.is_pressed() and not event.is_echo() \
		and (event as InputEventKey).scancode == KEY_MENU


## VOLTAR do controle remoto da TV Box: o Android pede para voltar (o jogo
## NÃO fecha — application/config/quit_on_go_back = false). No menu do
## operador ou na configuração dos botões, volta/sai; no jogo, nada.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _menu != null:
		if _menu.has_method("comando"):
			_menu.comando("sair")
		elif _menu.has_method("cancelar"):
			_menu.cancelar()


## Chama `metodo` no começo do próximo quadro (espalha o trabalho de um
## momento pesado por dois quadros: na TV Box tudo junto passava do tempo do
## quadro).
func _no_proximo_quadro(metodo: String, args := []) -> void:
	yield(get_tree(), "idle_frame")
	callv(metodo, args)


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
	return not _preparando and (estado == E.ATRACAO or estado == E.ABERTURA)


## Modal por cima do jogo ("QUANTOS VÃO JOGAR?"): com a imagem 3D
## separada, ela fica parada (a última, com um véu escuro por cima) e não é
## desenhada de novo — a TV Box só desenha o modal: abre liso, sem pesar.
## No desenho direto o 3D continua vivo atrás do véu (custa o mesmo que a
## jogada). A câmera para onde está (ao voltar, continua dali, sem pulo).
func _congelar_3d(sim: bool) -> void:
	if _menu != null:
		return
	_parado_3d = sim
	if not _direto:
		vp.render_target_update_mode = Viewport.UPDATE_DISABLED if sim else Viewport.UPDATE_ALWAYS
	if sim:
		cam.congelar()


## O tempo do último quadro em segundos de verdade (sem a velocidade do
## jogo nem a câmera lenta): para as contagens que a criança vê na tela.
func _delta_real() -> float:
	return get_process_delta_time() / max(Engine.time_scale, 0.01)


func _novo_seq() -> int:
	_seq += 1
	_pular = false
	return _seq


## Espera `t` segundos (de tela, mesmo em câmera lenta, encurtados pela
## velocidade do jogo); volta false se a sequência foi cancelada. pulavel:
## um sensor acionado encurta a espera. acelera false: segundos de verdade
## (a contagem da foto, para a criança se arrumar).
func _esperar(t: float, s: int, pulavel := true, acelera := true) -> bool:
	var passou := 0.0
	while passou < t:
		yield(get_tree(), "idle_frame")
		if s != _seq:
			return false
		passou += _delta_real() * (_velocidade if acelera else 1.0)
		if pulavel and _pular:
			_pular = false
			break
	return s == _seq


## NITIDEZ x LISURA, sozinho: a cada 2 s mede os quadros por segundo de
## verdade (relógio) E as travadinhas (quadros que passaram do tempo — a
## média pode estar boa e a tela ainda engasgar). Ruim duas vezes seguidas
## (abaixo de ~90% do alvo ou mais de 4% de quadros atrasados), a placa
## alivia, nesta ordem:
##   1) na qualidade automática ALTA (PC): passa para a MÉDIA — sai o brilho
##      (glow) e o 3D fica em até 1080: o que mais pesa e quase não se nota;
##   2) a imagem 3D diminui 10% (até 70%);
##   3) ainda muito lento e na automática: qualidade BAIXA.
## Com folga (~8 s no máximo), a imagem VOLTA A CRESCER 5% — sem passar,
## por 90 s, de um tamanho que já se mostrou pesado. Se quem não dá conta é
## o PROCESSADOR (não a placa de vídeo), diminuir a imagem não ajuda: aí
## não mexe — no PC a placa diz quanto tempo levou para desenhar; na TV Box
## (o Android não diz) vale a conta do processador. O fator e a qualidade
## escolhidos ficam guardados para a próxima vez que a máquina ligar.
func _medir_fps(_delta: float) -> void:
	if not _adaptar:
		return
	var alvo := _alvo_qps
	# cada quadro: atrasou? (1,5 vez o tempo de um quadro = pulou a vez)
	var agora_us := Time.get_ticks_usec()
	if _q_ultimo > 0 and float(agora_us - _q_ultimo) > 1500000.0 / alvo:
		_q_lentos += 1
	_q_ultimo = agora_us
	# (o Godot 3 não informa quanto a placa de vídeo levou: vale a conta do
	# processador, como na TV Box)
	# trocar o tamanho da imagem 3D refaz as imagens da placa de vídeo (um
	# tranco): nunca no meio da jogada — a medida continua e a troca fica
	# para a espera da próxima bola
	if estado in [E.ARREMESSO, E.ROLANDO, E.RESULTADO, E.REPLAY]:
		return
	var agora := Time.get_ticks_msec()
	# com o 3D parado atrás do modal os quadros saem de graça: não contam
	if _fps_t0 == 0 or estado == E.ABERTURA or estado == E.TESTE or _parado_3d:
		_fps_t0 = agora
		_fps_q = Engine.get_idle_frames()
		_q_lentos = 0
		_gpu_ms = 0.0
		_gpu_n = 0
		var hz := OS.get_screen_refresh_rate()
		_alvo_qps = min(clamp(hz if hz > 0.0 else 60.0, 30.0, 60.0), float(_qps))
		return
	if agora - _fps_t0 < 2000:
		return
	var quadros := Compat.imax(Engine.get_idle_frames() - _fps_q, 1)
	var fps := float(quadros) * 1000.0 / float(agora - _fps_t0)
	var atrasados := float(_q_lentos) / float(quadros)
	var placa := _gpu_ms / float(_gpu_n) if _gpu_n > 0 else -1.0
	_fps_t0 = agora
	_fps_q = Engine.get_idle_frames()
	_q_lentos = 0
	_gpu_ms = 0.0
	_gpu_n = 0
	var hz := OS.get_screen_refresh_rate()
	_alvo_qps = min(clamp(hz if hz > 0.0 else 60.0, 30.0, 60.0), float(_qps))
	if _qualidade_pendente != "" or _fator_pendente > 0.0:
		return   # já tem uma troca esperando o clarão: mede de novo depois dela
	if fps < alvo * 0.9 or atrasados > 0.04:
		_fps_bons = 0
		_fps_ruins += 1
		var placa_no_limite: bool
		if placa >= 0.0:
			# a placa de vídeo usou mais de 70% do tempo do quadro
			placa_no_limite = placa > 700.0 / alvo
		else:
			# TV Box: processador no limite (jogo + física por quadro) = a imagem não é o problema
			var passos := float(Engine.iterations_per_second) / max(fps, 1.0)
			var cpu := (Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * passos) * 1000.0
			placa_no_limite = cpu <= 800.0 / alvo
		if _fps_ruins < 2 or not placa_no_limite:
			return
		_fps_ruins = 0
		var auto := str(Ajustes.valor("video", "qualidade")) == "auto"
		if auto and _qualidade == "alta":
			_qualidade_pendente = "media"
			print("Qualidade automática: média (%d quadros/s, %d%% atrasados, placa %.1f ms) no próximo clarão" % [int(fps), int(atrasados * 100.0), placa])
		elif not _direto and _fator > FATOR_MIN + 0.01:
			_teto = _fator
			_teto_ate = agora + 90000
			_pedir_fator(max(FATOR_MIN, _fator - 0.1), fps)
		elif auto and _qualidade != "baixa" and fps < alvo * 0.75:
			_qualidade_pendente = "baixa"
			_pedir_fator(1.0, fps)
			print("Qualidade automática: baixa (%d quadros/s) no próximo clarão" % int(fps))
		elif _direto and _qualidade == "baixa" and fps < alvo * 0.6 and str(Ajustes.valor("video", "desenho")) == "auto" \
				and str(Ajustes.valor("video", "desenho_medido")) != "imagem":
			# nem na baixa o desenho direto tem fôlego (placa fraca demais
			# para a resolução da TV): da próxima vez que o jogo abrir, a
			# imagem 3D separada, que desce até 720 px
			Ajustes.definir("video", "desenho_medido", "imagem")
			print("Desenho automático: imagem 3D separada na próxima abertura (%d quadros/s na baixa)" % int(fps))
	elif fps >= alvo * 0.97 and atrasados < 0.01:
		_fps_ruins = 0
		_fps_bons += 1
		if _fps_bons >= 4 and _fator < 1.0:
			_fps_bons = 0
			var limite := _teto - 0.01 if agora < _teto_ate else 1.0
			var novo := min(min(1.0, _fator + 0.05), limite)
			if novo > _fator + 0.001:
				_pedir_fator(novo, fps)
	else:
		_fps_ruins = 0
		_fps_bons = 0


func _pedir_fator(novo: float, fps: float) -> void:
	if abs(novo - _fator) < 0.001 and _qualidade_pendente == "":
		return
	_fator_pendente = novo
	print("Imagem 3D: %d%% (%d quadros/s) no próximo clarão" % [int(round(novo * 100.0)), int(fps)])


## Um clarão branco cobre a tela agora: a troca de resolução pendente
## acontece aqui (o tranco de refazer as imagens fica escondido).
func _no_clarao() -> void:
	if _qualidade_pendente != "":
		_qualidade = _qualidade_pendente
		_qualidade_pendente = ""
		mundo.aplicar_qualidade(_qualidade)
		_qualidade_viewport()
		_tela_mudou(Tela.tamanho())
		_qualidade_salvar = str(Ajustes.valor("video", "qualidade")) == "auto"
	if _fator_pendente > 0.0:
		_fator = _fator_pendente
		_fator_pendente = -1.0
		_tela_mudou(Tela.tamanho())
		_fator_salvar = true
	_fps_t0 = 0   # a próxima medida começa depois da troca
