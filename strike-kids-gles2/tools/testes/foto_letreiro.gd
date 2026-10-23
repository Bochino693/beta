extends SceneTree

## (PC) fotos de perto dos letreiros STRIKE KIDS em 3D: o do fim da pista
## (em cima dos pinos) e o de trás dos jogadores.
##   godot3 --video-driver GLES2 --path . -s res://tools/testes/foto_letreiro.gd -- --pasta=<pasta>

var p: Node
var n := 0
var pasta := "user://letreiro"
var _q := 0
var _vez := 0
const VISTAS := [
	# [nome, câmera, alvo, fov]
	["fundo_perto", Vector3(0.0, 1.9, -7.4), Vector3(0.0, 1.86, -9.67), 40],
	["fundo_longe", Vector3(0.0, 1.0, -2.0), Vector3(0.0, 1.4, -9.67), 30],
	["tras", Vector3(0.0, 2.4, 4.2), Vector3(0.0, 2.55, 7.5), 50],
]


func _init() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("--pasta="):
			pasta = a.substr(8)
	Directory.new().make_dir_recursive(pasta)
	p = load("res://cenas/principal.tscn").instance()
	root.add_child(p)


func _idle(_d: float) -> bool:
	n += 1
	if p._preparando or n < 60:
		return false
	_q += 1
	if _q == 1:
		p.set_process(false)
		p._novo_seq()
		p.sem_msaa()
		p.hud.visible = false
		for nome in p.personagens:
			(p.personagens[nome] as Spatial).visible = false
		var v: Array = VISTAS[_vez]
		p.cam.corte(v[1], v[2], v[3], v[3])
	elif _q == 20:
		var img: Image = p.foto_3d()
		img.save_png("%s/%s.png" % [pasta, VISTAS[_vez][0]])
		print("FOTO ", VISTAS[_vez][0])
		_vez += 1
		_q = 0
		if _vez >= VISTAS.size():
			return true
	return false
