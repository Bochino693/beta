extends SceneTree

## O OVO QUE CHOCA (7.7), quadro a quadro: fotos do ovo do chão, do lado
## da pista (cenário dos dinos), em cada momento do choco - treme, racha, a casca pula,
## o filhote sobe e olha, volta. Só no PC, não vai no APK.
##   godot3 --video-driver GLES2 --path . --resolution 1080x1920 -s res://tools/testes/ovo_choca.gd -- --pasta=<fotos>

const MOMENTOS := [0.5, 1.15, 1.45, 1.7, 2.4, 3.2, 4.1, 4.7]
var p: Node
var n := 0
var pasta := "user://ovo_choca"
var _item: Dictionary
var _fila := []
var _espera := 0
var _h := 0.0


func _init() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("--pasta="):
			pasta = a.substr(8)
	Directory.new().make_dir_recursive(pasta)
	p = load("res://cenas/principal.tscn").instance()
	root.add_child(p)


func _idle(_d: float) -> bool:
	n += 1
	if _item.empty():
		if p._preparando or n < 30:
			return false
		p.set_process(false)
		p.set_physics_process(false)
		p.sem_msaa()
		p.hud.visible = false
		p._novo_seq()
		p.bola.guardar()
		for nome in p.personagens:
			(p.personagens[nome] as Spatial).visible = false
		p.mundo.aplicar_tema("dinos")
		var t = p.mundo.temas
		t.set_process(false)
		# o ovo que choca mais perto de quem joga (o do chão, do lado da pista)
		var olho := Vector3(0.0, 1.05, 2.2)
		var perto := INF
		for item in t._anim["dinos"]:
			if item.has("nascer"):
				var d: float = (item["no"] as Spatial).global_transform.origin.distance_to(olho)
				if d < perto:
					perto = d
					_item = item
		if _item.empty():
			print("ERRO: nenhum ovo que choca")
			return true
		var ovo: Vector3 = (_item["no"] as Spatial).global_transform.origin
		var de := (olho - ovo)
		de.y = 0.0
		var alvo := ovo + Vector3(0, 0.35, 0)
		print("OVO em ", ovo, " (", perto, " m de quem joga)")
		p.cam.corte(alvo + de.normalized() * 2.4 + Vector3(0, 0.55, 0), alvo, 34, 40)
		_fila = MOMENTOS.duplicate()
		return false
	if _espera > 0:
		_espera -= 1
		_posicionar()
		if _espera == 0:
			var img: Image = p.foto_3d()
			img.save_png("%s/ovo_%04.2f.png" % [pasta, _h])
			print("FOTO h=%.2f chocando=%s desenhos=%d" % [_h, str(_item.get("chocando", false)),
				Performance.get_monitor(Performance.RENDER_DRAW_CALLS_IN_FRAME)])
		return false
	if _fila.empty():
		# acabou: o ovo voltou inteiro?
		_h = 0.3
		_posicionar()
		print("FIM chocando=%s material de volta=%s" % [str(_item.get("chocando", false)),
			str((_item["no"] as MeshInstance).material_override == _item["mat_ovo"])])
		return true
	_h = _fila.pop_front()
	# (6 quadros de verdade até a foto: as lascas e os ciscos andam neles)
	_espera = 6
	return false


func _posicionar() -> void:
	var t = p.mundo.temas
	var cada: float = _item["cada"]
	# o choco é o segundo ciclo: _t + fase = cada + h
	t._t = fposmod(cada + _h - float(_item["fase"]), cada * 2.0)
	t._process(0.0)
