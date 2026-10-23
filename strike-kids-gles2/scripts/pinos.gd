class_name Pinos
extends Spatial

## OS 10 PINOS: montagem no triângulo, contagem dos caídos, carinhas e
## gravação para o replay. Quem varre e recoloca é a Maquina (maquina.gd).
## A queda é 100% física: um pino derruba o outro, batem nas paredes e
## voltam, caem no fosso.
##
## Numeração oficial (vista de quem joga):
##          7   8   9   10
##            4   5   6
##              2   3
##                1

signal batida(posicao, forca)
signal som_pousar

var pinos: Array = []
## a bola (Principal/calibração põem): perto dela os pinos não são freados
var bola: Spatial
## a máquina varrendo: os pinos não são freados (a barra empurra livre)
var varrendo := false
## sombrinhas pintadas no chão embaixo de cada pino (deitam junto com ele).
## Uma MultiMesh só para os 10 pinos = um desenho.
var _sombras: MultiMeshInstance
## por pino: [onde apareceu, removido, visível] da última sombra desenhada —
## pino parado (a maior parte do tempo) não refaz a conta nem a MultiMesh
var _ultimas: Array = []


static func posicao_do_pino(n: int) -> Vector3:
	var fileira := 0
	var primeiro := 1
	while n >= primeiro + fileira + 1:
		primeiro += fileira + 1
		fileira += 1
	var k := n - primeiro
	var x := (float(k) - float(fileira) * 0.5) * Medidas.ESPACO_PINOS
	return Vector3(x, 0.0, Medidas.Z_PINO1 - fileira * Medidas.FILEIRA)


## A FORMA DE COLISÃO DO PINO: três cilindros — base, barriga e
## pescoço com a cabeça — no lugar do casco de 71 pontos. A física testa um
## cilindro numa conta só (o casco percorria os 71 pontos a cada teste, em
## cada par de pinos encostados): a batida ficou ~3x mais leve e, com a
## física a 60 passos por segundo, ~6x (tools/testes/custo_fisica.gd) — na
## TV Box era o que travava no impacto. A base continua estreita (o pino
## tomba como um pino). [raio, altura, centro (altura a partir da base)];
## margem de 5 mm por dentro (na Bullet o cilindro não engorda com ela).
const CILINDROS := [[0.045, 0.10, 0.05], [0.083, 0.20, 0.17], [0.04, 0.21, 0.375]]


static func formas_do_pino() -> Array:
	var r := []
	for c in CILINDROS:
		var cil := CylinderShape.new()
		cil.radius = c[0]
		cil.height = c[1]
		cil.margin = 0.005
		r.append([cil, Vector3(0, c[2], 0)])
	return r


func montar() -> void:
	var malha: Mesh = load("res://modelos/pino.res")
	var formas := formas_do_pino()
	var rosto := Materiais.textura("rosto_pino")
	var meta: Dictionary = malha.get_meta("rosto", {})
	for n in range(1, 11):
		var p := Pino.new()
		add_child(p)
		p.montar(n, posicao_do_pino(n), malha, formas, rosto, meta)
		p.connect("bateu", self, "_pino_bateu")
		pinos.append(p)
	# Godot 3: a QuadMesh só olha para Z; a PlaneMesh já é deitada (olha para Y)
	var q := PlaneMesh.new()
	q.size = Vector2(0.28, 0.28)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = q
	mm.instance_count = pinos.size()
	_sombras = MultiMeshInstance.new()
	_sombras.multimesh = mm
	_sombras.material_override = Materiais.sombra_blob(0.5)
	_sombras.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	add_child(_sombras)


func _pino_bateu(pino: Pino, f: float) -> void:
	emit_signal("batida", pino.global_translation, f)


## O FOSSO SEGURA OS PINOS: o pino que caiu lá atrás (abaixo da pista) não
## volta mais para ela — perto da beirada, indo para a frente, ele é
## rebatido de leve para o fundo; e lá embaixo não pula alto. (Antes um
## pino batia na parede do fundo e voltava pulando para a pista.)
const BEIRADA_FOSSO := 0.3
const PULO_MAX_FOSSO := 0.9
## PINO DE MADEIRA PARA LOGO: deitado no chão (pista, canaleta ou fosso) e
## já devagar, ele perde 7% da velocidade e do giro a cada passo (1/60 s) e
## para em ~1 s. Sem isto ele rolava de um lado para o outro na canaleta,
## como um pêndulo, e seguia rolando pela pista por mais de 3 s (medido em
## tools/testes/pinos_vivos.gd; o amortecimento do próprio corpo não
## bastou). Pino deitado: centro abaixo de DEITADO_ALTURA (na pista ~0,08
## m; na canaleta e no fosso, menos) e mais devagar que DEITADO_VELOCIDADE
## (m/s) — o que voa ou acabou de ser batido não é freado.
const FREIO_DEITADO := 0.93
const LONGE_DA_BOLA := 0.8
const DEITADO_ALTURA := 0.13
const DEITADO_VELOCIDADE := 1.5
## SEM VOOS NEM PIÕES (6.3): um pino a 9 m/s anda 15 cm por passo da física
## — quase a largura dele. Batendo em outro pino ou na parede, a Bullet só
## vê a batida com os dois já entrando um no outro e, para separar, dá
## energia a mais: pinos girando a 15-19 voltas por segundo e subindo até
## 1 m (tools/testes/poucos_pinos.gd). Um pino de madeira de verdade não
## passa disto: giro (rad/s), subida (m/s, o centro sobe no máximo ~20 cm)
## e velocidade (m/s, ~1,25x a bola mais rápida).
const GIRO_MAX := 25.0
const SUBIDA_MAX := 2.4
const VEL_MAX := 11.0


## (Godot 3 + Bullet: dentro do _physics_process, a posição e as
## velocidades do NÓ são as de um passo atrás — o estado do corpo
## (body_get_direct_state) é o de agora. Mexendo na velocidade a cada passo
## a partir do valor do nó, a conta se realimentava e a gravidade sumia: um
## pino subiu 7 m em linha reta. Aqui tudo vem do estado do corpo.)
func _physics_process(_d: float) -> void:
	for p in pinos:
		var pino: Pino = p
		if pino.removido or pino.mode != RigidBody.MODE_RIGID:
			continue
		var st := PhysicsServer.body_get_direct_state(pino.get_rid())
		var tr: Transform = st.transform
		var o: Vector3 = tr.origin
		var v: Vector3 = st.linear_velocity
		var w: Vector3 = st.angular_velocity
		if w.length_squared() > GIRO_MAX * GIRO_MAX:
			w = w.normalized() * GIRO_MAX
			st.angular_velocity = w
		if v.y > SUBIDA_MAX + 0.01 or v.length_squared() > VEL_MAX * VEL_MAX + 0.1:
			v.y = min(v.y, SUBIDA_MAX)
			if v.length_squared() > VEL_MAX * VEL_MAX:
				v = v.normalized() * VEL_MAX
			st.linear_velocity = v
		# deitado (mais na horizontal que em pé), no chão, já devagar e longe
		# da bola: freia (perto dela, ou com a barra varrendo, o pino freado
		# era um peso morto que segurava e desviava a bola e a varrida)
		if not varrendo and tr.basis.y.y < 0.5 and o.y < DEITADO_ALTURA \
				and v.length_squared() < DEITADO_VELOCIDADE * DEITADO_VELOCIDADE \
				and (bola == null or not bola.visible or bola.global_transform.origin.distance_squared_to(o) > LONGE_DA_BOLA * LONGE_DA_BOLA):
			if v.length_squared() > 0.0001 or w.length_squared() > 0.01:
				v *= FREIO_DEITADO
				st.linear_velocity = v
				st.angular_velocity = w * FREIO_DEITADO
		if not pino.no_fosso:
			if o.z < Medidas.Z_FIM_DECK - 0.04 and o.y < 0.02:
				pino.entrou_no_fosso()
			continue
		var mudou := false
		if o.z > Medidas.Z_FIM_DECK - BEIRADA_FOSSO and v.z > 0.0:
			v.z = -v.z * 0.2
			mudou = true
		if v.y > PULO_MAX_FOSSO + 0.01:
			v.y = PULO_MAX_FOSSO
			mudou = true
		if mudou:
			st.linear_velocity = v


func _process(_d: float) -> void:
	var mm := _sombras.multimesh
	if _ultimas.size() != pinos.size():
		_ultimas.resize(pinos.size())
	for i in pinos.size():
		var p: Pino = pinos[i]
		# onde o pino APARECE neste quadro (interpolado entre passos da física);
		# a sombra é da BASE do pino (a origem do corpo é o centro de massa)
		var tp := Medidas.na_tela(p)
		var u = _ultimas[i]
		if u != null and u[0] == tp and u[1] == p.removido and u[2] == p.visible:
			continue
		_ultimas[i] = [tp, p.removido, p.visible]
		var g = tp.xform(-Pino.COM)
		# pino levantado pela máquina ou longe do chão: a sombra some
		var f := 0.0 if p.removido or not p.visible or g.y < -0.1 else clamp(1.0 - g.y * 2.2, 0.0, 1.0)
		# deitado: a sombra fica comprida no sentido do pino
		var eixo := tp.basis.y.normalized()
		var deitado := 1.0 - abs(eixo.y)
		var b := Basis().scaled(Vector3(f * (1.0 + deitado * 0.2), 1.0, f * (1.0 + deitado * 1.6)))
		var giro := atan2(eixo.x, eixo.z)
		b = Basis(Vector3.UP, giro) * b
		var chao := 0.004 if abs(g.x) < Medidas.MEIA_LARGURA and g.z > Medidas.Z_FIM_DECK else -0.2
		if chao < 0.0:
			# fora da pista não tem sombra (nem aparece no alçapão aberto)
			b = Basis().scaled(Vector3.ZERO)
		# perto da borda a sombra encolhe: o adesivo reto não sai da pista
		# (nem fica boiando por cima da canaleta)
		if chao > 0.0:
			f *= clamp((Medidas.MEIA_LARGURA - abs(g.x)) / 0.16, 0.0, 1.0)
			b = Basis(Vector3.UP, giro) * Basis().scaled(Vector3(max(f * (1.0 + deitado * 0.2), 0.001), 1.0, max(f * (1.0 + deitado * 1.6), 0.001)))
		var centro = g + Vector3(eixo.x, 0, eixo.z) * 0.19 * deitado
		mm.set_instance_transform(i, Transform(b, Vector3(centro.x, chao, centro.z)))


func em_pe() -> Array:
	var r: Array = []
	for p in pinos:
		if not p.removido and not p.esta_caido():
			r.append(p.numero)
	return r


func caidos_desde(antes: Array) -> Array:
	var r: Array = []
	var agora := em_pe()
	for n in antes:
		if not agora.has(n):
			r.append(n)
	return r


func pino(n: int) -> Pino:
	return pinos[n - 1]


## Antes da bola chegar: libera a física dos pinos em pé.
func soltar_todos() -> void:
	for p in pinos:
		if not p.removido:
			p.soltar()


## Carinha de medo quando a bola se aproxima.
func susto(bola_pos: Vector3) -> void:
	for p in pinos:
		if p.removido or p.esta_caido():
			continue
		var d: float = p.global_translation.distance_to(bola_pos)
		if d < 3.2 and p._expr == "normal":
			p.expressao("medo")


## Replay: os pinos voltam a ter cara normal (sem estrelinhas) para
## "reviver" a jogada.
func reviver() -> void:
	for p in pinos:
		if not p.removido:
			p.expressao("normal")
			p._estrelas.visible = false


func todos_parados() -> bool:
	for p in pinos:
		if p.removido or p.preso():
			continue
		if p.linear_velocity.length() > 0.06 or p.angular_velocity.length() > 0.25:
			return false
	return true


## Depois da jogada: os caídos ficam tontos (estrelinhas) ou bravinhos; os
## que ficaram de pé comemoram — quanto mais sobraram, mais festa, e alguns
## dão pulinhos. Devolve quantos vão pular (para a câmera esperar a festa).
func reagir() -> int:
	var de_pe: Array = []
	for p in pinos:
		if p.removido:
			continue
		if p.esta_caido():
			if randf() < 0.55:
				p.ficar_tonto()
			else:
				p.ficar_bravo()
		else:
			de_pe.append(p)
	var chance := clamp(0.3 + de_pe.size() * 0.06, 0.35, 0.85)
	de_pe.shuffle()
	var pulando := 0
	for i in de_pe.size():
		var pulos := 0
		if randf() < chance:
			pulos = 1 + int(randf() < 0.45)
			pulando += 1
		de_pe[i].comemorar(0.1 + i * 0.07, pulos)
	return pulando


func prender_todos() -> void:
	for p in pinos:
		p.parar_pulo()
		p.prender()


## Interpolação da física dos pinos (o replay desliga: ele mesmo os move).
func interpolar(sim: bool) -> void:
	for p in pinos:
		p.interpolar(sim)


## Rack completo no lugar, sem animação.
func repor_todos(_animar := false) -> void:
	for p in pinos:
		p.recolocar()


# ---------------------------------------------------------------- replay
func foto() -> Array:
	var r := []
	for p in pinos:
		r.append(p.global_transform)
	return r


func aplicar_foto(f: Array) -> void:
	for i in pinos.size():
		if not pinos[i].removido:
			pinos[i].global_transform = f[i]
