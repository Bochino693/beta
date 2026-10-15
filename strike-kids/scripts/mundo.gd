class_name Mundo
extends Node3D

## O MUNDO 3D: céu, sol, terreno com morros, a pista (madeira, canaletas,
## para-choques), o fundo dos pinos (veludo com estrelas, letreiro com
## lâmpadas) e os 4 CENÁRIOS (temas.gd): Parque de Diversões, Espaço,
## Fundo do Mar e Selva dos Dinos — um por rodada.
##
## Medidas: linha de falta em z = 0; os pinos em z = -10,5 (pista infantil,
## mais curta que a de adulto: a bola chega rápido); a pista vai para -Z.
##
## Marca Lazer & Sport: duas placas iluminadas dos lados do letreiro dos
## pinos. Pódios (escolha do personagem e foto) nas cores de Bob e Mia.

const MEIA_LARGURA := 0.675
const CANALETA := 0.25
const Z_PINO1 := -10.5
const ESPACO_PINOS := 0.38
const FILEIRA := 0.329
const Z_FIM_DECK := -11.95
const Z_FUNDO := -13.7
const Y_CANALETA := -0.09

const CAMADA_MUNDO := 1
const CAMADA_PINOS := 2
const CAMADA_BOLA := 4
const CAMADA_PISO_BOLA := 8
const CAMADA_PISO_PINOS := 16
const ALTURA_PODIO := 0.152
const BALAO_POS := Vector3(-2.9, 2.9, Z_PINO1 + 1.6)

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
var balao: Node3D
var mat_balao: ShaderMaterial
var _balao_partes := {}
var _podios: Array[Node3D] = []
var _mats_podio: Array[ShaderMaterial] = []
var _podio_destaque := -1
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
	_colunas()
	_balao_marca()
	_area_dos_jogadores()
	_montar_podios()
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
	_tema_balao(c.get("balao", {}))
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
	ambiente.ambient_light_color = Color(0.62, 0.7, 0.86)
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
	mat_pista.set_shader_parameter("z_pino1", Z_PINO1)
	# marca Lazer & Sport impressa na madeira, no meio da pista (sutil)
	mat_pista.set_shader_parameter("logo_marca", load("res://ui/marca/lazer_sport.png"))
	mat_pista.set_shader_parameter("usa_marca", true)
	mat_pista.set_shader_parameter("marca_ret", Vector4(0.0, -Z_PINO1 * 0.52, 1.02, 1.02 * 1698.0 / 2560.0 * 2.1))
	mat_pista.set_shader_parameter("meia_largura", MEIA_LARGURA)
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

	# --- canaletas: meia-cana de verdade (perfil liso, 56 segmentos na
	# curva), lábios no nível da pista; começam na linha de falta
	var perfil_c := Perfis.canaleta(CANALETA / 2.0)
	# mais escura no fundo da calha, clara nos lábios: lê-se a curva de longe
	var malha_c := Perfis.extrudar(perfil_c, Z_FIM_DECK, 0.1, true, true, 50.0, Vector4(-0.15, -0.005, 0.5, 1.05))
	for s in [-1, 1]:
		var x: float = s * (MEIA_LARGURA + CANALETA / 2)
		var mcan := Materiais.toon(false, 0.0, {"tinta": Color("#8FC4EE"), "borda": 0.18, "faixa": 0.22,
			"luz_minima": 0.45, "especular": 0.6, "tamanho_especular": 0.95})
		mats_canaleta.append(mcan)
		var can := MeshInstance3D.new()
		can.mesh = malha_c
		can.material_override = mcan
		can.position = Vector3(x, 0.0, 0.0)
		can.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		can.name = "canaleta_%d" % s
		add_child(can)
		# colisão: fundo da canaleta e parede de fora
		_corpo_caixa(Vector3(CANALETA, 0.1, comp), Vector3(x, Y_CANALETA - 0.05 - 0.02, 0.1 - comp / 2), 0.2, 0.1)
		# divisória (capping) arredondada entre a canaleta e o gramado: vai
		# dos pinos até a linha de falta (não invade a área do jogador)
		if mat_divisoria == null:
			mat_divisoria = Materiais.cor_toon(Color("#FFB627"), 0.0, {"borda": 0.25, "especular": 0.4})
		var largura_cap := 0.32
		var xc: float = s * (MEIA_LARGURA + CANALETA + 0.036 + largura_cap / 2)
		var cap := MeshInstance3D.new()
		cap.mesh = Perfis.extrudar(Perfis.retangulo(largura_cap, 0.34, 0.06, Vector2(0, -0.07)), Z_PINO1 + 0.2, 0.1)
		cap.material_override = mat_divisoria
		cap.position = Vector3(xc, 0.0, 0.0)
		cap.name = "divisoria_%d" % s
		add_child(cap)
		# (colisão igual à usada na calibração das jogadas)
		_corpo_caixa(Vector3(largura_cap, 0.34, Z_PINO1 * -1 + 0.6), Vector3(s * (MEIA_LARGURA + CANALETA + largura_cap / 2), -0.07,
			(Z_PINO1 + 0.6) / 2.0), 0.3, 0.3)
		# faixinha de luz em cima da divisória
		var luzes := _caixa(Vector3(0.05, 0.012, -Z_PINO1 - 0.3), Vector3(xc, 0.104, (Z_PINO1 + 0.2) / 2.0 + 0.05),
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


func definir_protecao(ligada: bool) -> void:
	for g in _bumpers:
		g.visible = ligada
		var sb := g.get_node("fisica") as StaticBody3D
		sb.collision_layer = CAMADA_MUNDO if ligada else 0


# ================================================================ fundo dos pinos
## Peça lisa feita por perfil (scripts/perfis.gd).
func _peca(perfil: PackedVector2Array, z0: float, z1: float, mat: Material, nome := "", sombra := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Perfis.extrudar(perfil, z0, z1)
	mi.material_override = mat
	if not sombra:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if nome != "":
		mi.name = nome
	add_child(mi)
	return mi


## A CAÇAPA e o GABINETE DA MÁQUINA: paredes laterais acolchoadas (os pinos
## batem e voltam), cortina pregueada de estrelas com almofada embaixo e, por
## fora, um gabinete fechado (laterais, teto e fundo com a marca) — de
## qualquer ângulo, inclusive por trás, é uma máquina de boliche inteira.
func _fundo_dos_pinos() -> void:
	var fosso := Materiais.cor_toon(Color("#16336E"), 0.0, {"borda": 0.3})
	var parede := Materiais.cor_toon(Color("#2A63C4"), 0.0, {"borda": 0.3, "especular": 0.25})
	var friso := Materiais.cor_toon(Color("#FFB627"), 0.0, {"borda": 0.25, "especular": 0.5})
	var gabinete := Materiais.cor_toon(Color("#123A7A"), 0.004, {"borda": 0.35, "especular": 0.2})
	var z_frente := Z_PINO1 + 0.9
	# paredes laterais (kickbacks): visual arredondado + a mesma colisão de antes
	for s in [-1, 1]:
		var x: float = s * (MEIA_LARGURA + CANALETA + 0.06)
		var kb := _peca(Perfis.retangulo(0.12, 1.0, 0.05, Vector2(x, 0.35)), Z_FUNDO, z_frente, parede, "parede_%d" % s)
		kb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_peca(Perfis.retangulo(0.17, 0.07, 0.034, Vector2(x, 0.875)), Z_FUNDO, z_frente + 0.02, friso, "", false)
		_corpo_caixa(Vector3(0.12, 1.0, -Z_FUNDO + z_frente), Vector3(x, 0.35, (z_frente + Z_FUNDO) / 2), 0.3, 0.35)
	# fosso
	_caixa(Vector3(2.0, 0.2, -Z_FUNDO + Z_FIM_DECK), Vector3(0, -0.24, (Z_FIM_DECK + Z_FUNDO) / 2), fosso, true, false, 0.9, 0.05)
	# cortina pregueada (estrelinhas) + almofada de borracha embaixo
	mat_fundo = ShaderMaterial.new()
	mat_fundo.shader = load("res://shaders/fundo_estrelas.gdshader")
	var fundo := MeshInstance3D.new()
	fundo.mesh = Perfis.cortina(2.2, 2.6, 11, 0.07)
	fundo.material_override = mat_fundo
	fundo.position = Vector3(0, 0.9, Z_FUNDO + 0.04)
	fundo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fundo.name = "cortina"
	add_child(fundo)
	var almofada := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.075
	cap.height = 2.0
	cap.radial_segments = 32
	cap.rings = 8
	almofada.mesh = cap
	almofada.rotation_degrees.z = 90
	almofada.position = Vector3(0, -0.07, Z_FUNDO + 0.1)
	almofada.material_override = Materiais.cor_toon(Color("#1A2236"), 0.0, {"borda": 0.4, "especular": 0.35})
	add_child(almofada)
	_corpo_caixa(Vector3(2.4, 2.0, 0.2), Vector3(0, 0.5, Z_FUNDO - 0.1), 0.9, 0.0)
	# teto escuro do fosso (esconde a parte de cima)
	_caixa(Vector3(2.3, 0.1, -Z_FUNDO + Z_PINO1 + 0.7), Vector3(0, 2.12, (Z_PINO1 + 0.7 + Z_FUNDO) / 2),
		Materiais.cor_toon(Color("#0B1B3A"), 0.0, {"borda": 0.0}), false, false)
	# gabinete por fora: laterais, teto e fundo (com a marca atrás)
	var z_tras := Z_FUNDO - 0.95
	var z_masc := Z_PINO1 + 0.68
	for s in [-1, 1]:
		_peca(Perfis.retangulo(0.34, 2.8, 0.12, Vector2(s * 1.23, 1.1)), z_tras + 0.3, z_masc, gabinete, "gabinete_lado_%d" % s)
	_peca(Perfis.retangulo(2.8, 0.32, 0.1, Vector2(0, 2.36)), z_tras + 0.3, z_masc, gabinete, "gabinete_teto")
	_peca(Perfis.retangulo(2.9, 2.85, 0.22, Vector2(0, 1.1)), z_tras, Z_FUNDO - 0.02, gabinete, "gabinete_fundo")
	_peca(Perfis.retangulo(2.96, 0.09, 0.04, Vector2(0, 2.5)), z_tras - 0.03, z_masc, friso, "", false)
	# a marca atrás do gabinete, sem placa (vista nos passeios de câmera)
	var marca: Texture2D = load("res://ui/marca/lazer_sport.png")
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_texture = marca
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.5, 1.5 * float(marca.get_height()) / float(marca.get_width()))
	q.mesh = qm
	q.material_override = mm
	q.rotation_degrees.y = 180
	q.position = Vector3(0, 1.4, z_tras - 0.01)
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(q)

	# letreiro (masking) acima dos pinos, com o logo e lâmpadas
	mat_placa = Materiais.cor_toon(Color("#0E2A5C"), 0.004, {"borda": 0.4})
	var placa := _peca(Perfis.retangulo(2.7, 0.95, 0.07, Vector2(0, 1.85)), Z_PINO1 + 0.68, Z_PINO1 + 0.82, mat_placa, "placa")
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


## Colunas dos dois lados do letreiro STRIKE KIDS, com faixas de lâmpadas:
## fecham a frente do gabinete da máquina.
func _colunas() -> void:
	var zc := Z_PINO1 + 0.75
	var pontos: Array[Vector3] = []
	for s in [-1, 1]:
		var x: float = s * 1.93
		_peca(Perfis.retangulo(1.16, 2.7, 0.12, Vector2(x, 1.0)), zc - 0.07, zc + 0.07, mat_placa, "coluna_%d" % s)
		for i in 21:
			pontos.append(Vector3(x - s * 0.5, 0.2 + i * 0.1, zc + 0.08))
			pontos.append(Vector3(x + s * 0.5, 0.2 + i * 0.1, zc + 0.08))
	add_child(lampadas_em(pontos, 50))


## BALÃO DA MARCA: a logo Lazer & Sport (sem fundo) impressa num balão que
## flutua ao lado da pista. Em cada cenário ele vira uma coisa do lugar:
## balão (parque, dinos), planetinha com anel (espaço), bolha (mar).
func _balao_marca() -> void:
	balao = Node3D.new()
	balao.name = "balao_marca"
	balao.position = BALAO_POS
	add_child(balao)
	var logo: Texture2D = load("res://ui/marca/lazer_sport.png")
	var corpo := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 72
	sm.rings = 36
	corpo.mesh = sm
	corpo.scale = Vector3(1.0, 1.12, 1.0)
	var w := 1.32
	mat_balao = Materiais.toon(true, 0.004, {"usa_rosto": true, "rosto": logo, "rosto_grade": Vector2(1, 1),
		"rosto_celula": Vector2.ZERO, "rosto_centro": Vector2(0.0, 0.06),
		"rosto_tamanho": Vector2(w, w * 1698.0 / 2560.0 / 1.12), "borda": 0.4, "faixa": 0.12, "luz_minima": 0.38,
		"especular": 0.3, "tamanho_especular": 0.985})
	corpo.material_override = mat_balao
	corpo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	balao.add_child(corpo)
	# nó e cordão (balão)
	var no := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.025
	cm.bottom_radius = 0.09
	cm.height = 0.14
	no.mesh = cm
	no.position.y = -1.17
	no.material_override = mat_balao
	balao.add_child(no)
	var cordao := MeshInstance3D.new()
	var cc := CylinderMesh.new()
	cc.top_radius = 0.008
	cc.bottom_radius = 0.008
	cc.height = 2.3
	cordao.mesh = cc
	cordao.position.y = -1.24 - 1.15
	cordao.material_override = Materiais.cor_toon(Color("#FFFFFF"), 0.0, {"borda": 0.0, "luz_minima": 0.6})
	balao.add_child(cordao)
	# anel (planetinha)
	var anel := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.32
	tm.outer_radius = 1.62
	tm.rings = 96
	tm.ring_segments = 12
	anel.mesh = tm
	anel.scale = Vector3(1.0, 0.16, 1.0)
	anel.rotation_degrees = Vector3(26, 0, -8)   # a frente do anel passa embaixo da logo
	anel.material_override = Materiais.cor_toon(Color("#FFC21A"), 0.003, {"borda": 0.35, "especular": 0.6})
	anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	balao.add_child(anel)
	_balao_partes = {"no": no, "cordao": cordao, "anel": anel}


func _tema_balao(b: Dictionary) -> void:
	var tipo: String = b.get("tipo", "balao")
	var cor: Color = b.get("cor", Color("#E8384F"))
	mat_balao.set_shader_parameter("tinta", cor)
	mat_balao.set_shader_parameter("borda", 1.1 if tipo == "bolha" else 0.4)
	mat_balao.set_shader_parameter("cor_borda", Color(1, 1, 1) if tipo == "bolha" else Color(1.0, 0.95, 0.9))
	(_balao_partes["no"] as Node3D).visible = tipo == "balao"
	(_balao_partes["cordao"] as Node3D).visible = tipo == "balao"
	(_balao_partes["anel"] as Node3D).visible = tipo == "planeta"


# ================================================================ área dos jogadores
## Atrás de quem joga: tapete, parede com o letreiro STRIKE KIDS aceso,
## sofás e o retorno de bolas. Quando a câmera vira para
## o mascote (reação, comemoração), o fundo é o salão — nada de chão
## infinito.
func _area_dos_jogadores() -> void:
	var z_parede := 7.7
	var marinho := Materiais.cor_toon(Color("#123A7A"), 0.004, {"borda": 0.3, "especular": 0.2})
	var azul := Materiais.cor_toon(Color("#1E62C8"), 0.0, {"borda": 0.3})
	var amarelo := Materiais.cor_toon(Color("#FFB627"), 0.0, {"borda": 0.25, "especular": 0.4})
	var vermelho := Materiais.cor_toon(Color("#E8384F"), 0.004, {"borda": 0.3, "especular": 0.3})
	var tapete := Materiais.cor_toon(Color("#1B3E86"), 0.0, {"borda": 0.15})
	# tapete entre a área de aproximação e a parede (+ friso amarelo)
	_caixa(Vector3(9.6, 0.06, z_parede - 6.3), Vector3(0, -0.03, (6.3 + z_parede) / 2), tapete, false, false)
	_caixa(Vector3(6.6, 0.065, 0.07), Vector3(0, -0.03, 6.33), amarelo, false, false)
	# parede: barra azul embaixo, friso amarelo, parte de cima azul-marinho
	_peca(Perfis.retangulo(9.6, 3.5, 0.2, Vector2(0, 1.65)), z_parede, z_parede + 0.3, marinho, "parede_fundo")
	_peca(Perfis.retangulo(9.4, 1.0, 0.06, Vector2(0, 0.5)), z_parede - 0.05, z_parede, azul, "", false)
	_peca(Perfis.retangulo(9.4, 0.09, 0.04, Vector2(0, 1.04)), z_parede - 0.07, z_parede, amarelo, "", false)
	# letreiro STRIKE KIDS virado para a pista, com lâmpadas em volta
	var logo_tex := Materiais.textura("logo")
	var pontos: Array[Vector3] = []
	if logo_tex != null:
		var lq := QuadMesh.new()
		var lw := 3.0
		lq.size = Vector2(lw, lw * float(logo_tex.get_height()) / float(logo_tex.get_width()))
		var ml := StandardMaterial3D.new()
		ml.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ml.albedo_texture = logo_tex
		ml.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ml.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		var logo := MeshInstance3D.new()
		logo.mesh = lq
		logo.material_override = ml
		logo.rotation_degrees.y = 180
		logo.position = Vector3(0, 2.3, z_parede - 0.03)
		logo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(logo)
		for i in 30:
			var x := -1.75 + i * (3.5 / 29.0)
			pontos.append(Vector3(x, 3.1, z_parede - 0.04))
			pontos.append(Vector3(x, 1.55, z_parede - 0.04))
	add_child(lampadas_em(pontos, 200))
	# sofás vermelhos encostados na parede
	for s in [-1, 1]:
		var sofa := Node3D.new()
		sofa.position = Vector3(s * 2.75, 0, z_parede - 0.42)
		sofa.rotation_degrees.y = 90
		add_child(sofa)
		for parte in [[Perfis.retangulo(0.66, 0.42, 0.12, Vector2(0.0, 0.21)), 0.0],
				[Perfis.retangulo(0.2, 0.86, 0.09, Vector2(-0.27, 0.43)), 0.0],
				[Perfis.retangulo(0.66, 0.6, 0.1, Vector2(0.0, 0.3)), 1.0]]:
			var mi := MeshInstance3D.new()
			if parte[1] == 0.0:
				mi.mesh = Perfis.extrudar(parte[0], -1.25, 1.25)
			else:
				mi.mesh = Perfis.extrudar(parte[0], -0.12, 0.12)
			mi.material_override = vermelho if parte[1] == 0.0 else marinho
			sofa.add_child(mi)
			if parte[1] == 1.0:
				var outro := mi.duplicate() as MeshInstance3D
				mi.position.z = -1.35
				outro.position.z = 1.35
				sofa.add_child(outro)
	# retorno de bolas (como num boliche de verdade), do lado direito
	var ret := Node3D.new()
	ret.position = Vector3(2.35, 0, 5.2)
	add_child(ret)
	var corpo := MeshInstance3D.new()
	corpo.mesh = Perfis.extrudar(Perfis.retangulo(0.56, 0.5, 0.1, Vector2(0, 0.25)), -0.8, 0.8)
	corpo.material_override = marinho
	ret.add_child(corpo)
	var capo := MeshInstance3D.new()
	capo.mesh = Perfis.extrudar(Perfis.retangulo(0.6, 0.5, 0.24, Vector2(0, 0.62)), 0.25, 0.8)
	capo.material_override = azul
	ret.add_child(capo)
	var trilho := MeshInstance3D.new()
	trilho.mesh = Perfis.extrudar(Perfis.retangulo(0.5, 0.06, 0.03, Vector2(0, 0.53)), -0.78, 0.3)
	trilho.material_override = amarelo
	ret.add_child(trilho)
	var cores := [Color("#169BD5"), Color("#FF7A21"), Color("#2DBE4E")]
	for i in 3:
		var b := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.13
		sm.height = 0.26
		sm.radial_segments = 32
		sm.rings = 16
		b.mesh = sm
		b.material_override = Materiais.cor_toon(cores[i], 0.003, {"borda": 0.4, "especular": 0.8})
		b.position = Vector3(0, 0.69, -0.62 + i * 0.29)
		ret.add_child(b)


# ================================================================ pódios
func _montar_podios() -> void:
	for i in 2:
		var g := Node3D.new()
		g.visible = false
		g.name = "podio_%d" % i
		add_child(g)
		var cor := Color("#169BD5") if i == 0 else Color("#FF7A21")
		var base := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.4
		cm.bottom_radius = 0.45
		cm.height = 0.14
		cm.radial_segments = 48
		cm.rings = 1
		base.mesh = cm
		base.position.y = 0.07
		base.material_override = Materiais.cor_toon(cor, 0.004, {"borda": 0.35})
		g.add_child(base)
		var tampa := MeshInstance3D.new()
		var ct := CylinderMesh.new()
		ct.top_radius = 0.37
		ct.bottom_radius = 0.37
		ct.height = 0.012
		ct.radial_segments = 48
		ct.rings = 1
		tampa.mesh = ct
		tampa.position.y = 0.146
		tampa.material_override = Materiais.cor_toon(Color("#F4F8FF"), 0.0, {"borda": 0.2})
		g.add_child(tampa)
		# anel de luz em volta da tampa (acende no escolhido)
		var aro := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.37
		tm.outer_radius = 0.405
		tm.rings = 64
		tm.ring_segments = 10
		aro.mesh = tm
		aro.position.y = 0.142
		var ma := Materiais.cor_toon(Color("#FFD43B"), 0.0, {"borda": 0.0, "emissao": Color(0, 0, 0)})
		aro.material_override = ma
		aro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(aro)
		_podios.append(g)
		_mats_podio.append(ma)


## Liga/desliga os pódios (posições no chão) e acende o do escolhido.
func podios(ligar: bool, posicoes: Array = [], destaque := -1) -> void:
	for i in _podios.size():
		var g := _podios[i]
		var ia := not g.visible
		g.visible = ligar and i < posicoes.size()
		if g.visible:
			g.position = posicoes[i]
			if ia:
				g.scale = Vector3(1, 0.2, 1)
				create_tween().tween_property(g, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_podio_destaque = destaque


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
	# balão da marca: sobe e desce devagar e balança um pouquinho
	balao.position = BALAO_POS + Vector3(0, sin(_t * 0.8) * 0.12, 0)
	balao.rotation = Vector3(0, sin(_t * 0.45) * 0.14, sin(_t * 0.6) * 0.04)
	mat_fundo.set_shader_parameter("fase", fposmod(_t * 0.4, 100.0))
	for i in _mats_podio.size():
		var on := 0.0
		if i == _podio_destaque:
			on = 0.75 + 0.25 * sin(_t * 6.0)
		_mats_podio[i].set_shader_parameter("emissao", Color(1.0, 0.75, 0.15) * on * 1.6)


## Modo das lâmpadas: 0 corrida, 1 piscando todas (strike!), 2 alternado.
func lampadas(modo: int) -> void:
	mat_lampadas.set_shader_parameter("modo", modo)
