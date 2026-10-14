extends SceneTree

## ASSADOR DE MODELOS
##
## Lê o que o tools/modelos/modelos.py gravou em tools/modelos/saida
## (.bin + .json) e salva recursos nativos do Godot em res://modelos/:
##   * leo.scn / lia.scn  — personagem montado (juntas + malhas)
##   * pino.res + pino_colisao.res
##   * cenario/<objeto>.res, terreno.res
## Cada malha ganha níveis de detalhe (LOD) automáticos: de longe o Godot
## desenha a versão leve, de perto a completa.
##
## Uso (na pasta do projeto):
##   godot --headless --path . --script res://tools/modelos/assar_modelos.gd

const ENTRADA := "res://tools/modelos/saida/"
const SAIDA := "res://modelos/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA + "cenario"))
	for nome in ["turbo", "rosi"]:
		if FileAccess.file_exists(ENTRADA + nome + ".json"):
			_assar_personagem(nome)
	if FileAccess.file_exists(ENTRADA + "pino.json"):
		_assar_pino()
	if FileAccess.file_exists(ENTRADA + "cenario.json"):
		_assar_soltos("cenario", SAIDA + "cenario/")
	if FileAccess.file_exists(ENTRADA + "terreno.json"):
		_assar_soltos("terreno", SAIDA)
	quit()


func _ler(nome: String) -> Array:
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ENTRADA + nome + ".json"))
	var blob := FileAccess.get_file_as_bytes(ENTRADA + nome + ".bin")
	return [info, blob]


func _malha(parte: Dictionary, blob: PackedByteArray, lod := true) -> ArrayMesh:
	var fv: PackedFloat32Array = blob.slice(parte["v"][0], parte["v"][0] + parte["v"][1]).to_float32_array()
	var fn: PackedFloat32Array = blob.slice(parte["n"][0], parte["n"][0] + parte["n"][1]).to_float32_array()
	var fc: PackedFloat32Array = blob.slice(parte["c"][0], parte["c"][0] + parte["c"][1]).to_float32_array()
	var ii: PackedInt32Array = blob.slice(parte["i"][0], parte["i"][0] + parte["i"][1]).to_int32_array()
	var n := fv.size() / 3
	var v := PackedVector3Array()
	var nn := PackedVector3Array()
	var c := PackedColorArray()
	v.resize(n)
	nn.resize(n)
	c.resize(n)
	for k in n:
		v[k] = Vector3(fv[k * 3], fv[k * 3 + 1], fv[k * 3 + 2])
		nn[k] = Vector3(fn[k * 3], fn[k * 3 + 1], fn[k * 3 + 2])
		c[k] = Color(fc[k * 4], fc[k * 4 + 1], fc[k * 4 + 2], fc[k * 4 + 3])
	# O Godot desenha a face da frente no sentido HORÁRIO; o modelador grava
	# no anti-horário: inverte cada triângulo.
	var idx := PackedInt32Array()
	idx.resize(ii.size())
	for t in ii.size() / 3:
		idx[t * 3] = ii[t * 3]
		idx[t * 3 + 1] = ii[t * 3 + 2]
		idx[t * 3 + 2] = ii[t * 3 + 1]
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = nn
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_INDEX] = idx
	if not lod:
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return am
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	im.generate_lods(25.0, 60.0, [])
	return im.get_mesh()


func _assar_personagem(nome: String) -> void:
	var dados := _ler(nome)
	var info: Dictionary = dados[0]
	var blob: PackedByteArray = dados[1]
	var raiz := Node3D.new()
	raiz.name = nome.capitalize()
	var nos := {}
	for parte in info["partes"]:
		var junta := Node3D.new()
		junta.name = parte["nome"]
		var p: Array = parte["pivo"]
		junta.position = Vector3(p[0], p[1], p[2])
		var pai: Node = raiz if parte["pai"] == "" else nos[parte["pai"]]
		pai.add_child(junta)
		junta.owner = raiz
		var mi := MeshInstance3D.new()
		mi.name = "malha"
		mi.mesh = _malha(parte, blob)
		junta.add_child(mi)
		mi.owner = raiz
		nos[parte["nome"]] = junta
	raiz.set_meta("rosto", info.get("rosto", {}))
	var cena := PackedScene.new()
	cena.pack(raiz)
	var r := ResourceSaver.save(cena, SAIDA + nome + ".scn", ResourceSaver.FLAG_COMPRESS)
	print("personagem ", nome, " -> ", r)
	raiz.free()


func _assar_pino() -> void:
	var dados := _ler("pino")
	var info: Dictionary = dados[0]
	var blob: PackedByteArray = dados[1]
	var m := _malha(info["partes"][0], blob)
	m.set_meta("rosto", info["rosto"])
	print("pino -> ", ResourceSaver.save(m, SAIDA + "pino.res", ResourceSaver.FLAG_COMPRESS))
	var pontos := PackedVector3Array()
	for q in info["casco"]:
		pontos.append(Vector3(q[0], q[1], q[2]))
	var forma := ConvexPolygonShape3D.new()
	forma.points = pontos
	print("pino colisao -> ", ResourceSaver.save(forma, SAIDA + "pino_colisao.res"))


func _assar_soltos(arquivo: String, pasta: String) -> void:
	var dados := _ler(arquivo)
	var info: Dictionary = dados[0]
	var blob: PackedByteArray = dados[1]
	for parte in info["partes"]:
		var m := _malha(parte, blob, parte["nome"] != "terreno")
		var r := ResourceSaver.save(m, pasta + parte["nome"] + ".res", ResourceSaver.FLAG_COMPRESS)
		print(arquivo, "/", parte["nome"], " -> ", r)
