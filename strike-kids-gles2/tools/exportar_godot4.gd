extends SceneTree

## Godot 4: grava cada malha/cena/forma dos modelos num formato neutro
## (binário simples + JSON) para o Godot 3 montar de novo.
##   godot --headless --path . --script exportar_godot4.gd -- <saida>

var saida := ""
var _malhas := {}   # Mesh -> nome do arquivo .msh


func _malha(m: Mesh, nome: String) -> String:
	if _malhas.has(m):
		return _malhas[m]
	var arq := nome + ".msh"
	var f := FileAccess.open(saida + "/" + arq, FileAccess.WRITE)
	f.store_buffer("SKM1".to_ascii_buffer())
	f.store_32(m.get_surface_count())
	for s in m.get_surface_count():
		var a: Array = m.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var n = a[Mesh.ARRAY_NORMAL]
		var c = a[Mesh.ARRAY_COLOR]
		var uv = a[Mesh.ARRAY_TEX_UV]
		var idx = a[Mesh.ARRAY_INDEX]
		f.store_32(m.surface_get_primitive_type(s))
		f.store_32(v.size())
		f.store_32((1 if n != null else 0) | (2 if c != null else 0) | (4 if uv != null else 0) | (8 if idx != null else 0))
		for p in v:
			f.store_float(p.x); f.store_float(p.y); f.store_float(p.z)
		if n != null:
			for p in n:
				f.store_float(p.x); f.store_float(p.y); f.store_float(p.z)
		if c != null:
			for p in c:
				f.store_float(p.r); f.store_float(p.g); f.store_float(p.b); f.store_float(p.a)
		if uv != null:
			for p in uv:
				f.store_float(p.x); f.store_float(p.y)
		if idx != null:
			f.store_32(idx.size())
			for i in idx:
				f.store_32(i)
	f.close()
	_malhas[m] = arq
	return arq


func _xf(t: Transform3D) -> Array:
	return [t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.y.x, t.basis.y.y, t.basis.y.z,
		t.basis.z.x, t.basis.z.y, t.basis.z.z, t.origin.x, t.origin.y, t.origin.z]


func _no(n: Node, base: String, caminho: String) -> Dictionary:
	var d := {"nome": str(n.name), "tipo": n.get_class(), "visivel": n.visible if n is Node3D else true}
	if n is Node3D:
		d["xf"] = _xf(n.transform)
	if n is MeshInstance3D and n.mesh:
		d["malha"] = _malha(n.mesh, base + "__" + caminho.replace("/", "_"))
	var filhos := []
	for c in n.get_children():
		filhos.append(_no(c, base, caminho + "/" + str(c.name)))
	d["filhos"] = filhos
	return d


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	saida = args[0]
	var lista := []
	for d in ["res://modelos", "res://modelos/cenario", "res://modelos/roupas"]:
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".res") or f.ends_with(".scn"):
				lista.append(d + "/" + f)
	var indice := {}
	for p in lista:
		var r = load(p)
		var rel: String = p.trim_prefix("res://")
		var base := rel.get_basename().replace("/", "__")
		if r is PackedScene:
			var raiz: Node = r.instantiate()
			indice[rel] = {"cena": _no(raiz, base, str(raiz.name))}
			raiz.free()
		elif r is Mesh:
			indice[rel] = {"malha": _malha(r, base)}
		elif r is ConvexPolygonShape3D:
			var pts := []
			for q in r.points:
				pts.append_array([q.x, q.y, q.z])
			indice[rel] = {"convexa": pts}
		else:
			print("?? ", p, " ", r.get_class())
	var f := FileAccess.open(saida + "/indice.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(indice, "\t"))
	f.close()
	print("EXPORTADOS ", indice.size(), " recursos, ", _malhas.size(), " malhas")
	quit()
