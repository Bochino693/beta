extends Node

## Bob e Mia de corpo inteiro (e em dupla), com fundo transparente e em alta
## resolução, para os adesivos (kit de divulgação).
##   godot --path . res://tools/testes/adesivos_render.tscn -- --saida=pasta [--tam=2400] [--so=a,b]

const ITENS := [
	# [arquivo, [[personagem, roupa, animação, instante, expressão, x, giro_y, jatos]...], câmera x, câmera y, distância, fov, olhar_y]
	["bob_acenando", [["bob", "", "acenar", 0.3, "empolgado", 0.0, 0.0, false]], 0.35, 0.62, 3.3, 30, 0.58],
	["mia_festa", [["mia", "", "festa", 0.0, "empolgado", 0.0, 0.0, false]], -0.35, 0.62, 3.3, 30, 0.58],
	["bob_jato", [["bob", "", "comemora_strike", 0.92, "empolgado", 0.0, 0.0, true]], 0.3, 0.9, 3.9, 30, 0.86],
	["bob_vibra", [["bob", "", "comemora_strike", 1.5, "risada", 0.0, 0.0, false]], 0.3, 0.66, 3.4, 30, 0.62],
	["mia_vitoria", [["mia", "", "vitoria", 0.6, "empolgado", 0.0, 0.0, false]], -0.3, 0.7, 3.5, 30, 0.66],
	["mia_escolhida", [["mia", "", "escolhido", 0.75, "empolgado", 0.0, 0.0, false]], -0.3, 0.72, 3.6, 30, 0.68],
	["bob_astronauta", [["bob", "astronauta", "acenar", 0.3, "empolgado", 0.0, 0.0, false]], 0.35, 0.65, 3.4, 30, 0.61],
	["mia_pirata", [["mia", "pirata", "feliz", 0.4, "piscadinha", 0.0, 0.0, false]], -0.35, 0.65, 3.4, 30, 0.61],
	["bob_dino", [["bob", "dino", "festa", 0.0, "risada", 0.0, 0.0, false]], 0.35, 0.65, 3.4, 30, 0.61],
	["mia_parque", [["mia", "parque", "acenar", 0.3, "empolgado", 0.0, 0.0, false]], -0.35, 0.68, 3.5, 30, 0.64],
	["dupla_acenando", [["bob", "", "acenar", 0.3, "empolgado", -0.42, 10.0, false], ["mia", "", "acenar", 0.9, "empolgado", 0.42, -10.0, false]], 0.0, 0.62, 4.2, 30, 0.58],
	["dupla_festa", [["bob", "", "festa", 0.0, "risada", -0.42, 12.0, false], ["mia", "", "festa", 1.0, "empolgado", 0.42, -12.0, false]], 0.0, 0.66, 4.3, 30, 0.62],
	# roupas que faltavam (cada tema do gabinete com o Bob e a Mia na roupa do cenário)
	["mia_astronauta", [["mia", "astronauta", "festa", 0.0, "empolgado", 0.0, 0.0, false]], -0.35, 0.65, 3.4, 30, 0.61],
	["bob_pirata", [["bob", "pirata", "acenar", 0.3, "empolgado", 0.0, 0.0, false]], 0.35, 0.65, 3.4, 30, 0.61],
	["mia_dino", [["mia", "dino", "acenar", 0.3, "risada", 0.0, 0.0, false]], -0.35, 0.65, 3.4, 30, 0.61],
	["bob_parque", [["bob", "parque", "festa", 0.0, "empolgado", 0.0, 0.0, false]], 0.35, 0.68, 3.5, 30, 0.64],
	["dupla_astronauta", [["bob", "astronauta", "festa", 0.0, "risada", -0.42, 12.0, false], ["mia", "astronauta", "festa", 1.0, "empolgado", 0.42, -12.0, false]], 0.0, 0.66, 4.3, 30, 0.62],
	["dupla_pirata", [["bob", "pirata", "acenar", 0.3, "empolgado", -0.42, 10.0, false], ["mia", "pirata", "acenar", 0.9, "piscadinha", 0.42, -10.0, false]], 0.0, 0.62, 4.2, 30, 0.58],
	["dupla_dino", [["bob", "dino", "festa", 0.0, "risada", -0.42, 12.0, false], ["mia", "dino", "festa", 1.0, "empolgado", 0.42, -12.0, false]], 0.0, 0.66, 4.3, 30, 0.62],
	["dupla_parque", [["bob", "parque", "acenar", 0.3, "empolgado", -0.42, 10.0, false], ["mia", "parque", "acenar", 0.9, "empolgado", 0.42, -10.0, false]], 0.0, 0.62, 4.2, 30, 0.58],
	["bob_busto", [["bob", "", "parado", 0.0, "empolgado", 0.0, 0.0, false]], 0.33, 0.93, 2.15, 30, 0.8],
	["mia_busto", [["mia", "", "parado", 0.0, "empolgado", 0.0, 0.0, false]], -0.33, 0.93, 2.15, 30, 0.8],
]

var saida := "user://adesivos"
var tam := 2400
var so: PackedStringArray = []
var vp: SubViewport
var indice := -1
var espera := 0
var montados: Array = []
var cam: Camera3D


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--saida="):
			saida = a.substr(8)
		elif a.begins_with("--tam="):
			tam = int(a.substr(6))
		elif a.begins_with("--so="):
			so = a.substr(5).split(",")
	DirAccess.make_dir_recursive_absolute(saida)
	vp = SubViewport.new()
	vp.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	vp.size = Vector2i(tam, tam)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.66, 0.62, 0.92)
	e.ambient_light_energy = 0.62
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_white = 1.6
	we.environment = e
	vp.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-35, -30, 0)
	sol.light_energy = 1.05
	sol.light_color = Color(1.0, 0.95, 0.86)
	vp.add_child(sol)
	cam = Camera3D.new()
	vp.add_child(cam)
	_proximo()


func _proximo() -> void:
	for p in montados:
		p.queue_free()
	montados.clear()
	indice += 1
	while not so.is_empty() and indice < ITENS.size() and not (ITENS[indice][0] in so):
		indice += 1
	if indice >= ITENS.size():
		print("ADESIVOS OK")
		get_tree().quit()
		return
	var item: Array = ITENS[indice]
	for d in item[1]:
		var p := Personagem.new()
		vp.add_child(p)
		p.montar(d[0])
		p.posicionar(Vector3(d[5], 0, 0), deg_to_rad(d[6]))
		if d[1] != "":
			p.trocar_roupa(d[1])
		p.tocar(d[2], 0.01, true)
		p.expressao(d[4])
		p.set_process(false)
		p._aplicar(p._amostra_clip(Animacoes.pegar(d[2]), d[3]), 0.0)
		if d[7]:
			p.jatos(true)
		# sem sombra no chão: o adesivo é recortado em volta do corpo
		p._sombra.visible = false
		for sp in p._sombras_pe.values():
			sp.visible = false
		montados.append(p)
	cam.fov = item[5]
	cam.look_at_from_position(Vector3(item[2], item[3], item[4]), Vector3(0, item[6], 0))
	espera = 0


func _process(_d: float) -> void:
	if indice >= ITENS.size():
		return
	espera += 1
	if espera == 8:
		var img: Image = vp.get_texture().get_image()
		var arq: String = "%s/%s.png" % [saida, ITENS[indice][0]]
		img.save_png(arq)
		print("salvo ", arq)
		_proximo()
