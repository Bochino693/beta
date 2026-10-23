extends SceneTree

## (PC) GALERIA DOS MODELOS DO CENÁRIO: uma foto de cada modelo, sozinho,
## com o material e a luz do jogo (para comparar versões dos modelos).
##   godot3 --video-driver GLES2 --path . -s res://tools/testes/galeria_modelos.gd -- --pasta=<fotos> [--modelos=<pasta dos .res>] [--contorno]
## (--modelos: por padrão res://modelos/cenario; pode ser uma pasta de fora
## com outra versão dos mesmos .res)

const ONDE := Vector3(0, 60, -30)

var p: Node
var n := 0
var pasta := "user://galeria"
var modelos := "res://modelos/cenario"
var contorno := 0.0
var _nomes := []
var _i := 0
var _q := 0
var _mi: MeshInstance


func _init() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("--pasta="):
			pasta = a.substr(8)
		elif a.begins_with("--modelos="):
			modelos = a.substr(10)
		elif a == "--contorno":
			contorno = 0.004
	Directory.new().make_dir_recursive(pasta)
	var d := Directory.new()
	if d.open(modelos) == OK:
		d.list_dir_begin(true, true)
		var f := d.get_next()
		while f != "":
			if f.ends_with(".res"):
				_nomes.append(f)
			f = d.get_next()
	_nomes.sort()
	p = load("res://cenas/principal.tscn").instance()
	root.add_child(p)


func _idle(_d: float) -> bool:
	n += 1
	if p._preparando or n < 60:
		return false
	_q += 1
	if _q == 1:
		if _i == 0:
			p.set_process(false)
			p._novo_seq()
			p.sem_msaa()
			p.hud.visible = false
			# a capa da preparação (aquecer.gd) ainda sumindo: sai já
			for c in p.get_children():
				if c is CanvasLayer and (c as CanvasLayer).layer == 120:
					c.queue_free()
			for nome in p.personagens:
				(p.personagens[nome] as Spatial).visible = false
		if _mi:
			_mi.queue_free()
		_mi = MeshInstance.new()
		_mi.mesh = load(modelos.plus_file(_nomes[_i]))
		_mi.material_override = p.mundo.temas._mat_modelo(_nomes[_i].get_basename(), contorno, Color.white)
		_mi.translation = ONDE
		p.mundo.add_child(_mi)
		var caixa: AABB = _mi.mesh.get_aabb()
		var c: Vector3 = ONDE + caixa.position + caixa.size * 0.5
		var r: float = max(caixa.size.length() * 0.5, 0.05)
		var dir := Vector3(0.55, 0.35, 1.0).normalized()
		p.cam.corte(c + dir * r * 2.6, c, 40, 40)
	elif _q == 10:
		var img: Image = p.foto_3d()
		img.save_png("%s/%s.png" % [pasta, _nomes[_i].get_basename()])
		_i += 1
		_q = 0
		if _i >= _nomes.size():
			print("GALERIA: %d modelos" % _nomes.size())
			return true
	return false
