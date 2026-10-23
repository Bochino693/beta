extends Node

## CALIBRAÇÃO DAS JOGADAS (física de verdade, sem tela).
##   godot3 --no-window --path . --fixed-fps 60 res://tools/testes/calibrar.tscn -- --zonas=C,X --saida=res://dados/parte.json
## (edição OpenGL ES 2.0: a física é a Bullet do Godot 3 — a tabela é desta física)
## Para cada posição de sensor, joga a bola em várias linhas, velocidades e
## efeitos (cada uma 2 vezes, saindo de pontos um pouco diferentes), com o
## rack completo, e anota quantos/quais pinos caíram. Sem as opções, faz
## tudo e grava res://dados/tabela_jogadas.json (o planejador usa).

const ZONAS := {"Z": -0.43, "X": -0.21, "C": 0.0, "V": 0.21, "B": 0.43}
const VELOCIDADES := [7.0, 7.9, 8.8]
const EFEITOS := [-0.12, 0.0, 0.12]
## de onde a bola sai (como no jogo, que sorteia entre 0,28 e 0,45): 4
## amostras de cada linha, para o planejador saber quais rendem sempre o
## mesmo (a física é caótica nas batidas de raspão)
const SAIDAS := [0.29, 0.33, 0.37, 0.42]

var mundo: Mundo
var pinos: Pinos
var maquina: Maquina
var bola: Bola
var fila := []
var atual = null
var t := 0.0
var fase := 0
var x_entrada := 0.0
## DESVIO DA BOLA na batida: a linha reta que ela fazia ao chegar nos
## pinos (posição e velocidade) contra onde ela sai do fim da pista
var v_entrada := Vector3.ZERO
var x_saida := 9.0
var resultados := []
var inicio_ms := 0
var saida := "res://dados/tabela_jogadas.json"
var validar := ""   # --validar=normal: testa o planejador (Jogada) em vez de calibrar


func _ready() -> void:
	var zonas: Array = ZONAS.keys()
	for a in OS.get_cmdline_args():
		if a.begins_with("--zonas="):
			zonas = a.substr(8).split(",")
		elif a.begins_with("--saida="):
			saida = a.substr(8)
		elif a.begins_with("--validar="):
			validar = a.substr(10)
		elif a.begins_with("--linha="):
			# depuração: --linha=X,-0.21,0.16,8.8,0.12  (5 saídas diferentes)
			var l: PoolStringArray = a.substr(8).split(",")
			for zs in [0.29, 0.32, 0.35, 0.4, 0.45]:
				fila.append([l[0], float(l[1]), float(l[2]), float(l[3]), float(l[4]), zs, -1])
			validar = "linha"
	mundo = Mundo.new()
	add_child(mundo)
	mundo.construir()
	mundo.definir_protecao(true)
	pinos = Pinos.new()
	add_child(pinos)
	pinos.montar()
	# a máquina de pinos, como no jogo: o alçapão do fosso fica fechado na
	# jogada (a bola rola até a caçapa; os pinos ficam no chão do fosso)
	maquina = Maquina.new()
	add_child(maquina)
	maquina.montar(pinos)
	bola = Bola.new()
	add_child(bola)
	pinos.bola = bola
	bola.vestir("bob")
	if OS.get_environment("EXP_MASSA_BOLA") != "":
		bola.mass = float(OS.get_environment("EXP_MASSA_BOLA"))
	if OS.get_environment("EXP_QUIQUE_BOLA") != "":
		bola.physics_material_override.bounce = float(OS.get_environment("EXP_QUIQUE_BOLA"))
	bola.guardar()
	if validar == "linha":
		return
	if validar != "":
		var tudo := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
		for z in zonas:
			for i in 80:
				var j = Jogada.planejar(z, tudo, true, validar, true)
				# sai de um ponto um pouco diferente a cada vez (como no jogo)
				fila.append([z, j.origem_x, j.alvo_x, j.velocidade, j.efeito, rand_range(0.28, 0.45), j.esperado])
		print("validando ", fila.size(), " jogadas (", validar, ")")
		inicio_ms = Time.get_ticks_msec()
		return
	for z in zonas:
		var x0: float = ZONAS[z]
		for i in 51:
			var xt = -0.5 + i * 0.02
			if abs(xt - x0) > 0.62:
				continue
			for v in VELOCIDADES:
				for e in EFEITOS:
					for zs in SAIDAS:
						fila.append([z, x0, stepify(xt, 0.001), v, e, zs])
	print("jogadas para simular: ", fila.size())
	inicio_ms = Time.get_ticks_msec()


func _physics_process(delta: float) -> void:
	if atual == null:
		if fila.empty():
			_gravar()
			set_physics_process(false)
			return
		atual = fila.pop_front()
		maquina.instantaneo()
		pinos.repor_todos()
		pinos.soltar_todos()
		bola.guardar()
		t = 0.0
		fase = 0
		x_entrada = 9.0
		x_saida = 9.0
		return
	t += delta
	if fase == 0 and t > 0.05:
		var x0: float = atual[1]
		var xt: float = atual[2]
		var zs: float = atual[5]
		# mesma linha (de x0 em z=0,35 até xt nos pinos), saindo de zs
		var u := (0.35 - zs) / (0.35 - Medidas.Z_PINO1)
		var origem := Vector3(lerp(x0, xt, u), Bola.RAIO + 0.04, zs)
		var alvo := Vector3(xt, Bola.RAIO, Medidas.Z_PINO1)
		var dir := alvo - origem
		dir.y = 0
		bola.lancar(origem, dir.normalized() * float(atual[3]), float(atual[4]))
		fase = 1
		t = 0.0
		return
	if fase == 1:
		var b := bola.global_translation
		if x_entrada > 8.0 and b.z < Medidas.Z_PINO1 + 0.4:
			x_entrada = b.x
			v_entrada = bola.linear_velocity
		if x_saida > 8.0 and b.z < Medidas.Z_FIM_DECK + 0.03:
			x_saida = b.x
		var fim := b.z < Medidas.Z_FIM_DECK - 0.3 or b.y < -0.4 or t > 5.0
		if fim:
			fase = 2
			t = 0.0
		return
	if fase == 2 and (t > 3.0 or (t > 1.2 and pinos.todos_parados())):
		var em_pe := pinos.em_pe()
		if validar == "linha":
			var desvio := 0.0
			if x_saida < 8.0 and v_entrada.z < -0.1:
				var reta := x_entrada + v_entrada.x / -v_entrada.z * (Medidas.Z_PINO1 + 0.4 - Medidas.Z_FIM_DECK - 0.03)
				desvio = x_saida - reta
			print("saida z=", atual[5], " caidos=", 10 - em_pe.size(), " bola=", bola.global_translation, " entrada=", x_entrada,
				" desvio=%.3f" % desvio)
		var caidos := []
		for n in range(1, 11):
			if not em_pe.has(n):
				caidos.append(n)
		resultados.append([atual[0], atual[1], atual[2], atual[3], atual[4], caidos.size(), caidos, stepify(x_entrada, 0.001),
			atual[6] if atual.size() > 6 else -1])
		if resultados.size() % 100 == 0:
			print(resultados.size(), " prontas (", (Time.get_ticks_msec() - inicio_ms) / 1000, " s)")
		atual = null


func _gravar() -> void:
	if validar != "":
		for z in ZONAS:
			var n := 0
			var soma := 0
			var strikes := 0
			var esp_strikes := 0
			var acerto := 0
			var hist := {}
			for r in resultados:
				if r[0] != z:
					continue
				n += 1
				soma += int(r[5])
				strikes += 1 if int(r[5]) == 10 else 0
				esp_strikes += 1 if int(r[8]) == 10 else 0
				acerto += 1 if abs(int(r[5]) - int(r[8])) <= 1 else 0
				if int(r[5]) == 0:
					print("  zero: ", r)
				hist[int(r[5])] = hist.get(int(r[5]), 0) + 1
			if n > 0:
				print("%s: média %.1f  strikes %d%% (planejados %d%%)  perto do planejado %d%%  %s" % [z, float(soma) / n,
					100 * strikes / n, 100 * esp_strikes / n, 100 * acerto / n, str(hist)])
		print("VALIDACAO OK")
		get_tree().quit()
		return
	Directory.new().make_dir_recursive(ProjectSettings.globalize_path("res://dados"))
	var f := File.new()
	f.open(saida, File.WRITE)
	f.store_string(to_json({"versao": 2, "jogadas": resultados}))
	f.close()
	# resumo por zona
	for z in ZONAS:
		var n := 0
		var soma := 0
		var strikes := 0
		for r in resultados:
			if r[0] == z:
				n += 1
				soma += int(r[5])
				if int(r[5]) == 10:
					strikes += 1
		if n > 0:
			print("zona %s: %d jogadas, média %.1f pinos, %d strikes (%.0f%%)" % [z, n, float(soma) / n, strikes, 100.0 * strikes / n])
	print("CALIBRACAO OK")
	get_tree().quit()
