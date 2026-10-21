extends Node

## PERFIL QUADRO A QUADRO (só no PC, não vai no APK).
##   godot3 --path . -- --desempenho [--perfil=arquivo.csv] [--perfil-seg=90]
## Para cada quadro grava: tempo do quadro, quantos passos de física, quanto
## a física levou (scripts + motor), quanto os scripts do quadro levaram
## (_process + corrotinas, que também vão à parte) e o resto (desenho e
## espera da tela), o estado do jogo e o número de
## desenhos. No fim escreve o CSV e um resumo dos piores quadros.
## Com --fixed-fps 60 cada quadro vale 1/60 s de jogo, e o tempo de verdade
## de cada um é o custo dele (dá para comparar antes e depois).

var arquivo := "user://perfil.csv"
var segundos := 90.0
var principal: Node
var _linhas := []
var _t_quadro := 0
var _passos := 0
var _fis_us := 0
var _fis_ini := 0
var _proc_ini := 0
var _pre_us := 0
var _corot_us := 0
var _fim_proc := 0
var _ultimo_passo_fim := 0
var _jogo := 0.0
var _ini_us := 0
## STRIKE_MARCAS=1: escreve "QUADRO n estado" a cada quadro (para casar com
## o registro de shaders compilados do Mesa: MESA_GLSL=dump)
var _marcas := OS.get_environment("STRIKE_MARCAS") != ""


class _Sonda:
	extends Node
	var dono
	var lado := 0

	func _process(_d):
		dono._sonda_proc(lado)

	func _physics_process(_d):
		dono._sonda_fis(lado)


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	principal = get_parent()
	for a in OS.get_cmdline_args():
		if a.begins_with("--perfil="):
			arquivo = a.substr(9)
		elif a.begins_with("--perfil-seg="):
			segundos = float(a.substr(13))
	for lado in [0, 1]:
		var s := _Sonda.new()
		s.dono = self
		s.lado = lado
		s.pause_mode = Node.PAUSE_MODE_PROCESS
		s.process_priority = -100000 if lado == 0 else 100000
		get_tree().root.call_deferred("add_child", s)
	# "idle_frame" chama primeiro quem se ligou antes (número de objeto
	# menor): esta sonda roda antes das corrotinas (yield) do quadro
	get_tree().connect("idle_frame", self, "_antes_das_corrotinas")
	_ini_us = OS.get_ticks_usec()
	set_process(false)


func _antes_das_corrotinas() -> void:
	_pre_us = OS.get_ticks_usec()


func _sonda_fis(lado: int) -> void:
	var agora := OS.get_ticks_usec()
	if lado == 0:
		_fis_ini = agora
		if _ultimo_passo_fim > 0 and _passos > 0:
			_fis_us += agora - _ultimo_passo_fim   # o passo do motor de antes
	else:
		_fis_us += agora - _fis_ini
		_ultimo_passo_fim = agora
		_passos += 1


func _sonda_proc(lado: int) -> void:
	var agora := OS.get_ticks_usec()
	if lado == 0:
		var pre := _pre_us if _pre_us > 0 else agora
		if _ultimo_passo_fim > 0 and _passos > 0:
			_fis_us += pre - _ultimo_passo_fim   # o último passo do motor
		_corot_us = agora - pre
		_ultimo_passo_fim = 0
		_pre_us = 0
		_proc_ini = agora
		return
	var proc := agora - _proc_ini
	if _t_quadro > 0:
		var quadro := agora - _t_quadro
		var desenho := quadro - proc - _fis_us - _corot_us
		var estado := "?"
		if "estado" in principal and "E" in principal:
			estado = principal.E.keys()[principal.estado]
		_linhas.append([float(agora - _ini_us) / 1e6, quadro, _passos, _fis_us, proc + _corot_us, desenho, estado,
			int(Performance.get_monitor(Performance.RENDER_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_VERTICES_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0),
			int(Performance.get_monitor(Performance.OBJECT_COUNT)),
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), _corot_us, OS.get_system_time_msecs(), _jogo])
	if _marcas:
		print("QUADRO %d %s %.2f" % [_linhas.size(), principal.E.keys()[principal.estado] if "E" in principal else "?", _jogo])
	_t_quadro = agora
	_passos = 0
	_fis_us = 0
	_jogo += get_process_delta_time() / max(Engine.time_scale, 0.01)
	if _jogo >= segundos:
		_terminar()


func _terminar() -> void:
	var f := File.new()
	f.open(arquivo, File.WRITE)
	f.store_line("t;quadro_us;passos;fisica_us;scripts_us;desenho_us;estado;desenhos;vertices;tex_mb;objetos;nos;corrotinas_us;relogio_ms;jogo_s")
	for l in _linhas:
		var partes := PoolStringArray()
		for v in l:
			partes.append(str(v))
		f.store_line(partes.join(";"))
	f.close()
	print("PERFIL: %d quadros em %s" % [_linhas.size(), arquivo])
	get_tree().quit()
