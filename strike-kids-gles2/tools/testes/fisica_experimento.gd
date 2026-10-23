extends "res://tools/testes/custo_fisica.gd"

## EXPERIMENTOS DE CUSTO DA FÍSICA (só no PC; o binário "server" do Godot 3
## roda sem placa de vídeo e mede só a física e os scripts):
##   EXP=monitor godot3_server --path . --fixed-fps 60 res://tools/testes/fisica_experimento.tscn -- --linha=C,0.0,0.06,8.8,0.0
## EXP (separados por vírgula): monitor (pinos sem lista de contatos),
## ccd (bola sem CCD).


func _ready() -> void:
	var exp_ := OS.get_environment("EXP")
	for e in exp_.split(","):
		if e == "monitor":
			for p in pinos.pinos:
				p.contact_monitor = false
		elif e == "ccd":
			bola.continuous_cd = false
	print("EXP=", exp_)
