extends SceneTree

## Peso de cada modelo de uma pasta: superfícies (cada uma é um desenho a
## mais), vértices e triângulos.
##   godot3 --no-window --path . -s res://tools/testes/estat_modelos.gd -- <pasta> [<pasta2>]
## (pasta: res://modelos/cenario ou uma pasta qualquer com .res)


func _init() -> void:
	var pastas := []
	for a in OS.get_cmdline_args():
		if a.begins_with("res://") or a.begins_with("/"):
			if not a.ends_with(".gd"):
				pastas.append(a)
	for pasta in pastas:
		var d := Directory.new()
		if d.open(pasta) != OK:
			printerr("sem pasta: ", pasta)
			continue
		d.list_dir_begin(true, true)
		var nomes := []
		var f := d.get_next()
		while f != "":
			if f.ends_with(".res") or f.ends_with(".mesh"):
				nomes.append(f)
			f = d.get_next()
		nomes.sort()
		var tv := 0
		var tt := 0
		for nome in nomes:
			var m = load(pasta.plus_file(nome))
			if not m is Mesh:
				continue
			var v := 0
			var t := 0
			for s in (m as Mesh).get_surface_count():
				var arr: Array = m.surface_get_arrays(s)
				v += (arr[Mesh.ARRAY_VERTEX] as PoolVector3Array).size()
				var ind = arr[Mesh.ARRAY_INDEX]
				t += ((ind as PoolIntArray).size() if ind != null else (arr[Mesh.ARRAY_VERTEX] as PoolVector3Array).size()) / 3
			tv += v
			tt += t
			print("%-16s sup=%d vert=%6d tri=%6d" % [nome.get_basename(), m.get_surface_count(), v, t])
		print("TOTAL %s: vert=%d tri=%d" % [pasta, tv, tt])
	quit()
