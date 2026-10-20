extends Node

## A CÂMERA DA MÁQUINA (webcam USB, ex.: a câmera Sigma ligada na TV Box) e
## as FOTOS DAS CRIANÇAS. Quando a partida começa, cada jogador tira uma
## foto ("SORRIA!" 3-2-1) e o rostinho aparece no placar, na faixa
## "VEZ DE", no strike, na CLASSIFICAÇÃO do fim e na atração.
##
## De onde vem a imagem (escolhido sozinho):
##   * TV Box (Android): plugin StrikeCamera (addons/StrikeCamera), o mesmo
##     método do jogo de soco: câmera do sistema (API clássica, por onde as
##     TV Box publicam a webcam USB), depois Camera2 e, se a TV Box não
##     publicar a webcam, a UVC DIRETA (libuvc, pelo USB). Se um caminho
##     abre mas não manda imagem, o plugin passa para o próximo sozinho.
##     Como no jogo de soco, a câmera ACORDA 15 s depois da abertura e
##     FICA LIGADA (sem ninguém vendo, só conta os quadros — não pesa): a
##     foto sai na hora, sem esperar a webcam "esquentar", e o driver USB
##     não fica abrindo e fechando. Sem imagem, reabre do zero só na tela
##     de espera, no máximo a cada 30 s e 3 vezes.
##     PERMISSÕES SÓ NA PRIMEIRA VEZ: a da câmera é pedida UMA vez (na
##     tela de espera, com o aviso na tela "toque em PERMITIR"; o Android
##     guarda a resposta para sempre). A da webcam USB só serve para a UVC
##     direta e também é pedida uma vez só (marque "Usar por padrão").
##     Depois disso o jogo nunca mais pede sozinho: só o operador, no TESTE
##     DA CÂMERA do menu (guardado em user://fotos/camera.cfg);
##   * PC com Windows: ffmpeg (o Godot 4.6 não tem câmera no Windows).
##     Coloque o ffmpeg.exe na pasta do jogo (ou instale no PATH);
##   * Linux / Mac / teste: CameraServer do Godot.
## Sem câmera, o jogo segue normalmente com os mascotes no lugar das fotos.
##
## A imagem da câmera passa por shaders/camera.gdshader (converte YUV/RGB,
## recorta o quadrado do meio, espelha e gira se a câmera estiver de lado)
## numa telinha de 384x384 — que é a foto.
##
## As fotos ficam SÓ na máquina (user://fotos/).
##
## Teste no PC sem webcam: godot --path . -- --camera-falsa

signal mudou
## aviso na tela do jogo antes da janela de permissão do Android ("" = some)
signal janela_android(texto)

const PASTA := "user://fotos/"
const LADO := 384                  # foto quadrada, em pixels
const PERMISSAO := "android.permission.CAMERA"
const DICA_CAMERA := "A FOTO DAS CRIANÇAS USA A CÂMERA: NA JANELA DO ANDROID, TOQUE EM \"PERMITIR\"\nela só aparece desta vez"
const JANELA_MAX_MS := 25000
const W_FF := 640
const H_FF := 480

var status := "procurando"         # procurando | desligada | sem_permissao | sem_permissao_usb | sem_camera | pronta
var fonte := ""                    # android | ffmpeg | servidor
var nome_camera := ""
var feed: CameraFeed
var fotos := {}                    # "j0", "j1" -> ImageTexture (só desta partida)
var _imagens := {}                 # as mesmas fotos em Image (para gravar sem ler da placa de vídeo)
## no PC a câmera que não foi achada é procurada de novo no máximo a cada
## 15 s: procurar travava o quadro por dezenas ou centenas de ms
const BUSCA_MS := 15000
var _busca_ms := -BUSCA_MS
var _vp: Viewport
var _mat: ShaderMaterial
var _tex_a: Texture
var _tex_b: Texture
var _ligada := false               # a câmera está aberta
var _vendo := false                # alguém vendo (prévia/foto): os quadros viram imagem
var _desligar_em := -1.0
var _recordes := {}
# câmera de teste (PC)
var _falsa: CameraFeed
var _falsa_base: Image
var _falsas: Array = []
var _falsa_t := 0.0
# Android (plugin)
var _plugin: Object
var _quadro_visto := -1
var _quadro_ms := 0
var despertar_s := 15.0            # a câmera acorda 15 s depois da abertura
var espera_usb_ms := 20000         # janela USB só depois de 20 s sem câmera do sistema
var reabrir_ms := 30000            # sem imagem: reabre no máximo a cada 30 s...
var reaberturas_max := 3           # ...e no máximo 3 vezes (o driver USB não gosta)
var _sempre := false               # acordou: fica ligada direto
var _busca_desde_ms := -1          # quando a procura no Android começou
var _sistema_visto := false        # a webcam já apareceu como câmera do sistema
var _aberta_ms := 0
var _vivo_ms := 0                  # quando chegou quadro pela última vez
var _ultimo_n := -1
var _vigia_t := 0.0
var _reaberturas := 0
var _reaberta_ms := -1000000
var _pedir_agora := false          # o operador pediu (TESTE DA CÂMERA no menu)
var _janela_ate := 0               # a janela do Android está aberta (até este ms)
var _img_y: Image
var _img_uv: Image
# Windows (ffmpeg)
var _ffmpeg := ""
var _ff_dispositivo := ""
var _ff_pid := -1
var _ff_linha: Thread  #G3?
var _ff_trava := Mutex.new()
var _ff_quadro := PoolByteArray()
var _ff_novo := false
var _ff_rodando := false
var _img_rgb: Image


class FeedFalso extends CameraFeed:
	func _activate_feed() -> bool:
		return true

	func _deactivate_feed() -> void:
		pass


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	Compat.criar_pasta(PASTA)
	_vp = Viewport.new()
	_vp.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_vp.size = Vector2(LADO, LADO)
	_vp.disable_3d = true
	_vp.transparent_bg = false
	_vp.render_target_update_mode = Viewport.UPDATE_DISABLED
	add_child(_vp)
	var tela := ColorRect.new()
	tela.size = Vector2(LADO, LADO)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/camera.shader")
	tela.material = _mat
	_vp.add_child(tela)
	CameraServer.camera_feed_added.connect(func(_id): _procurar_servidor.call_deferred())  #G3?
	CameraServer.camera_feed_removed.connect(func(_id): _procurar_servidor.call_deferred())  #G3?
	if "--camera-falsa" in OS.get_cmdline_args() or OS.has_environment("STRIKE_CAMERA_FALSA"):
		_criar_falsa()
	# a câmera é procurada (e a permissão pedida) logo depois da abertura
	# começar; no Android ela acorda e fica ligada 15 s depois
	get_tree().create_timer(1.0).timeout.connect(iniciar)  #G3?
	get_tree().create_timer(despertar_s).timeout.connect(_acordar)  #G3?
	_ler_fotos_guardadas()


## As fotos do recorde e da classificação (user://fotos/) são lidas do
## disco já na abertura, numa linha de trabalho separada: ler e preparar
## cada PNG na hora em que a tela de espera aparece dava um tranco.
func _ler_fotos_guardadas() -> void:
	var caminhos := []
	for f in Compat.arquivos_em(PASTA):
		if f.get_extension() == "png" and (f.begins_with("recorde_") or f.begins_with("rank_")):
			caminhos.append(PASTA + f)
	if caminhos.empty():
		return
	var lidas_chegaram := _fotos_lidas
	Tarefas.rodar(func():  #G3?
		var lidas := {}
		for c in caminhos:
			var img := Image.load_from_file(c)  #G3?
			if img != null and not img.empty():
				img.generate_mipmaps()
				lidas[c] = img
		lidas_chegaram.call_deferred(lidas))


func _fotos_lidas(lidas: Dictionary) -> void:
	for c in lidas:
		if not _recordes.has(c):
			_recordes[c] = Compat.textura_de_imagem(lidas[c])


func pronta() -> bool:
	return status == "pronta"


func texto_status() -> String:
	match status:
		"pronta":
			if fonte == "android" and _plugin != null and _ligada:
				return "OK (%s) - %s" % [nome_camera, str(_plugin.call("estado"))]  #G3?
			return "OK (%s)" % nome_camera
		"desligada":
			return "desligada no menu"
		"sem_permissao":
			return "sem permissão do Android (aceite a janela da câmera)"
		"sem_permissao_usb":
			return "webcam no USB: aceite a janela do Android (marque Usar por padrão)"
		"sem_camera":
			if OS.get_name() == "Windows" and _ffmpeg == "":
				return "no PC: coloque o ffmpeg.exe na pasta do jogo"
			return "nenhuma câmera encontrada"
	return "procurando..."


func iniciar() -> void:
	if not bool(Ajustes.valor("jogo", "foto")):
		_parar()
		_mudar("desligada")
		return
	if status == "desligada":
		_mudar("procurando")
	if _falsa != null:
		fonte = "servidor"
		CameraServer.monitoring_feeds = true
		_procurar_servidor.call_deferred()  #G3?
		return
	if OS.get_name() == "Android":
		if not OS.get_granted_permissions().has(PERMISSAO):
			# a janela do Android só na tela de espera (na_espera), uma vez
			_mudar("sem_permissao")
			return
		if Engine.has_singleton("StrikeCamera"):
			_plugin = Engine.get_singleton("StrikeCamera")
			fonte = "android"
			# a lista chega sem parar o jogo e então a câmera liga (_lista_chegou)
			_procurar_android_sem_parar()
			return
	elif OS.get_name() == "Windows":
		fonte = "ffmpeg"
		_procurar_ffmpeg()
		return
	fonte = "servidor"
	CameraServer.monitoring_feeds = true
	_procurar_servidor.call_deferred()  #G3?


## Procura de novo agora (o jogo chama ao começar a escolha dos jogadores:
## alguém pode ter ligado a câmera depois).
func procurar_agora() -> void:
	if status != "pronta" and status != "desligada":
		# (o CameraServer já avisa sozinho quando uma câmera chega: não
		# precisa desligar e religar a vigia, que travava o jogo)
		_busca_ms = Time.get_ticks_msec()
		iniciar()


## A janela do Android "Permitir que o Strike Kids tire fotos?": UMA vez
## sozinha (na espera); depois, só quando o operador pede.
func _pedir_permissao() -> void:
	if janela_aberta() or ArduinoBridge.janela_aberta():
		return   # uma janela do Android por vez
	if _pedir_agora:
		_pedir_agora = false
	elif _lembrado("permissao_pedida"):
		return
	_lembrar("permissao_pedida")
	if not get_tree().on_request_permissions_result.is_connected(_permissao):
		get_tree().on_request_permissions_result.connect(_permissao)  #G3?
	_janela_ate = Time.get_ticks_msec() + JANELA_MAX_MS
	# a janela do Android congela a imagem do jogo: o aviso entra antes
	emit_signal("janela_android", DICA_CAMERA)
	get_tree().create_timer(0.6, true, false, true).timeout.connect(func(): OS.request_permission(PERMISSAO))  #G3?


## O operador pediu (TESTE DA CÂMERA, ou ligou a foto no menu): a janela
## que faltar (câmera ou webcam USB) pode abrir de novo.
func pedir_permissao_agora() -> void:
	if OS.get_name() != "Android":
		return
	_pedir_agora = true
	if not OS.get_granted_permissions().has(PERMISSAO):
		_mudar("sem_permissao")
		_pedir_permissao()
	elif status == "sem_permissao_usb" and _plugin != null:
		_pedir_usb(Time.get_ticks_msec())
	else:
		_pedir_agora = false


func janela_aberta() -> bool:
	return _janela_ate > 0 and Time.get_ticks_msec() < _janela_ate


func _fechou_janela() -> void:
	if _janela_ate > 0:
		_janela_ate = 0
		emit_signal("janela_android", "")


func _notification(what: int) -> void:
	# o jogo voltou para a frente: a janela do Android fechou
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		_fechou_janela()


func _permissao(nome: String, ok: bool) -> void:
	if nome == PERMISSAO:
		_fechou_janela()
		if ok:
			iniciar()


func _mudar(s: String) -> void:
	if s != status:
		status = s
		emit_signal("mudou")


# ================================================================ procurar
func _procurar_android(lista := "") -> void:
	if _busca_desde_ms < 0:
		_busca_desde_ms = Time.get_ticks_msec()
	if lista == "":
		lista = str(_plugin.call("listar"))  #G3?
	var melhor := ""
	var usb_sem_permissao := false
	for linha in lista.split("\n", false):
		if linha.begins_with("#"):
			continue
		var p := linha.split("|")
		if p.size() < 3:
			continue
		if p[2] == "uvc":
			# webcam vista direto no USB (UVC): só serve com a permissão USB
			if p.size() > 3 and p[3] == "0":
				usb_sem_permissao = true
				continue
			if melhor == "":
				melhor = "webcam USB"
			continue
		var nome := "câmera USB" if p[1] == "externa" else "câmera %s" % p[1]
		_sistema_visto = true
		if melhor == "" or p[1] == "externa":
			melhor = nome
	if melhor == "":
		_mudar("sem_permissao_usb" if usb_sem_permissao else "sem_camera")
		return
	nome_camera = melhor
	_mudar("pronta")


## Na TV Box a lista de câmeras vem do Android (câmera clássica, Camera2 e
## USB): numa TV Box fraca isso pode levar dezenas de ms — feito numa
## linha de trabalho separada, o jogo não para enquanto procura.
var _procurando := false


func _procurar_android_sem_parar() -> void:
	if OS.get_name() != "Android":
		_procurar_android()
		return
	if _procurando or _plugin == null:
		return
	_procurando = true
	var plugin := _plugin
	var chegou := _lista_chegou
	Tarefas.rodar(func():  #G3?
		var lista := str(plugin.call("listar"))  #G3?
		chegou.call_deferred(lista))


func _lista_chegou(lista: String) -> void:
	_procurando = false
	if _plugin == null or status == "desligada":
		return
	_procurar_android(lista if lista != "" else "#vazia")
	if status == "sem_permissao_usb":
		_pedir_usb(Time.get_ticks_msec())
	elif status == "pronta":
		_manter_ligada()


## Tela de espera (atração), a cada poucos segundos: confere a câmera. As
## janelas do Android aparecem SÓ aqui, nunca no meio do jogo (como no
## jogo de soco), e cada uma UMA vez na vida: a da câmera e a da webcam
## USB. A câmera ligada e sem imagem reabre aqui.
func na_espera() -> void:
	if status == "desligada":
		return
	var agora := Time.get_ticks_msec()
	if _janela_ate > 0 and agora >= _janela_ate:
		_fechou_janela()
	if OS.get_name() == "Android" and not OS.get_granted_permissions().has(PERMISSAO):
		_mudar("sem_permissao")
		_pedir_permissao()
		return
	if fonte != "android" or _plugin == null:
		if status in ["sem_camera", "procurando", "sem_permissao"] and agora - _busca_ms >= BUSCA_MS:
			procurar_agora()
		return
	# (a permissão USB recém-dada precisa ser vista logo: procura em toda
	# espera, como no jogo de soco — na TV Box sem parar o jogo)
	if status != "pronta":
		_procurar_android_sem_parar()
	if status == "sem_permissao_usb":
		_pedir_usb(agora)
	elif status == "pronta":
		if _ligada:
			_reabrir_se_muda(agora)
		else:
			_manter_ligada()


## A janela USB da webcam (só para a UVC direta). Como no jogo de soco:
## nunca logo depois do boot (o serviço de câmera do Android ainda conta
## zero câmeras) e nunca se a webcam já apareceu como câmera do sistema —
## aí ela não precisa de permissão USB nenhuma, só abrir.
func _pedir_usb(agora: int) -> void:
	if agora - _busca_desde_ms < espera_usb_ms and not _pedir_agora:
		return
	if _sistema_visto or (_sistema_lembrado() and agora - _busca_desde_ms < 45000):
		return
	if _lembrado("usb_pedida") and not _pedir_agora:
		return   # já pediu uma vez: nunca mais sozinho
	_pedir_agora = false
	_lembrar("usb_pedida")
	_plugin.call("pedir_usb")  #G3?


## Ligada e sem imagem há 30 s: reabre do zero. Raro e só na tela de
## espera — no jogo de soco, abrir e fechar a webcam a cada poucos segundos
## mexia no driver USB e derrubava a TV Box.
func _reabrir_se_muda(agora: int) -> void:
	if agora - Compat.imax(_vivo_ms, _aberta_ms) < reabrir_ms:
		return
	if _reaberturas >= reaberturas_max or agora - _reaberta_ms < reabrir_ms:
		return
	_reaberturas += 1
	_reaberta_ms = agora
	_plugin.call("fechar")  #G3?
	_abrir_android()


## O que o jogo guarda entre uma abertura e outra (user://fotos/camera.cfg):
## a webcam já mandou imagem como câmera do sistema? as janelas de
## permissão já foram pedidas uma vez?
var _lembrancas: ConfigFile


func _lembrado(chave: String) -> bool:
	if _lembrancas == null:
		_lembrancas = ConfigFile.new()
		_lembrancas.load(PASTA + "camera.cfg")
	return bool(_lembrancas.get_value("camera", chave, false))  #G3?


func _lembrar(chave: String) -> void:
	if _lembrado(chave):
		return
	_lembrancas.set_value("camera", chave, true)  #G3?
	_lembrancas.save(PASTA + "camera.cfg")


func _sistema_lembrado() -> bool:
	return _lembrado("sistema")


func _lembrar_sistema() -> void:
	_lembrar("sistema")


## Alguém apertou START. No Android a câmera já fica ligada (só garante);
## no PC ela liga agora, para a imagem estar pronta no "SORRIA!".
func preparar() -> void:
	procurar_agora()
	if not pronta() or not bool(Ajustes.valor("jogo", "foto")):
		return
	if fonte == "android":
		_sempre = true
		_manter_ligada()
	else:
		ligar()


## Vale fazer a sessão de fotos? Câmera achada e, no Android, mandando
## imagem (ou ainda subindo). Câmera muda: o jogo segue com os mascotes.
func pode_fotografar() -> bool:
	if not pronta() or not bool(Ajustes.valor("jogo", "foto")):
		return false
	if fonte == "android" and _ligada and not _vendo:
		var agora := Time.get_ticks_msec()
		return (_vivo_ms > 0 and agora - _vivo_ms < 5000) or agora - _aberta_ms < 25000
	return true


## Android: 15 s depois da abertura (longe do pico de memória do
## carregamento) a câmera acorda e fica ligada.
func _acordar() -> void:
	if fonte != "android":
		return
	_sempre = true
	_manter_ligada()


## Abre a câmera (se ainda não está), sem ninguém vendo: só conta quadros.
func _manter_ligada() -> void:
	if not _sempre or fonte != "android" or _plugin == null or _ligada:
		return
	if not pronta() or not bool(Ajustes.valor("jogo", "foto")):
		return
	_abrir_android()


func _abrir_android() -> void:
	_plugin.call("ver", _vendo)  #G3?
	_plugin.call("abrir", "auto", W_FF, H_FF)  #G3?
	_ligada = true
	_quadro_visto = -1
	_ultimo_n = -1
	_aberta_ms = Time.get_ticks_msec()


## O que o Android enxerga (para o teste da câmera no menu do operador).
func relatorio() -> String:
	if fonte == "android" and _plugin != null:
		return str(_plugin.call("relatorio"))  #G3?
	return texto_status()


## No PC a busca roda numa linha de execução separada (o ffmpeg demora um
## pouco para listar as câmeras e o jogo não pode travar).
var _ff_busca: Thread  #G3?


func _procurar_ffmpeg() -> void:
	if _ff_busca != null:
		if _ff_busca.is_alive():
			return
		_ff_busca.wait_to_finish()
	_ff_busca = Thread.new()  #G3?
	_ff_busca.start(_buscar_ffmpeg)


func _buscar_ffmpeg() -> void:
	var exe := _ffmpeg if _ffmpeg != "" else _achar_ffmpeg()
	var achados: Array = []
	if exe != "":
		var saida := []
		OS.execute(exe, ["-hide_banner", "-list_devices", "true", "-f", "dshow", "-i", "dummy"], saida, true)
		var texto := "\n".join(saida)
		var re := RegEx.create_from_string("\"([^\"]+)\"\\s*\\(video\\)")
		for m in re.search_all(texto):
			achados.append(m.get_string(1))
		if achados.empty():
			# ffmpeg antigo: nomes depois de "DirectShow video devices"
			var em_video := false
			var re2 := RegEx.create_from_string("\\]\\s+\"([^\"]+)\"")
			for linha in texto.split("\n"):
				if "video devices" in linha:
					em_video = true
				elif "audio devices" in linha:
					em_video = false
				elif em_video and not "Alternative name" in linha:
					var m := re2.search(linha)
					if m:
						achados.append(m.get_string(1))
	_ffmpeg_achado.call_deferred(exe, achados)


func _ffmpeg_achado(exe: String, achados: Array) -> void:
	_ffmpeg = exe
	if achados.empty():
		_mudar("sem_camera")
		return
	_ff_dispositivo = achados[0]
	for a in achados:
		var n := a.to_lower()
		if "usb" in n or "sigma" in n or "uvc" in n:
			_ff_dispositivo = a
			break
	nome_camera = _ff_dispositivo
	_mudar("pronta")


func _achar_ffmpeg() -> String:
	var pasta := OS.get_executable_path().get_base_dir()
	for c in [pasta.path_join("ffmpeg.exe"), pasta.path_join("ffmpeg/bin/ffmpeg.exe"), pasta.path_join("ffmpeg/ffmpeg.exe")]:
		if Compat.existe_arquivo(c):
			return c
	var saida := []
	if OS.execute("where", ["ffmpeg"], saida) == 0 and not saida.empty():
		var primeiro := str(saida[0]).split("\n")[0].strip_edges()
		if primeiro != "" and Compat.existe_arquivo(primeiro):
			return primeiro
	return ""


## CameraServer: a de teste, senão a webcam USB (externa), senão a primeira.
func _procurar_servidor() -> void:
	if fonte != "servidor" or status == "desligada" or not CameraServer.monitoring_feeds:
		return
	var escolhida: CameraFeed = null
	var nota := -1
	for f: CameraFeed in CameraServer.feeds():
		var n := 0
		var nome: String = f.get_name().to_lower()
		if f == _falsa:
			n = 10
		elif f.get_position() == CameraFeed.FEED_UNSPECIFIED:
			n = 3
		if "usb" in nome or "sigma" in nome or "uvc" in nome or "extern" in nome:
			n += 4
		if n > nota:
			nota = n
			escolhida = f
	if escolhida == null:
		feed = null
		_mudar("sem_camera")
		return
	if escolhida != feed:
		if feed != null and _ligada:
			feed.feed_is_active = false
			_ligada = false
		feed = escolhida
		nome_camera = feed.get_name()
		_escolher_formato()
		var a := CameraTexture.new()
		a.camera_feed_id = feed.get_id()
		a.which_feed = CameraServer.FEED_RGBA_IMAGE
		var b := CameraTexture.new()
		b.camera_feed_id = feed.get_id()
		b.which_feed = CameraServer.FEED_CBCR_IMAGE
		_tex_a = a
		_tex_b = b
	_mudar("pronta")


## A resolução mais perto de 640x480 (leve para a TV Box e boa para a foto).
func _escolher_formato() -> void:
	var formatos: Array = feed.get_formats()
	if formatos.empty():
		return
	var melhor := 0
	var nota := INF
	for i in formatos.size():
		var f: Dictionary = formatos[i]
		var w := int(f.get("width", 0))
		var h := int(f.get("height", 0))
		if w <= 0 or h <= 0:
			continue
		var n := abs(float(w * h - 640 * 480))
		if "jp" in str(f.get("format", "")).to_lower():
			n += 50000.0   # JPEG custa processador para abrir: só se não tiver outro
		if n < nota:
			nota = n
			melhor = i
	feed.set_format(melhor, {})


# ================================================================ ligar / desligar
## Liga a câmera (para a prévia e a foto).
func ligar() -> bool:
	if not pronta():
		return false
	_desligar_em = -1.0
	if not _vendo:
		_vendo = true
		# a foto só com quadro NOVO (nunca o da partida anterior)
		_quadro_visto = -1
		if fonte == "android" and _ligada:
			_plugin.call("ver", true)  #G3?
	if not _ligada:
		match fonte:
			"android":
				_abrir_android()
			"ffmpeg":
				_iniciar_ffmpeg()
			_:
				feed.feed_is_active = true
				_mat.set_shader_param("cam_a", _tex_a)
				_mat.set_shader_param("cam_b", _tex_b)
		_ligada = true
	_vp.render_target_update_mode = Viewport.UPDATE_ALWAYS
	return true


## Desliga depois de um tempinho (a webcam não gosta de liga-desliga seguido).
func desligar(atraso := 6.0) -> void:
	_desligar_em = atraso


## Ninguém mais vendo. No Android a câmera continua ligada (só contando os
## quadros); no PC ela desliga.
func _soltar() -> void:
	_vendo = false
	_vp.render_target_update_mode = Viewport.UPDATE_DISABLED
	if fonte == "android" and _sempre and _ligada and bool(Ajustes.valor("jogo", "foto")):
		_plugin.call("ver", false)  #G3?
		return
	_parar()


func _parar() -> void:
	_vendo = false
	if not _ligada:
		return
	match fonte:
		"android":
			_plugin.call("fechar")  #G3?
		"ffmpeg":
			_parar_ffmpeg()
		_:
			if feed:
				feed.feed_is_active = false
	_ligada = false
	_vp.render_target_update_mode = Viewport.UPDATE_DISABLED


func ao_vivo() -> Texture:
	return _vp.get_texture()


## A câmera já mandou imagem desde que foi ligada?
func tem_imagem() -> bool:
	match fonte:
		"android":
			return _quadro_visto >= 0
		"ffmpeg":
			return _img_rgb != null
	return _tex_a != null and _tex_a.get_size().x > 1.0


func _process(delta: float) -> void:
	if _falsa != null and _ligada:
		_falsa_t += delta
		if fposmod(_falsa_t, 0.1) < delta:
			_atualizar_falsa()
	if _desligar_em >= 0.0:
		_desligar_em -= delta
		if _desligar_em < 0.0:
			_soltar()
	# (procurar câmera trava o quadro por dezenas de ms: só na abertura e
	# quando alguém aperta START — procurar_agora — nunca no meio do jogo)
	if not _ligada:
		return
	match fonte:
		"android":
			_vigiar_android(delta)
			if _vendo:
				_quadro_android()
		"ffmpeg":
			_quadro_ffmpeg()
		_:
			if feed != null:
				var tipo := 1
				match feed.get_datatype():
					CameraFeed.FEED_YCBCR:
						tipo = 2
					CameraFeed.FEED_YCBCR_SEP:
						tipo = 3
				_ajustar_shader(tipo, _tex_a.get_size())


func _ajustar_shader(tipo: int, tam: Vector2) -> void:
	_mat.set_shader_param("tipo", tipo)
	if tam.x > 1.0 and tam.y > 1.0:
		var asp := tam.x / tam.y
		_mat.set_shader_param("escala_uv", Vector2(1.0 / asp, 1.0) if asp >= 1.0 else Vector2(1.0, asp))
	# a câmera pode estar montada de lado/ao contrário: o operador acerta
	# no menu ("Giro da câmera")
	_mat.set_shader_param("giro", int(Ajustes.valor("jogo", "camera_giro")) / 90 % 4)
	_mat.set_shader_param("espelhar", bool(Ajustes.valor("jogo", "camera_espelho")))


## Android, uma vez por segundo: a câmera está viva? (só o contador de
## quadros: não custa nada)
func _vigiar_android(delta: float) -> void:
	_vigia_t += delta
	if _vigia_t < 1.0:
		return
	_vigia_t = 0.0
	# a TV Box pausou o app (o plugin solta a câmera): liga de novo
	if str(_plugin.call("estado")) == "parada":  #G3?
		_abrir_android()
		return
	var n := int(_plugin.call("quadros"))  #G3?
	if n > 0 and n != _ultimo_n:
		_ultimo_n = n
		_vivo_ms = Time.get_ticks_msec()
		_reaberturas = 0
		if not _sistema_lembrado() and str(_plugin.call("fonte")) in ["sistema", "camera2"]:  #G3?
			_lembrar_sistema()


## Android: Y e UV (4:2:0) do plugin viram duas texturas; a cor sai no shader.
func _quadro_android() -> void:
	var n := int(_plugin.call("quadros"))  #G3?
	if n <= 0 or n == _quadro_visto:
		return
	var agora := Time.get_ticks_msec()
	if _quadro_visto >= 0 and agora - _quadro_ms < 60:
		return
	_quadro_ms = agora
	_quadro_visto = n
	var w := int(_plugin.call("largura"))  #G3?
	var h := int(_plugin.call("altura"))  #G3?
	if w < 2 or h < 2:
		return
	var y: PoolByteArray = _plugin.call("plano_y")  #G3?
	var uv: PoolByteArray = _plugin.call("plano_uv")  #G3?
	if y.size() != w * h or uv.size() != (w / 2) * (h / 2) * 2:
		return
	var iy := Image.create_from_data(w, h, false, Image.FORMAT_L8, y)  #G3?
	var iuv := Image.create_from_data(w / 2, h / 2, false, Image.FORMAT_RG8, uv)  #G3?
	if _img_y == null or _img_y.get_size() != iy.get_size():
		_tex_a = Compat.textura_de_imagem(iy)
		_tex_b = Compat.textura_de_imagem(iuv)
		_mat.set_shader_param("cam_a", _tex_a)
		_mat.set_shader_param("cam_b", _tex_b)
	else:
		(_tex_a as ImageTexture).update(iy)
		(_tex_b as ImageTexture).update(iuv)
	_img_y = iy
	_img_uv = iuv
	_ajustar_shader(3, Vector2(w, h))


# ---------------------------------------------------------------- ffmpeg (PC)
## ffmpeg manda quadros RGB crus (640x480) por um "cano"; uma linha de
## execução separada lê e guarda o último quadro.
func _iniciar_ffmpeg() -> void:
	_parar_ffmpeg()
	var args := PoolStringArray(["-hide_banner", "-loglevel", "error", "-f", "dshow", "-rtbufsize", "64M",
		"-i", "video=" + _ff_dispositivo,
		"-vf", "scale=%d:%d:force_original_aspect_ratio=increase,crop=%d:%d" % [W_FF, H_FF, W_FF, H_FF],
		"-r", "15", "-pix_fmt", "rgb24", "-f", "rawvideo", "-"])
	var r := OS.execute_with_pipe(_ffmpeg, args, true)
	if r.empty():
		_mudar("sem_camera")
		return
	_ff_pid = int(r["pid"])
	_ff_rodando = true
	_ff_linha = Thread.new()  #G3?
	_ff_linha.start(_ler_ffmpeg.bind(r["stdio"]))  #G3?


func _ler_ffmpeg(cano: FileAccess) -> void:  #G3?
	var tam := W_FF * H_FF * 3
	var acumulado := PoolByteArray()
	var vazios := 0
	while _ff_rodando:
		var pedaco := cano.get_buffer(tam - acumulado.size())
		if pedaco.empty():
			vazios += 1
			if vazios > 50:
				break
			OS.delay_msec(20)
			continue
		vazios = 0
		acumulado.append_array(pedaco)
		if acumulado.size() >= tam:
			_ff_trava.lock()
			_ff_quadro = acumulado
			_ff_novo = true
			_ff_trava.unlock()
			acumulado = PoolByteArray()
	cano.close()


func _quadro_ffmpeg() -> void:
	_ff_trava.lock()
	var novo := _ff_novo
	var dados := _ff_quadro
	_ff_novo = false
	_ff_trava.unlock()
	if not novo:
		return
	var img := Image.create_from_data(W_FF, H_FF, false, Image.FORMAT_RGB8, dados)  #G3?
	if _img_rgb == null:
		_tex_a = Compat.textura_de_imagem(img)
		_mat.set_shader_param("cam_a", _tex_a)
	else:
		(_tex_a as ImageTexture).update(img)
	_img_rgb = img
	_ajustar_shader(1, Vector2(W_FF, H_FF))


func _parar_ffmpeg() -> void:
	_ff_rodando = false
	if _ff_pid > 0:
		OS.kill(_ff_pid)
		_ff_pid = -1
	if _ff_linha != null:
		_ff_linha.wait_to_finish()
		_ff_linha = null
	_img_rgb = null


func _exit_tree() -> void:
	Tarefas.esperar_todas()
	_parar_ffmpeg()
	if _ff_busca != null:
		_ff_busca.wait_to_finish()
	if _plugin != null:
		_plugin.call("fechar")  #G3?
	# a câmera de teste (feita em GDScript) sai do CameraServer antes do
	# motor desligar (senão ele a apaga depois dos scripts e o jogo cai ao sair)
	if _falsa != null:
		_falsa.feed_is_active = false
		CameraServer.remove_feed(_falsa)
		_falsa = null


# ================================================================ foto
## Tira a foto (a câmera precisa estar ligada há alguns quadros). Volta a
## textura, ou null se a câmera não mandou imagem.
## Tira a foto, igual ao jogo de soco: espera um quadro BOM (até 4 s) —
## com imagem, nem escuro nem chapado (tampa na lente). A foto não se perde
## porque a câmera demorou um pouco ou mandou um quadro ruim.
func tirar(chave: String) -> ImageTexture:
	if not _ligada:
		return null
	var limite := Time.get_ticks_msec() + 4000
	var img: Image = null
	while Time.get_ticks_msec() < limite:
		if tem_imagem():
			yield(VisualServer, "frame_post_draw")
			var i := _vp.get_texture().get_image()
			if i != null and not i.empty() and not _escura(i) and _contraste(i) >= 0.04:
				img = i
				break
		yield(get_tree(), "idle_frame")
	if img == null:
		return null
	img.convert(Image.FORMAT_RGB8)  #G3?
	img.generate_mipmaps()
	var t := Compat.textura_de_imagem(img)
	fotos[chave] = t
	_imagens[chave] = img
	if _falsa != null and _falsas.size() > 1:
		# câmera de teste: o próximo jogador é outra criança
		_falsa_base = _falsas[(_falsas.find(_falsa_base) + 1) % _falsas.size()]
	return t


## Diferença entre o ponto mais claro e o mais escuro (grade 8x6): imagem
## "chapada" (lente tampada, câmera sem imagem) fica perto de zero.
func _contraste(img: Image) -> float:
	var claro := 0.0
	var escuro := 1.0
	for gx in 8:
		for gy in 6:
			var c := img.get_pixel(int((gx + 0.5) / 8.0 * img.get_width()), int((gy + 0.5) / 6.0 * img.get_height()))
			var v := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			claro = max(claro, v)
			escuro = min(escuro, v)
	return claro - escuro


func _escura(img: Image) -> bool:
	var soma := 0.0
	for i in 64:
		var c := img.get_pixel((i * 37) % img.get_width(), (i * 53) % img.get_height())
		soma += c.r + c.g + c.b
	return soma / (64.0 * 3.0) < 0.03


func foto(chave: String) -> Texture:
	return fotos.get(chave)


func limpar_partida() -> void:
	fotos.clear()
	_imagens.clear()


## Grava a foto num arquivo (para a classificação e o recorde). O PNG é
## escrito numa linha de execução separada (levava dezenas de ms no PC e
## centenas na TV Box, travando o fim da partida); a foto já fica no cache,
## então ninguém precisa ler o arquivo enquanto ele está sendo escrito.
func gravar(chave: String, nome_arquivo: String) -> String:
	var t: ImageTexture = fotos.get(chave)
	if t == null:
		return ""
	var img: Image = _imagens.get(chave)
	if img == null:
		img = t.get_image()
	var caminho := PASTA + nome_arquivo
	_recordes[caminho] = t
	Tarefas.rodar(func(): img.save_png(caminho))  #G3?
	return caminho


## Carrega uma foto gravada (com cache).
func carregar(caminho: String) -> Texture:
	if caminho == "":
		return null
	if _recordes.has(caminho):
		return _recordes[caminho]
	var t: Texture = null
	if Compat.existe_arquivo(caminho):
		var img := Image.load_from_file(caminho)  #G3?
		if img != null and not img.empty():
			img.generate_mipmaps()
			t = Compat.textura_de_imagem(img)
	_recordes[caminho] = t
	return t


# ---------------------------------------------------------------- recorde
func salvar_recorde(chave: String, jogadores: int) -> String:
	return gravar(chave, "recorde_j%d.png" % jogadores)


func foto_recorde(jogadores: int) -> Texture:
	return carregar(str(Ajustes.recorde(jogadores).get("foto", "")))


func apagar_recordes() -> void:
	_recordes.clear()
	for f in Compat.arquivos_em(PASTA):
		if f.begins_with("recorde_") or f.begins_with("rank_"):
			Compat.apagar(PASTA + f)


# ---------------------------------------------------------------- câmera de teste (PC)
func _criar_falsa() -> void:
	_falsa = FeedFalso.new()
	_falsa.set_name("Câmera de teste")
	for c in ["res://tools/testes/foto_teste.png", "res://tools/testes/foto_teste_2.png"]:
		var cam := ProjectSettings.globalize_path(c)
		if Compat.existe_arquivo(cam):
			var im := Image.load_from_file(cam)  #G3?
			if im != null and not im.empty():
				im.convert(Image.FORMAT_RGB8)  #G3?
				_falsas.append(im)
	if not _falsas.empty():
		_falsa_base = _falsas[0]
	if _falsa_base == null or _falsa_base.empty():
		_falsa_base = Image.create(640, 480, false, Image.FORMAT_RGB8)  #G3?
		_falsa_base.fill(Color(0.3, 0.6, 0.9))
		_falsa_base.fill_rect(Rect2(220, 120, 200, 240), Color(1.0, 0.8, 0.65))
	_falsa_base.convert(Image.FORMAT_RGB8)  #G3?
	_falsa.set_rgb_image(_falsa_base)
	CameraServer.add_feed(_falsa)


func _atualizar_falsa() -> void:
	# mexe um tiquinho, para parecer imagem ao vivo
	var img := _falsa_base.duplicate() as Image
	var dx := int(sin(_falsa_t * 2.0) * 6.0)
	if dx != 0:
		img.blit_rect(_falsa_base, Rect2(Compat.imax(0, -dx), 0, img.get_width() - Compat.iabs(dx), img.get_height()), Vector2(Compat.imax(0, dx), 0))
	_falsa.set_rgb_image(img)
