extends SceneTree

## MODELOS 3D PARA O GODOT 3: lê as malhas exportadas do projeto Godot 4
## (strike-kids/, pelo tools/exportar_godot4.gd: binário .msh + indice.json)
## e grava as mesmas peças em modelos/ no formato do Godot 3 — as mesmas
## posições, normais e cores de vértice, peça por peça.
##   godot3 --no-window --path . --script res://tools/montar_modelos.gd -- <pasta_exportada>

var origem := ""
var _cache := {}


func _malha(arq: String) -> ArrayMesh:
	if _cache.has(arq):
		return _cache[arq]
	var f := File.new()
	if f.open(origem + "/" + arq, File.READ) != OK:
		push_error("sem " + arq)
		return null
	var magica := f.get_buffer(4).get_string_from_ascii()
	assert(magica == "SKM1")
	var m := ArrayMesh.new()
	var n_sup := f.get_32()
	for _s in n_sup:
		var prim := f.get_32()
		var nv := f.get_32()
		var flags := f.get_32()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		var v := PoolVector3Array()
		v.resize(nv)
		for i in nv:
			v[i] = Vector3(f.get_float(), f.get_float(), f.get_float())
		arrays[Mesh.ARRAY_VERTEX] = v
		if flags & 1:
			var n := PoolVector3Array()
			n.resize(nv)
			for i in nv:
				n[i] = Vector3(f.get_float(), f.get_float(), f.get_float())
			arrays[Mesh.ARRAY_NORMAL] = n
		if flags & 2:
			var c := PoolColorArray()
			c.resize(nv)
			for i in nv:
				c[i] = Color(f.get_float(), f.get_float(), f.get_float(), f.get_float())
			arrays[Mesh.ARRAY_COLOR] = c
		if flags & 4:
			var uv := PoolVector2Array()
			uv.resize(nv)
			for i in nv:
				uv[i] = Vector2(f.get_float(), f.get_float())
			arrays[Mesh.ARRAY_TEX_UV] = uv
		if flags & 8:
			var ni := f.get_32()
			var idx := PoolIntArray()
			idx.resize(ni)
			for i in ni:
				idx[i] = f.get_32()
			arrays[Mesh.ARRAY_INDEX] = idx
		# cores em 8 bits e normais compactadas (padrão); posição em float
		m.add_surface_from_arrays(prim, arrays)
	f.close()
	_cache[arq] = m
	return m


func _xf(a: Array) -> Transform:
	return Transform(Basis(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]), Vector3(a[6], a[7], a[8])),
		Vector3(a[9], a[10], a[11]))


func _no(d: Dictionary, raiz: Node) -> Spatial:
	var n: Spatial
	if d.has("malha"):
		var mi := MeshInstance.new()
		mi.mesh = _malha(d["malha"])
		n = mi
	else:
		n = Spatial.new()
	n.name = d["nome"]
	if d.has("xf"):
		n.transform = _xf(d["xf"])
	n.visible = d.get("visivel", true)
	for c in d["filhos"]:
		var filho := _no(c, raiz if raiz else n)
		n.add_child(filho)
	return n


func _dono(n: Node, raiz: Node) -> void:
	for c in n.get_children():
		c.owner = raiz
		_dono(c, raiz)


func _init() -> void:
	var args := OS.get_cmdline_args()
	origem = args[args.size() - 1]
	var f := File.new()
	f.open(origem + "/indice.json", File.READ)
	var indice: Dictionary = parse_json(f.get_as_text())
	f.close()
	var n := 0
	for rel in indice:
		var item: Dictionary = indice[rel]
		var destino: String = "res://" + rel
		Directory.new().make_dir_recursive(destino.get_base_dir())
		var r: Resource
		if item.has("cena"):
			var raiz := _no(item["cena"], null)
			_dono(raiz, raiz)
			var cena := PackedScene.new()
			cena.pack(raiz)
			raiz.free()
			r = cena
		elif item.has("malha"):
			r = _malha(item["malha"])
		elif item.has("convexa"):
			var pts := PoolVector3Array()
			var p: Array = item["convexa"]
			for i in range(0, p.size(), 3):
				pts.append(Vector3(p[i], p[i + 1], p[i + 2]))
			var forma := ConvexPolygonShape.new()
			forma.points = pts
			r = forma
		if ResourceSaver.save(destino, r, ResourceSaver.FLAG_COMPRESS) != OK:
			push_error("não gravou " + destino)
		else:
			n += 1
	print("MONTADOS ", n, " de ", indice.size())
	quit()
