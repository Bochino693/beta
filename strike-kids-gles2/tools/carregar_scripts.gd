extends SceneTree

## Carrega scripts com o jogo de verdade (autoloads registrados) e diz quais
## não compilam — os erros saem no log como SCRIPT ERROR.
##   godot3 --no-window --path . -s res://tools/carregar_scripts.gd -- res://scripts/hud.gd [...]
## Sem argumentos: todos os scripts de scripts/ e autoload/.

func _initialize() -> void:
	call_deferred("_rodar")


func _rodar() -> void:
	var lista := []
	for a in OS.get_cmdline_args():
		if a.begins_with("res://") and a.ends_with(".gd") and not a.ends_with("carregar_scripts.gd"):
			lista.append(a)
	if lista.empty():
		for pasta in ["res://autoload", "res://scripts"]:
			var d := Directory.new()
			d.open(pasta)
			d.list_dir_begin(true, true)
			var f := d.get_next()
			while f != "":
				if f.ends_with(".gd"):
					lista.append(pasta + "/" + f)
				f = d.get_next()
	var ruins := 0
	for p in lista:
		var s = load(p)
		if s == null or not (s as GDScript).can_instance():
			ruins += 1
			print("NAO_COMPILA ", p)
		else:
			print("COMPILA     ", p)
	print("CARREGAR_FIM ", ruins, " com erro")
	quit()
