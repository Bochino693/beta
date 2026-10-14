class_name Mundo
extends Node3D

## O MUNDO 3D: céu, sol, terreno com morros, a pista (madeira, canaletas,
## para-choques), o fundo dos pinos (veludo com estrelas, letreiro com
## lâmpadas) e os 4 CENÁRIOS (temas.gd): Parque de Diversões, Espaço,
## Fundo do Mar e Selva dos Dinos — um por rodada.
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
const CAMADA_PISO_BOLA := 8
const CAMADA_PISO_PINOS := 16

var ambiente: Environment
var sol: DirectionalLight3D
var mat_pista: ShaderMaterial
var mat_lampadas: ShaderMaterial
var mat_fundo: ShaderMaterial
var mat_ceu: ShaderMaterial
var mat_placa: ShaderMaterial
var mat_divisoria: ShaderMaterial
var mat_faixa: ShaderMaterial
var mats_canaleta: Array[ShaderMaterial] = []
var mat_terreno: ShaderMaterial
var temas: Temas
var tema := ""
var _bumpers: Array[Node3D] = []
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
	temas = Temas.new()
	add_child(temas)
	temas.construir(self)
	aplicar_tema("parque")
	definir_protecao(Ajustes.protecao_canaleta())


## Troca o cenário: céu, luz, neblina, terreno, cores da pista e decoração.
func aplicar_tema(nome: String) -> void:
	if not Temas.CONFIG.has(nome):
		nome = "parque"
	tema = nome
	var c: Dictionary = Temas.CONFIG[nome]
	var ceu: Array = c["ceu"]
	mat_ceu.set_shader_parameter("cor_topo", ceu[0])
	mat_ceu.set_shader_parameter("cor_meio", ceu[1])
	mat_ceu.set_shader_parameter("cor_horizonte", ceu[2])
	mat_ceu.set_shader_parameter("cor_chao", ceu[3])
	mat_ceu.set_shader_parameter("cor_sol", c.get("cor_sol", Color(1.0, 0.95, 0.75)))
	mat_ceu.set_shader_parameter("forca_sol", c.get("forca_sol", 1.0))
	mat_ceu.set_shader_parameter("estrelas", c.get("estrelas", 0.0))
	mat_ceu.set_shader_parameter("cor_nebulosa", c.get("nebulosa", Color(0.9, 0.4, 1.0)))
	mat_ceu.set_shader_parameter("raios", c.get("raios", 0.0))
	ambiente.ambient_light_color = c["ambiente"]
	ambiente.ambient_light_energy = c.get("ambiente_forca", 0.62)
	ambiente.fog_light_color = c["neblina"]
	ambiente.fog_density = c.get("neblina_densidade", 0.0045)
	sol.light_color = c["sol"]
	sol.light_energy = c.get("sol_forca", 1.05)
	var f: Array = c["fundo"]
	mat_fundo.set_shader_parameter("cor_a", f[0])
	mat_fundo.set_shader_parameter("cor_b", f[1])
	mat_placa.set_shader_parameter("tinta", c["placa"])
	mat_divisoria.set_shader_parameter("tinta", c["divisoria"])
	mat_faixa.set_shader_parameter("tinta", c["faixa"])
	for m in mats_canaleta:
		m.set_shader_parameter("tinta", c["canaleta"])
	var chao: Array = c["chao"]
	mat_terreno.set_shader_parameter("modo", int(c["chao_modo"]))
	for i in 4:
		mat_terreno.set_shader_parameter(["cor_a", "cor_b", "cor_c", "cor_d"][i], chao[i])
	temas.mostrar(nome)


# ================================================================ ambiente
func _ambiente() -> void:
	var we := WorldEnvironment.new()
	ambiente = Environment.new()
	var ceu := Sky.new()
	var mc := ShaderMaterial.new()
	mc.shader = load("res://shaders/ceu.gdshader")
	mat_ceu = mc
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
	# sombra nítida perto da câmera (2 divisões) na alta; uma só na média
	sol.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if q == "alta" else DirectionalLight3D.SHADOW_ORTHOGONAL
	sol.directional_shadow_split_1 = 0.25
	sol.directional_shadow_max_distance = 32.0 if q == "alta" else 26.0
	RenderingServer.directional_shadow_atlas_set_size(4096 if q == "alta" else 2048, true)


# ================================================================ terreno
func _terreno() -> void:
	# um relevo só; o desenho do chão de cada cenário sai do shader (nítido)
	mat_terreno = ShaderMaterial.new()
	mat_terreno.shader = load("res://shaders/terreno.gdshader")
	var t := MeshInstance3D.new()
	t.mesh = load("res://modelos/terreno.res")
	t.material_override = mat_terreno
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
	var deck := _caixa(Vector3(MEIA_LARGURA * 2, 0.2, comp), Vector3(0, -0.1, 0.1 - comp / 2), mat_pista, false, false)
	deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# física: duas peças INTEIRAS (sem emendas, que fariam a bola pular):
	# a da bola é lisa (óleo); a dos pinos tem atrito de madeira seca, para
	# eles não escorregarem como no gelo. Cada uma só "existe" para quem pisa.
	var cb := 1.2 - Z_FIM_DECK
	var piso_bola := _corpo_caixa(Vector3(MEIA_LARGURA * 2, 0.2, cb), Vector3(0, -0.1, 1.2 - cb / 2), 0.05, 0.05)
	piso_bola.collision_layer = CAMADA_PISO_BOLA
	var piso_pinos := _corpo_caixa(Vector3(MEIA_LARGURA * 2, 0.2, cb), Vector3(0, -0.1, 1.2 - cb / 2), 0.42, 0.1)
	piso_pinos.collision_layer = CAMADA_PISO_PINOS

	# --- área de aproximação (onde o personagem corre)
	var ma := StandardMaterial3D.new()
	ma.albedo_texture = Materiais.textura("madeira")
	ma.albedo_color = Color(0.93, 0.84, 0.76)
	ma.uv1_scale = Vector3(4.2, 1.6, 1)
	ma.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	ma.roughness = 0.35
	var aprox := _caixa(Vector3(6.6, 0.2, 6.2), Vector3(0, -0.101, 3.2), ma, true, false, 0.8, 0.0)
	aprox.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# faixa colorida nas bordas da aproximação
	mat_faixa = Materiais.cor_toon(Color("#FF9F2E"))
	for s in [-1, 1]:
		_caixa(Vector3(0.12, 0.04, 6.2), Vector3(s * 3.3, 0.0, 3.2), mat_faixa, false, false)

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
		var mcan := _material_por_dentro(Color("#B9A6FF"))
		mats_canaleta.append(mcan)
		cil.material_override = mcan
		cil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(cil)
		# colisão: fundo da canaleta e parede de fora
		_corpo_caixa(Vector3(CANALETA, 0.1, comp), Vector3(x, Y_CANALETA - 0.05 - 0.02, 0.1 - comp / 2), 0.2, 0.1)
		# divisória (capping) colorida entre a canaleta e o gramado
		if mat_divisoria == null:
			mat_divisoria = Materiais.cor_toon(Color("#FFB627"), 0.0, {"borda": 0.25})
		var largura_cap := 0.32
		var xc: float = s * (MEIA_LARGURA + CANALETA + largura_cap / 2)
		_caixa(Vector3(largura_cap, 0.34, Z_PINO1 * -1 + 0.6), Vector3(xc, -0.07, (Z_PINO1 + 0.6) / 2.0 + 0.0),
			mat_divisoria, true, true, 0.3, 0.3)
		# faixinha de luz em cima da divisória
		var luzes := _caixa(Vector3(0.05, 0.012, -Z_PINO1 + 0.5), Vector3(xc, 0.105, Z_PINO1 / 2.0 + 0.0),
			Materiais.cor_toon(Color("#FFFFFF"), 0.0, {"emissao": Color(0.35, 0.85, 1.0), "borda": 0.0}), false, false)
		luzes.name = "luz_divisoria_%d" % s

	# --- para-choques (bumpers) listrados de doce
	# cápsula simples + listras pelo shader (nítidas em 4K e levinhas)
	var mb := CapsuleMesh.new()
	mb.radius = 0.07
	mb.height = 1.14
	mb.radial_segments = 24
	mb.rings = 6
	var mat_b := ShaderMaterial.new()
	mat_b.shader = load("res://shaders/doce_listrado.gdshader")
	if Materiais.contornos_ligados:
		var contorno_b := ShaderMaterial.new()
		contorno_b.shader = Materiais.shader(Materiais.CONTORNO)
		contorno_b.set_shader_parameter("espessura", 0.003)
		contorno_b.set_shader_parameter("usa_cor_vertice", 0.0)
		mat_b.next_pass = contorno_b
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
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(s * 0.735, 0.1, -0.6 - i * 0.96)))
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
	q.size = Vector2(2.2, 2.6)
	fundo.mesh = q
	fundo.material_override = mat_fundo
	fundo.position = Vector3(0, 0.9, Z_FUNDO + 0.01)
	add_child(fundo)
	_corpo_caixa(Vector3(2.4, 2.0, 0.2), Vector3(0, 0.5, Z_FUNDO - 0.1), 0.9, 0.0)
	# teto escuro do fosso (esconde a parte de cima)
	_caixa(Vector3(2.3, 0.1, -Z_FUNDO + Z_PINO1 + 0.7), Vector3(0, 2.12, (Z_PINO1 + 0.7 + Z_FUNDO) / 2),
		Materiais.cor_toon(Color("#4A238F"), 0.0, {"borda": 0.0}), false, false)

	# letreiro (masking) acima dos pinos, com o logo e lâmpadas
	mat_placa = Materiais.cor_toon(Color("#3A1C7A"), 0.004, {"borda": 0.4})
	var placa := _caixa(Vector3(2.7, 0.95, 0.14), Vector3(0, 1.85, Z_PINO1 + 0.75), mat_placa, false, true)
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

	# lâmpadas: contorno da placa (o arco-íris do parque tem as suas: temas.gd)
	var pontos: Array[Vector3] = []
	var zc := Z_PINO1 + 0.83
	for i in 26:
		pontos.append(Vector3(-1.3 + i * 0.104, 2.29, zc))
		pontos.append(Vector3(-1.3 + i * 0.104, 1.41, zc))
	for i in 9:
		pontos.append(Vector3(-1.33, 1.41 + i * 0.11, zc))
		pontos.append(Vector3(1.33, 1.41 + i * 0.11, zc))
	mat_lampadas = ShaderMaterial.new()
	mat_lampadas.shader = load("res://shaders/lampadas.gdshader")
	add_child(lampadas_em(pontos))


## Fileira de lâmpadas (MultiMesh) que piscam com o material comum.
func lampadas_em(pontos: Array[Vector3], fase0 := 0) -> MultiMeshInstance3D:
	var cores := [Color("#FFE14D"), Color("#FF9F2E"), Color("#4FD8FF"), Color("#8DFF6A")]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = load("res://modelos/cenario/lampada.res")
	mm.instance_count = pontos.size()
	for i in pontos.size():
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.75), pontos[i]))
		mm.set_instance_color(i, cores[i % cores.size()])
		mm.set_instance_custom_data(i, Color(float(i + fase0), 0, 0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat_lampadas
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


# ================================================================ decoração
func _objeto(nome: String, pos: Vector3, rot_y := 0.0, escala := 1.0, contorno := 0.0, pai: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var caminho := "res://modelos/cenario/%s.res" % nome
	if not ResourceLoader.exists(caminho):
		push_warning("modelo que falta: " + caminho)
		return mi
	mi.mesh = load(caminho)
	mi.material_override = Materiais.toon(false, contorno, {"borda": 0.3})
	mi.position = pos
	mi.rotation.y = rot_y
	mi.scale = Vector3.ONE * escala
	# só os objetos perto da pista fazem sombra (economiza a placa de vídeo)
	if absf(pos.x) > 4.5 or pos.z < -18.0:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(pai if pai != null else self).add_child(mi)
	return mi


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


## Modo das lâmpadas: 0 corrida, 1 piscando todas (strike!), 2 alternado.
func lampadas(modo: int) -> void:
	mat_lampadas.set_shader_parameter("modo", modo)
