extends SceneTree

## (PC) abre e fecha o menu do operador e o modal de jogadores no desenho
## atual (direto ou imagem) e tira fotos da tela.
##   godot3 --video-driver GLES2 --path . -s res://tools/testes/teste_menu_direto.gd -- --pasta=<pasta>

var p: Node
var n := 0
var pasta := "user://menu_teste"
var _passo := 0
var _q := 0


func _init() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("--pasta="):
			pasta = a.substr(8)
	Directory.new().make_dir_recursive(pasta)
	p = load("res://cenas/principal.tscn").instance()
	root.add_child(p)


func _idle(_d: float) -> bool:
	n += 1
	if p._preparando or n < 60:
		return false
	_q += 1
	match _passo:
		0:
			if _q > 120:
				_foto("1_atracao")
				p.abrir_menu(p.CENA_OPERADOR)
				_proximo()
		1:
			if _q > 30:
				_foto("2_menu")
				p.fechar_menu()
				_proximo()
		2:
			if _q > 60:
				_foto("3_depois_do_menu")
				p._congelar_3d(true)
				_proximo()
		3:
			if _q > 30:
				_foto("4_congelado")
				p._congelar_3d(false)
				_proximo()
		4:
			if _q > 30:
				_foto("5_descongelado")
				print("TESTE MENU OK direto=", p._direto)
				return true
	return false


func _proximo() -> void:
	_passo += 1
	_q = 0


func _foto(nome: String) -> void:
	var img: Image = root.get_texture().get_data()
	img.flip_y()
	img.save_png("%s/%s.png" % [pasta, nome])
	print("FOTO ", nome, " camera_atual=", p.cam.current)
