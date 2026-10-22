extends SceneTree

## FILME DOS PINOS (só no PC): um STRIKE visto de perto (como os pinos
## voam, tombam e caem no fosso) e depois a MÁQUINA: a barra varre, o
## alçapão abre e os pinos caem no poço (a queda de desenho animado).
## Foto a cada 2 quadros (15 por segundo com --fixed-fps 30).
##   godot3 --video-driver GLES2 --path . --fixed-fps 30 -s res://tools/testes/filme_pinos.gd -- --janela=540x960 --pasta=<pasta> [--zona=C]

var p: Node
var n := 0
var pasta := "user://filme_pinos"
var zona := "C"
var _fase := 0
var _foto := 0
var _q := 0
var _t := 0.0


func _init() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("--pasta="):
			pasta = a.substr(8)
		elif a.begins_with("--zona="):
			zona = a.substr(7)
	Directory.new().make_dir_recursive(pasta)
	p = load("res://cenas/principal.tscn").instance()
	root.add_child(p)


func _idle(delta: float) -> bool:
	n += 1
	match _fase:
		0:
			if p._preparando or n < 30:
				return false
			p.set_process(false)
			p.sem_msaa()
			p.hud.visible = false
			p._novo_seq()
			p.maquina.instantaneo()
			p.pinos.repor_todos()
			p.bola.guardar()
			for nome in p.personagens:
				(p.personagens[nome] as Spatial).visible = false
			p.maquina.connect("alcapao", self, "_alcapao")
			_t = 0.0
			_fase = 1
		1:
			_t += delta
			if _t < 0.3:
				return false
			var j = Jogada.planejar(zona, p.pinos.em_pe(), true, "normal", true)
			var origem := Vector3(j.origem_x, Bola.RAIO + 0.04, 0.35)
			var dir := Vector3(j.alvo_x, Bola.RAIO, Medidas.Z_PINO1) - origem
			dir.y = 0
			p.bola.lancar(origem, dir.normalized() * float(j.velocidade), float(j.efeito))
			p.pinos.soltar_todos()
			# de cima (--de-cima) ou de frente, perto: os pinos, as paredes e o fosso
			if OS.get_cmdline_args().has("--de-cima"):
				p.cam.corte(Vector3(0.0, 1.85, Medidas.Z_PINO1 + 1.5), Vector3(0.0, 0.0, Medidas.Z_PINO1 - 0.7), 72, 72)
			else:
				p.cam.corte(Vector3(0.35, 0.62, -8.2), Vector3(0.0, 0.22, -11.0), 42, 42)
			_fase = 2
		2:
			if p.bola.global_translation.z < Medidas.Z_PINO1 + 1.2:
				_fase = 3
				_q = 0
		3:
			_q += 1
			if _q % 2 == 0:
				_salvar("a")
			if _q > 75:
				# a máquina: barra, alçapão, mesa (como depois de um strike)
				var r = p.maquina.rack_novo(true)
				_fase = 4
				_q = 0
		4:
			_q += 1
			if _q % 2 == 0:
				_salvar("b")
			if not p.maquina.trabalhando or _q > 330:
				return true
	return false


func _alcapao(abrindo: bool) -> void:
	if abrindo:
		p.cam.corte(Vector3(0.98, 1.08, Medidas.ALCAPAO_Z0 - 0.15), Vector3(-0.12, -0.45, Medidas.ALCAPAO_Z1 + 0.75), 56, 56)
	else:
		p.cam.corte(Vector3(1.1, 1.25, Medidas.Z_PINO1 + 2.6), Vector3(-0.1, 0.05, Medidas.Z_PINO1 - 0.9), 52, 52)


func _salvar(fase: String) -> void:
	var img: Image = p.foto_3d()
	img.save_png("%s/%s_%03d.png" % [pasta, fase, _foto])
	_foto += 1
