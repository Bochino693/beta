class_name Aquecer
extends Viewport

## PREPARAR TUDO ANTES DA ABERTURA (evita os "engasgos").
##
## A placa de vídeo só prepara (compila) o desenho de um material na
## primeira vez em que ele aparece na tela — e isso trava o jogo por um
## instante: na troca de cenário, na primeira bola de fogo, no confete...
## Na Mali-400/450 cada um leva dezenas de milissegundos (são uns 70).
##
## Por isso, logo ao abrir, uma CAPA igual à imagem de abertura da TV Box
## (com uma barrinha de progresso) cobre a tela enquanto:
##   1) uma telinha escondida de 96x96, que enxerga o MESMO mundo 3D,
##      desenha uma amostra de cada material do jogo — inclusive os dos
##      cenários que ainda não apareceram, partículas, lâmpadas (MultiMesh)
##      e o rastro da bola — e os materiais e imagens 2D da interface. Poucas
##      amostras por quadro: a tela segue viva (sem "o app não responde")
##      e a barrinha anda;
##   2) as LETRAS de cada fonte (tamanho e contorno) que o jogo usa: no
##      Godot 3 cada letra nova é desenhada pela FreeType e a página inteira
##      de letras vai de novo para a placa de vídeo — números do placar,
##      contagens e letreiros apareciam com um tranquinho na primeira vez;
##   3) ENSAIO GERAL, de verdade e por baixo da capa (principal.ensaio): a
##      tela do jogo volta a ser desenhada com a bola de fogo e o rastro,
##      estrelas, confete, poeira, fogos, pinos tontos, os jatos dos
##      bichinhos, e a logo aparecendo e sumindo com o brilho e as
##      estrelinhas — do jeito que vão aparecer: uma amostra nem sempre é
##      desenhada do mesmo jeito (o rastro, a logo que some aos poucos...).
## Só então a capa sai (sinal `pronto`) e a abertura começa, lisa. A
## telinha e as amostras são apagadas no fim. Durante as amostras a tela do
## jogo fica parada (principal), senão ela compilava tudo de uma vez no
## primeiro quadro.

signal pronto

const ALTURA := 400.0      # lá no alto, longe de tudo que a câmera do jogo vê
## amostras novas por quadro (cada uma pode ser um shader a compilar)
const POR_QUADRO := 4
## o ensaio geral: no mínimo este tempo (s de verdade) e estes quadros,
## para tudo o que ele dispara ter aparecido (a logo some na metade)
const ENSAIO_S := 1.0
const ENSAIO_QUADROS := 12
## letras preparadas em cada fonte; nas gigantes (contagem, números que
## voam) só os números — cada letra enorme ocupa muito da página de letras
const LETRAS := "0123456789 ABCDEFGHIJKLMNOPQRSTUVWXYZÁÉÍÓÚÂÊÔÃÕÇ!?:.,%-+()/&"
const MINUSCULAS := "abcdefghijklmnopqrstuvwxyzáéíóúâêôãõç"
const NUMEROS := "0123456789 +!"
const FONTES_POR_QUADRO := 3
const SAIDA_S := 0.3
## amostras apagadas por quadro no fim (por trás da capa)
const APAGAR_POR_QUADRO := 24
## Imagens que só aparecem mais tarde (letreiros do resultado, cartões dos
## cenários, fim de jogo, a bola de cada bichinho): carregadas já aqui —
## ler e mandar para a placa de vídeo na primeira vez que aparecessem dava
## um tranco (na TV Box, bem visível).
const TEXTURAS := ["strike", "spare", "ops", "boa", "super", "uau", "quase", "pegando_fogo", "empate",
	"novo_recorde", "parabens", "venceu", "fim_de_jogo", "replay", "cen_dinos", "cen_parque", "cen_espaco",
	"cen_mar", "estrela", "estrela_placar", "estrela_vazia", "bola_bob", "bola_mia", "retrato_bob",
	"retrato_mia", "retrato_bob_empolgado", "retrato_mia_empolgado"]

var _fila := []            # amostras ainda não postas na telinha
var _total := 1
var _lado := 1
var _postas := 0
var _interface: Node
var _ensaio: Object        # quem faz o ensaio geral (principal.ensaio(fase))
var _etapa := 0            # 0 amostras, 1 letras, 2 ensaio geral, 3 limpando, 4 saindo
var _fontes := []
var _meio := false
var _t := 0.0
var _quadros := 0
var _inicio_ms := OS.get_ticks_msec()
var _capa: CanvasLayer
var _fundo: Control
var _barra: ColorRect
var _trilho: ColorRect


func preparar(vp: Viewport, interface: Node, extras: Array = [], ensaio: Object = null) -> void:
	_interface = interface
	_ensaio = ensaio
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	size = Vector2(96, 96)
	# o MESMO mundo (e a mesma neblina e o mesmo jeito de desenhar) da tela do jogo
	world = vp.find_world()
	msaa = vp.msaa
	usage = vp.usage
	hdr = vp.hdr
	render_target_update_mode = Viewport.UPDATE_ALWAYS
	_montar_capa()
	var cam := Camera.new()
	cam.fov = 75.0
	cam.far = 40.0
	add_child(cam)
	cam.current = true
	var amostras := _amostras_3d(vp)
	# materiais que ainda não estão na cena (as partículas dos efeitos:
	# estrelas, confete, faíscas, fumaça) — desenhadas em MultiMesh
	for m in extras:
		if m is Material:
			amostras.append(_multi(_quad(), m, true, true))
	_lado = int(ceil(sqrt(float(max(amostras.size(), 1)))))
	cam.translation = Vector3(0, ALTURA, max(6.0, _lado * 0.6))
	for i in amostras.size():
		var x: float = float(i % _lado) - _lado * 0.5
		var y: float = float(i / _lado) - _lado * 0.5
		(amostras[i] as Spatial).translation = Vector3(x * 0.6, ALTURA + y * 0.6, 0.0)
	_fila = amostras
	var n_2d := _fila.size()
	_fila.append_array(_amostras_2d(interface))
	n_2d = _fila.size() - n_2d
	_total = max(_fila.size(), 1)
	print("Aquecer: %d materiais 3D, %d amostras 2D" % [amostras.size(), n_2d])


func _process(delta: float) -> void:
	_quadros += 1
	_t += delta / max(Engine.time_scale, 0.01)
	match _etapa:
		0:
			# poucas amostras novas por quadro (os shaders compilam aos poucos)
			for i in POR_QUADRO:
				if _fila.empty():
					break
				add_child(_fila.pop_front())
				_postas += 1
			_progresso(0.7 * float(_postas) / float(_total))
			if _fila.empty():
				_etapa = 1
				_fontes = (Compat.estado("fontes") as Dictionary).keys()
		1:
			# as letras de algumas fontes por quadro
			for i in FONTES_POR_QUADRO:
				if _fontes.empty():
					break
				_preparar_letras(_fontes.pop_back())
			_progresso(0.8 - 0.1 * float(_fontes.size()) / float(max((Compat.estado("fontes") as Dictionary).size(), 1)))
			if _fontes.empty():
				_etapa = 2
				_t = 0.0
				_quadros = 0
				_fase_ensaio(0)
		2:
			_progresso(0.8 + 0.2 * min(_t / ENSAIO_S, 1.0))
			if not _meio and _t >= ENSAIO_S * 0.5:
				_meio = true
				_fase_ensaio(1)
			if _t >= ENSAIO_S and _quadros >= ENSAIO_QUADROS:
				_fase_ensaio(2)
				_etapa = 3
				render_target_update_mode = Viewport.UPDATE_DISABLED
		3:
			# as amostras saem da memória AOS POUCOS, ainda por trás da capa:
			# apagar as ~270 de uma vez travava o primeiro quadro da
			# abertura (22 ms no PC, uns 150 ms na TV Box)
			var apagar := []
			for c in get_children():
				if c is Camera:
					continue
				apagar.append(c)
				if apagar.size() >= APAGAR_POR_QUADRO:
					break
			for c in apagar:
				remove_child(c)
				c.free()
			if apagar.empty():
				_etapa = 4
				_progresso(1.0)
				print("Aquecer: pronto em %d ms" % (OS.get_ticks_msec() - _inicio_ms))
				# a capa some num instante e o jogo começa
				var tw := _capa.create_tween()
				tw.tween_property(_fundo, "modulate:a", 0.0, SAIDA_S)
				tw.tween_callback(_capa, "queue_free")
				emit_signal("pronto")
		4:
			# a telinha (já vazia) sai da memória
			queue_free()


## Desenha (sem mostrar) as letras de uma fonte (Compat.fonte: chave
## "nome|tamanho|contorno"): pedir o tamanho do texto já desenha cada letra.
func _preparar_letras(chave: String) -> void:
	var f: DynamicFont = Compat.estado("fontes").get(chave)
	if f == null:
		return
	if f.size >= 100:
		f.get_string_size(NUMEROS)
		return
	f.get_string_size(LETRAS)
	if chave.begins_with("fredoka"):
		f.get_string_size(MINUSCULAS)


## 0 começa o ensaio geral, 1 metade (a logo começa a sumir), 2 fim.
func _fase_ensaio(fase: int) -> void:
	if _ensaio != null and _ensaio.has_method("ensaio"):
		_ensaio.ensaio(fase)


## A CAPA: a mesma imagem e a mesma cor de fundo da abertura da TV Box
## (project.godot), por cima de tudo — quem olha não vê a troca da abertura
## do Android para o jogo. Em pé (monitor girado): ui/splash.png, que a
## rotação da tela deixa igual à splash_giro_*.png do APK; deitada: a
## splash_giro_0.png.
func _montar_capa() -> void:
	_capa = CanvasLayer.new()
	_capa.layer = 120
	_capa.pause_mode = Node.PAUSE_MODE_PROCESS
	get_parent().add_child(_capa)
	_fundo = ColorRect.new()
	_fundo.color = Compat.config("application/boot_splash/bg_color", Color(0.024, 0.078, 0.188))
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Tela.cobrir(_fundo)
	_capa.add_child(_fundo)
	var caminho := "res://ui/splash.png"
	if not Tela.em_pe() and ResourceLoader.exists("res://ui/splash_giro_0.png"):
		caminho = "res://ui/splash_giro_0.png"
	var img := TextureRect.new()
	img.texture = load(caminho)
	img.expand = true
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Tela.cobrir(img)
	_fundo.add_child(img)
	# barrinha de progresso discreta, embaixo
	var T: Vector2 = Tela.tamanho()
	var larg: float = min(T.x, T.y) * 0.42
	_trilho = ColorRect.new()
	_trilho.color = Color(1, 1, 1, 0.16)
	_trilho.rect_size = Vector2(larg, 8)
	_trilho.rect_position = Vector2((T.x - larg) * 0.5, T.y * 0.93)
	_trilho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fundo.add_child(_trilho)
	_barra = ColorRect.new()
	_barra.color = Color("#FFD43B")
	_barra.rect_size = Vector2(0, 8)
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trilho.add_child(_barra)


func _progresso(f: float) -> void:
	if _barra:
		_barra.rect_size.x = _trilho.rect_size.x * clamp(f, 0.0, 1.0)


## Todos os nós debaixo de `no` (ele não entra) que são da classe `classe`
## (Godot 3: sem find_children).
static func _descendentes(no: Node, classe: String, saida := []) -> Array:
	for f in no.get_children():
		if f.is_class(classe):
			saida.append(f)
		_descendentes(f, classe, saida)
	return saida


## Uma amostra para cada combinação de material + tipo de desenho.
func _amostras_3d(vp: Viewport) -> Array:
	var r := []
	var vistos := {}
	for no in _descendentes(vp, "GeometryInstance"):
		if no is MeshInstance:
			var mi := no as MeshInstance
			if mi.mesh == null:
				continue
			for s in mi.mesh.get_surface_count():
				var m: Material = mi.get_active_material(s)
				if m == null or vistos.has(_chave(m, 0)):
					continue
				vistos[_chave(m, 0)] = true
				var a := MeshInstance.new()
				a.mesh = mi.mesh if mi.mesh.get_surface_count() == 1 else _quad()
				a.material_override = m
				a.scale = Vector3.ONE * _escala(a.mesh)
				r.append(a)
		elif no is MultiMeshInstance:
			var mmi := no as MultiMeshInstance
			var m: Material = mmi.material_override
			if mmi.multimesh == null or mmi.multimesh.mesh == null:
				continue
			if m == null:
				m = mmi.multimesh.mesh.surface_get_material(0)
			if m == null or vistos.has(_chave(m, 1)):
				continue
			vistos[_chave(m, 1)] = true
			r.append(_multi(mmi.multimesh.mesh, m, mmi.multimesh.color_format != MultiMesh.COLOR_NONE,
				mmi.multimesh.custom_data_format != MultiMesh.CUSTOM_DATA_NONE))
		elif no is CPUParticles:
			var p := no as CPUParticles
			if p.mesh == null:
				continue
			var m: Material = p.material_override if p.material_override else p.mesh.surface_get_material(0)
			if m == null or vistos.has(_chave(m, 2)):
				continue
			vistos[_chave(m, 2)] = true
			r.append(_multi(p.mesh, m, true, true))
		else:
			# desenho feito na hora (ImmediateGeometry: o rastro da bola) —
			# o mesmo shader de uma malha comum
			var gi := no as GeometryInstance
			var m: Material = gi.material_override
			if m == null or vistos.has(_chave(m, 0)):
				continue
			vistos[_chave(m, 0)] = true
			var a := MeshInstance.new()
			a.mesh = _quad()
			a.material_override = m
			r.append(a)
	return r


## Os materiais 2D da interface (painéis, fotos redondas, brilho da marca,
## a imagem 3D...), cada um numa imagem de verdade (com textura, como na
## tela), as imagens que aparecem depois e as estrelinhas 2D (partículas).
func _amostras_2d(interface: Node) -> Array:
	var r := []
	var vistos := {}
	var materiais := []
	for c in _descendentes(interface, "CanvasItem"):
		var m: Material = (c as CanvasItem).material
		if m != null and not vistos.has(m):
			vistos[m] = true
			var tx: Texture = (c as TextureRect).texture if c is TextureRect and (c as TextureRect).texture else Materiais.textura("estrela")
			materiais.append([m, tx])
	if interface.has_method("material_foto"):
		materiais.append([interface.material_foto(Color.white), Materiais.textura("retrato_bob")])
	# cada material de dois jeitos (a OpenGL ES 2.0 do Godot 3 junta
	# desenhos vizinhos num "lote" com outro shader): sozinho, e num trio
	# com transparência, giro e escala — como as fotos e placas animadas
	var n := 0
	var separa: Texture = Materiais.textura("estrela_vazia")
	for par in materiais:
		r.append(_amostra_2d(par[0], par[1], n, Color.white, 0.0))
		r.append(_amostra_2d(null, separa, n + 1, Color.white, 0.0))
		r.append(_amostra_2d(par[0], par[1], n + 2, Color(1, 1, 1, 0.6), 0.0))
		r.append(_amostra_2d(par[0], par[1], n + 3, Color(1, 1, 1, 0.8), 12.0))
		r.append(_amostra_2d(par[0], par[1], n + 4, Color.white, 0.0))
		r.append(_amostra_2d(null, separa, n + 5, Color.white, 0.0))
		n += 6
	var k := 0
	for nome in TEXTURAS:
		var tx := Materiais.textura(nome)
		if tx != null:
			k += 1
			var tr := TextureRect.new()
			tr.texture = tx
			tr.expand = true
			tr.rect_size = Vector2(4, 4)
			tr.rect_position = Vector2(k % 24 * 4, 92)
			r.append(tr)
	var p := CPUParticles2D.new()
	p.texture = Materiais.textura("estrela")
	p.amount = 2
	p.lifetime = 10.0
	p.position = Vector2(48, 48)
	p.emitting = true
	r.append(p)
	return r


func _amostra_2d(m: Material, tx: Texture, i: int, cor: Color, giro: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tx
	t.expand = true
	t.rect_size = Vector2(8, 8)
	t.rect_position = Vector2(i % 12 * 8, i / 12 * 8)
	t.rect_pivot_offset = Vector2(4, 4)
	t.rect_rotation = giro
	t.rect_scale = Vector2.ONE * (0.9 if giro != 0.0 else 1.0)
	t.modulate = cor
	t.material = m
	return t


## Chave de material + tipo de desenho (0 malha, 1 MultiMesh, 2 partículas).
static func _chave(m: Material, tipo: int) -> String:
	return "%d|%d" % [m.get_instance_id(), tipo]


func _escala(m: Mesh) -> float:
	var t := m.get_aabb().get_longest_axis_size()
	return 0.5 / max(t, 0.01)


func _quad() -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.5)
	return q


## As partículas (CPUParticles) e as lâmpadas são desenhadas em MultiMesh:
## é outro "jeito" de desenhar, que também precisa ser preparado.
func _multi(malha: Mesh, m: Material, cores: bool, extra: bool) -> MultiMeshInstance:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	# Godot 3: os formatos antes do número de cópias
	mm.color_format = MultiMesh.COLOR_FLOAT if cores else MultiMesh.COLOR_NONE
	mm.custom_data_format = MultiMesh.CUSTOM_DATA_FLOAT if extra else MultiMesh.CUSTOM_DATA_NONE
	mm.mesh = malha
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform(Basis().scaled(Vector3.ONE * _escala(malha)), Vector3.ZERO))
	if cores:
		mm.set_instance_color(0, Color.white)
	var mmi := MultiMeshInstance.new()
	mmi.multimesh = mm
	mmi.material_override = m
	return mmi
