extends SceneTree

## VITRINE: fotos fixas da imagem 3D (bichinhos com a roupinha de cada
## fase, rosto, pinos, pista e cenário) — para comparar o visual antes e
## depois de mexer nos modelos ou nos shaders.
##   godot3 --video-driver GLES2 --path . -s res://tools/testes/vitrine.gd -- --janela=1080x1920 --pasta=<pasta>

var p: Node
var n := 0
var pasta := "user://vitrine"
var _fila := []
var _espera := 0
var _tema := ""

const VISTAS := {
	"bichos": [Vector3(0.0, 0.95, 4.45), Vector3(0.0, 0.62, 2.5), 40],
	"rosto_bob": [Vector3(-0.5, 0.98, 3.45), Vector3(-0.62, 0.88, 2.5), 30],
	"rosto_mia": [Vector3(0.5, 0.98, 3.45), Vector3(0.62, 0.88, 2.5), 30],
	"pinos": [Vector3(0.35, 0.62, -8.2), Vector3(0.0, 0.22, -11.0), 42],
	"pino_perto": [Vector3(0.12, 0.42, -9.72), Vector3(0.0, 0.25, -10.5), 40],
	"pista": [Vector3(0.0, 1.05, 2.2), Vector3(0.0, 0.18, -9.9), 55],
	"cenario": [Vector3(2.2, 2.6, 5.4), Vector3(-0.6, 0.6, -6.0), 62],
}


func _init() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("--pasta="):
			pasta = a.substr(8)
	Directory.new().make_dir_recursive(pasta)
	p = load("res://cenas/principal.tscn").instance()
	root.add_child(p)


func _idle(_d: float) -> bool:
	n += 1
	if _fila.empty() and _tema == "":
		if p._preparando or n < 30:
			return false
		p.set_process(false)
		p.set_physics_process(false)
		# (o llvmpipe devolve a imagem preta com o MSAA da OpenGL ES 2.0)
		p.vp.msaa = Viewport.MSAA_DISABLED
		# para a demonstração que estava rodando (as corrotinas param sozinhas)
		p._novo_seq()
		p.bola.guardar()
		for t in Temas.ORDEM:
			_fila.append(t)
		_tema = "?"
		return false
	if _espera > 0:
		_espera -= 1
		if _espera == 0:
			_foto()
		return false
	if _fila.empty():
		return true
	var item = _fila.pop_front()
	if item is String:
		_tema = item
		p.mundo.aplicar_tema(_tema)
		p.pinos.repor_todos()
		var i := 0
		for nome in ["bob", "mia"]:
			var b: Personagem = p.personagens[nome]
			b.visible = true
			b.pedir_roupa(p.ROUPA_DO_TEMA.get(_tema, ""))
			b.global_transform = Transform(Basis(), p.PODIOS[i])
			i += 1
		# as fotos desta fase vêm logo depois dela (antes da próxima fase)
		var depois := [["roupa", 25]]
		for v in VISTAS:
			depois.append([v, 8])
		depois.invert()
		for d in depois:
			_fila.push_front(d)
	elif item[0] == "roupa":
		var i := 0
		for nome in ["bob", "mia"]:
			var b: Personagem = p.personagens[nome]
			b.trocar_roupa(p.ROUPA_DO_TEMA.get(_tema, ""))
			# cada um no seu pódio, de frente, parado (sem andar para a pista)
			b.global_transform = Transform(Basis(), p.PODIOS[i])
			b.set_process(false)
			b.set_physics_process(false)
			i += 1
		_espera = 0
		_atual = ""
		_esperar(item[1])
	else:
		var v: Array = VISTAS[item[0]]
		p.cam.corte(v[0], v[1], v[2], v[2])
		_atual = item[0]
		_esperar(item[1])
	return false


var _atual := ""


func _esperar(q: int) -> void:
	_espera = q


func _foto() -> void:
	if _atual == "":
		return
	# (a imagem da Viewport já sai em pé: render_target_v_flip)
	var img: Image = p.vp.get_texture().get_data()
	var nome := "%s/%s_%s.png" % [pasta, _tema, _atual]
	img.save_png(nome)
	print("FOTO ", nome)
