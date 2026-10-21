extends SceneTree

## Quanto custa desenhar cada vista do jogo (chamadas de desenho, objetos,
## vértices, trocas de material) — o que mais pesa no processador de uma
## TV Box com Mali-400/450 e OpenGL ES 2.0.
##   godot3 --video-driver GLES2 --path . -s res://tools/testes/medir_desenho.gd

var p: Node
var n := 0


func _init() -> void:
	p = load("res://cenas/principal.tscn").instance()
	root.add_child(p)


func _idle(_d: float) -> bool:
	n += 1
	if n % 60 == 0:
		print("quadro %4d %-9s desenhos=%4d objetos=%4d vertices=%6d materiais=%3d shaders=%3d" % [n, p.E.keys()[p.estado],
			Performance.get_monitor(Performance.RENDER_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_VERTICES_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_MATERIAL_CHANGES_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_SHADER_CHANGES_IN_FRAME)])
	return n >= 900
