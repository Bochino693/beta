extends SceneTree

## Depuração da imagem 3D: abre o jogo, espera alguns quadros e grava a
## imagem da Viewport 3D e a da tela, com o estado das peças.
##   godot3 --video-driver GLES2 --path . -s res://tools/testes/depurar_3d.gd -- <pasta>

var p: Node
var n := 0
var pasta := "user://dep"


func _init() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("/"):
			pasta = a
	p = load("res://cenas/principal.tscn").instance()
	root.add_child(p)


func _idle(_d: float) -> bool:
	n += 1
	if p.vp == null:
		print("depurar_3d confere a imagem 3D separada: rode com STRIKE_DESENHO=imagem")
		return true
	if n == 90 or n == 240:
		var vp: Viewport = p.vp
		print("quadro ", n, " vp.size=", vp.size, " update=", vp.render_target_update_mode, " msaa=", vp.msaa,
			" own_world=", vp.own_world, " cam=", p.cam, " current=", p.cam.current, " cam_pos=", p.cam.global_transform.origin,
			" estado=", p.E.keys()[p.estado])
		print("  camera da vp: ", vp.get_camera(), "  mundo filhos=", p.mundo.get_child_count())
		var img := vp.get_texture().get_data()
		img.save_png(pasta + "/vp_%d.png" % n)
		var tela := root.get_texture().get_data()
		tela.flip_y()
		tela.save_png(pasta + "/tela_%d.png" % n)
		print("  tela3d: ", p.hud.tela3d, " visivel=", p.hud.tela3d.visible, " textura=", p.hud.tela3d.texture, " tam=", p.hud.tela3d.rect_size, " pos=", p.hud.tela3d.rect_position)
	if n == 100 and OS.get_cmdline_args().has("--sem-msaa"):
		p.vp.msaa = Viewport.MSAA_DISABLED
		print("MSAA desligado")
	if n >= 240:
		return true
	return false
