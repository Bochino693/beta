extends SceneTree

## (PC) foto das bolas do Bob e da Mia paradas na pista, de perto.
##   godot3 --video-driver GLES2 --path . -s res://tools/testes/foto_bolas.gd -- --pasta=<pasta>

var p: Node
var n := 0
var pasta := "user://bolas"
var _q := 0
var _vez := 0


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
		var quem: String = ["bob", "mia"][_vez]
		p.bola.vestir(quem)
		p.bola.ensaio(Vector3(0.0, Bola.RAIO, -1.0))
		p.cam.corte(Vector3(0.25, 0.32, -0.45), Vector3(0.0, Bola.RAIO, -1.0), 32, 32)
	elif _q == 20:
		var img: Image = p.foto_3d()
		img.save_png("%s/bola_%s.png" % [pasta, ["bob", "mia"][_vez]])
		print("FOTO bola ", ["bob", "mia"][_vez])
		_vez += 1
		_q = 0
		if _vez >= 2:
			return true
	return false
