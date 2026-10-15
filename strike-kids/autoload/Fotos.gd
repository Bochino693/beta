extends Node

## A CÂMERA DA MÁQUINA (webcam USB, ex.: a câmera Sigma ligada na TV Box) e
## as FOTOS DAS CRIANÇAS. Quando a partida começa, cada jogador tira uma
## foto ("SORRIA!" 3-2-1) e o rostinho aparece no placar, na faixa
## "VEZ DE", no strike, na CLASSIFICAÇÃO do fim e na atração.
##
## De onde vem a imagem (escolhido sozinho):
##   * TV Box (Android): plugin StrikeCamera (addons/StrikeCamera) — abre a
##     webcam USB (câmera "externa", que o Godot sozinho NÃO enxerga) pela
##     Camera2, ou pela Camera1 nas TV Box com driver antigo;
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

const PASTA := "user://fotos/"
const LADO := 384                  # foto quadrada, em pixels
const PERMISSAO := "android.permission.CAMERA"
const W_FF := 640
const H_FF := 480

var status := "procurando"         # procurando | desligada | sem_permissao | sem_camera | pronta
var fonte := ""                    # android | ffmpeg | servidor
var nome_camera := ""
var feed: CameraFeed
var fotos := {}                    # "j0", "j1" -> ImageTexture (só desta partida)
var _vp: SubViewport
var _mat: ShaderMaterial
var _tex_a: Texture2D
var _tex_b: Texture2D
var _ligada := false
var _desligar_em := -1.0
var _recordes := {}
# câmera de teste (PC)
var _falsa: CameraFeed
var _falsa_base: Image
var _falsas: Array[Image] = []
var _falsa_t := 0.0
# Android (plugin)
var _plugin: Object
var _quadro_visto := -1
var _img_y: Image
var _img_uv: Image
# Windows (ffmpeg)
var _ffmpeg := ""
var _ff_dispositivo := ""
var _ff_pid := -1
var _ff_linha: Thread
var _ff_trava := Mutex.new()
var _ff_quadro := PackedByteArray()
var _ff_novo := false
var _ff_rodando := false
var _img_rgb: Image


class FeedFalso extends CameraFeed:
	func _activate_feed() -> bool:
		return true

	func _deactivate_feed() -> void:
		pass


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(PASTA)
	_vp = SubViewport.new()
	_vp.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_vp.size = Vector2i(LADO, LADO)
	_vp.disable_3d = true
	_vp.transparent_bg = false
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	var tela := ColorRect.new()
	tela.size = Vector2(LADO, LADO)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/camera.gdshader")
	tela.material = _mat
	_vp.add_child(tela)
	CameraServer.camera_feed_added.connect(func(_id): _procurar_servidor.call_deferred())
	CameraServer.camera_feed_removed.connect(func(_id): _procurar_servidor.call_deferred())
	if "--camera-falsa" in OS.get_cmdline_user_args() or OS.has_environment("STRIKE_CAMERA_FALSA"):
		_criar_falsa()
	# a câmera é procurada logo depois da abertura começar
	get_tree().create_timer(1.0).timeout.connect(iniciar)


func pronta() -> bool:
	return status == "pronta"


func texto_status() -> String:
	match status:
		"pronta":
			return "OK (%s)" % nome_camera
		"desligada":
			return "desligada no menu"
		"sem_permissao":
			return "sem permissão do Android"
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
		_procurar_servidor.call_deferred()
		return
	if OS.get_name() == "Android":
		if not OS.get_granted_permissions().has(PERMISSAO):
			_mudar("sem_permissao")
			if not get_tree().on_request_permissions_result.is_connected(_permissao):
				get_tree().on_request_permissions_result.connect(_permissao)
			OS.request_permission(PERMISSAO)
			return
		if Engine.has_singleton("StrikeCamera"):
			_plugin = Engine.get_singleton("StrikeCamera")
			fonte = "android"
			_procurar_android()
			return
	elif OS.get_name() == "Windows":
		fonte = "ffmpeg"
		_procurar_ffmpeg()
		return
	fonte = "servidor"
	CameraServer.monitoring_feeds = true
	_procurar_servidor.call_deferred()


## Procura de novo agora (o jogo chama ao começar a escolha dos jogadores:
## alguém pode ter ligado a câmera depois).
func procurar_agora() -> void:
	if status != "pronta" and status != "desligada":
		if fonte == "servidor" and _falsa == null:
			CameraServer.monitoring_feeds = false
		iniciar()


func _permissao(nome: String, ok: bool) -> void:
	if nome == PERMISSAO and ok:
		iniciar()


func _mudar(s: String) -> void:
	if s != status:
		status = s
		mudou.emit()


# ================================================================ procurar
func _procurar_android() -> void:
	var lista := str(_plugin.call("listar"))
	var melhor := ""
	for linha in lista.split("\n", false):
		if linha.begins_with("#"):
			continue
		var p := linha.split("|")
		if p.size() < 3:
			continue
		var nome := "câmera USB" if p[1] == "externa" else "câmera %s" % p[1]
		if melhor == "" or p[1] == "externa":
			melhor = nome
	if melhor == "":
		_mudar("sem_camera")
		return
	nome_camera = melhor
	_mudar("pronta")


## No PC a busca roda numa linha de execução separada (o ffmpeg demora um
## pouco para listar as câmeras e o jogo não pode travar).
var _ff_busca: Thread


func _procurar_ffmpeg() -> void:
	if _ff_busca != null:
		if _ff_busca.is_alive():
			return
		_ff_busca.wait_to_finish()
	_ff_busca = Thread.new()
	_ff_busca.start(_buscar_ffmpeg)


func _buscar_ffmpeg() -> void:
	var exe := _ffmpeg if _ffmpeg != "" else _achar_ffmpeg()
	var achados: Array[String] = []
	if exe != "":
		var saida := []
		OS.execute(exe, ["-hide_banner", "-list_devices", "true", "-f", "dshow", "-i", "dummy"], saida, true)
		var texto := "\n".join(saida)
		var re := RegEx.create_from_string("\"([^\"]+)\"\\s*\\(video\\)")
		for m in re.search_all(texto):
			achados.append(m.get_string(1))
		if achados.is_empty():
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


func _ffmpeg_achado(exe: String, achados: Array[String]) -> void:
	_ffmpeg = exe
	if achados.is_empty():
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
		if FileAccess.file_exists(c):
			return c
	var saida := []
	if OS.execute("where", ["ffmpeg"], saida) == 0 and not saida.is_empty():
		var primeiro := str(saida[0]).split("\n")[0].strip_edges()
		if primeiro != "" and FileAccess.file_exists(primeiro):
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
	if formatos.is_empty():
		return
	var melhor := 0
	var nota := INF
	for i in formatos.size():
		var f: Dictionary = formatos[i]
		var w := int(f.get("width", 0))
		var h := int(f.get("height", 0))
		if w <= 0 or h <= 0:
			continue
		var n := absf(float(w * h - 640 * 480))
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
	if not _ligada:
		match fonte:
			"android":
				_quadro_visto = -1
				_plugin.call("abrir", "auto", W_FF, H_FF)
			"ffmpeg":
				_iniciar_ffmpeg()
			_:
				feed.feed_is_active = true
				_mat.set_shader_parameter("cam_a", _tex_a)
				_mat.set_shader_parameter("cam_b", _tex_b)
		_ligada = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	return true


## Desliga depois de um tempinho (a webcam não gosta de liga-desliga seguido).
func desligar(atraso := 6.0) -> void:
	_desligar_em = atraso


func _parar() -> void:
	if not _ligada:
		return
	match fonte:
		"android":
			_plugin.call("fechar")
		"ffmpeg":
			_parar_ffmpeg()
		_:
			if feed:
				feed.feed_is_active = false
	_ligada = false
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED


func ao_vivo() -> Texture2D:
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
			_parar()
	# (procurar câmera trava o quadro por dezenas de ms: só na abertura e
	# quando alguém aperta START — procurar_agora — nunca no meio do jogo)
	if not _ligada:
		return
	match fonte:
		"android":
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
	_mat.set_shader_parameter("tipo", tipo)
	if tam.x > 1.0 and tam.y > 1.0:
		var asp := tam.x / tam.y
		_mat.set_shader_parameter("escala_uv", Vector2(1.0 / asp, 1.0) if asp >= 1.0 else Vector2(1.0, asp))
	# a câmera pode estar montada de lado/ao contrário: o operador acerta
	# no menu ("Giro da câmera")
	_mat.set_shader_parameter("giro", int(Ajustes.valor("jogo", "camera_giro")) / 90 % 4)
	_mat.set_shader_parameter("espelhar", bool(Ajustes.valor("jogo", "camera_espelho")))


## Android: Y e UV (4:2:0) do plugin viram duas texturas; a cor sai no shader.
var _conferir_t := 0.0


func _quadro_android() -> void:
	# a TV Box pausou o app (o plugin solta a câmera): liga de novo
	_conferir_t += get_process_delta_time()
	if _conferir_t > 1.0:
		_conferir_t = 0.0
		if str(_plugin.call("estado")) == "parada":
			_plugin.call("abrir", "auto", W_FF, H_FF)
	var n := int(_plugin.call("quadros"))
	if n == _quadro_visto:
		return
	_quadro_visto = n
	var w := int(_plugin.call("largura"))
	var h := int(_plugin.call("altura"))
	if w < 2 or h < 2:
		return
	var y: PackedByteArray = _plugin.call("plano_y")
	var uv: PackedByteArray = _plugin.call("plano_uv")
	if y.size() != w * h or uv.size() != (w / 2) * (h / 2) * 2:
		return
	var iy := Image.create_from_data(w, h, false, Image.FORMAT_L8, y)
	var iuv := Image.create_from_data(w / 2, h / 2, false, Image.FORMAT_RG8, uv)
	if _img_y == null or _img_y.get_size() != iy.get_size():
		_tex_a = ImageTexture.create_from_image(iy)
		_tex_b = ImageTexture.create_from_image(iuv)
		_mat.set_shader_parameter("cam_a", _tex_a)
		_mat.set_shader_parameter("cam_b", _tex_b)
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
	var args := PackedStringArray(["-hide_banner", "-loglevel", "error", "-f", "dshow", "-rtbufsize", "64M",
		"-i", "video=" + _ff_dispositivo,
		"-vf", "scale=%d:%d:force_original_aspect_ratio=increase,crop=%d:%d" % [W_FF, H_FF, W_FF, H_FF],
		"-r", "15", "-pix_fmt", "rgb24", "-f", "rawvideo", "-"])
	var r := OS.execute_with_pipe(_ffmpeg, args, true)
	if r.is_empty():
		_mudar("sem_camera")
		return
	_ff_pid = int(r["pid"])
	_ff_rodando = true
	_ff_linha = Thread.new()
	_ff_linha.start(_ler_ffmpeg.bind(r["stdio"]))


func _ler_ffmpeg(cano: FileAccess) -> void:
	var tam := W_FF * H_FF * 3
	var acumulado := PackedByteArray()
	var vazios := 0
	while _ff_rodando:
		var pedaco := cano.get_buffer(tam - acumulado.size())
		if pedaco.is_empty():
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
			acumulado = PackedByteArray()
	cano.close()


func _quadro_ffmpeg() -> void:
	_ff_trava.lock()
	var novo := _ff_novo
	var dados := _ff_quadro
	_ff_novo = false
	_ff_trava.unlock()
	if not novo:
		return
	var img := Image.create_from_data(W_FF, H_FF, false, Image.FORMAT_RGB8, dados)
	if _img_rgb == null:
		_tex_a = ImageTexture.create_from_image(img)
		_mat.set_shader_parameter("cam_a", _tex_a)
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
	_parar_ffmpeg()
	if _ff_busca != null:
		_ff_busca.wait_to_finish()
	if _plugin != null:
		_plugin.call("fechar")


# ================================================================ foto
## Tira a foto (a câmera precisa estar ligada há alguns quadros). Volta a
## textura, ou null se a câmera não mandou imagem.
func tirar(chave: String) -> ImageTexture:
	if not _ligada or not tem_imagem():
		return null
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	if img == null or img.is_empty() or _escura(img):
		return null
	img.convert(Image.FORMAT_RGB8)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	fotos[chave] = t
	if _falsa != null and _falsas.size() > 1:
		# câmera de teste: o próximo jogador é outra criança
		_falsa_base = _falsas[(_falsas.find(_falsa_base) + 1) % _falsas.size()]
	return t


func _escura(img: Image) -> bool:
	var soma := 0.0
	for i in 64:
		var c := img.get_pixel((i * 37) % img.get_width(), (i * 53) % img.get_height())
		soma += c.r + c.g + c.b
	return soma / (64.0 * 3.0) < 0.03


func foto(chave: String) -> Texture2D:
	return fotos.get(chave)


func limpar_partida() -> void:
	fotos.clear()


## Grava a foto num arquivo (para a classificação e o recorde).
func gravar(chave: String, nome_arquivo: String) -> String:
	var t: ImageTexture = fotos.get(chave)
	if t == null:
		return ""
	var caminho := PASTA + nome_arquivo
	t.get_image().save_png(caminho)
	return caminho


## Carrega uma foto gravada (com cache).
func carregar(caminho: String) -> Texture2D:
	if caminho == "":
		return null
	if _recordes.has(caminho):
		return _recordes[caminho]
	var t: Texture2D = null
	if FileAccess.file_exists(caminho):
		var img := Image.load_from_file(caminho)
		if img != null and not img.is_empty():
			img.generate_mipmaps()
			t = ImageTexture.create_from_image(img)
	_recordes[caminho] = t
	return t


# ---------------------------------------------------------------- recorde
func salvar_recorde(chave: String, jogadores: int) -> String:
	var caminho := gravar(chave, "recorde_j%d.png" % jogadores)
	_recordes.erase(caminho)
	return caminho


func foto_recorde(jogadores: int) -> Texture2D:
	return carregar(str(Ajustes.recorde(jogadores).get("foto", "")))


func apagar_recordes() -> void:
	_recordes.clear()
	for f in DirAccess.get_files_at(PASTA):
		if f.begins_with("recorde_") or f.begins_with("rank_"):
			DirAccess.remove_absolute(PASTA + f)


# ---------------------------------------------------------------- câmera de teste (PC)
func _criar_falsa() -> void:
	_falsa = FeedFalso.new()
	_falsa.set_name("Câmera de teste")
	for c in ["res://tools/testes/foto_teste.png", "res://tools/testes/foto_teste_2.png"]:
		var cam := ProjectSettings.globalize_path(c)
		if FileAccess.file_exists(cam):
			var im := Image.load_from_file(cam)
			if im != null and not im.is_empty():
				im.convert(Image.FORMAT_RGB8)
				_falsas.append(im)
	if not _falsas.is_empty():
		_falsa_base = _falsas[0]
	if _falsa_base == null or _falsa_base.is_empty():
		_falsa_base = Image.create(640, 480, false, Image.FORMAT_RGB8)
		_falsa_base.fill(Color(0.3, 0.6, 0.9))
		_falsa_base.fill_rect(Rect2i(220, 120, 200, 240), Color(1.0, 0.8, 0.65))
	_falsa_base.convert(Image.FORMAT_RGB8)
	_falsa.set_rgb_image(_falsa_base)
	CameraServer.add_feed(_falsa)


func _atualizar_falsa() -> void:
	# mexe um tiquinho, para parecer imagem ao vivo
	var img := _falsa_base.duplicate() as Image
	var dx := int(sin(_falsa_t * 2.0) * 6.0)
	if dx != 0:
		img.blit_rect(_falsa_base, Rect2i(maxi(0, -dx), 0, img.get_width() - absi(dx), img.get_height()), Vector2i(maxi(0, dx), 0))
	_falsa.set_rgb_image(img)
