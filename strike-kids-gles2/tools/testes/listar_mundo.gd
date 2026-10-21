extends SceneTree

## Lista as peças do mundo 3D (fora o cenário das fases) com o peso de cada
## uma: nome, tipo, malha, índices e quantas instâncias.
##   godot3 --video-driver GLES2 --path . -s res://tools/testes/listar_mundo.gd

var p: Node
var n := 0


func _init() -> void:
	p = load("res://cenas/principal.tscn").instance()
	root.add_child(p)


func _indices(m: Mesh) -> int:
	var t := 0
	for s in m.get_surface_count():
		var arr: Array = m.surface_get_arrays(s)
		var ind = arr[Mesh.ARRAY_INDEX]
		t += (ind as PoolIntArray).size() if ind != null else (arr[Mesh.ARRAY_VERTEX] as PoolVector3Array).size()
	return t


func _listar(no: Node, nivel: int) -> void:
	for c in no.get_children():
		if c is Temas:
			continue
		var info := ""
		if c is MeshInstance and c.mesh != null:
			info = "malha %s idx=%d sup=%d" % [c.mesh.resource_path.get_file() if c.mesh.resource_path != "" else c.mesh.get_class(), _indices(c.mesh), c.mesh.get_surface_count()]
		elif c is MultiMeshInstance and c.multimesh != null and c.multimesh.mesh != null:
			info = "multimesh %s idx=%d x%d" % [c.multimesh.mesh.resource_path.get_file(), _indices(c.multimesh.mesh), c.multimesh.instance_count]
		elif c is CPUParticles:
			info = "particulas x%d malha=%s" % [c.amount, c.mesh.get_class() if c.mesh else "-"]
		if info != "" or nivel < 2:
			print("%s%s [%s] %s %s" % ["  ".repeat(nivel), c.name, c.get_class(), info, "" if not (c is Spatial) or c.is_visible_in_tree() else "(escondido)"])
		_listar(c, nivel + 1)


func _idle(_d: float) -> bool:
	n += 1
	if n == 30:
		_listar(p.mundo, 0)
		return true
	return false
