class_name Maquina
extends Spatial

## A MÁQUINA DE PINOS (pinsetter), como num boliche de verdade:
##   * BARRA varredora: desce na frente dos pinos (proteção), varre os
##     caídos para o fosso (empurrando de verdade, com física) e sobe.
##   * ALÇAPÃO: depois da varrida as duas portinhas do chão do fosso abrem
##     para baixo e os pinos caem no poço escuro (só com a bola já
##     recolhida; na jogada o chão fica sempre fechado). A queda é de
##     DESENHO ANIMADO: cada pino dá um pulinho e cai reto, girando, um
##     depois do outro, cada um com uma notinha de xilofone (a escala vai
##     subindo) e um assobio "fiuuu" — e nenhum volta para a pista.
##   * MESA: desce sobre os pinos, levanta os que ficaram em pé, espera a
##     varrida e devolve cada um no seu lugar. Num rack novo, desce já com
##     os 10 pinos encaixados e os deixa na pista.

signal terminou
signal som(nome)
## o alçapão vai abrir (true: a câmera do jogo corta para o fosso) / já
## fechou (false: volta para a mesa)
signal alcapao(abrindo)

const Y_REPOUSO := 1.85
const Y_ENCAIXE := 0.575       # altura da mesa com os pinos apoiados na pista
const Y_LEVANTA := 0.95
const Y_BARRA_CIMA := 1.72
const Y_BARRA_BAIXO := 0.085
const ABRE_ALCAPAO := 1.4      # quanto as portinhas giram para baixo (rad)

var pinos: Pinos
var mesa: Spatial
var barra: KinematicBody
var portas: Array = []
var _portas_lado: Array = []     # -1 = dobradiça na esquerda, 1 = na direita
var _z_mesa := 0.0
var _z_barra := 0.0
var _carregando: Array = []     # pinos presos na mesa: [pino, de onde saiu, lugar certo]
var _centrar := 0.0             # 0 = onde o pino estava, 1 = no lugar certo
var _seq := 0
var _tweens: Array = []
var trabalhando := false
var rapidez := 1.25             # >1 = máquina mais rápida


func montar(p: Pinos) -> void:
	pinos = p
	_z_mesa = Medidas.Z_PINO1 - Medidas.FILEIRA * 1.5
	_z_barra = Medidas.Z_PINO1 + 0.5
	var cor_maquina := Color("#E4EAF4")
	var cor_detalhe := Color("#FFD23F")
	# mesa
	mesa = Spatial.new()
	mesa.name = "mesa"
	add_child(mesa)
	mesa.translation = Vector3(0, Y_REPOUSO, _z_mesa)
	var placa := MeshInstance.new()
	var bm := CubeMesh.new()
	bm.size = Vector3(1.28, 0.07, 1.32)
	placa.mesh = bm
	placa.material_override = Materiais.cor_toon(cor_maquina, 0.0, {"borda": 0.3, "especular": 0.6})
	mesa.add_child(placa)
	var mat_copo := Materiais.cor_toon(cor_detalhe, 0.0, {"borda": 0.3})
	for n in range(1, 11):
		var pos := Pinos.posicao_do_pino(n)
		var copo := MeshInstance.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.075
		cm.bottom_radius = 0.06
		cm.height = 0.12
		cm.radial_segments = 16
		copo.mesh = cm
		copo.material_override = mat_copo
		copo.translation = Vector3(pos.x, -0.035 - 0.06, pos.z - _z_mesa)
		mesa.add_child(copo)
	# colunas que sobem para o teto (o mecanismo)
	for s in [-1.0, 1.0]:
		var col := MeshInstance.new()
		var cc := CylinderMesh.new()
		cc.top_radius = 0.03
		cc.bottom_radius = 0.03
		cc.height = 1.4
		col.mesh = cc
		col.material_override = Materiais.cor_toon(cor_maquina.darkened(0.25), 0.0, {"borda": 0.2})
		col.translation = Vector3(s * 0.55, 0.7, 0)
		mesa.add_child(col)
	# barra varredora (corpo físico que empurra os pinos)
	barra = KinematicBody.new()
	barra.name = "barra"
	barra.set_sync_to_physics(true)
	barra.collision_layer = Medidas.CAMADA_MUNDO
	barra.collision_mask = 0
	# o atrito e o quique de fábrica do Godot 4 (1 e 0), na conta da Bullet
	var pm_barra := Medidas.material(1.0, 0.0, "pinos")
	PhysicsServer.body_set_param(barra.get_rid(), PhysicsServer.BODY_PARAM_FRICTION, pm_barra.friction)
	PhysicsServer.body_set_param(barra.get_rid(), PhysicsServer.BODY_PARAM_BOUNCE, pm_barra.bounce)
	var cs := CollisionShape.new()
	var bs := BoxShape.new()
	bs.extents = Vector3(Medidas.MEIA_LARGURA * 2 + 0.3, 0.17, 0.07) / 2.0
	cs.shape = bs
	barra.add_child(cs)
	var vis := MeshInstance.new()
	var bb := CubeMesh.new()
	bb.size = bs.extents * 2.0
	vis.mesh = bb
	vis.material_override = Materiais.cor_toon(cor_detalhe, 0.003, {"borda": 0.3})
	barra.add_child(vis)
	for s in [-1.0, 1.0]:
		var haste := MeshInstance.new()
		var hb := CubeMesh.new()
		hb.size = Vector3(0.05, 1.3, 0.05)
		haste.mesh = hb
		haste.material_override = Materiais.cor_toon(cor_maquina.darkened(0.25), 0.0, {"borda": 0.2})
		haste.translation = Vector3(s * (Medidas.MEIA_LARGURA + 0.12), 0.65, 0)
		barra.add_child(haste)
	add_child(barra)
	barra.translation = Vector3(0, Y_BARRA_CIMA, _z_barra)
	_montar_alcapao()
	# mesa, barra e portinhas andam nos passos da física (tweens de física): interpoladas
	for n in [mesa, barra] + portas:
		(n as Node).physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
		(n as Node).reset_physics_interpolation()


## As duas portinhas do alçapão (o vão é o Medidas.ALCAPAO_*): cada uma gira
## na dobradiça da beirada de fora; fechadas, o chão fica liso como o resto
## do fosso (mesma altura, mesmo atrito).
func _montar_alcapao() -> void:
	var comp := Medidas.ALCAPAO_Z0 - Medidas.ALCAPAO_Z1
	var mat := Materiais.cor_toon(Color("#1D4290"), 0.0, {"borda": 0.3})
	var mat_faixa := Materiais.cor_toon(Color("#FFD23F"), 0.0, {"borda": 0.25})
	var pm := Medidas.material(0.9, 0.0, "pinos")
	for s in [-1.0, 1.0]:
		var porta := KinematicBody.new()
		porta.name = "alcapao_%d" % int(s)
		porta.set_sync_to_physics(true)
		porta.collision_layer = Medidas.CAMADA_MUNDO
		porta.collision_mask = 0
		# (Godot 3: o KinematicBody não tem material; atrito e quique vão
		# direto para o servidor de física)
		PhysicsServer.body_set_param(porta.get_rid(), PhysicsServer.BODY_PARAM_FRICTION, pm.friction)
		PhysicsServer.body_set_param(porta.get_rid(), PhysicsServer.BODY_PARAM_BOUNCE, pm.bounce)
		var tam := Vector3(Medidas.ALCAPAO_X - 0.004, 0.04, comp - 0.008)
		var cs := CollisionShape.new()
		var bs := BoxShape.new()
		bs.extents = tam / 2.0
		cs.shape = bs
		cs.translation = Vector3(-s * tam.x / 2.0, -tam.y / 2.0, 0)
		porta.add_child(cs)
		var vis := MeshInstance.new()
		var bm := CubeMesh.new()
		bm.size = tam
		vis.mesh = bm
		vis.material_override = mat
		vis.translation = cs.translation
		vis.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
		porta.add_child(vis)
		# faixa amarela na beirada do meio (onde o chão se abre)
		var faixa := MeshInstance.new()
		var fm := CubeMesh.new()
		fm.size = Vector3(0.045, 0.004, tam.z - 0.05)
		faixa.mesh = fm
		faixa.material_override = mat_faixa
		faixa.translation = Vector3(-s * (tam.x - 0.035), 0.002, 0)
		faixa.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
		porta.add_child(faixa)
		add_child(porta)
		portas.append(porta)
		_portas_lado.append(s)
	_fechar_portas()


## Portinhas fechadas, na hora (o transform INTEIRO: num corpo sincronizado
## com a física, mexer só no giro antes de um passo da física levaria a
## posição de antes, a da origem).
func _fechar_portas() -> void:
	for i in portas.size():
		portas[i].transform = Transform(Basis(), Vector3(_portas_lado[i] * Medidas.ALCAPAO_X, Medidas.Y_CHAO_FOSSO,
			(Medidas.ALCAPAO_Z0 + Medidas.ALCAPAO_Z1) / 2.0))
		portas[i].reset_physics_interpolation()


## Abre (as portinhas giram para baixo, acelerando como quem cai) ou fecha.
func _alcapao(abrir: bool, dur: float) -> SceneTreeTween:
	var t := create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	t.set_parallel(true)
	for i in portas.size():
		var alvo = _portas_lado[i] * ABRE_ALCAPAO if abrir else 0.0
		t.tween_property(portas[i], "rotation:z", alvo, dur / rapidez).set_trans(Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_IN if abrir else Tween.EASE_IN_OUT)
	_tweens.append(t)
	return t


func _pausa(dur: float) -> SceneTreeTween:
	var t := create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	t.tween_interval(dur / rapidez)
	_tweens.append(t)
	return t


func _physics_process(_delta: float) -> void:
	for item in _carregando:
		var p: Pino = item[0]
		var off: Vector3 = (item[1] as Vector3).linear_interpolate(item[2], _centrar)
		p.colocar_em(mesa.global_translation + off)


func _tw(alvo: Object, prop: String, valor, dur: float) -> SceneTreeTween:
	var t := create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	t.tween_property(alvo, prop, valor, dur / rapidez).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tweens.append(t)
	return t


## Espera o tween; false se a máquina foi interrompida no meio. (Godot 3:
## quem chama espera com yield(_ok(t, s), "completed").)
func _ok(t: SceneTreeTween, s: int) -> bool:
	yield(t, "finished")
	_tweens.erase(t)
	return s == _seq


## Depois de uma bola que não fechou a rodada: guarda os pinos em pé,
## varre os caídos e devolve os em pé no lugar. derrubou: a bola derrubou
## algum pino (numa jogada errada o alçapão não abre).
func reposicionar(derrubou := true) -> void:
	var r = _ciclo(true, derrubou)
	if r is GDScriptFunctionState:
		yield(r, "completed")


## Rack novo (rodada nova): varre tudo e desce os 10 pinos.
func rack_novo(derrubou := true) -> void:
	var r = _ciclo(false, derrubou)
	if r is GDScriptFunctionState:
		yield(r, "completed")


## Pinos caídos lá no fosso (atrás da pista), que o alçapão faria cair.
func _pinos_no_fosso(levados: Array) -> int:
	var n := 0
	for p in pinos.pinos:
		if levados.has(p) or p.removido:
			continue
		var g: Vector3 = p.posicao_base()
		if g.z < Medidas.Z_FIM_DECK and g.z > Medidas.ALCAPAO_Z1 - 0.1 and abs(g.x) < Medidas.ALCAPAO_X + 0.05 and g.y < 0.0:
			n += 1
	return n


## Os pinos que estão no fosso (atrás do fim da pista), os que o alçapão
## derruba no poço — da esquerda para a direita (a cascata de notas).
func _pinos_do_fosso(levados: Array) -> Array:
	var r: Array = []
	for p in pinos.pinos:
		if levados.has(p) or p.removido:
			continue
		var g: Vector3 = p.posicao_base()
		if g.z < Medidas.Z_FIM_DECK + 0.02 and g.y < 0.05:
			r.append(p)
	r.sort_custom(self, "_da_esquerda")
	return r


func _da_esquerda(a: Pino, b: Pino) -> bool:
	return a.global_transform.origin.x < b.global_transform.origin.x


## A QUEDA DIVERTIDA (desenho animado, sem física): um depois do outro, cada
## pino achata, dá um pulinho, estica e cai reto no poço girando — e vai
## para o meio do vão (não passa pelas portinhas abertas). Termina quando o
## último chega lá embaixo.
const QUEDA_DUR := 0.62
const QUEDA_INTERVALO := 0.075


func _queda_divertida(caindo: Array) -> SceneTreeTween:
	var t := create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	t.set_parallel(true)
	t.tween_interval(0.05)
	for i in caindo.size():
		var p: Pino = caindo[i]
		var atraso: float = (0.16 + i * QUEDA_INTERVALO) / rapidez
		var de: Transform = p.global_transform
		var x: float = clamp(de.origin.x * 0.55, -0.42, 0.42)
		var z: float = clamp(de.origin.z, Medidas.ALCAPAO_Z0 - 0.3, Medidas.ALCAPAO_Z1 + 0.3)
		var para := Vector3(x, Medidas.POCO_FUNDO + 0.12, z)
		var eixo := Vector3(rand_range(-1.0, 1.0), 0.0, rand_range(-1.0, 1.0))
		if eixo.length() < 0.2:
			eixo = Vector3.RIGHT
		var voltas: float = rand_range(0.55, 1.1) * (1.0 if randf() < 0.5 else -1.0)
		t.tween_callback(self, "_pulo_do_pino", [i]).set_delay(atraso)
		t.tween_method(self, "_cair_pino", 0.0, 1.0, QUEDA_DUR / rapidez, [p, de, para, eixo.normalized(), voltas]) \
			.set_delay(atraso)
		t.tween_callback(self, "_pino_no_fundo", [p]).set_delay(atraso + QUEDA_DUR / rapidez)
	_tweens.append(t)
	return t


func _pulo_do_pino(i: int) -> void:
	emit_signal("som", "queda_%d" % i)


func _pino_no_fundo(p: Pino) -> void:
	p.malha.scale = Vector3.ONE
	emit_signal("som", "fundo")


## k: 0..1 da queda de um pino. Até 0,22: achata e dá o pulinho (7 cm);
## depois cai acelerando (como quem cai de verdade) até o fundo do poço,
## girando em volta de um eixo deitado.
func _cair_pino(k: float, p: Pino, de: Transform, para: Vector3, eixo: Vector3, voltas: float) -> void:
	var pos: Vector3
	var giro := 0.0
	if k < 0.22:
		var u := k / 0.22
		pos = de.origin + Vector3(0, sin(u * PI * 0.5) * 0.07, 0)
		var a := sin(u * PI)
		p.malha.scale = Vector3(1.0 - 0.08 * a, 1.0 + 0.12 * a, 1.0 - 0.08 * a) if u > 0.35 else \
			Vector3(1.0 + 0.1 * a, 1.0 - 0.14 * a, 1.0 + 0.1 * a)
	else:
		var u := (k - 0.22) / 0.78
		var topo := de.origin + Vector3(0, 0.07, 0)
		var xz := u * (2.0 - u)
		pos = Vector3(lerp(topo.x, para.x, xz), lerp(topo.y, para.y, u * u), lerp(topo.z, para.z, xz))
		giro = voltas * TAU * u
		p.malha.scale = Vector3.ONE
	p.global_transform = Transform(Basis(eixo, giro) * de.basis, pos)


func _ciclo(manter: bool, derrubou := true) -> void:
	_seq += 1
	var s := _seq
	trabalhando = true
	pinos.prender_todos()
	# 1. barra desce na frente (proteção)
	emit_signal("som", "barra")
	if not yield(_ok(_tw(barra, "translation:y", Y_BARRA_BAIXO, 0.55), s), "completed"):
		return
	# 2. mesa desce e levanta os pinos em pé (centralizando no lugar certo)
	_carregando.clear()
	_centrar = 0.0
	if manter:
		var em_pe := pinos.em_pe()
		if not em_pe.empty():
			emit_signal("som", "mesa")
			if not yield(_ok(_tw(mesa, "translation:y", Y_ENCAIXE + 0.02, 0.7), s), "completed"):
				return
			for n in em_pe:
				var p := pinos.pino(n)
				var b := p.posicao_base()
				var onde := Vector3(b.x, p.lugar.y, b.z)
				p.colocar_em(onde)
				p.collision_layer = 0
				_carregando.append([p, onde - mesa.global_translation, p.lugar - mesa.global_translation])
			var t := _tw(mesa, "translation:y", Y_LEVANTA, 0.45)
			t.parallel().tween_property(self, "_centrar", 1.0, 0.45 / rapidez)
			if not yield(_ok(t, s), "completed"):
				return
	# 3. varre os caídos para o fosso (a barra empurra de verdade)
	var levados := []
	for item in _carregando:
		levados.append(item[0])
	for p in pinos.pinos:
		if not levados.has(p) and not p.removido:
			p.soltar()
			p.sleeping = false
	emit_signal("som", "varrer")
	if not yield(_ok(_tw(barra, "translation:z", Medidas.Z_FIM_DECK - 0.15, 0.7), s), "completed"):
		return
	# 3b. o ALÇAPÃO: as portinhas abrem para baixo e os pinos do fosso caem
	# (com a física) até o fundo do poço — só se a bola derrubou pinos e há
	# pino caído no fosso (bola na canaleta / jogada errada: fica fechado)
	if derrubou and _pinos_no_fosso(levados) > 0:
		emit_signal("alcapao", true)
		if not yield(_ok(_pausa(0.25), s), "completed"):
			return
		var caindo := _pinos_do_fosso(levados)
		for p in caindo:
			p.prender()
		emit_signal("som", "alcapao")
		var abre := _alcapao(true, 0.38)
		if not yield(_ok(_queda_divertida(caindo), s), "completed"):
			return
		if abre.is_valid() and abre.is_running():
			if not yield(_ok(abre, s), "completed"):
				return
		if not yield(_ok(_pausa(0.2), s), "completed"):
			return
		# a barra volta enquanto o alçapão fecha; os pinos lá embaixo saem do jogo
		var fecha := _alcapao(false, 0.55)
		if not yield(_ok(_tw(barra, "translation:z", _z_barra, 0.55), s), "completed"):
			return
		if fecha.is_valid() and fecha.is_running():
			if not yield(_ok(fecha, s), "completed"):
				return
		_fechar_portas()   # no lugar exato (sem acumular sobra de conta)
		for p in pinos.pinos:
			if not levados.has(p):
				p.tirar()
		emit_signal("alcapao", false)
	else:
		for p in pinos.pinos:
			if not levados.has(p):
				p.tirar()
		if not yield(_ok(_tw(barra, "translation:z", _z_barra, 0.5), s), "completed"):
			return
	# 4. mesa devolve (ou traz os 10 novos)
	if not manter:
		mesa.translation.y = Y_REPOUSO
		_centrar = 1.0
		for p in pinos.pinos:
			p.recolocar()
			p.collision_layer = 0
			var off = p.lugar - Vector3(0, Y_ENCAIXE, _z_mesa)
			_carregando.append([p, off, off])
			# já na mesa (sem aparecer um quadro na pista)
			p.colocar_em(mesa.global_translation + off)
			p.reset_physics_interpolation()
	if not _carregando.empty():
		emit_signal("som", "mesa")
		if not yield(_ok(_tw(mesa, "translation:y", Y_ENCAIXE, 0.85 if not manter else 0.75), s), "completed"):
			return
		for item in _carregando:
			var p: Pino = item[0]
			p.recolocar()
		_carregando.clear()
		emit_signal("som", "pousar")
		pinos.emit_signal("som_pousar")
		if not yield(_ok(_tw(mesa, "translation:y", Y_REPOUSO, 0.6), s), "completed"):
			return
	# 5. barra sobe
	emit_signal("som", "barra")
	if not yield(_ok(_tw(barra, "translation:y", Y_BARRA_CIMA, 0.5), s), "completed"):
		return
	trabalhando = false
	emit_signal("terminou")


## Sem animação (atração, começo).
func instantaneo() -> void:
	_seq += 1
	for t in _tweens:
		if t.is_valid():
			t.kill()
	_tweens.clear()
	_carregando.clear()
	_centrar = 0.0
	mesa.translation = Vector3(0, Y_REPOUSO, _z_mesa)
	barra.translation = Vector3(0, Y_BARRA_CIMA, _z_barra)
	mesa.reset_physics_interpolation()
	barra.reset_physics_interpolation()
	_fechar_portas()
	for p in pinos.pinos:
		p.recolocar()
	trabalhando = false
