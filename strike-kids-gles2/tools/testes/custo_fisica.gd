extends "res://tools/testes/calibrar.gd"

## CUSTO DA FÍSICA (só no PC, não vai no APK)
##   godot3 --no-window --path . --fixed-fps 60 res://tools/testes/custo_fisica.tscn -- --linha=C,0.0,0.06,8.8,0.0
## As mesmas jogadas da calibração (--linha: 5 saídas da mesma linha), e o
## tempo de cada passo da física (com --fixed-fps 60 cada quadro tem um
## passo): antes da bola (pinos soltos), com a bola rolando e depois da
## batida (pinos assentando). Serve para comparar mudanças na colisão — e
## as linhas "saida" mostram se as jogadas continuam dando o mesmo resultado.
## (Godot 3: o _ready e o _physics_process da calibração também rodam,
## sozinhos, antes/depois destes.)

var _t_ant := 0
var _soma := {}
var _n := {}
var _max := {}


func _physics_process(_delta: float) -> void:
	var agora := OS.get_ticks_usec()
	if _t_ant > 0 and atual != null:
		var k: String = ["antes da bola", "bola rolando", "depois da batida"][Compat.iclamp(fase, 0, 2)]
		var d := agora - _t_ant
		_soma[k] = _soma.get(k, 0) + d
		_n[k] = _n.get(k, 0) + 1
		_max[k] = max(_max.get(k, 0), d)
	_t_ant = OS.get_ticks_usec()


func _gravar() -> void:
	var tot := 0
	var ntot := 0
	for k in _soma:
		tot += _soma[k]
		ntot += _n[k]
		print("CUSTO %s: %d passos, média %.3f ms, pior %.2f ms" % [k, _n[k], _soma[k] / 1000.0 / _n[k], _max[k] / 1000.0])
	if ntot > 0:
		print("CUSTO total: %d passos, média %.3f ms por passo" % [ntot, tot / 1000.0 / ntot])
	._gravar()
