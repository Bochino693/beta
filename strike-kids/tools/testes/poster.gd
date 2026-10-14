extends Node

## CENA DO PÔSTER (sem HUD): Turbo voando com os jatos, Rosi pulando e os
## pinos explodindo atrás. Renderiza a imagem "crua" que o
## tools/testes/montar_posteres.py transforma em pôster/banner.
##   godot --path . --fixed-fps 30 --resolution 1080x1920 res://tools/testes/poster.tscn -- --saida=arquivo.png --formato=vertical

var saida := "/tmp/poster.png"
var formato := "vertical"
var quadro := 0
var cam: Camera3D
var mundo: Mundo
var pinos: Pinos
var efeitos: Efeitos
var bola: Bola
var turbo: Personagem
var rosi: Personagem


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--saida="):
			saida = a.substr(8)
		elif a.begins_with("--formato="):
			formato = a.substr(10)
	mundo = Mundo.new()
	add_child(mundo)
	mundo.construir()
	mundo.aplicar_qualidade("alta")
	mundo.lampadas(1)
	pinos = Pinos.new()
	add_child(pinos)
	pinos.montar()
	efeitos = Efeitos.new()
	add_child(efeitos)
	bola = Bola.new()
	add_child(bola)
	bola.vestir("turbo")
	bola.guardar()
	turbo = Personagem.new()
	add_child(turbo)
	turbo.montar("turbo")
	rosi = Personagem.new()
	add_child(rosi)
	rosi.montar("rosi")
	var v := formato == "vertical"
	turbo.posicionar(Vector3(-0.6 if v else -1.15, 0, -9.3), 16)
	rosi.posicionar(Vector3(0.62 if v else 1.15, 0, -9.0), -14)
	mundo.ambiente.tonemap_exposure = 0.9
	turbo.tocar("vitoria", 0.01, true)
	turbo.jatos(true)
	turbo.expressao("empolgado")
	rosi.tocar("parado", 0.01, true)
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	if v:
		cam.fov = 50
		cam.look_at_from_position(Vector3(0.0, 1.5, -4.7), Vector3(0, 0.95, -12.4))
	else:
		cam.fov = 34
		cam.look_at_from_position(Vector3(0.0, 1.0, -5.6), Vector3(0, 0.85, -12.4))


func _process(_d: float) -> void:
	quadro += 1
	if quadro == 12:
		rosi.tocar("feliz", 0.01, true)
	if quadro == 16:
		pinos.preparar([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
		pinos.estourar(Vector3(0.05, 0, -13.75))
		for p in pinos.pinos:
			p.apply_impulse(Vector3(randf_range(-0.6, 0.6), randf_range(0.5, 1.6), randf_range(-0.6, 0.2)), Vector3(0, 0.35, 0))
		bola.lancar(Vector3(0.04, Bola.RAIO, -13.2), Vector3(0, 0, -3.0))
		bola.acender(0.6)
		efeitos.estrelas(Vector3(0, 0.7, -14.2), 40, 1.2)
		efeitos.confete(Vector3(0, 1.8, -10.5), 2.2, 120)
	if quadro == 27:
		rosi.expressao("risada")
	if quadro == 28:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(saida)
		print("salvo ", saida)
		get_tree().quit()
