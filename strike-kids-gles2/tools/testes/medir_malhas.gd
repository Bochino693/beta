extends SceneTree

## As malhas mais pesadas do mundo 3D (índices = cantos de triângulo),
## somadas por nome de nó (as instâncias do mesmo objeto juntas).
##   godot3 --video-driver GLES2 --path . -s res://tools/testes/medir_malhas.gd

var p: Node
var n := 0


func _init() -> void:
	p = load("res://cenas/principal.tscn").instance()
	root.add_child(p)


func _contar(no: Node, soma: Dictionary, caminho: String) -> void:
	for c in no.get_children():
		var nome: String = caminho + "/" + c.name
		if c is MeshInstance and c.mesh != null and c.is_visible_in_tree():
			var idx := 0
			var vert := 0
			for s in c.mesh.get_surface_count():
				var arr: Array = c.mesh.surface_get_arrays(s)
				vert += (arr[Mesh.ARRAY_VERTEX] as PoolVector3Array).size()
				var ind = arr[Mesh.ARRAY_INDEX]
				idx += (ind as PoolIntArray).size() if ind != null else (arr[Mesh.ARRAY_VERTEX] as PoolVector3Array).size()
			var chave := _chave(nome)
			var e: Array = soma.get(chave, [0, 0, 0])
			e[0] += idx
			e[1] += vert
			e[2] += 1
			soma[chave] = e
		elif c is MultiMeshInstance and c.multimesh != null and c.multimesh.mesh != null and c.is_visible_in_tree():
			var m: Mesh = c.multimesh.mesh
			var idx2 := 0
			for s in m.get_surface_count():
				var arr2: Array = m.surface_get_arrays(s)
				var ind2 = arr2[Mesh.ARRAY_INDEX]
				idx2 += (ind2 as PoolIntArray).size() if ind2 != null else (arr2[Mesh.ARRAY_VERTEX] as PoolVector3Array).size()
			var k: int = c.multimesh.visible_instance_count if c.multimesh.visible_instance_count >= 0 else c.multimesh.instance_count
			var chave2 := _chave(nome) + " (multimesh x%d)" % k
			var e2: Array = soma.get(chave2, [0, 0, 0])
			e2[0] += idx2 * k
			e2[2] += k
			soma[chave2] = e2
		_contar(c, soma, nome)


func _chave(nome: String) -> String:
	# junta as instâncias: tira números e @ dos nomes
	var partes := nome.split("/")
	var r := []
	for s in partes:
		var t := ""
		for ch in s:
			if not (ch in "0123456789@"):
				t += ch
		r.append(t)
	return "/".join(PoolStringArray(Compat.fatia(r, max(r.size() - 3, 0))))


func _maior(a: Array, b: Array) -> bool:
	return a[0] > b[0]


func _idle(_d: float) -> bool:
	n += 1
	if n == 300:
		var soma := {}
		_contar(p.vp, soma, "")
		var lista := []
		for k in soma:
			lista.append([soma[k][0], k, soma[k][1], soma[k][2]])
		lista.sort_custom(self, "_maior")
		var total := 0
		for e in lista:
			total += e[0]
		print("TOTAL indices visíveis (sem recorte): ", total, "  estado=", p.E.keys()[p.estado])
		for i in min(40, lista.size()):
			print("%8d idx  %7d vert  x%-4d %s" % [lista[i][0], lista[i][2], lista[i][3], lista[i][1]])
		return true
	return false
