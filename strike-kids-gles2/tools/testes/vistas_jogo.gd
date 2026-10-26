extends SceneTree

## VISTAS DO JOGO (6.9): fotos das câmeras de verdade de cada fase — a
## pista de frente (de onde a criança joga), a vista larga da espera/fim, a
## de cima e uma olhando o fundo do cenário — com o custo de cada uma
## (vértices e desenhos), para comparar o visual antes e depois.
##   godot3 --video-driver GLES2 --path . --resolution 1080x1920 -s res://tools/testes/vistas_jogo.gd -- --pasta=<fotos> [--temas=mar,dinos]

var p: Node
var n := 0
var pasta := "user://vistas"
var _fila := []
var _espera := 0
var _atual := ""
var _tema := ""
var _so_vistas := []

const VISTAS := {
	# a pista de frente (principal.gd: POS_PISTA, ALVO_PISTA, 34 / 40)
	"jogo": [Vector3(0.0, 1.05, 2.2), Vector3(0.0, 0.18, -9.9), 34, 40],
	# a vista larga da espera, da escolha e do fim
	"larga": [Vector3(0.0, 1.35, 6.6), Vector3(0.0, 1.1, 2.3), 40, 44],
	# do alto (a espera vista de cima)
	"alto": [Vector3(0.0, 4.5, 6.5), Vector3(0.0, 0.0, -2.0), 50, 50],
	# o fundo do cenário (o que fica atrás do gabinete)
	"fundo": [Vector3(0.0, 3.2, -4.0), Vector3(0.0, 4.0, -40.0), 50, 50],
}


func _init() -> void:
	var so := []
	for a in OS.get_cmdline_args():
		if a.begins_with("--pasta="):
			pasta = a.substr(8)
		elif a.begins_with("--temas="):
			so = Array(a.substr(8).split(","))
		elif a.begins_with("--vistas="):
			_so_vistas = Array(a.substr(9).split(","))
	Directory.new().make_dir_recursive(pasta)
	for t in Temas.ORDEM:
		if so.empty() or t in so:
			_fila.append(t)
	p = load("res://cenas/principal.tscn").instance()
	root.add_child(p)


func _idle(_d: float) -> bool:
	n += 1
	if _tema == "":
		if p._preparando or n < 30:
			return false
		p.set_process(false)
		p.set_physics_process(false)
		# (o llvmpipe devolve a imagem preta com o MSAA da OpenGL ES 2.0)
		p.sem_msaa()
		p.hud.visible = false
		p._novo_seq()
		p.bola.guardar()
		for nome in p.personagens:
			(p.personagens[nome] as Spatial).visible = false
		_tema = "?"
		return false
	if _espera > 0:
		_espera -= 1
		if _espera == 0:
			_foto()
		return false
	if _fila.empty():
		return true
	var item = _fila.pop_front()
	if item is String:
		_tema = item
		p.mundo.aplicar_tema(_tema)
		p.pinos.repor_todos()
		var depois := []
		for v in VISTAS:
			if _so_vistas.empty() or v in _so_vistas:
				depois.append(v)
		depois.invert()
		for d in depois:
			_fila.push_front([d])
		_espera = 20
		_atual = ""
	else:
		var v: Array = VISTAS[item[0]]
		p.cam.corte(v[0], v[1], v[2], v[3])
		_atual = item[0]
		_espera = 10
	return false


func _foto() -> void:
	if _atual == "":
		return
	var img: Image = p.foto_3d()
	var nome := "%s/%s_%s.png" % [pasta, _tema, _atual]
	img.save_png(nome)
	print("VISTA %-7s %-6s vertices=%7d desenhos=%4d" % [_tema, _atual,
		Performance.get_monitor(Performance.RENDER_VERTICES_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_DRAW_CALLS_IN_FRAME)])
