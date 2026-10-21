extends Node

## FOTOS EM INSTANTES FIXOS do jogo rodando (diagnóstico de qualidade).
##   godot3 --path . --fixed-fps 30 -- --janela=1080x1920 --instantes=pasta --em=1.0,2.5,6.0
## Tira uma foto da tela em cada instante (segundos desde o começo) e sai.

var pasta := "user://instantes"
var tempos: Array = [1.0, 3.0, 6.0]
var t := 0.0
var n := 0


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	for a in OS.get_cmdline_args():
		if a.begins_with("--instantes="):
			pasta = a.substr(12)
		elif a.begins_with("--em="):
			tempos = []
			for x in a.substr(5).split(","):
				tempos.append(float(x))
	Directory.new().make_dir_recursive(pasta)


func _process(delta: float) -> void:
	# o tempo de verdade do jogo (a câmera lenta e a velocidade não contam)
	t += delta / max(Engine.time_scale, 0.01)
	if n < tempos.size() and t >= float(tempos[n]):
		var nome := "%s/t%05.1f.png" % [pasta, float(tempos[n])]
		n += 1
		yield(VisualServer, "frame_post_draw")
		var img := get_viewport().get_texture().get_data()
		img.flip_y()
		img.save_png(nome)
		print("FOTO ", nome)
		if n >= tempos.size():
			get_tree().quit()
