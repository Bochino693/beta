extends Node

## MAQUETE 3D DO GABINETE (divulgação): o gabinete do Strike Kids com os
## adesivos de um tema (texturas do gerar_gabinete.py) e o jogo na tela.
##   godot --path . res://tools/testes/gabinete_render.tscn -- --texturas=PASTA \
##         --tela=quadro.jpg --saida=PASTA [--vistas=frente_esquerda,frente,lateral,tras_direita]
## A FILA: as máquinas lado a lado, uma de cada tema (pastas de texturas e
## telas na mesma ordem):
##   ... -- --texturas=PASTA1,PASTA2,... --tela=q1.jpg,q2.jpg,... --saida=PASTA --vistas=fila,fila_lado
##   (fila.json: onde fica cada máquina em cada foto, para os nomes no catálogo)
## Medidas em metros (as mesmas do GABINETE do gerar_gabinete.py).

const L := 0.80          # largura da pista e da torre
const PC := 2.60         # comprimento da pista
const PH := 0.52         # altura das laterais da pista
const PISO := 0.45       # altura do piso da pista
const PL := 0.70         # largura do piso
const TP := 0.60         # profundidade da torre
const TH := 2.00         # altura da torre
const LH := 0.38         # altura do letreiro
const LP := 0.30         # profundidade do letreiro
const TELA := Vector2(0.535, 0.95)
const TELA_BASE := 0.76
const PASSO := 1.0       # fila: de uma máquina à outra (centro a centro)
## a cor do chão já iluminado: o fundo da mesma cor esconde o horizonte (estúdio)
const FUNDO := Color8(151, 164, 199)
const FUNDO_FILA := Color8(160, 173, 209)   # na fila o sol vem mais de cima

var pastas: PackedStringArray = []
var telas: PackedStringArray = []
var saida := ""
var fundo := Color(0, 0, 0, 0)
var vistas_pedidas: PackedStringArray = []
var vp: SubViewport
var cam: Camera3D
var pai: Node3D
var indice := -1
var espera := 0
var VISTAS := {}
var ordem: Array = []
var posicoes := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--texturas="):
			pastas = a.substr(11).split(",")
		elif a.begins_with("--saida="):
			saida = a.substr(8)
		elif a.begins_with("--tela="):
			telas = a.substr(7).split(",")
		elif a.begins_with("--vistas="):
			vistas_pedidas = a.substr(9).split(",")
		elif a.begins_with("--fundo="):
			var c := a.substr(8).split(",")
			fundo = Color8(int(c[0]), int(c[1]), int(c[2]))
	DirAccess.make_dir_recursive_absolute(saida)
	var n := pastas.size()
	if fundo.a == 0.0:
		fundo = FUNDO_FILA if n > 1 else FUNDO
	_vistas(n)
	if not vistas_pedidas.is_empty():
		ordem = Array(vistas_pedidas)
	elif n > 1:
		ordem = ["fila", "fila_lado"]
	else:
		ordem = ["frente_esquerda", "frente", "lateral", "tras_direita"]
	vp = SubViewport.new()
	vp.size = VISTAS[ordem[0]][3]
	vp.msaa_3d = Viewport.MSAA_4X
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	_ambiente(n > 1)
	for k in n:
		_gabinete(pastas[k], telas[k] if k < telas.size() else "", Vector3(k * PASSO, 0, 0))
	cam = Camera3D.new()
	vp.add_child(cam)
	_proxima()


func _vistas(n: int) -> void:
	var xc := (n - 1) * PASSO / 2.0 + L / 2.0
	var xf := (n - 1) * PASSO + L
	VISTAS = {
		# nome: [posição da câmera, para onde olha, fov (vertical), tamanho da foto]
		"frente_esquerda": [Vector3(-2.45, 2.05, PC + 2.25), Vector3(0.45, 0.86, 0.95), 38.0, Vector2i(2400, 1600)],
		"frente": [Vector3(L / 2, 1.6, PC + 3.0), Vector3(L / 2, 0.82, 1.2), 40.0, Vector2i(1200, 1800)],
		"lateral": [Vector3(5.2, 1.25, 0.95), Vector3(0.4, 1.05, 0.95), 40.0, Vector2i(2400, 1600)],
		"tras_direita": [Vector3(3.1, 2.2, -2.7), Vector3(0.4, 0.95, 0.5), 40.0, Vector2i(2400, 1600)],
		"fila": [Vector3(xc, 2.7, PC + 0.95 * xf + 0.6), Vector3(xc, 0.9, 0.9), 25.5, Vector2i(3600, 1500)],
		"fila_lado": [Vector3(-3.3, 2.6, PC + 4.4), Vector3(xc - 0.3, 0.74, 0.5), 35.5, Vector2i(3200, 1800)],
	}


func _ambiente(fila: bool) -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = fundo
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.80, 0.84, 0.95)
	e.ambient_light_energy = 0.36
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_white = 1.6
	we.environment = e
	vp.add_child(we)
	var sol := DirectionalLight3D.new()
	# na fila o sol vem mais de cima: a sombra de uma máquina não cobre a vizinha
	sol.rotation_degrees = Vector3(-64, -24, 0) if fila else Vector3(-48, -32, 0)
	sol.light_energy = 0.68
	sol.light_color = Color(1.0, 0.97, 0.92)
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 30.0 if fila else 12.0
	vp.add_child(sol)
	var preenche := DirectionalLight3D.new()
	preenche.rotation_degrees = Vector3(-20, 140, 0)
	preenche.light_energy = 0.28
	vp.add_child(preenche)
	# chão grande e sem brilho: a mesma cor em todo lugar, como o fundo
	var chao := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	chao.mesh = pm
	chao.position = Vector3(L / 2, 0, 0.8)
	var mc := StandardMaterial3D.new()
	mc.albedo_color = Color(0.40, 0.43, 0.50)
	mc.roughness = 1.0
	mc.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mc.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	chao.material_override = mc
	vp.add_child(chao)


func _textura(pasta: String, nome: String) -> Texture2D:
	var c := pasta.path_join(nome + ".png")
	var img := Image.load_from_file(c)
	if img == null:
		push_error("sem a textura " + c)
		return null
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _mat_adesivo(pasta: String, nome: String, brilho := 0.0, rugo := 0.38, especular := 0.55) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _textura(pasta, nome)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.roughness = rugo
	m.metallic_specular = especular
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if brilho > 0.0:
		m.emission_enabled = true
		m.emission_texture = m.albedo_texture
		m.emission_energy_multiplier = brilho
	return m


func _mat_cor(c: Color, rugo := 0.6, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rugo
	m.metallic = metal
	return m


## Um adesivo: retângulo w x h com o centro em 'centro', virado para 'normal';
## 'direita' = para onde vai a borda direita do desenho.
func _placa(m: Material, w: float, h: float, centro: Vector3, normal: Vector3, direita: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	mi.mesh = q
	var cima := normal.cross(direita).normalized()
	mi.transform = Transform3D(Basis(direita.normalized(), cima, normal.normalized()), centro)
	mi.material_override = m
	pai.add_child(mi)


func _caixa(tam3: Vector3, centro: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam3
	mi.mesh = b
	mi.position = centro
	mi.material_override = mat
	pai.add_child(mi)
	return mi


func _gabinete(pasta: String, tela: String, origem: Vector3) -> void:
	pai = Node3D.new()
	pai.position = origem
	vp.add_child(pai)
	var escuro := _mat_cor(Color(0.05, 0.06, 0.1), 0.7)
	var e := 0.0015
	# ---- torre (o corpo fica atrás da tela; a frente é o adesivo com os furos)
	_caixa(Vector3(L - 0.004, TH, TP - 0.03), Vector3(L / 2, TH / 2, -(TP + 0.03) / 2), escuro)
	_caixa(Vector3(L - 0.004, PH, 0.03), Vector3(L / 2, PH / 2, -0.015), escuro)
	_placa(_mat_adesivo(pasta, "03_torre_frente"), L, TH - PH, Vector3(L / 2, (PH + TH) / 2, e), Vector3(0, 0, 1), Vector3(1, 0, 0))
	_placa(_mat_adesivo(pasta, "04_torre_lateral_esquerda"), TP, TH, Vector3(-e, TH / 2, -TP / 2), Vector3(-1, 0, 0), Vector3(0, 0, 1))
	_placa(_mat_adesivo(pasta, "04_torre_lateral_direita"), TP, TH, Vector3(L + e, TH / 2, -TP / 2), Vector3(1, 0, 0), Vector3(0, 0, -1))
	_placa(_mat_adesivo(pasta, "05_torre_traseira"), L, TH, Vector3(L / 2, TH / 2, -TP - e), Vector3(0, 0, -1), Vector3(-1, 0, 0))
	# tela do jogo (atrás da janela)
	var mt := StandardMaterial3D.new()
	var img := Image.load_from_file(tela) if tela != "" else null
	if img:
		img.generate_mipmaps()
		mt.albedo_texture = ImageTexture.create_from_image(img)
		mt.emission_enabled = true
		mt.emission_texture = mt.albedo_texture
		mt.emission_energy_multiplier = 0.55
		mt.albedo_color = Color(0.55, 0.55, 0.55)
	else:
		mt.albedo_color = Color(0.02, 0.03, 0.06)
	mt.roughness = 0.15
	var tv := MeshInstance3D.new()
	var qt := QuadMesh.new()
	qt.size = TELA + Vector2(0.02, 0.02)
	tv.mesh = qt
	tv.position = Vector3(L / 2, TELA_BASE + TELA.y / 2, -0.012)
	tv.material_override = mt
	pai.add_child(tv)
	# ---- letreiro (luminoso)
	_caixa(Vector3(L - 0.004, LH, LP - 0.004), Vector3(L / 2, TH + LH / 2, -LP / 2), escuro)
	_placa(_mat_adesivo(pasta, "01_letreiro_frente", 0.35), L, LH, Vector3(L / 2, TH + LH / 2, e), Vector3(0, 0, 1), Vector3(1, 0, 0))
	_placa(_mat_adesivo(pasta, "02_letreiro_lateral_esquerda", 0.2), LP, LH, Vector3(-e, TH + LH / 2, -LP / 2), Vector3(-1, 0, 0), Vector3(0, 0, 1))
	_placa(_mat_adesivo(pasta, "02_letreiro_lateral_direita", 0.2), LP, LH, Vector3(L + e, TH + LH / 2, -LP / 2), Vector3(1, 0, 0), Vector3(0, 0, -1))
	_placa(_mat_adesivo(pasta, "02_letreiro_traseira", 0.2), L, LH, Vector3(L / 2, TH + LH / 2, -LP - e), Vector3(0, 0, -1), Vector3(-1, 0, 0))
	# ---- pista (o corpo para antes da frente: o retorno das bolas é um nicho)
	var zf := PC - 0.26
	_caixa(Vector3(L - 0.04, PISO - 0.01, zf - 0.01), Vector3(L / 2, (PISO - 0.01) / 2, (zf + 0.01) / 2), escuro)
	var prof := 0.23
	var zc := zf + prof / 2
	_caixa(Vector3(0.22, PISO - 0.01, prof), Vector3(0.02 + 0.11, (PISO - 0.01) / 2, zc), escuro)
	_caixa(Vector3(0.22, PISO - 0.01, prof), Vector3(L - 0.02 - 0.11, (PISO - 0.01) / 2, zc), escuro)
	_caixa(Vector3(0.32, PISO - 0.01 - 0.2, prof), Vector3(L / 2, 0.2 + (PISO - 0.01 - 0.2) / 2, zc), escuro)
	_caixa(Vector3(0.32, 0.04, prof), Vector3(L / 2, 0.02, zc), _mat_cor(Color(0.12, 0.13, 0.2), 0.6))
	_placa(_mat_adesivo(pasta, "06_pista_lateral_esquerda"), PC, PH, Vector3(-e, PH / 2, PC / 2), Vector3(-1, 0, 0), Vector3(0, 0, 1))
	_placa(_mat_adesivo(pasta, "06_pista_lateral_direita"), PC, PH, Vector3(L + e, PH / 2, PC / 2), Vector3(1, 0, 0), Vector3(0, 0, -1))
	_placa(_mat_adesivo(pasta, "07_pista_frente"), L, PH, Vector3(L / 2, PH / 2, PC + e), Vector3(0, 0, 1), Vector3(1, 0, 0))
	# o piso deitado reflete o céu claro de raspão: menos brilho que as paredes
	_placa(_mat_adesivo(pasta, "08_pista_piso", 0.0, 0.7, 0.25), PL, PC, Vector3(L / 2, PISO, PC / 2), Vector3(0, 1, 0), Vector3(1, 0, 0))
	# paredes de dentro das laterais (entre o piso e o topo) e o friso de cima
	var friso := _mat_cor(Color(0.95, 0.96, 0.98), 0.25, 0.3)
	for x in [0.009, L - 0.009]:
		_caixa(Vector3(0.018, PH - PISO, PC), Vector3(x, (PH + PISO) / 2, PC / 2), escuro)
		_caixa(Vector3(0.03, 0.02, PC + 0.01), Vector3(x, PH + 0.01, PC / 2), friso)
	for x in [0.035, L - 0.035]:
		_caixa(Vector3(0.05 - 0.018, 0.012, PC), Vector3(x, PISO - 0.03, PC / 2), escuro)
	_caixa(Vector3(L + 0.01, 0.02, 0.03), Vector3(L / 2, PH + 0.01, PC - 0.005), friso)
	# botão START, moedeiro e bolas no retorno
	var verm := _mat_cor(Color(0.95, 0.12, 0.18), 0.25)
	var botao := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.028
	cil.bottom_radius = 0.03
	cil.height = 0.03
	botao.mesh = cil
	botao.rotation_degrees = Vector3(90, 0, 0)
	botao.position = Vector3(0.13, 0.33, PC + 0.01)
	botao.material_override = verm
	pai.add_child(botao)
	_caixa(Vector3(0.058, 0.108, 0.01), Vector3(0.67, 0.33, PC - 0.002), _mat_cor(Color(0.75, 0.76, 0.8), 0.3, 0.8))
	var cores := [Color(0.18, 0.42, 1.0), Color(1.0, 0.24, 0.3), Color(1.0, 0.8, 0.2)]
	for k in 3:
		var bola := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.055
		sm.height = 0.11
		bola.mesh = sm
		bola.position = Vector3(0.31 + k * 0.09, 0.04 + 0.055, PC - 0.12)
		bola.material_override = _mat_cor(cores[k], 0.15, 0.1)
		pai.add_child(bola)
	var rolando := MeshInstance3D.new()
	var sm2 := SphereMesh.new()
	sm2.radius = 0.055
	sm2.height = 0.11
	rolando.mesh = sm2
	rolando.position = Vector3(0.43, PISO + 0.055, 1.25)
	rolando.material_override = _mat_cor(Color(0.18, 0.42, 1.0), 0.15, 0.1)
	pai.add_child(rolando)


func _proxima() -> void:
	indice += 1
	if indice >= ordem.size():
		if not posicoes.is_empty():
			var f := FileAccess.open(saida.path_join("fila.json"), FileAccess.WRITE)
			f.store_string(JSON.stringify(posicoes, "  "))
		print("MAQUETE OK")
		get_tree().quit()
		return
	var v: Array = VISTAS[ordem[indice]]
	vp.size = v[3]
	cam.fov = v[2]
	cam.look_at_from_position(v[0], v[1])
	espera = 0


func _process(_d: float) -> void:
	if indice >= ordem.size():
		return
	espera += 1
	if espera == 6:
		var nome: String = ordem[indice]
		var img: Image = vp.get_texture().get_image()
		var arq: String = "%s/%s.png" % [saida, nome]
		img.save_png(arq)
		print("salvo ", arq)
		if pastas.size() > 1:
			# topo do letreiro e pé da frente de cada máquina, em pixels da foto
			var lista := []
			for k in pastas.size():
				var o := Vector3(k * PASSO, 0, 0)
				var topo := cam.unproject_position(o + Vector3(L / 2, TH + LH, 0))
				var pe := cam.unproject_position(o + Vector3(L / 2, 0, PC))
				lista.append({"topo": [topo.x, topo.y], "pe": [pe.x, pe.y]})
			posicoes[nome] = lista
		_proxima()
