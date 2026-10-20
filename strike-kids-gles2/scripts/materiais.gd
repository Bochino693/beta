class_name Materiais
extends Reference

## FÁBRICA DE MATERIAIS (com cache dos shaders) — edição OpenGL ES 2.0.
##
## LUZ NOS SHADERS: na placa OpenGL ES 2 (Mali-400/450) a luz do motor
## desenha cada objeto de novo para cada luz. Aqui a cena não tem luz
## nenhuma: o toon calcula o sol e a luz ambiente POR VÉRTICE, com a
## direção e as cores que o cenário passa em definir_luz(). Os materiais
## que usam a luz ficam registrados para receber a luz de cada cenário.

const TOON := "res://shaders/toon.shader"
const TOON_PERSONAGEM := "res://shaders/toon_personagem.shader"
const CONTORNO := "res://shaders/contorno.shader"
const SOMBRA := "res://shaders/sombra.shader"
const ADITIVO := "res://shaders/aditivo.shader"


static func _e() -> Dictionary:
	var e: Dictionary = Compat.estado("materiais")
	if e.empty():
		e["shaders"] = {}
		e["texturas"] = {}
		e["contornos"] = true
		e["registrados"] = []
		e["luz_dir"] = Vector3(0.35, 0.8, 0.5).normalized()
		# luz LINEAR (cor x força), como o motor do Godot 4 entregava
		e["luz_cor"] = Vector3(1.05, 0.935, 0.745)
		e["ambiente"] = Vector3(0.212, 0.278, 0.439)
	return e


## Contornos (casca invertida, o traço escuro em volta): nos bichinhos,
## pinos e peças da pista (a decoração do cenário leve não tem). Na
## qualidade BAIXA ficam desligados (cada peça com contorno é desenhada
## duas vezes).
static func contornos_ligados() -> bool:
	return bool(_e()["contornos"])


static func definir_contornos(sim: bool) -> void:
	_e()["contornos"] = sim


static func fonte(nome: String) -> Resource:
	return load("res://fontes/%s.ttf" % nome)


static func shader(caminho: String) -> Shader:
	var s: Dictionary = _e()["shaders"]
	if not s.has(caminho):
		s[caminho] = load(caminho)
	return s[caminho]


static func textura(nome: String) -> Texture:
	var t: Dictionary = _e()["texturas"]
	if not t.has(nome):
		var c := "res://texturas/%s.png" % nome
		if not ResourceLoader.exists(c):
			c = "res://ui/%s.png" % nome
		t[nome] = load(c) if ResourceLoader.exists(c) else null
	return t[nome]


## Guarda o material para receber a luz de cada cenário (e já aplica a de agora).
static func registrar(m: ShaderMaterial) -> ShaderMaterial:
	var e := _e()
	(e["registrados"] as Array).append(weakref(m))
	m.set_shader_param("luz_dir", e["luz_dir"])
	m.set_shader_param("luz_cor", e["luz_cor"])
	m.set_shader_param("ambiente", e["ambiente"])
	return m


## A luz do cenário: `direcao` aponta PARA o sol (no mundo); `cor` é a luz
## do sol e `ambiente` a do céu que chega em todo lado, as duas LINEARES e
## já com a força (cor x força, como o motor do Godot 4 entregava).
static func definir_luz(direcao: Vector3, cor: Vector3, ambiente: Vector3) -> void:
	var e := _e()
	e["luz_dir"] = direcao.normalized()
	e["luz_cor"] = cor
	e["ambiente"] = ambiente
	var vivos := []
	for w in e["registrados"]:
		var m = w.get_ref()
		if m == null:
			continue
		vivos.append(w)
		m.set_shader_param("luz_dir", e["luz_dir"])
		m.set_shader_param("luz_cor", cor)
		m.set_shader_param("ambiente", ambiente)
	e["registrados"] = vivos


## Toon com cor do vértice. `personagem`: sem estampa/escurecer (rosto limpo).
static func toon(personagem := false, contorno := 0.0035, parametros := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader(TOON_PERSONAGEM if personagem else TOON)
	for k in parametros:
		m.set_shader_param(k, parametros[k])
	if contorno > 0.0 and contornos_ligados():
		var c := ShaderMaterial.new()
		c.shader = shader(CONTORNO)
		c.set_shader_param("espessura", contorno)
		m.next_pass = c
	return registrar(m)


static func sombra_blob(forca := 0.55) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader(SOMBRA)
	m.set_shader_param("textura", textura("sombra"))
	m.set_shader_param("forca", forca)
	m.render_priority = -1
	return m


static func aditivo(nome_textura: String, cor := Color.white, forca := 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader(ADITIVO)
	m.set_shader_param("textura", textura(nome_textura))
	m.set_shader_param("cor", cor)
	m.set_shader_param("forca", forca)
	return m


## Material de partícula (billboard, cor da partícula, soma ou mistura).
static func particula(nome_textura: String, somar := true) -> SpatialMaterial:
	var m := SpatialMaterial.new()
	m.flags_unshaded = true
	m.flags_transparent = true
	m.params_blend_mode = SpatialMaterial.BLEND_MODE_ADD if somar else SpatialMaterial.BLEND_MODE_MIX
	m.params_billboard_mode = SpatialMaterial.BILLBOARD_PARTICLES
	m.params_billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = textura(nome_textura)
	m.flags_do_not_receive_shadows = true
	m.flags_no_depth_test = false
	m.params_depth_draw_mode = SpatialMaterial.DEPTH_DRAW_DISABLED
	return m


## Material simples (cor sólida, toon), para peças montadas no código.
static func cor_toon(c: Color, contorno := 0.0, parametros := {}) -> ShaderMaterial:
	var p := parametros.duplicate()
	p["tinta"] = c
	return toon(false, contorno, p)
