extends SceneTree

## REFAZ modelos/terreno.res com a fórmula de agora (Mundo._altura_terreno:
## os morros e os PATAMARES da 7.5). Parte da malha que está no git (feita
## com a fórmula dos morros: os pontos e os triângulos de lá) e:
##   * perto de cada patamar, divide em 4 os triângulos que não seguem a
##     fórmula (mais de TOLERANCIA de diferença dentro deles), até 4 vezes
##     — a malha é mais rala onde o morro é liso e não desenharia o degrau;
##     o vizinho que ficou com um ponto novo na beira é dividido em 2 (sem
##     fresta entre os triângulos);
##   * cada ponto ganha a altura da fórmula e, onde ela mudou, a normal pela
##     inclinação da própria fórmula; a cor do ponto novo é a média.
##   godot3 --no-window --path . -s res://tools/refazer_terreno.gd
## (rodar sobre a malha original: git checkout -- modelos/terreno.res)

const CAMINHO := "res://modelos/terreno.res"
const TOLERANCIA := 0.1
const VEZES := 4

var mundo
var vs := []          # Vector3
var ns := []          # Vector3
var cs := []          # Color
var tris := []        # [a, b, c]


func _init() -> void:
	mundo = load("res://scripts/mundo.gd").new()
	var malha: ArrayMesh = load(CAMINHO)
	var arr: Array = malha.surface_get_arrays(0)
	vs = Array(arr[Mesh.ARRAY_VERTEX])
	ns = Array(arr[Mesh.ARRAY_NORMAL])
	cs = Array(arr[Mesh.ARRAY_COLOR])
	var ix: PoolIntArray = arr[Mesh.ARRAY_INDEX]
	var t := 0
	while t < ix.size():
		tris.append([ix[t], ix[t + 1], ix[t + 2]])
		t += 3
	var antes := tris.size()
	for vez in VEZES:
		var n := _dividir()
		print("TERRENO: passada %d, %d triângulos divididos" % [vez + 1, n])
		if n == 0:
			break
	var mudou := 0
	for i in vs.size():
		var v: Vector3 = vs[i]
		var y: float = mundo._altura_terreno(v.x, v.z)
		if abs(y - v.y) > 0.0005 or i >= arr[Mesh.ARRAY_VERTEX].size():
			mudou += 1
			ns[i] = _normal(v.x, v.z)
		vs[i] = Vector3(v.x, y, v.z)
	var novo_ix := PoolIntArray()
	for tr in tris:
		novo_ix.append_array(PoolIntArray(tr))
	arr[Mesh.ARRAY_VERTEX] = PoolVector3Array(vs)
	arr[Mesh.ARRAY_NORMAL] = PoolVector3Array(ns)
	arr[Mesh.ARRAY_COLOR] = PoolColorArray(cs)
	arr[Mesh.ARRAY_INDEX] = novo_ix
	var nova := ArrayMesh.new()
	nova.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var erro := ResourceSaver.save(CAMINHO, nova, ResourceSaver.FLAG_COMPRESS)
	print("TERRENO: %d -> %d triângulos, %d pontos mudaram; gravado: %s" % [antes, tris.size(), mudou, "ok" if erro == OK else str(erro)])
	mundo.free()
	quit()


## Uma passada: marca os triângulos perto de um patamar que não seguem a
## fórmula, fecha (quem ficou com 2 ou 3 lados divididos também é marcado)
## e troca: os marcados por 4, os vizinhos com 1 lado dividido por 2.
func _dividir() -> int:
	var marcados := {}
	for k in tris.size():
		if _perto_de_patamar(tris[k]) and _erro(tris[k]) > TOLERANCIA:
			marcados[k] = true
	if marcados.empty():
		return 0
	var meios := {}       # "a_b" (a < b) -> índice do ponto do meio
	for k in marcados:
		_meios_do(tris[k], meios)
	var mudou := true
	while mudou:
		mudou = false
		for k in tris.size():
			if marcados.has(k):
				continue
			if _lados_divididos(tris[k], meios) >= 2:
				marcados[k] = true
				_meios_do(tris[k], meios)
				mudou = true
	var novos := []
	for k in tris.size():
		var tr: Array = tris[k]
		var a: int = tr[0]
		var b: int = tr[1]
		var c: int = tr[2]
		if marcados.has(k):
			var ab: int = meios[_chave(a, b)]
			var bc: int = meios[_chave(b, c)]
			var ca: int = meios[_chave(c, a)]
			novos.append([a, ab, ca])
			novos.append([ab, b, bc])
			novos.append([ca, bc, c])
			novos.append([ab, bc, ca])
		elif meios.has(_chave(a, b)):
			var m: int = meios[_chave(a, b)]
			novos.append([a, m, c])
			novos.append([m, b, c])
		elif meios.has(_chave(b, c)):
			var m: int = meios[_chave(b, c)]
			novos.append([a, b, m])
			novos.append([a, m, c])
		elif meios.has(_chave(c, a)):
			var m: int = meios[_chave(c, a)]
			novos.append([a, b, m])
			novos.append([m, b, c])
		else:
			novos.append(tr)
	tris = novos
	return marcados.size()


func _chave(a: int, b: int) -> String:
	return "%d_%d" % [min(a, b), max(a, b)]


func _meios_do(tr: Array, meios: Dictionary) -> void:
	for l in [[tr[0], tr[1]], [tr[1], tr[2]], [tr[2], tr[0]]]:
		var k := _chave(l[0], l[1])
		if meios.has(k):
			continue
		var p: Vector3 = (vs[l[0]] + vs[l[1]]) * 0.5
		vs.append(Vector3(p.x, mundo._altura_terreno(p.x, p.z), p.z))
		ns.append(_normal(p.x, p.z))
		cs.append((cs[l[0]] as Color).linear_interpolate(cs[l[1]], 0.5))
		meios[k] = vs.size() - 1


func _lados_divididos(tr: Array, meios: Dictionary) -> int:
	var n := 0
	for l in [[tr[0], tr[1]], [tr[1], tr[2]], [tr[2], tr[0]]]:
		if meios.has(_chave(l[0], l[1])):
			n += 1
	return n


func _perto_de_patamar(tr: Array) -> bool:
	var c: Vector3 = (vs[tr[0]] + vs[tr[1]] + vs[tr[2]]) / 3.0
	for pt in mundo.PATAMARES:
		if Vector2(c.x - pt[0], c.z - pt[1]).length() < float(pt[3]) + 1.5:
			return true
	return false


## A maior diferença entre o triângulo (plano pelos 3 pontos, com a altura
## da fórmula) e a fórmula, em 10 pontos dentro dele.
func _erro(tr: Array) -> float:
	var a: Vector3 = vs[tr[0]]
	var b: Vector3 = vs[tr[1]]
	var c: Vector3 = vs[tr[2]]
	var ha: float = mundo._altura_terreno(a.x, a.z)
	var hb: float = mundo._altura_terreno(b.x, b.z)
	var hc: float = mundo._altura_terreno(c.x, c.z)
	var pior := 0.0
	for u in [0.0, 0.25, 0.5, 0.75]:
		for w in [0.0, 0.25, 0.5, 0.75]:
			if u + w > 1.0:
				continue
			var x: float = a.x + (b.x - a.x) * u + (c.x - a.x) * w
			var z: float = a.z + (b.z - a.z) * u + (c.z - a.z) * w
			var y: float = ha + (hb - ha) * u + (hc - ha) * w
			pior = max(pior, abs(y - mundo._altura_terreno(x, z)))
	return pior


func _normal(x: float, z: float) -> Vector3:
	var e := 0.05
	var dx: float = (mundo._altura_terreno(x + e, z) - mundo._altura_terreno(x - e, z)) / (2.0 * e)
	var dz: float = (mundo._altura_terreno(x, z + e) - mundo._altura_terreno(x, z - e)) / (2.0 * e)
	return Vector3(-dx, 1.0, -dz).normalized()
