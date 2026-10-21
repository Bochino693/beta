class_name Lote
extends Reference

## JUNTAR AS PEÇAS PARADAS: dezenas de malhas com o MESMO material viram uma
## malha só — uma chamada de desenho no lugar de dezenas (e o mesmo para o
## contorno e a sombra). É o que mais pesa numa TV Box: o número de
## "desenhos" por quadro, não os triângulos.
##
## Só junta MeshInstance paradas; o que se mexe, acende ou some (balões,
## rodas, pódios, para-choques...) vai em `fora` e fica como está.
##
## Edição OpenGL ES 2.0 (Godot 3):
##  * no SurfaceTool, juntar uma malha COM índice (CubeMesh, modelos) e uma
##    SEM índice (as peças de perfil, scripts/perfis.gd) perde a sem índice
##    (só os triângulos com índice são desenhados): toda peça entra com
##    índice — a sem índice ganha um (juntando os vértices iguais);
##  * a Mali-400/450 só desenha com índices de 16 bits: um lote nunca passa
##    de MAX_VERTICES (se passar, vira mais de um).

const MAX_VERTICES := 65000


## Junta as malhas paradas debaixo de `raiz` (menos as de `fora` e os filhos
## delas), por material e por REGIÃO (quadrados de `celula` metros): poucos
## desenhos e a câmera ainda deixa de desenhar o que está fora do quadro.
## Devolve quantas peças sumiram.
static func juntar(raiz: Spatial, fora: Array = [], celula := 10.0) -> int:
	var excluir := {}
	for n in fora:
		if n != null:
			excluir[n] = true
	var pecas: Array = []
	_coletar(raiz, excluir, pecas)
	var grupos := {}
	for mi in pecas:
		var c: Vector3 = mi.global_transform.origin
		var regiao := Vector2(Compat.ifloor(c.x / celula), Compat.ifloor(c.z / celula)) if celula > 0.0 else Vector2.ZERO
		var chave := "%d|%d|%d|%s" % [mi.material_override.get_instance_id(), mi.cast_shadow, int(_tem_cor(mi.mesh)), regiao]
		if not grupos.has(chave):
			grupos[chave] = []
		grupos[chave].append(mi)
	var inv := raiz.global_transform.affine_inverse()
	var sumiram := 0
	var indexadas := {}
	for chave in grupos:
		var lista: Array = grupos[chave]
		if lista.size() < 2:
			continue
		# [peça, malha com índice], em partes de até MAX_VERTICES vértices
		var partes := [[]]
		var nv := 0
		for mi in lista:
			var mv: Array = _indexada((mi as MeshInstance).mesh, indexadas)
			var atual: Array = partes[partes.size() - 1]
			if nv + int(mv[1]) > MAX_VERTICES and not atual.empty():
				atual = []
				partes.append(atual)
				nv = 0
			atual.append([mi, mv[0]])
			nv += int(mv[1])
		for parte in partes:
			if parte.size() < 2:
				continue
			_juntar_parte(raiz, inv, parte)
			sumiram += parte.size() - 1
	return sumiram


## Uma malha só com as peças de `parte` ([peça, malha com índice]); as peças somem.
static func _juntar_parte(raiz: Spatial, inv: Transform, parte: Array) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var escalado := false
	for par in parte:
		var xf: Transform = inv * (par[0] as MeshInstance).global_transform
		if not is_equal_approx(xf.basis.get_scale().x, 1.0):
			escalado = true
		st.append_from(par[1], 0, xf)
	var arrays := st.commit_to_arrays()
	if escalado:
		# a escala entra na normal: devolve o comprimento 1 (contorno certo)
		var nn: PoolVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in nn.size():
			nn[i] = nn[i].normalized()
		arrays[Mesh.ARRAY_NORMAL] = nn
	# nenhum shader usa a tangente (as caixas têm, as peças de perfil não):
	# sem ela, o lote fica menor e sem tangente zerada
	arrays[Mesh.ARRAY_TANGENT] = null
	var malha := ArrayMesh.new()
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var primeira: MeshInstance = parte[0][0]
	var novo := MeshInstance.new()
	novo.name = "lote"
	novo.mesh = malha
	novo.material_override = primeira.material_override
	novo.cast_shadow = primeira.cast_shadow
	raiz.add_child(novo)
	for par in parte:
		var mi: Node = par[0]
		mi.get_parent().remove_child(mi)
		mi.free()


## [a malha com índice, quantos vértices] (a sem índice ganha um; guardada
## em `cache`: a mesma malha usada por várias peças é feita uma vez só).
static func _indexada(m: Mesh, cache: Dictionary) -> Array:
	if cache.has(m):
		return cache[m]
	var arrays := m.surface_get_arrays(0)
	var r: Mesh = m
	if arrays[Mesh.ARRAY_INDEX] == null:
		var st := SurfaceTool.new()
		st.create_from(m, 0)
		st.index()
		r = st.commit()
		arrays = r.surface_get_arrays(0)
	var par := [r, (arrays[Mesh.ARRAY_VERTEX] as PoolVector3Array).size()]
	cache[m] = par
	return par


static func _coletar(no: Node, excluir: Dictionary, saida: Array) -> void:
	for f in no.get_children():
		if excluir.has(f):
			continue
		if f is MeshInstance:
			var mi := f as MeshInstance
			if mi.mesh != null and mi.material_override != null and mi.mesh.get_surface_count() == 1 \
					and _triangulos(mi.mesh) and mi.get_child_count() == 0 and mi.visible:
				saida.append(mi)
				continue
		if f is Spatial and (f as Spatial).visible:
			_coletar(f, excluir, saida)


static func _tem_cor(m: Mesh) -> bool:
	if m is ArrayMesh:
		return (m as ArrayMesh).surface_get_format(0) & Mesh.ARRAY_FORMAT_COLOR != 0
	return m.surface_get_arrays(0)[Mesh.ARRAY_COLOR] != null


static func _triangulos(m: Mesh) -> bool:
	if m is ArrayMesh:
		return (m as ArrayMesh).surface_get_primitive_type(0) == Mesh.PRIMITIVE_TRIANGLES
	return m is PrimitiveMesh
