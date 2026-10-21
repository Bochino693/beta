extends SceneTree

## Compila todos os shaders de res://shaders na placa de vídeo (desenha um
## quadro com cada um) e mostra os erros.
##   godot3 --video-driver GLES2 --path . -s res://tools/testar_shaders.gd

var _n := 0


func _init() -> void:
	var cam := Camera.new()
	cam.translation = Vector3(0, 1, 3)
	root.add_child(cam)
	cam.current = true
	var d := Directory.new()
	d.open("res://shaders")
	d.list_dir_begin(true)
	var nome := d.get_next()
	var x := -6.0
	while nome != "":
		if nome.ends_with(".shader"):
			var sh: Shader = load("res://shaders/" + nome)
			var m := ShaderMaterial.new()
			m.shader = sh
			if sh.get_mode() == Shader.MODE_CANVAS_ITEM:
				var r := TextureRect.new()
				r.texture = load("res://texturas/estrela.png")
				r.material = m
				r.rect_position = Vector2(x * 20 + 200, 100)
				root.add_child(r)
			else:
				var mi := MeshInstance.new()
				mi.mesh = SphereMesh.new()
				mi.material_override = m
				mi.translation = Vector3(x * 0.4, 0, 0)
				root.add_child(mi)
			print("SHADER ", nome)
			_n += 1
			x += 1.0
		nome = d.get_next()


var _quadros := 0


func _idle(_d: float) -> bool:
	_quadros += 1
	if _quadros == 4:
		print("DESENHADOS ", _n)
		return true
	return false
