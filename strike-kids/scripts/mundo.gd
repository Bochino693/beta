class_name Mundo
extends Node3D

## O MUNDO 3D: céu, sol, gramado com morros, a pista (madeira, canaletas,
## para-choques), o fundo dos pinos (veludo com estrelas, arco-íris, torres,
## letreiro com lâmpadas) e a decoração do "Parque Doce" (pirulitos,
## árvores, cogumelos, nuvens, balões).
##
## Medidas: linha de falta em z = 0; os pinos em z = -14; a pista vai para -Z.

const MEIA_LARGURA := 0.675
const CANALETA := 0.25
const Z_PINO1 := -14.0
const ESPACO_PINOS := 0.38
const FILEIRA := 0.329
const Z_FIM_DECK := -15.45
const Z_FUNDO := -17.2
const Y_CANALETA := -0.09

const CAMADA_MUNDO := 1
const CAMADA_PINOS := 2
const CAMADA_BOLA := 4

var ambiente: Environment
var sol: DirectionalLight3D
var mat_pista: ShaderMaterial
var mat_lampadas: ShaderMaterial
var mat_fundo: ShaderMaterial
var _bumpers: Array[Node3D] = []
var _baloes: Array = []
var _nuvens: Array = []
var _t := 0.0
var _luz := 0.0
var _luz_alvo := 0.0
var bola_z := 100.0


func construir() -> void:
	_ambiente()
	_sol()
	_terreno()
	_pista()
	_fundo_dos_pinos()
	_decoracao()
	_nuvens_e_baloes()
	definir_protecao(Ajustes.protecao_canaleta())


# ================================================================ ambiente
func _ambiente() -> void:
	var we := WorldEnvironment.new()
	ambiente = Environment.new()
	var ceu := Sky.new()
	var mc := ShaderMaterial.new()
	mc.shader = load("res://shaders/ceu.gdshader")
	ceu.sky_material = mc
	ceu.radiance_size = Sky.RADIANCE_SIZE_32
	ambiente.background_mode = Environment.BG_SKY
	ambiente.sky = ceu
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.ambient_light_color = Color(0.66, 0.62, 0.92)
	ambiente.ambient_light_energy = 0.62
	ambiente.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	ambiente.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	ambiente.tonemap_exposure = 1.0
	ambiente.tonemap_white = 1.6
	ambiente.glow_enabled = true
	ambiente.glow_intensity = 0.55
	ambiente.glow_strength = 0.9
	ambiente.glow_bloom = 0.0
	ambiente.glow_hdr_threshold = 1.0
	ambiente.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	ambiente.fog_enabled = true
	ambiente.fog_light_color = Color(0.86, 0.9, 1.0)
	ambiente.fog_density = 0.0045
	ambiente.fog_sky_affect = 0.0
	ambiente.adjustment_enabled = true
	ambiente.adjustment_saturation = 1.12
	ambiente.adjustment_contrast = 1.04
	we.environment = ambiente
	add_child(we)


func _sol() -> void:
	sol = DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-52, 28, 0)
	sol.light_color = Color(1.0, 0.95, 0.86)
	sol.light_energy = 1.05
	sol.shadow_enabled = true
	sol.shadow_bias = 0.04
	sol.shadow_normal_bias = 1.2
	sol.shadow_blur = 1.5
	sol.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sol.directional_shadow_max_distance = 26.0
	add_child(sol)


## Qualidade: "alta" (sombras reais + glow), "media" (glow, sombra só da
## pista), "baixa" (sem glow nem sombra; para TV Box fraca).
func aplicar_qualidade(q: String) -> void:
	sol.shadow_enabled = q != "baixa"
	ambiente.glow_enabled = q != "baixa"
	ambiente.fog_enabled = q == "alta" or q == "media"
	RenderingServer.directional_shadow_atlas_set_size(4096 if q == "alta" else 2048, true)


# ================================================================ terreno
func _terreno() -> void:
	var t := MeshInstance3D.new()
	t.mesh = load("res://modelos/terreno.res")
	t.material_override = Materiais.toon(false, 0.0, {"borda": 0.0, "faixa": 0.25})
	t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(t)
	# chão de segurança (nada cai para sempre)
	var chao := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	chao.add_child(cs)
	chao.position.y = -0.6
	chao.collision_layer = CAMADA_MUNDO
	add_child(chao)


# ================================================================ pista
func _caixa(tam: Vector3, pos: Vector3, mat: Material, colisao := true, sombra := true, atrito := 0.4, quique := 0.2) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	if not sombra:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	if colisao:
		_corpo_caixa(tam, pos, atrito, quique)
	return mi


func _corpo_caixa(tam: Vector3, pos: Vector3, atrito := 0.4, quique := 0.2) -> StaticBody3D:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = tam
	cs.shape = bs
	sb.add_child(cs)
	sb.position = pos
	sb.collision_layer = CAMADA_MUNDO
	sb.collision_mask = 0
	var pm := PhysicsMaterial.new()
	pm.friction = atrito
	pm.bounce = quique
	sb.physics_material_override = pm
	add_child(sb)
	return sb


func _pista() -> void:
	# --- tábuas da pista (com marcações e luzes)
	mat_pista = ShaderMaterial.new()
	mat_pista.shader = load("res://shaders/pista.gdshader")
	mat_pista.set_shader_parameter("madeira", Materiais.textura("madeira"))
	var comp := 0.1 - Z_FIM_DECK
	var deck := _caixa(Vector3(MEIA_LARGURA * 2, 0.2, comp), Vector3(0, -0.1, 0.1 - comp / 2), mat_pista, true, false, 0.06, 0.05)
	deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# --- área de aproximação (onde o personagem corre)
	var ma := StandardMaterial3D.new()
	ma.albedo_texture = Materiais.textura("madeira")
	ma.albedo_color = Color(0.93, 0.84, 0.76)
	ma.uv1_scale = Vector3(4.2, 1.6, 1)
	ma.roughness = 0.35
	var aprox := _caixa(Vector3(6.6, 0.2, 6.2), Vector3(0, -0.101, 3.2), ma, true, false, 0.8, 0.0)
	aprox.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# faixa colorida nas bordas da aproximação
	for s in [-1, 1]:
		_caixa(Vector3(0.12, 0.04, 6.2), Vector3(s * 3.3, 0.0, 3.2), Materiais.cor_toon(Color("#FF7EC1")), false, false)

	# --- canaletas: cilindro visto por dentro (meia-cana côncava)
	var mc := Materiais.toon(false, 0.0, {"tinta": Color("#BBA8FF"), "borda": 0.0})
	mc.render_priority = 0
	var cull := mc.duplicate() as ShaderMaterial
	for s in [-1, 1]:
		var x: float = s * (MEIA_LARGURA + CANALETA / 2)
		var cil := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = CANALETA / 2
		cm.bottom_radius = CANALETA / 2
		cm.height = comp
		cm.radial_segments = 24
		cm.cap_top = false
		cm.cap_bottom = false
		cil.mesh = cm
		cil.rotation_degrees.x = 90
		cil.position = Vector3(x, 0.0, 0.1 - comp / 2)
		cil.material_override = _material_por_dentro(Color("#B9A6FF"))
		cil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(cil)
		# colisão: fundo da canaleta e parede de fora
		_corpo_caixa(Vector3(CANALETA, 0.1, comp), Vector3(x, Y_CANALETA - 0.05 - 0.02, 0.1 - comp / 2), 0.2, 0.1)
		# divisória (capping) colorida entre a canaleta e o gramado
		var largura_cap := 0.32
		var xc: float = s * (MEIA_LARGURA + CANALETA + largura_cap / 2)
		_caixa(Vector3(largura_cap, 0.34, Z_PINO1 * -1 + 0.6), Vector3(xc, -0.07, (Z_PINO1 + 0.6) / 2.0 + 0.0),
			Materiais.cor_toon(Color("#FF8FD0"), 0.0, {"borda": 0.25}), true, true, 0.3, 0.3)
		# faixinha de luz em cima da divisória
		var luzes := _caixa(Vector3(0.05, 0.012, -Z_PINO1 + 0.5), Vector3(xc, 0.105, Z_PINO1 / 2.0 + 0.0),
			Materiais.cor_toon(Color("#FFFFFF"), 0.0, {"emissao": Color(0.35, 0.85, 1.0), "borda": 0.0}), false, false)
		luzes.name = "luz_divisoria_%d" % s

	# --- para-choques (bumpers) listrados de doce
	var mb: Mesh = load("res://modelos/cenario/bumper.res")
	var mat_b := Materiais.toon(false, 0.003)
	for s in [-1, 1]:
		var grupo := Node3D.new()
		grupo.name = "bumpers_%d" % s
		add_child(grupo)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mb
		var n := 14
		mm.instance_count = n
		for i in n:
			mm.set_instance_transform(i, Transform3D(Basis(), Vector3(s * 0.735, 0.1, -0.6 - i * 0.96)))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat_b
		grupo.add_child(mmi)
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var cap := CylinderShape3D.new()
		cap.radius = 0.075
		cap.height = n * 0.96 + 0.2
		cs.shape = cap
		cs.rotation_degrees.x = 90
		cs.position = Vector3(s * 0.735, 0.1, -0.6 - (n - 1) * 0.96 / 2)
		sb.add_child(cs)
		sb.collision_layer = CAMADA_MUNDO
		sb.collision_mask = 0
		var pm := PhysicsMaterial.new()
		pm.bounce = 0.55
		pm.friction = 0.1
		sb.physics_material_override = pm
		sb.name = "fisica"
		grupo.add_child(sb)
		_bumpers.append(grupo)


func _material_por_dentro(c: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = load("res://shaders/toon.gdshader").code.replace("cull_back", "cull_front")
	sh.code = sh.code.replace("float ndl = dot(NORMAL, LIGHT);", "float ndl = dot(-NORMAL, LIGHT);")
	m.shader = sh
	m.set_shader_parameter("tinta", c)
	m.set_shader_parameter("borda", 0.0)
	m.set_shader_parameter("luz_minima", 0.55)
	return m


func definir_protecao(ligada: bool) -> void:
	for g in _bumpers:
		g.visible = ligada
		var sb := g.get_node("fisica") as StaticBody3D
		sb.collision_layer = CAMADA_MUNDO if ligada else 0


# ================================================================ fundo dos pinos
func _fundo_dos_pinos() -> void:
	var roxo := Materiais.cor_toon(Color("#7C4DFF"), 0.0, {"borda": 0.3})
	var lilas := Materiais.cor_toon(Color("#B388FF"), 0.0, {"borda": 0.3})
	# paredes laterais (kickbacks) — os pinos batem e voltam
	for s in [-1, 1]:
		_caixa(Vector3(0.12, 1.0, -Z_FUNDO + Z_PINO1 + 0.9), Vector3(s * (MEIA_LARGURA + CANALETA + 0.06), 0.35, (Z_PINO1 + 0.9 + Z_FUNDO) / 2),
			lilas, true, true, 0.3, 0.35)
	# fosso
	_caixa(Vector3(2.0, 0.2, -Z_FUNDO + Z_FIM_DECK), Vector3(0, -0.24, (Z_FIM_DECK + Z_FUNDO) / 2), roxo, true, false, 0.9, 0.05)
	# cortina do fundo (estrelinhas): colisão macia
	mat_fundo = ShaderMaterial.new()
	mat_fundo.shader = load("res://shaders/fundo_estrelas.gdshader")
	var fundo := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.2, 1.8)
	fundo.mesh = q
	fundo.material_override = mat_fundo
	fundo.position = Vector3(0, 0.5, Z_FUNDO + 0.01)
	add_child(fundo)
	_corpo_caixa(Vector3(2.4, 2.0, 0.2), Vector3(0, 0.5, Z_FUNDO - 0.1), 0.9, 0.0)
	# teto escuro do fosso (esconde a parte de cima)
	_caixa(Vector3(2.3, 0.1, -Z_FUNDO + Z_PINO1 + 0.7), Vector3(0, 1.42, (Z_PINO1 + 0.7 + Z_FUNDO) / 2),
		Materiais.cor_toon(Color("#4A238F"), 0.0, {"borda": 0.0}), false, false)

	# letreiro (masking) acima dos pinos, com o logo e lâmpadas
	var placa := _caixa(Vector3(2.7, 0.95, 0.14), Vector3(0, 1.85, Z_PINO1 + 0.75), Materiais.cor_toon(Color("#3A1C7A"), 0.004, {"borda": 0.4}), false, true)
	placa.name = "placa"
	var logo_tex := Materiais.textura("logo")
	if logo_tex != null:
		var logo := MeshInstance3D.new()
		var lq := QuadMesh.new()
		var asp := float(logo_tex.get_width()) / float(logo_tex.get_height())
		lq.size = Vector2(min(2.5, 0.86 * asp), min(2.5, 0.86 * asp) / asp)
		logo.mesh = lq
		var ml := StandardMaterial3D.new()
		ml.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ml.albedo_texture = logo_tex
		ml.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		ml.alpha_scissor_threshold = 0.4
		ml.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		logo.material_override = ml
		logo.position = Vector3(0, 1.86, Z_PINO1 + 0.83)
		logo.name = "logo"
		add_child(logo)

	# arco-íris e torres
	var arco := MeshInstance3D.new()
	arco.mesh = load("res://modelos/cenario/arco_iris.res")
	arco.material_override = Materiais.toon(false, 0.0, {"borda": 0.35})
	arco.position = Vector3(0, -0.05, Z_FUNDO - 0.5)
	arco.scale = Vector3.ONE * 0.95
	add_child(arco)
	for s in [-1, 1]:
		var torre := MeshInstance3D.new()
		torre.mesh = load("res://modelos/cenario/torre.res")
		torre.material_override = Materiais.toon(false, 0.004, {"borda": 0.35})
		torre.position = Vector3(s * 2.75, -0.02, Z_FUNDO + 0.4)
		torre.rotation_degrees.y = -s * 25
		add_child(torre)

	# lâmpadas: contorno da placa + arco
	var pontos: Array[Vector3] = []
	var zc := Z_PINO1 + 0.83
	for i in 26:
		pontos.append(Vector3(-1.3 + i * 0.104, 2.29, zc))
		pontos.append(Vector3(-1.3 + i * 0.104, 1.41, zc))
	for i in 9:
		pontos.append(Vector3(-1.33, 1.41 + i * 0.11, zc))
		pontos.append(Vector3(1.33, 1.41 + i * 0.11, zc))
	var R := 3.0 * 0.95 - 0.42 * 0.95 - 0.08
	for i in 40:
		var a := PI * (i + 0.5) / 40.0
		pontos.append(Vector3(cos(a) * R, sin(a) * R - 0.05, Z_FUNDO - 0.5 + 0.38))
	var cores := [Color("#FFE14D"), Color("#FF5FA8"), Color("#4FD8FF"), Color("#8DFF6A")]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = load("res://modelos/cenario/lampada.res")
	mm.instance_count = pontos.size()
	for i in pontos.size():
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.75), pontos[i]))
		mm.set_instance_color(i, cores[i % cores.size()])
		mm.set_instance_custom_data(i, Color(float(i), 0, 0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mat_lampadas = ShaderMaterial.new()
	mat_lampadas.shader = load("res://shaders/lampadas.gdshader")
	mmi.material_override = mat_lampadas
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


# ================================================================ decoração
func _objeto(nome: String, pos: Vector3, rot_y := 0.0, escala := 1.0, contorno := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = load("res://modelos/cenario/%s.res" % nome)
	mi.material_override = Materiais.toon(false, contorno, {"borda": 0.3})
	mi.position = pos
	mi.rotation.y = rot_y
	mi.scale = Vector3.ONE * escala
	# só os objetos perto da pista fazem sombra (economiza a placa de vídeo)
	if absf(pos.x) > 4.5 or pos.z < -18.0:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _decoracao() -> void:
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 2026
	var tipos := ["arvore_verde", "arvore_rosa", "arvore_lilas", "pirulito", "cogumelo", "bengala",
		"presente", "donut", "cupcake", "arvore_verde", "pirulito", "arvore_rosa"]
	var usados: Array[Vector2] = []
	var colocados := 0
	var tentativas := 0
	while colocados < 46 and tentativas < 2000:
		tentativas += 1
		var s := -1.0 if rnd.randf() < 0.5 else 1.0
		var x := s * rnd.randf_range(3.6, 15.0)
		var z := rnd.randf_range(-34.0, 7.0)
		# perto da área de jogo: só objetos baixos e bem afastados da câmera
		if z > -2.0 and abs(x) < 5.0:
			continue
		var p := Vector2(x, z)
		var ok := true
		for u in usados:
			if u.distance_to(p) < 2.6:
				ok = false
				break
		if not ok:
			continue
		usados.append(p)
		var tipo: String = tipos[rnd.randi() % tipos.size()]
		var esc := rnd.randf_range(0.9, 1.35)
		if tipo.begins_with("arvore"):
			esc *= 1.25
		var y := _altura_terreno(x, z)
		_objeto(tipo, Vector3(x, y - 0.05, z), rnd.randf() * TAU, esc)
		colocados += 1
	# destaque perto da pista (vistos de perto nas jogadas)
	for item in [["pirulito", -2.55, -1.5, 0.3, 0.75, 0.004], ["pirulito", 2.7, -3.5, -0.4, 0.85, 0.004],
			["presente", -3.9, 3.4, 0.4, 0.8, 0.004], ["cupcake", 3.9, 2.6, 0.0, 0.75, 0.004],
			["bengala", 2.3, -8.0, 2.0, 0.9, 0.0], ["bengala", -2.3, -9.0, 1.0, 0.9, 0.0],
			["cogumelo", -2.4, -5.5, 0.0, 0.9, 0.0], ["donut", 2.4, -11.5, 0.5, 0.85, 0.0]]:
		var y: float = 0.0 if (item[2] > 0.0 and absf(item[1]) < 3.3) else _altura_terreno(item[1], item[2])
		_objeto(item[0], Vector3(item[1], y - 0.02, item[2]), item[3], item[4], item[5])


## Mesma fórmula do tools/modelos/modelos.py (gerar_terreno), para apoiar
## os objetos no chão.
func _altura_terreno(x: float, z: float) -> float:
	var morros := [[-9, -20, 6, 2.2], [10, -26, 7, 2.6], [-14, -42, 9, 3.4], [15, -48, 10, 3.8], [0, -64, 16, 5.0],
		[-20, -10, 6, 1.8], [21, -8, 7, 2.2], [-26, -30, 9, 4.0], [27, -34, 10, 4.5], [-6, -52, 6, 2.0], [6, -58, 7, 2.4]]
	var h := 0.0
	for m in morros:
		h += m[3] * exp(-((x - m[0]) * (x - m[0]) + (z - m[1]) * (z - m[1])) / (2.0 * m[2] * m[2]))
	var p: float = clamp((abs(x) - 3.2) / 4.0, 0.0, 1.0)
	p = p * p * (3.0 - 2.0 * p)
	return h * p + 0.06 * sin(x * 0.7) * sin(z * 0.55) * p - 0.02 - 0.22 * (1.0 - p)


func _nuvens_e_baloes() -> void:
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 77
	var mn: Mesh = load("res://modelos/cenario/nuvem.res")
	var mat_n := Materiais.toon(false, 0.0, {"borda": 0.6, "luz_minima": 0.5, "cor_borda": Color(1, 0.9, 1)})
	for i in 14:
		var n := MeshInstance3D.new()
		n.mesh = mn
		n.material_override = mat_n
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var lado := -1.0 if i % 2 == 0 else 1.0
		n.position = Vector3(lado * rnd.randf_range(4.0, 22.0), rnd.randf_range(6.0, 15.0), rnd.randf_range(-60.0, -8.0))
		n.scale = Vector3.ONE * rnd.randf_range(1.2, 2.6)
		n.rotation.y = rnd.randf() * TAU
		add_child(n)
		_nuvens.append([n, rnd.randf_range(0.15, 0.4)])
	var mb: Mesh = load("res://modelos/cenario/balao.res")
	var cores := [Color("#FF4B5C"), Color("#FFD43B"), Color("#4FC3F7"), Color("#5ED16A"), Color("#B388FF"), Color("#FF7EC1")]
	var linha_mat := Materiais.cor_toon(Color("#FFFFFF"), 0.0, {"borda": 0.0})
	for i in 16:
		var b := Node3D.new()
		var mi := MeshInstance3D.new()
		mi.mesh = mb
		mi.material_override = Materiais.toon(false, 0.0, {"tinta": cores[i % cores.size()], "borda": 0.6, "especular": 0.8, "tamanho_especular": 0.95})
		b.add_child(mi)
		var fio := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.004
		cm.bottom_radius = 0.004
		cm.height = 0.9
		cm.radial_segments = 4
		fio.mesh = cm
		fio.position.y = -0.45
		fio.material_override = linha_mat
		b.add_child(fio)
		var lado := -1.0 if i % 2 == 0 else 1.0
		var base := Vector3(lado * rnd.randf_range(1.8, 5.5), rnd.randf_range(2.2, 4.8), rnd.randf_range(-19.0, -4.0))
		if i < 4:
			base = Vector3(lado * rnd.randf_range(2.0, 2.8), rnd.randf_range(2.6, 3.4), Z_FUNDO + rnd.randf_range(0.0, 1.5))
		b.position = base
		b.scale = Vector3.ONE * rnd.randf_range(0.8, 1.15)
		add_child(b)
		_baloes.append([b, base, rnd.randf() * TAU, rnd.randf_range(0.6, 1.1)])


# ================================================================ animação
func acender_pista(ligar: bool) -> void:
	_luz_alvo = 1.0 if ligar else 0.0


func _process(delta: float) -> void:
	if mat_pista == null:
		return
	_t = fposmod(_t + delta, 3600.0)
	_luz = move_toward(_luz, _luz_alvo, delta * 2.5)
	mat_pista.set_shader_parameter("luz", _luz)
	mat_pista.set_shader_parameter("fase", fposmod(_t * 2.2, 1.0))
	mat_pista.set_shader_parameter("bola_z", bola_z)
	mat_lampadas.set_shader_parameter("fase", fposmod(_t * 0.9, 100.0))
	mat_fundo.set_shader_parameter("fase", fposmod(_t * 0.4, 100.0))
	for n in _nuvens:
		var no: Node3D = n[0]
		no.position.x += n[1] * delta
		if no.position.x > 30.0:
			no.position.x = -30.0
	for b in _baloes:
		var no: Node3D = b[0]
		var base: Vector3 = b[1]
		var f: float = b[2]
		var v: float = b[3]
		no.position = base + Vector3(sin(_t * 0.5 * v + f) * 0.12, sin(_t * 0.9 * v + f * 2.0) * 0.18, 0)
		no.rotation.z = sin(_t * 0.7 * v + f) * 0.12


## Modo das lâmpadas: 0 corrida, 1 piscando todas (strike!), 2 alternado.
func lampadas(modo: int) -> void:
	mat_lampadas.set_shader_parameter("modo", modo)
