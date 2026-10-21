extends SceneTree

## FILME DA BOLA NO FOSSO (só no PC): uma jogada de verdade vista de lado,
## fotos a cada 2 passos da física desde a batida até a bola entrar na
## caçapa — para conferir que ela cai sem quicar e passa entre os pinos.
##   godot3 --video-driver GLES2 --path . -s res://tools/testes/filme_fosso.gd -- --janela=540x960 --pasta=<pasta> [--zona=C] [--jogadas=3]

var p: Node
var n := 0
var pasta := "user://filme_fosso"
var zona := "C"
var jogadas := 3
var canaleta := false
var _feitas := 0
var _fase := 0
var _foto := 0
var _passos := 0
var _t := 0.0


func _init() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("--pasta="):
			pasta = a.substr(8)
		elif a.begins_with("--zona="):
			zona = a.substr(7)
		elif a.begins_with("--jogadas="):
			jogadas = int(a.substr(10))
		elif a == "--canaleta":
			canaleta = true
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
			p.vp.msaa = Viewport.MSAA_DISABLED
			_fase = 1
		1:
			# jogada nova: para o que estava rodando, pinos no lugar
			p._novo_seq()
			p.maquina.instantaneo()
			p.pinos.repor_todos()
			p.bola.guardar()
			for nome in p.personagens:
				(p.personagens[nome] as Spatial).visible = false
			_t = 0.0
			_fase = 2
		2:
			_t += delta
			if _t < 0.3:
				return false
			var j = Jogada.planejar(zona, p.pinos.em_pe(), true, "normal", true)
			var origem := Vector3(j.origem_x, Bola.RAIO + 0.04, 0.35)
			var dir := Vector3(j.alvo_x, Bola.RAIO, Medidas.Z_PINO1) - origem
			var vel: float = j.velocidade
			var efeito: float = j.efeito
			if canaleta:
				# sem para-choque: a bola vai para a canaleta da direita
				p.mundo.definir_protecao(false)
				origem = Vector3(0.3, Bola.RAIO + 0.04, 0.35)
				dir = Vector3(0.95, Bola.RAIO, Medidas.Z_PINO1) - origem
				vel = 7.9
				efeito = 0.0
			dir.y = 0
			p.bola.lancar(origem, dir.normalized() * vel, efeito)
			p.pinos.soltar_todos()
			# de lado e de cima: o fim da pista, o fosso e a boca da caçapa
			p.cam.corte(Vector3(0.82, 1.0, Medidas.Z_FIM_DECK + 0.95), Vector3(-0.12, -0.12, Medidas.Z_FUNDO + 0.3), 62, 62)
			_fase = 3
		3:
			if p.bola.visible and p.bola.global_translation.z < Medidas.Z_PINO1 + 0.3:
				_fase = 4
				_passos = 0
		4:
			_passos += 1
			if _passos % 2 == 0:
				_salvar()
			if not p.bola.visible or _passos > 140:
				for i in 6:
					_salvar()
				_feitas += 1
				if _feitas >= jogadas:
					return true
				_fase = 1
	return false


func _salvar() -> void:
	var img: Image = p.vp.get_texture().get_data()
	img.save_png("%s/j%d_%03d.png" % [pasta, _feitas, _foto])
	_foto += 1
