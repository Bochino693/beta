extends "res://tools/testes/calibrar.gd"

## PINOS PESADOS OU "DE PLÁSTICO"? (só no PC, não vai no APK)
##   godot3 --no-window --path . --fixed-fps 60 res://tools/testes/pinos_vivos.tscn -- --linha=C,0.0,0.06,8.8,0.0
## As jogadas da calibração (--linha: 5 saídas da mesma linha) e, em cada
## uma, como os pinos se mexem depois da batida: a maior altura que um pino
## sobe, quantos quiques (descia e voltou a subir rápido), o giro mais
## rápido e quanto tempo até todos assentarem. EXP_FOGO=1: bola de fogo.

var _alt_max := 0.0
var _quiques := 0
var _giro_max := 0.0
var _t_assenta := 0.0
var _vy_ant := {}
var _y0 := {}
var _pos2 := {}      # onde cada pino estava 1 s antes do fim
var _anda := 0.0     # o quanto o pino que mais andou no último segundo andou
var _tot := {"alt": 0.0, "quiques": 0, "giro": 0.0, "assenta": 0.0, "caidos": 0, "n": 0}


func _physics_process(delta: float) -> void:
	if atual == null:
		return
	if fase == 0:
		if _y0.empty() or t < delta * 1.5:
			_y0.clear()
			_vy_ant.clear()
			_alt_max = 0.0
			_quiques = 0
			_giro_max = 0.0
			_t_assenta = 0.0
			for p in pinos.pinos:
				_y0[p] = (p as RigidBody).global_transform.origin.y
		return
	if fase == 1 and t < delta * 1.5 and OS.get_environment("EXP_FOGO") != "":
		bola.fogo(true)
	var mexendo := false
	for p in pinos.pinos:
		var rb := p as RigidBody
		if rb.mode != RigidBody.MODE_RIGID or not _y0.has(p):
			continue
		var y := rb.global_transform.origin.y
		if y > -0.05:
			_alt_max = max(_alt_max, y - float(_y0[p]))
		var vy := rb.linear_velocity.y
		if float(_vy_ant.get(p, 0.0)) < -0.4 and vy > 0.4 and y > -0.05:
			_quiques += 1
		_vy_ant[p] = vy
		_giro_max = max(_giro_max, rb.angular_velocity.length())
		if rb.linear_velocity.length() > 0.05 or rb.angular_velocity.length() > 0.2:
			mexendo = true
	if mexendo and fase >= 1:
		_t_assenta = t if fase == 2 else 0.0
	if fase == 2 and _pos2.empty() and t >= 2.0:
		for p in pinos.pinos:
			_pos2[p] = (p as RigidBody).global_transform.origin


func _process(_d: float) -> void:
	# a calibração zera `atual` ao terminar a jogada: aí fecha a conta dela
	if atual == null and not _y0.empty():
		var caidos := 10 - pinos.em_pe().size()
		_anda = 0.0
		for p in _pos2:
			var d: float = (p as RigidBody).global_transform.origin.distance_to(_pos2[p])
			_anda = max(_anda, d)
			if d > 0.05:
				print("  andou %.2f m: %s de %s para %s (em pe=%s)" % [d, (p as Node).name, str(_pos2[p]),
					str((p as RigidBody).global_transform.origin), str(not (p as Pino).esta_caido())])
		_pos2.clear()
		print("PINOS caidos=%d  subiu=%.2f m  quiques=%d  giro=%.1f rad/s  andou no ultimo 1 s=%.3f m" % [
			caidos, _alt_max, _quiques, _giro_max, _anda])
		_tot["assenta"] += _anda
		for p in pinos.pinos:
			var rb := p as RigidBody
			if rb.mode == RigidBody.MODE_RIGID and (rb.linear_velocity.length() > 0.05 or rb.angular_velocity.length() > 0.2):
				print("  mexendo: %s em %s v=%.2f giro=%.2f dormindo=%s" % [rb.name, str(rb.global_transform.origin), rb.linear_velocity.length(),
					rb.angular_velocity.length(), str(rb.sleeping)])
		_tot["alt"] += _alt_max
		_tot["quiques"] += _quiques
		_tot["giro"] += _giro_max
		_tot["caidos"] += caidos
		_tot["n"] += 1
		_y0.clear()
		if fila.empty():
			var n: float = max(_tot["n"], 1)
			print("MEDIA caidos=%.1f  subiu=%.2f m  quiques=%.1f  giro=%.1f rad/s  andou no ultimo 1 s=%.3f m" % [
				_tot["caidos"] / n, _tot["alt"] / n, _tot["quiques"] / n, _tot["giro"] / n, _tot["assenta"] / n])
