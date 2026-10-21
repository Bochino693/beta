extends SceneTree

## MALHAS LEVES PARA A MALI-400/450 (TX9): tira e devolve as malhas de
## modelos/ para o simplificador (tools/malhas_leves.py, meshoptimizer).
##
##   1) godot3 --no-window --path . -s res://tools/malhas_leves.gd -- --exportar <pasta>
##   2) python3 tools/malhas_leves.py <pasta>
##   3) godot3 --no-window --path . -s res://tools/malhas_leves.gd -- --importar <pasta>
##
## Cada malha (as peças dos bichinhos e das roupinhas, o pino, o terreno,
## cada objeto do cenário) sai num .msh com as mesmas listas do Godot
## (posição, normal, cor, uv, índices). O simplificador grava o .leve.msh
## com menos triângulos; a volta troca as superfícies NA PRÓPRIA malha
## (mesmo material, mesmo formato compactado, mesmas metas) e grava o
## recurso no mesmo lugar — nada mais da cena muda.

const PASTAS := ["res://modelos"]
const LISTAS := [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR,
	Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]
const COLUNAS := {Mesh.ARRAY_VERTEX: 3, Mesh.ARRAY_NORMAL: 3, Mesh.ARRAY_TANGENT: 4, Mesh.ARRAY_COLOR: 4,
	Mesh.ARRAY_TEX_UV: 2, Mesh.ARRAY_TEX_UV2: 2}

var pasta := ""


func _init() -> void:
	var args := OS.get_cmdline_args()
	var modo := ""
	for i in args.size():
		if args[i] in ["--exportar", "--importar"] and i + 1 < args.size():
			modo = args[i]
			pasta = args[i + 1]
	if modo == "":
		printerr("uso: -- --exportar <pasta>  |  -- --importar <pasta>")
		quit(1)
		return
	Directory.new().make_dir_recursive(pasta)
	if modo == "--exportar":
		_exportar()
	else:
		_importar()
	quit()


func _arquivos(dir: String, lista: Array) -> void:
	var d := Directory.new()
	if d.open(dir) != OK:
		return
	d.list_dir_begin(true, true)
	var f := d.get_next()
	while f != "":
		var c := dir.plus_file(f)
		if d.current_is_dir():
			_arquivos(c, lista)
		elif f.get_extension() in ["scn", "res", "tscn", "tres"]:
			lista.append(c)
		f = d.get_next()
	d.list_dir_end()
	lista.sort()


## Malhas de um recurso: [[caminho do nó ("" = o próprio recurso), malha]].
func _malhas(r: Resource) -> Array:
	var lista := []
	if r is ArrayMesh:
		lista.append(["", r])
	elif r is PackedScene:
		var st: SceneState = (r as PackedScene).get_state()
		for i in st.get_node_count():
			for k in st.get_node_property_count(i):
				var v = st.get_node_property_value(i, k)
				if v is ArrayMesh:
					lista.append([str(st.get_node_path(i)) + ":" + st.get_node_property_name(i, k), v])
	return lista


func _exportar() -> void:
	var arquivos := []
	for p in PASTAS:
		_arquivos(p, arquivos)
	var indice := []
	var vistas := {}
	var n := 0
	for arq in arquivos:
		var r: Resource = load(arq)
		for par in _malhas(r):
			var m: ArrayMesh = par[1]
			var id: int = m.get_instance_id()
			if vistas.has(id):
				continue
			vistas[id] = true
			var nome := "m%04d" % n
			n += 1
			var sups := []
			var f := File.new()
			f.open(pasta.plus_file(nome + ".msh"), File.WRITE)
			f.store_buffer("SKL1".to_ascii())
			f.store_32(m.get_surface_count())
			for s in m.get_surface_count():
				var arr: Array = m.surface_get_arrays(s)
				var listas := 0
				for t in LISTAS:
					if arr[t] != null and arr[t].size() > 0:
						listas |= 1 << t
				var tem_indice: bool = arr[Mesh.ARRAY_INDEX] != null and arr[Mesh.ARRAY_INDEX].size() > 0
				var ossos: bool = arr[Mesh.ARRAY_BONES] != null and arr[Mesh.ARRAY_BONES].size() > 0
				var nv: int = arr[Mesh.ARRAY_VERTEX].size()
				f.store_32(m.surface_get_primitive_type(s))
				f.store_32(nv)
				f.store_32(listas)
				for t in LISTAS:
					if listas & (1 << t):
						_gravar_lista(f, arr[t], t)
				var ind: PoolIntArray = arr[Mesh.ARRAY_INDEX] if tem_indice else PoolIntArray()
				if not tem_indice:
					ind.resize(nv)
					for i in nv:
						ind[i] = i
				f.store_32(ind.size())
				for i in ind:
					f.store_32(i)
				sups.append({"primitiva": m.surface_get_primitive_type(s), "vertices": nv,
					"triangulos": ind.size() / 3, "ossos": ossos, "formas": m.get_blend_shape_count()})
			f.close()
			indice.append({"id": nome, "recurso": arq, "no": par[0], "superficies": sups})
	var j := File.new()
	j.open(pasta.plus_file("indice.json"), File.WRITE)
	j.store_string(JSON.print(indice, " "))
	j.close()
	print("EXPORTADAS ", n, " malhas de ", arquivos.size(), " recursos")


func _gravar_lista(f: File, a, tipo: int) -> void:
	match tipo:
		Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL:
			for v in a:
				f.store_float(v.x)
				f.store_float(v.y)
				f.store_float(v.z)
		Mesh.ARRAY_TANGENT:
			for x in a:
				f.store_float(x)
		Mesh.ARRAY_COLOR:
			for c in a:
				f.store_float(c.r)
				f.store_float(c.g)
				f.store_float(c.b)
				f.store_float(c.a)
		Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2:
			for v in a:
				f.store_float(v.x)
				f.store_float(v.y)


func _ler_lista(f: File, tipo: int, nv: int):
	match tipo:
		Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL:
			var a := PoolVector3Array()
			a.resize(nv)
			for i in nv:
				a[i] = Vector3(f.get_float(), f.get_float(), f.get_float())
			return a
		Mesh.ARRAY_TANGENT:
			var t := PoolRealArray()
			t.resize(nv * 4)
			for i in nv * 4:
				t[i] = f.get_float()
			return t
		Mesh.ARRAY_COLOR:
			var c := PoolColorArray()
			c.resize(nv)
			for i in nv:
				c[i] = Color(f.get_float(), f.get_float(), f.get_float(), f.get_float())
			return c
		_:
			var u := PoolVector2Array()
			u.resize(nv)
			for i in nv:
				u[i] = Vector2(f.get_float(), f.get_float())
			return u


func _importar() -> void:
	var j := File.new()
	if j.open(pasta.plus_file("indice.json"), File.READ) != OK:
		printerr("sem indice.json em ", pasta)
		return
	var indice: Array = parse_json(j.get_as_text())
	j.close()
	# cada recurso uma vez: troca as malhas dele e grava
	var por_recurso := {}
	for e in indice:
		if not por_recurso.has(e["recurso"]):
			por_recurso[e["recurso"]] = []
		por_recurso[e["recurso"]].append(e)
	var trocadas := 0
	var gravados := 0
	for arq in por_recurso:
		var r: Resource = load(arq)
		var malhas := {}
		for par in _malhas(r):
			malhas[par[0]] = par[1]
		var mudou := false
		for e in por_recurso[arq]:
			var leve: String = pasta.plus_file(e["id"] + ".leve.msh")
			if not File.new().file_exists(leve) or not malhas.has(e["no"]):
				continue
			if _trocar(malhas[e["no"]], leve):
				trocadas += 1
				mudou = true
		if mudou:
			var flags := ResourceSaver.FLAG_COMPRESS if arq.get_extension() in ["scn", "res"] else 0
			if ResourceSaver.save(arq, r, flags) == OK:
				gravados += 1
			else:
				printerr("não gravou ", arq)
	print("TROCADAS ", trocadas, " malhas; ", gravados, " recursos gravados")


func _trocar(m: ArrayMesh, caminho: String) -> bool:
	var f := File.new()
	if f.open(caminho, File.READ) != OK:
		return false
	if f.get_buffer(4).get_string_from_ascii() != "SKL1":
		return false
	var n_sup := f.get_32()
	if n_sup != m.get_surface_count():
		printerr("superfícies diferentes em ", caminho)
		return false
	var novas := []
	for s in n_sup:
		var prim := f.get_32()
		var nv := f.get_32()
		var listas := f.get_32()
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		for t in LISTAS:
			if listas & (1 << t):
				arr[t] = _ler_lista(f, t, nv)
		var ni := f.get_32()
		var ind := PoolIntArray()
		ind.resize(ni)
		for i in ni:
			ind[i] = f.get_32()
		arr[Mesh.ARRAY_INDEX] = ind
		novas.append([prim, arr, m.surface_get_format(s), m.surface_get_material(s), m.surface_get_name(s)])
	f.close()
	# troca todas (na mesma ordem), com o mesmo formato compactado e material
	while m.get_surface_count() > 0:
		m.surface_remove(0)
	for s in novas.size():
		var nova: Array = novas[s]
		var compactar: int = int(nova[2]) & (Mesh.ARRAY_COMPRESS_VERTEX | Mesh.ARRAY_COMPRESS_NORMAL |
			Mesh.ARRAY_COMPRESS_TANGENT | Mesh.ARRAY_COMPRESS_COLOR | Mesh.ARRAY_COMPRESS_TEX_UV |
			Mesh.ARRAY_COMPRESS_TEX_UV2 | Mesh.ARRAY_FLAG_USE_2D_VERTICES | Mesh.ARRAY_FLAG_USE_16_BIT_BONES)
		m.add_surface_from_arrays(nova[0], nova[1], [], compactar)
		if nova[3] != null:
			m.surface_set_material(s, nova[3])
		if str(nova[4]) != "":
			m.surface_set_name(s, nova[4])
	return true
