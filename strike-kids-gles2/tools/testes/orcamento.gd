extends SceneTree

## ORÇAMENTO DA PLACA DE VÍDEO, fase por fase: quantos cantos de triângulo
## (índices) cada parte do mundo 3D manda desenhar — cenário, pista,
## máquina, pinos, bichinhos (com a roupinha da fase), bola, céu — e quanto
## o desenhista do Godot desenhou de verdade em cada vista (com o recorte
## do que está fora da câmera).
## Na Mali-400/450 (TX9) o que mais pesa são os vértices: o total por
## quadro tem que caber no ORCAMENTO abaixo.
##   godot3 --video-driver GLES2 --path . -s res://tools/testes/orcamento.gd

## índices por quadro que a Mali-450 desenha a 60 quadros com folga
const ORCAMENTO := 240000

var p: Node
var n := 0
var _etapa := 0
var _temas: Array = []
var _vistas := [
	["pista", Vector3(0.0, 1.05, 2.2), Vector3(0.0, 0.18, -6.0)],
	["mascote", Vector3(0.9, 1.3, 4.6), Vector3(0.0, 0.7, 2.6)],
	["pinos", Vector3(0.0, 0.9, -4.2), Vector3(0.0, 0.2, -7.6)],
	["alto", Vector3(0.0, 4.5, 6.5), Vector3(0.0, 0.0, -2.0)],
]
var _vista := 0
var _espera := 0
var _linhas := []


func _init() -> void:
	p = load("res://cenas/principal.tscn").instance()
	root.add_child(p)


func _contar(no: Node, soma: Dictionary, grupo: String) -> void:
	for c in no.get_children():
		var g := grupo
		if g == "":
			g = _grupo(c)
		if c is MeshInstance and c.mesh != null and c.is_visible_in_tree():
			soma[g] = soma.get(g, 0) + _indices(c.mesh) * (2 if _tem_contorno(c) else 1)
		elif c is MultiMeshInstance and c.multimesh != null and c.multimesh.mesh != null and c.is_visible_in_tree():
			var k: int = c.multimesh.visible_instance_count if c.multimesh.visible_instance_count >= 0 else c.multimesh.instance_count
			var dobro := 2 if c.material_override != null and c.material_override.next_pass != null else 1
			soma[g] = soma.get(g, 0) + _indices(c.multimesh.mesh) * k * dobro
		elif c is CPUParticles and c.mesh != null and c.is_visible_in_tree():
			soma[g] = soma.get(g, 0) + _indices(c.mesh) * c.amount
		_contar(c, soma, g)


func _tem_contorno(mi: MeshInstance) -> bool:
	var m: Material = mi.material_override
	if m == null and mi.mesh.get_surface_count() > 0:
		m = mi.get_surface_material(0)
		if m == null:
			m = mi.mesh.surface_get_material(0)
	return m != null and m.next_pass != null


func _indices(m: Mesh) -> int:
	var t := 0
	for s in m.get_surface_count():
		var arr: Array = m.surface_get_arrays(s)
		var ind = arr[Mesh.ARRAY_INDEX]
		t += (ind as PoolIntArray).size() if ind != null else (arr[Mesh.ARRAY_VERTEX] as PoolVector3Array).size()
	return t


func _grupo(c: Node) -> String:
	if c == p.mundo:
		return ""   # o mundo se divide: cenário de cada fase e o resto (pista, céu...)
	if c.get_parent() == p.mundo:
		if c is Temas:
			return ""
		return "mundo/" + c.name
	if c.get_parent() is Temas:
		return "cenario/" + c.name
	if c == p.pinos:
		return "pinos"
	if c == p.maquina:
		return "maquina"
	if c == p.bola:
		return "bola"
	if c == p.efeitos:
		return "efeitos"
	for nome in p.personagens:
		if c == p.personagens[nome]:
			return "bicho/" + nome
	return "outros/" + c.get_class()


func _idle(_d: float) -> bool:
	n += 1
	if _etapa == 0:
		if p._preparando or n < 30:
			return false
		# tudo parado: a vista da câmera é a de cada medida
		p.set_process(false)
		p.set_physics_process(false)
		_temas = Temas.ORDEM.duplicate()
		_etapa = 1
		_espera = 0
		return false
	if _etapa == 1:
		if _temas.empty():
			_resumo()
			return true
		var t: String = _temas[0]
		if _espera == 0:
			p.mundo.aplicar_tema(t)
			for nome in p.personagens:
				var b: Personagem = p.personagens[nome]
				b.visible = true
				b.pedir_roupa(p.ROUPA_DO_TEMA.get(t, ""))
			_vista = 0
		_espera += 1
		if _espera == 20:
			for nome in p.personagens:
				(p.personagens[nome] as Personagem).trocar_roupa(p.ROUPA_DO_TEMA.get(t, ""))
		if _espera < 40:
			return false
		var v: Array = _vistas[_vista]
		if (_espera - 40) % 6 == 0:
			p.cam.corte(v[1], v[2], 50, 50)
		elif (_espera - 40) % 6 == 5:
			var desenhado := int(Performance.get_monitor(Performance.RENDER_VERTICES_IN_FRAME))
			var chamadas := int(Performance.get_monitor(Performance.RENDER_DRAW_CALLS_IN_FRAME))
			_linhas.append("%-7s %-8s desenhado=%7d indices  chamadas=%4d%s" % [t, v[0], desenhado, chamadas,
				"   <-- ACIMA DO ORCAMENTO" if desenhado > ORCAMENTO else ""])
			_vista += 1
			if _vista >= _vistas.size():
				var soma := {}
				_contar(p.raiz_3d, soma, "")
				var chaves := soma.keys()
				chaves.sort()
				var total := 0
				for k in chaves:
					total += soma[k]
				_linhas.append("%-7s TUDO (sem recorte) = %d indices" % [t, total])
				for k in chaves:
					if soma[k] >= 2000:
						_linhas.append("        %8d  %s" % [soma[k], k])
				_temas.pop_front()
				_espera = 0
	return false


func _resumo() -> void:
	print("ORCAMENTO da Mali-450: %d indices por quadro" % ORCAMENTO)
	for l in _linhas:
		print(l)
