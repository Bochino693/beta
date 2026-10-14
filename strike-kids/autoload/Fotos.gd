extends Node

## A CÂMERA DA MÁQUINA (webcam USB, ex.: a câmera Sigma ligada na TV Box) e
## as FOTOS DAS CRIANÇAS. Quando a partida começa, cada jogador tira uma
## foto ("SORRIA!" 3-2-1) e o rostinho aparece no placar, na faixa
## "VEZ DE", no strike, na tela final e no quadro de recorde.
##
## Usa o CameraServer do Godot 4.6. No Android: permissão CAMERA e a webcam
## USB precisa aparecer como câmera do sistema (TV Box com Android 9 ou
## mais costuma mostrar como câmera "externa"). Sem câmera, o jogo segue
## normalmente com os mascotes no lugar das fotos.
##
## As fotos ficam SÓ na TV Box (user://fotos/): as da partida ficam na
## memória e somem na partida seguinte; a do recorde fica gravada até o
## recorde ser batido ou zerado no menu do operador.
##
## Teste no PC sem webcam: godot --path . -- --camera-falsa

signal mudou

const PASTA := "user://fotos/"
const LADO := 384                  # foto quadrada, em pixels
const PERMISSAO := "android.permission.CAMERA"

var status := "procurando"         # procurando | desligada | sem_permissao | sem_camera | pronta
var nome_camera := ""
var feed: CameraFeed
var fotos := {}                    # "j0", "j1" -> ImageTexture (só desta partida)
var _vp: SubViewport
var _mat: ShaderMaterial
var _tex_a: CameraTexture
var _tex_b: CameraTexture
var _ligada := false
var _desligar_em := -1.0
var _falsa: CameraFeed
var _falsa_base: Image
var _falsas: Array[Image] = []
var _falsa_t := 0.0
var _recordes := {}


class FeedFalso extends CameraFeed:
	func _activate_feed() -> bool:
		return true

	func _deactivate_feed() -> void:
		pass


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(PASTA)
	_vp = SubViewport.new()
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
	CameraServer.camera_feed_added.connect(func(_id): _procurar.call_deferred())
	CameraServer.camera_feed_removed.connect(func(_id): _procurar.call_deferred())
	if "--camera-falsa" in OS.get_cmdline_user_args() or OS.has_environment("STRIKE_CAMERA_FALSA"):
		_criar_falsa()
	# como na S905L: a câmera só acorda depois da abertura do jogo
	get_tree().create_timer(3.5).timeout.connect(iniciar)


func pronta() -> bool:
	return status == "pronta" and feed != null


func texto_status() -> String:
	match status:
		"pronta":
			return "OK (%s)" % nome_camera
		"desligada":
			return "desligada no menu"
		"sem_permissao":
			return "sem permissão do Android"
		"sem_camera":
			return "nenhuma câmera encontrada"
	return "procurando..."


func iniciar() -> void:
	if not bool(Ajustes.valor("jogo", "foto")):
		_mudar("desligada")
		return
	if status == "desligada":
		_mudar("procurando")
	if OS.get_name() == "Android" and not OS.get_granted_permissions().has(PERMISSAO):
		_mudar("sem_permissao")
		if not get_tree().on_request_permissions_result.is_connected(_permissao):
			get_tree().on_request_permissions_result.connect(_permissao)
		OS.request_permission(PERMISSAO)
		return
	CameraServer.monitoring_feeds = true
	_procurar.call_deferred()


func _permissao(nome: String, ok: bool) -> void:
	if nome == PERMISSAO and ok:
		CameraServer.monitoring_feeds = true
		_procurar.call_deferred()


func _mudar(s: String) -> void:
	if s != status:
		status = s
		mudou.emit()


## Escolhe a câmera: a de teste, senão a webcam USB (externa), senão a primeira.
func _procurar() -> void:
	if status == "desligada" or not CameraServer.monitoring_feeds:
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
		_tex_a = CameraTexture.new()
		_tex_a.camera_feed_id = feed.get_id()
		_tex_a.which_feed = CameraServer.FEED_RGBA_IMAGE
		_tex_b = CameraTexture.new()
		_tex_b.camera_feed_id = feed.get_id()
		_tex_b.which_feed = CameraServer.FEED_CBCR_IMAGE
		_mat.set_shader_parameter("cam_a", _tex_a)
		_mat.set_shader_parameter("cam_b", _tex_b)
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


## Liga a câmera (para a prévia e a foto).
func ligar() -> bool:
	if not pronta():
		return false
	_desligar_em = -1.0
	if not _ligada:
		feed.feed_is_active = true
		_ligada = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	return true


## Desliga depois de um tempinho (a webcam não gosta de liga-desliga seguido).
func desligar(atraso := 6.0) -> void:
	_desligar_em = atraso


func ao_vivo() -> Texture2D:
	return _vp.get_texture()


func _process(delta: float) -> void:
	if _falsa != null and _ligada:
		_falsa_t += delta
		if fposmod(_falsa_t, 0.1) < delta:
			_atualizar_falsa()
	if _desligar_em >= 0.0:
		_desligar_em -= delta
		if _desligar_em < 0.0 and _ligada:
			feed.feed_is_active = false
			_ligada = false
			_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if _ligada and feed != null:
		_ajustar_shader()


func _ajustar_shader() -> void:
	var tipo := 1
	match feed.get_datatype():
		CameraFeed.FEED_YCBCR:
			tipo = 2
		CameraFeed.FEED_YCBCR_SEP:
			tipo = 3
	_mat.set_shader_parameter("tipo", tipo)
	var tam := _tex_a.get_size()
	if tam.x > 1.0 and tam.y > 1.0:
		var asp := tam.x / tam.y
		_mat.set_shader_parameter("escala_uv", Vector2(1.0 / asp, 1.0) if asp >= 1.0 else Vector2(1.0, asp))
	# a transformação da câmera (feed_transform) não é usada: cada TV Box
	# entrega de um jeito e a câmera pode estar montada de lado/ao contrário.
	# O operador acerta no menu ("Giro da câmera").
	_mat.set_shader_parameter("giro", int(Ajustes.valor("jogo", "camera_giro")) / 90 % 4)
	_mat.set_shader_parameter("espelhar", bool(Ajustes.valor("jogo", "camera_espelho")))


## Tira a foto (a câmera precisa estar ligada há alguns quadros). Volta a
## textura, ou null se a câmera não mandou imagem.
func tirar(chave: String) -> ImageTexture:
	if not _ligada:
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


# ---------------------------------------------------------------- recorde
func salvar_recorde(chave: String, jogadores: int) -> String:
	var t: ImageTexture = fotos.get(chave)
	if t == null:
		return ""
	var caminho := PASTA + "recorde_j%d.png" % jogadores
	t.get_image().save_png(caminho)
	_recordes.erase(jogadores)
	return caminho


func foto_recorde(jogadores: int) -> Texture2D:
	if _recordes.has(jogadores):
		return _recordes[jogadores]
	var caminho := str(Ajustes.recorde(jogadores).get("foto", ""))
	var t: Texture2D = null
	if caminho != "" and FileAccess.file_exists(caminho):
		var img := Image.load_from_file(caminho)
		if img != null and not img.is_empty():
			img.generate_mipmaps()
			t = ImageTexture.create_from_image(img)
	_recordes[jogadores] = t
	return t


func apagar_recordes() -> void:
	_recordes.clear()
	for f in DirAccess.get_files_at(PASTA):
		if f.begins_with("recorde_"):
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
