class_name Hud
extends Control

## TUDO O QUE É 2D POR CIMA DO 3D: placar, mapa dos pinos, o convite
## "ROLE A BOLA!", letreiros (STRIKE!...), faixa "VEZ DE...", nome do
## cenário, modo replay e as telas de atração, escolha, fim e inatividade.
## Não há setinhas nem alvos na tela: a mira é sempre o STRIKE.
##
## Responsivo: tudo é reposicionado em `layout()` conforme a tela (em pé ou
## deitada). Unidade "u" = lado menor / 1080.

const COR_BOB := Color("#13A3BC")
const COR_MIA := Color("#8657F2")
const DESTAQUE := Color("#FFB627")
const ROXO := Color("#3B0A63")
const ZONAS := ["Z", "X", "C", "V", "B"]

var fonte: FontFile
var fonte_titulo: FontFile
var u := 1.0
var retrato := true

var tela3d: TextureRect
var _flash: ColorRect
var _tarja_cima: ColorRect
var _tarja_baixo: ColorRect
var _replay: TextureRect
var _replay_ponto: Panel

var _cartoes: Array = []          # [{painel, avatar, nome, pontos, rodadas(HBox), cor, valor_mostrado}]
var _info: Label
var _bolas_box: HBoxContainer
var _mapa: Panel
var _mapa_pontos := {}
var _toque: Control
var _aviso: Label
var _aviso_sub: Label
var _cenario: TextureRect
var _sequencia: Label
var _centro: Control
var _faixa: Panel
var _faixa_texto: Label
var _faixa_avatar: TextureRect
var _atracao: Control
var _logo: TextureRect
var _aperte: Label
var _recorde: Label
var _creditos: Label
var _modal: Panel
var _modal_titulo: Label
var _modal_texto: Label
var _modal_barra: ColorRect
var _modal_barra_fundo: ColorRect
var _selecao: Control
var _sel_nomes: Array[Label] = []
var _sel_texto: Label
var _fim: Control
var _fim_painel: Panel
var _inativo: Panel
var _inativo_texto: Label
var _tempo := 0.0
var _convite := false
var _retratos := {}


func montar(textura_3d: Texture2D) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	fonte = load("res://fontes/fredoka_700.ttf")
	fonte_titulo = load("res://fontes/titan_one.ttf")
	for p in ["bob", "mia"]:
		_retratos[p] = Materiais.textura("retrato_" + p)
	tela3d = TextureRect.new()
	tela3d.texture = textura_3d
	tela3d.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tela3d.stretch_mode = TextureRect.STRETCH_SCALE
	tela3d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tela3d)
	_montar_placar()
	_montar_mapa()
	_montar_toque()
	_centro = Control.new()
	_centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_centro)
	_montar_faixa()
	_montar_replay()
	_montar_atracao()
	_montar_modal()
	_montar_selecao()
	_fim = Control.new()
	_fim.visible = false
	_fim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fim)
	_montar_inatividade()
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	layout()


# ================================================================ peças
func rotulo(texto: String, tam: float, cor := Color.WHITE, contorno := 0.0, cor_contorno := ROXO, f: Font = null) -> Label:
	var l := Label.new()
	l.text = texto
	var ls := LabelSettings.new()
	ls.font = f if f != null else fonte
	ls.font_size = int(tam)
	ls.font_color = cor
	if contorno > 0.0:
		ls.outline_size = int(contorno)
		ls.outline_color = cor_contorno
	ls.shadow_size = int(max(1.0, tam * 0.06))
	ls.shadow_color = Color(0.1, 0.0, 0.2, 0.45)
	ls.shadow_offset = Vector2(0, tam * 0.06)
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func caixa(cor: Color, raio := 28.0, borda := 0.0, cor_borda := Color.WHITE, sombra := 10.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = cor
	s.set_corner_radius_all(int(raio))
	if borda > 0.0:
		s.set_border_width_all(int(borda))
		s.border_color = cor_borda
	s.shadow_size = int(sombra)
	s.shadow_color = Color(0.1, 0.0, 0.25, 0.35)
	s.shadow_offset = Vector2(0, sombra * 0.4)
	s.anti_aliasing = true
	return s


func painel(cor: Color, raio := 28.0, borda := 0.0, cor_borda := Color.WHITE) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", caixa(cor, raio, borda, cor_borda))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _tamanho_rotulo(l: Label, tam: float) -> void:
	l.label_settings.font_size = int(tam)
	l.label_settings.shadow_size = int(max(1.0, tam * 0.06))
	l.label_settings.shadow_offset = Vector2(0, tam * 0.06)


# ================================================================ placar
func _montar_placar() -> void:
	for i in 2:
		var cor := COR_BOB if i == 0 else COR_MIA
		var p := painel(cor, 34, 6)
		add_child(p)
		var av := TextureRect.new()
		av.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		av.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		av.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(av)
		var nome := rotulo("", 34, Color.WHITE, 8)
		nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		p.add_child(nome)
		var pts := rotulo("0", 64, Color("#FFF6A8"), 12, ROXO, fonte_titulo)
		pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		p.add_child(pts)
		var rod := HBoxContainer.new()
		rod.alignment = BoxContainer.ALIGNMENT_BEGIN
		rod.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(rod)
		_cartoes.append({"painel": p, "avatar": av, "nome": nome, "pontos": pts, "rodadas": rod, "cor": cor, "valor": 0.0, "alvo": 0})
	_info = rotulo("", 34, Color.WHITE, 9)
	add_child(_info)
	_bolas_box = HBoxContainer.new()
	_bolas_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_bolas_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bolas_box)
	mostrar_placar(false)


func mostrar_placar(sim: bool) -> void:
	for c in _cartoes:
		c["painel"].visible = sim and c.get("usado", false)
	_info.visible = sim
	_bolas_box.visible = sim
	if _mapa:
		_mapa.visible = sim


## jogadores: [{personagem}], placar: Placar
func configurar_placar(personagens: Array) -> void:
	for i in 2:
		var c: Dictionary = _cartoes[i]
		c["usado"] = i < personagens.size()
		if i < personagens.size():
			var p: String = personagens[i]
			c["nome"].text = p.to_upper()
			c["avatar"].texture = _retratos.get(p)
			var cor := COR_BOB if p == "bob" else COR_MIA
			c["cor"] = cor
			(c["painel"] as Panel).add_theme_stylebox_override("panel", caixa(cor, 34 * u, 6 * u))
			c["valor"] = 0.0
			c["alvo"] = 0
			c["pontos"].text = "0"
	layout()


func atualizar_placar(placar: Placar) -> void:
	for i in placar.jogadores.size():
		var c: Dictionary = _cartoes[i]
		c["alvo"] = placar.total(i)
		var rod: HBoxContainer = c["rodadas"]
		for f in rod.get_children():
			f.queue_free()
		var j: Dictionary = placar.jogadores[i]
		for r in placar.rodadas:
			var bolas: Array = j["rodadas"][r]
			var soma := 0
			for b in bolas:
				soma += int(b)
			var cel := Panel.new()
			cel.custom_minimum_size = Vector2(46, 46) * u
			cel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var cor_cel := Color(1, 1, 1, 0.22)
			var txt := ""
			if bolas.size() > 0:
				cor_cel = Color(1, 1, 1, 0.95)
				txt = str(soma)
				if soma >= 10 and bolas.size() == 1:
					cor_cel = Color("#FFD43B")
					txt = ""
				elif soma >= 10:
					cor_cel = Color("#7FE7FF")
			var atual := (i == placar.jogador_atual and r == placar.rodada_atual)
			cel.add_theme_stylebox_override("panel", caixa(cor_cel, 23 * u, 4 * u if atual else 0.0, Color("#FFF6A8"), 0))
			if txt != "":
				var l := rotulo(txt, 26 * u, ROXO)
				l.label_settings.shadow_size = 0
				l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				cel.add_child(l)
			elif cor_cel == Color("#FFD43B"):
				var e := TextureRect.new()
				e.texture = Materiais.textura("estrela_placar")
				e.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				e.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				e.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				e.mouse_filter = Control.MOUSE_FILTER_IGNORE
				cel.add_child(e)
			rod.add_child(cel)
		var ativo := i == placar.jogador_atual
		var painel_c: Panel = c["painel"]
		painel_c.modulate = Color(1, 1, 1, 1) if ativo or placar.jogadores.size() == 1 else Color(0.78, 0.78, 0.85, 0.9)
		painel_c.scale = Vector2.ONE * (1.0 if ativo else 0.94)
	_info.text = "RODADA %d de %d" % [placar.rodada_atual + 1, placar.rodadas]
	for b in _bolas_box.get_children():
		b.queue_free()
	for k in placar.tentativas:
		var bola := Panel.new()
		bola.custom_minimum_size = Vector2(34, 34) * u
		var usada := k < placar.bola_atual
		bola.add_theme_stylebox_override("panel", caixa(Color(1, 1, 1, 0.25) if usada else _cor_atual(placar), 17 * u, 3 * u, Color.WHITE, 4))
		bola.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bolas_box.add_child(bola)


func _cor_atual(placar: Placar) -> Color:
	return COR_BOB if placar.atual()["personagem"] == "bob" else COR_MIA


# ================================================================ mapa dos pinos
func _montar_mapa() -> void:
	_mapa = painel(Color(0.16, 0.05, 0.32, 0.72), 26, 4, Color(1, 1, 1, 0.6))
	add_child(_mapa)
	for n in range(1, 11):
		var d := Panel.new()
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mapa.add_child(d)
		_mapa_pontos[n] = d
	mostrar_mapa([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
	_mapa.visible = false


func mostrar_mapa(em_pe: Array) -> void:
	for n in _mapa_pontos:
		var d: Panel = _mapa_pontos[n]
		var de_pe := em_pe.has(n)
		d.add_theme_stylebox_override("panel", caixa(Color.WHITE if de_pe else Color(1, 1, 1, 0.12), 99, 3 if de_pe else 0, DESTAQUE, 0))


# ================================================================ convite e toque
## Sem luzes nem setas na tela. No PC/tablet dá para tocar na tela: a
## posição do toque (5 faixas, da esquerda para a direita) vale como o sensor.
func _montar_toque() -> void:
	_toque = Control.new()
	_toque.mouse_filter = Control.MOUSE_FILTER_STOP
	_toque.gui_input.connect(_ao_tocar)
	_toque.visible = false
	add_child(_toque)
	_aviso = rotulo("ROLE A BOLA!", 64, Color("#FFF6A8"), 16, ROXO, fonte_titulo)
	add_child(_aviso)
	_aviso.visible = false
	_aviso_sub = rotulo("mire no STRIKE!", 40, Color.WHITE, 10, ROXO)
	add_child(_aviso_sub)
	_aviso_sub.visible = false
	_cenario = TextureRect.new()
	_cenario.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cenario.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cenario.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cenario.visible = false
	add_child(_cenario)
	_sequencia = rotulo("", 40, Color("#FFF6A8"), 10, Color("#7A1E00"), fonte_titulo)
	_sequencia.visible = false
	add_child(_sequencia)


signal toque_sensor(zona: String)


func _ao_tocar(ev: InputEvent) -> void:
	var pos := Vector2(-1, -1)
	if ev is InputEventMouseButton and ev.pressed:
		pos = ev.position
	elif ev is InputEventScreenTouch and ev.pressed:
		pos = ev.position
	if pos.x < 0.0:
		return
	var i := clampi(int(pos.x / maxf(size.x, 1.0) * 5.0), 0, 4)
	toque_sensor.emit(ZONAS[i])


func convite(ligado: bool, texto := "ROLE A BOLA!") -> void:
	_convite = ligado
	_aviso.text = texto
	_aviso.visible = ligado
	_aviso_sub.visible = ligado
	_toque.visible = true


func mostrar_sensores(sim: bool) -> void:
	_toque.visible = sim
	if not sim:
		_aviso.visible = false
		_aviso_sub.visible = false


func sensor_acendeu(_zona: String) -> void:
	_convite = false
	_aviso.visible = false
	_aviso_sub.visible = false


## Nome do cenário (letreiro grande que entra girando e sai).
func anunciar_cenario(tema: String, dur := 2.2) -> void:
	var tex := Materiais.textura("cen_" + tema)
	if tex == null:
		return
	_cenario.texture = tex
	var T := size
	var w: float = minf(T.x * 0.86, 900.0 * u)
	var h: float = w * float(tex.get_height()) / float(tex.get_width())
	_cenario.size = Vector2(w, h)
	_cenario.position = Vector2((T.x - w) / 2, T.y * (0.3 if retrato else 0.24) - h / 2)
	_cenario.pivot_offset = _cenario.size / 2
	_cenario.visible = true
	_cenario.scale = Vector2.ZERO
	_cenario.rotation = -0.5
	_cenario.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_cenario, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_cenario, "rotation", 0.0, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(dur)
	tw.tween_property(_cenario, "scale", Vector2.ONE * 1.25, 0.3)
	tw.parallel().tween_property(_cenario, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func(): _cenario.visible = false)


## Sequência de strikes (aparece embaixo do placar do jogador).
func sequencia(n: int) -> void:
	_sequencia.visible = n >= 2
	if n >= 2:
		_sequencia.text = "%d STRIKES SEGUIDOS!" % n
		_pular(_sequencia)


# ================================================================ letreiros
## Letreiro grande no centro (STRIKE!, SPARE!...). sub: texto embaixo.
func letreiro(nome: String, sub := "", dur := 1.7, altura := 0.38) -> void:
	var tex := Materiais.textura(nome)
	if tex == null:
		return
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var T := size
	var larg: float = min(T.x * 0.9, tex.get_width() * u * 0.95)
	var alt := larg * tex.get_height() / tex.get_width()
	tr.size = Vector2(larg, alt)
	tr.position = Vector2((T.x - larg) / 2, T.y * altura - alt / 2)
	tr.pivot_offset = tr.size / 2
	tr.scale = Vector2.ZERO
	tr.rotation = deg_to_rad(-12)
	_centro.add_child(tr)
	var tw := create_tween()
	tw.tween_property(tr, "scale", Vector2.ONE * 1.18, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(tr, "rotation", deg_to_rad(3), 0.22)
	tw.tween_property(tr, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(tr, "rotation", 0.0, 0.18)
	tw.tween_property(tr, "scale", Vector2.ONE * 1.05, dur * 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(tr, "position:y", tr.position.y - 120 * u, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(tr, "modulate:a", 0.0, 0.3)
	tw.tween_callback(tr.queue_free)
	_estrelas_2d(tr.position + tr.size / 2, 26)
	if sub != "":
		var l := rotulo(sub, 58 * u, Color.WHITE, 14 * u, ROXO, fonte_titulo)
		l.size = Vector2(T.x, 90 * u)
		l.position = Vector2(0, tr.position.y + alt + 10 * u)
		l.pivot_offset = l.size / 2
		l.scale = Vector2.ZERO
		_centro.add_child(l)
		var t2 := create_tween()
		t2.tween_interval(0.18)
		t2.tween_property(l, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t2.tween_interval(dur * 0.55)
		t2.tween_property(l, "modulate:a", 0.0, 0.3)
		t2.tween_callback(l.queue_free)


## Texto grande simples (ex.: "7 PINOS!").
func texto_grande(texto: String, cor := Color("#FFF6A8"), dur := 1.4, altura := 0.38) -> void:
	var T := size
	var l := rotulo(texto, 110 * u, cor, 22 * u, ROXO, fonte_titulo)
	l.size = Vector2(T.x, 160 * u)
	l.position = Vector2(0, T.y * altura - 80 * u)
	l.pivot_offset = l.size / 2
	l.scale = Vector2.ZERO
	_centro.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2.ONE * 1.12, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.15)
	tw.tween_interval(dur)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)


## "+120" voando até o placar do jogador.
func pontos_voando(pontos: int, jogador: int) -> void:
	if jogador >= _cartoes.size():
		return
	var c: Dictionary = _cartoes[jogador]
	var p: Panel = c["painel"]
	var l := rotulo("+%d" % pontos, 84 * u, Color("#FFF6A8"), 18 * u, ROXO, fonte_titulo)
	l.size = Vector2(400, 120) * u
	l.position = Vector2(size.x / 2 - 200 * u, size.y * 0.5)
	l.pivot_offset = l.size / 2
	_centro.add_child(l)
	var destino := p.position + p.size / 2 - l.size / 2
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2.ONE * 1.2, 0.15)
	tw.tween_interval(0.35)
	tw.tween_property(l, "position", destino, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(l, "scale", Vector2.ONE * 0.5, 0.55)
	tw.tween_callback(func():
		l.queue_free()
		_pular(p))


func _pular(no: Control) -> void:
	no.pivot_offset = no.size / 2
	var tw := create_tween()
	tw.tween_property(no, "scale", Vector2.ONE * 1.08, 0.08)
	tw.tween_property(no, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _estrelas_2d(centro: Vector2, n: int) -> void:
	var p := CPUParticles2D.new()
	p.texture = Materiais.textura("estrela")
	p.amount = n
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 1.0
	p.position = centro
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 60 * u
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 450 * u
	p.initial_velocity_max = 900 * u
	p.gravity = Vector2(0, 900 * u)
	p.angular_velocity_min = -360
	p.angular_velocity_max = 360
	p.scale_amount_min = 0.12 * u
	p.scale_amount_max = 0.3 * u
	var g := Gradient.new()
	g.set_color(0, Color("#FFE14D"))
	g.set_color(1, Color("#FF9F2E"))
	g.add_point(0.5, Color("#7FE7FF"))
	p.color_initial_ramp = g
	_centro.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.6).timeout.connect(p.queue_free)


func flash(cor := Color.WHITE, forca := 0.7, dur := 0.35) -> void:
	_flash.color = Color(cor.r, cor.g, cor.b, forca)
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, dur)


# ================================================================ faixa "VEZ DE"
func _montar_faixa() -> void:
	_faixa = painel(COR_BOB, 40, 7)
	_faixa.visible = false
	add_child(_faixa)
	_faixa_avatar = TextureRect.new()
	_faixa_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_faixa_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_faixa_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_faixa.add_child(_faixa_avatar)
	_faixa_texto = rotulo("", 76, Color.WHITE, 16, ROXO, fonte_titulo)
	_faixa.add_child(_faixa_texto)


func faixa(personagem: String, texto: String, sub := "") -> void:
	var cor := COR_BOB if personagem == "bob" else COR_MIA
	_faixa.add_theme_stylebox_override("panel", caixa(cor, 40 * u, 7 * u))
	_faixa_avatar.texture = _retratos.get(personagem)
	_faixa_texto.text = texto + ("\n" + sub if sub != "" else "")
	var T := size
	var h := 210 * u
	var w: float = min(T.x * 0.92, 980 * u)
	_faixa.size = Vector2(w, h)
	_faixa_avatar.size = Vector2(h * 1.25, h * 1.25)
	_faixa_avatar.position = Vector2(-h * 0.15, -h * 0.35)
	_faixa_texto.size = Vector2(w - h * 1.1, h)
	_faixa_texto.position = Vector2(h * 1.05, 0)
	_tamanho_rotulo(_faixa_texto, (70 if sub == "" else 58) * u)
	_faixa_texto.label_settings.outline_size = int(16 * u)
	var y := T.y * (0.3 if retrato else 0.36)
	_faixa.position = Vector2(-w - 50 * u, y)
	_faixa.visible = true
	var tw := create_tween()
	tw.tween_property(_faixa, "position:x", (T.x - w) / 2, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.25)
	tw.tween_property(_faixa, "position:x", T.x + 50 * u, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _faixa.visible = false)


# ================================================================ replay
func _montar_replay() -> void:
	_tarja_cima = ColorRect.new()
	_tarja_baixo = ColorRect.new()
	for t in [_tarja_cima, _tarja_baixo]:
		t.color = Color(0.03, 0.0, 0.08, 1)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(t)
	_replay = TextureRect.new()
	_replay.texture = Materiais.textura("replay")
	_replay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_replay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_replay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_replay.visible = false
	add_child(_replay)
	_replay_ponto = painel(Color("#FF2E4D"), 99)
	_replay_ponto.visible = false
	add_child(_replay_ponto)


func modo_replay(ligado: bool) -> void:
	var T := size
	var h := T.y * (0.1 if retrato else 0.12) if ligado else 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_tarja_cima, "size:y", h, 0.35).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_tarja_baixo, "size:y", h, 0.35).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_tarja_baixo, "position:y", T.y - h, 0.35).set_trans(Tween.TRANS_QUAD)
	_replay.visible = ligado
	_replay_ponto.visible = ligado
	var w := 420 * u
	_replay.size = Vector2(w, w * 0.236)
	_replay.position = Vector2(T.x - w - 40 * u, T.y * (0.1 if retrato else 0.12) * 0.5 - w * 0.118)
	_replay_ponto.size = Vector2(34, 34) * u
	_replay_ponto.position = _replay.position + Vector2(-50 * u, w * 0.118 - 17 * u)
	if ligado:
		mostrar_placar(false)
		mostrar_sensores(false)


# ================================================================ atração
func _montar_atracao() -> void:
	_atracao = Control.new()
	_atracao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_atracao)
	_logo = TextureRect.new()
	_logo.texture = Materiais.textura("logo")
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_atracao.add_child(_logo)
	_aperte = rotulo("APERTE START", 88, Color.WHITE, 20, ROXO, fonte_titulo)
	_atracao.add_child(_aperte)
	_recorde = rotulo("", 40, Color("#FFF6A8"), 10)
	_atracao.add_child(_recorde)
	_creditos = rotulo("", 34, Color.WHITE, 9)
	_atracao.add_child(_creditos)
	_atracao.visible = false


func atracao(ligado: bool, recorde := "", creditos := "") -> void:
	_atracao.visible = ligado
	_recorde.text = recorde
	_creditos.text = creditos
	if ligado:
		mostrar_placar(false)
		mostrar_sensores(false)


# ================================================================ modal (1 ou 2 jogadores)
func _montar_modal() -> void:
	_modal = painel(Color(0.18, 0.06, 0.38, 0.94), 44, 7, Color("#BFF3FF"))
	_modal.visible = false
	add_child(_modal)
	_modal_titulo = rotulo("", 70, Color("#FFF6A8"), 16, ROXO, fonte_titulo)
	_modal.add_child(_modal_titulo)
	_modal_texto = rotulo("", 40, Color.WHITE, 10)
	_modal_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_modal.add_child(_modal_texto)
	_modal_barra_fundo = ColorRect.new()
	_modal_barra_fundo.color = Color(1, 1, 1, 0.18)
	_modal.add_child(_modal_barra_fundo)
	_modal_barra = ColorRect.new()
	_modal_barra.color = Color("#FFD43B")
	_modal.add_child(_modal_barra)


func modal(ligado: bool, titulo := "", texto := "", fracao := -1.0) -> void:
	if ligado and not _modal.visible:
		_modal.pivot_offset = _modal.size / 2
		_modal.scale = Vector2.ONE * 0.8
		create_tween().tween_property(_modal, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_modal.visible = ligado
	_modal_titulo.text = titulo
	_modal_texto.text = texto
	_modal_barra.visible = fracao >= 0.0
	_modal_barra_fundo.visible = fracao >= 0.0
	if fracao >= 0.0:
		_modal_barra.size.x = _modal_barra_fundo.size.x * clamp(fracao, 0.0, 1.0)


# ================================================================ escolha do personagem
func _montar_selecao() -> void:
	_selecao = Control.new()
	_selecao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selecao.visible = false
	add_child(_selecao)
	var t := rotulo("ESCOLHA SEU AMIGO!", 84, Color("#FFF6A8"), 18, ROXO, fonte_titulo)
	t.name = "titulo"
	_selecao.add_child(t)
	for i in 2:
		var l := rotulo("BOB" if i == 0 else "MIA", 70, Color.WHITE, 16, COR_BOB if i == 0 else COR_MIA, fonte_titulo)
		_selecao.add_child(l)
		_sel_nomes.append(l)
	_sel_texto = rotulo("", 40, Color.WHITE, 10)
	_selecao.add_child(_sel_texto)


func selecao(ligado: bool, destaque := 0, texto := "") -> void:
	_selecao.visible = ligado
	_sel_texto.text = texto
	for i in 2:
		var l := _sel_nomes[i]
		l.pivot_offset = l.size / 2
		l.scale = Vector2.ONE * (1.25 if i == destaque else 0.9)
		l.modulate = Color(1, 1, 1, 1) if i == destaque else Color(1, 1, 1, 0.55)


# ================================================================ fim de jogo
## dados: {jogadores: [{personagem, pontos, estrelas, strikes, spares}], vencedor, recorde: bool, recorde_valor}
func tela_fim(ligado: bool, dados := {}) -> void:
	for f in _fim.get_children():
		f.queue_free()
	_fim.visible = ligado
	if not ligado:
		return
	mostrar_placar(false)
	mostrar_sensores(false)
	var T := size
	var titulo := TextureRect.new()
	titulo.texture = Materiais.textura("fim_de_jogo")
	titulo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	titulo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tw_l: float = min(T.x * 0.62, 640 * u)
	titulo.size = Vector2(tw_l, tw_l * 0.61)
	titulo.position = Vector2((T.x - tw_l) / 2, T.y * 0.04)
	titulo.pivot_offset = titulo.size / 2
	titulo.scale = Vector2.ZERO
	_fim.add_child(titulo)
	create_tween().tween_property(titulo, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var js: Array = dados.get("jogadores", [])
	var n := js.size()
	var larg_card: float = min(T.x * (0.88 if n == 1 else 0.45), 520 * u if n == 2 else 700 * u)
	var alt_card := 430 * u
	var y := T.y * (0.66 if retrato else 0.5)
	if not retrato:
		y = T.y * 0.42
	for i in n:
		var j: Dictionary = js[i]
		var cor := COR_BOB if j["personagem"] == "bob" else COR_MIA
		var c := painel(cor, 40 * u, 7 * u)
		c.size = Vector2(larg_card, alt_card)
		var x := (T.x - larg_card * n - 30 * u * (n - 1)) / 2 + i * (larg_card + 30 * u)
		c.position = Vector2(x, y + 900 * u)
		_fim.add_child(c)
		var tw := create_tween()
		tw.tween_interval(0.3 + i * 0.2)
		tw.tween_property(c, "position:y", y, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var nome := rotulo(str(j["personagem"]).to_upper(), 54 * u, Color.WHITE, 12 * u, ROXO, fonte_titulo)
		nome.size = Vector2(larg_card, 70 * u)
		nome.position = Vector2(0, 18 * u)
		c.add_child(nome)
		var pts := rotulo("0", 120 * u, Color("#FFF6A8"), 22 * u, ROXO, fonte_titulo)
		pts.size = Vector2(larg_card, 140 * u)
		pts.position = Vector2(0, 90 * u)
		c.add_child(pts)
		var alvo := int(j["pontos"])
		var tw2 := create_tween()
		tw2.tween_interval(0.8 + i * 0.2)
		tw2.tween_method(func(v: float): pts.text = str(int(v)), 0.0, float(alvo), 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var leg := rotulo("PONTOS", 34 * u, Color.WHITE, 8 * u)
		leg.size = Vector2(larg_card, 44 * u)
		leg.position = Vector2(0, 225 * u)
		c.add_child(leg)
		# estrelas
		var ne := int(j.get("estrelas", 1))
		for k in 3:
			var e := TextureRect.new()
			e.texture = Materiais.textura("estrela_placar" if k < ne else "estrela_vazia")
			e.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			e.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var es := 92 * u if k == 1 else 76 * u
			e.size = Vector2(es, es)
			e.position = Vector2(larg_card / 2 - es / 2 + (k - 1) * 100 * u, 280 * u - (10 * u if k == 1 else 0.0))
			e.pivot_offset = e.size / 2
			e.scale = Vector2.ZERO
			c.add_child(e)
			var tw3 := create_tween()
			tw3.tween_interval(2.2 + k * 0.25 + i * 0.1)
			tw3.tween_property(e, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var det := rotulo("%d STRIKES   %d SPARES" % [j.get("strikes", 0), j.get("spares", 0)], 30 * u, Color.WHITE, 8 * u)
		det.size = Vector2(larg_card, 40 * u)
		det.position = Vector2(0, alt_card - 58 * u)
		c.add_child(det)
		if dados.get("vencedor", -9) == i and n > 1:
			var v := TextureRect.new()
			v.texture = Materiais.textura("venceu")
			v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			v.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			v.size = Vector2(larg_card * 0.9, larg_card * 0.26)
			v.position = Vector2(larg_card * 0.05, -larg_card * 0.2)
			v.pivot_offset = v.size / 2
			v.scale = Vector2.ZERO
			c.add_child(v)
			var tw4 := create_tween()
			tw4.tween_interval(2.9)
			tw4.tween_property(v, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if dados.get("vencedor", -9) == -1 and n > 1:
		_atrasado(3.0, func(): letreiro("empate", "", 2.5, 0.55))
	if dados.get("recorde", false):
		_atrasado(3.4, func(): letreiro("novo_recorde", "%d PONTOS" % dados.get("recorde_valor", 0), 3.0, 0.42 if retrato else 0.3))
	var ap := rotulo("APERTE START PARA JOGAR DE NOVO", 46 * u, Color.WHITE, 12 * u, ROXO, fonte_titulo)
	ap.size = Vector2(T.x, 70 * u)
	ap.position = Vector2(0, T.y - 170 * u)
	ap.name = "aperte"
	_fim.add_child(ap)


func fim_contagem(segundos: int) -> void:
	var ap := _fim.get_node_or_null("aperte") as Label
	if ap:
		ap.text = "APERTE START PARA JOGAR DE NOVO  (%d)" % segundos


func _atrasado(t: float, f: Callable) -> void:
	get_tree().create_timer(t).timeout.connect(f)


# ================================================================ inatividade
func _montar_inatividade() -> void:
	_inativo = painel(Color(0.18, 0.06, 0.38, 0.95), 44, 7, Color("#BFF3FF"))
	_inativo.visible = false
	add_child(_inativo)
	_inativo_texto = rotulo("", 52, Color.WHITE, 12)
	_inativo_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inativo.add_child(_inativo_texto)


func inatividade(ligado: bool, segundos := 10) -> void:
	_inativo.visible = ligado
	_inativo_texto.text = "AINDA ESTÁ AÍ?\n\nRole a bola para continuar!\n\n%d" % segundos


# ================================================================ layout responsivo
func layout() -> void:
	var T := Tela.tamanho()
	size = T
	position = Vector2.ZERO
	retrato = T.y >= T.x
	u = min(T.x, T.y) / 1080.0
	tela3d.position = Vector2.ZERO
	tela3d.size = T
	_flash.size = T
	_centro.size = T
	_tarja_cima.position = Vector2.ZERO
	_tarja_cima.size = Vector2(T.x, _tarja_cima.size.y)
	_tarja_baixo.size = Vector2(T.x, _tarja_baixo.size.y)
	_tarja_baixo.position = Vector2(0, T.y - _tarja_baixo.size.y)
	# placar
	var usados := 0
	for c in _cartoes:
		if c.get("usado", false):
			usados += 1
	var margem := 26 * u
	var larg: float
	var alt := 200 * u
	if retrato:
		larg = (T.x - margem * 3) / 2 if usados == 2 else T.x * 0.62
	else:
		larg = 560 * u
	for i in 2:
		var c: Dictionary = _cartoes[i]
		var p: Panel = c["painel"]
		p.size = Vector2(larg, alt)
		var x: float
		if usados == 1:
			x = (T.x - larg) / 2 if retrato else margem
		else:
			x = margem if i == 0 else T.x - larg - margem
		p.position = Vector2(x, margem + 40 * u)
		p.pivot_offset = p.size / 2
		var av: TextureRect = c["avatar"]
		av.size = Vector2(alt * 1.15, alt * 1.15)
		av.position = Vector2(-alt * 0.12, -alt * 0.32)
		var nome: Label = c["nome"]
		_tamanho_rotulo(nome, 42 * u)
		nome.label_settings.outline_size = int(10 * u)
		nome.size = Vector2(larg - alt * 1.0, 54 * u)
		nome.position = Vector2(alt * 0.98, 10 * u)
		var pts: Label = c["pontos"]
		_tamanho_rotulo(pts, 78 * u)
		pts.label_settings.outline_size = int(14 * u)
		pts.size = Vector2(larg - alt * 1.0 - 20 * u, 88 * u)
		pts.position = Vector2(alt * 0.98, 52 * u)
		pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var rod: HBoxContainer = c["rodadas"]
		rod.position = Vector2(alt * 0.98, alt - 64 * u)
		rod.size = Vector2(larg - alt, 50 * u)
		rod.add_theme_constant_override("separation", int(8 * u))
	var base_y := margem + 40 * u + alt + 16 * u
	_tamanho_rotulo(_info, 34 * u)
	_info.label_settings.outline_size = int(9 * u)
	if retrato:
		_info.size = Vector2(T.x, 48 * u)
		_info.position = Vector2(0, base_y)
		_bolas_box.size = Vector2(T.x, 40 * u)
		_bolas_box.position = Vector2(0, base_y + 52 * u)
	else:
		_info.size = Vector2(larg, 48 * u)
		_info.position = Vector2(margem, base_y)
		_bolas_box.size = Vector2(larg, 40 * u)
		_bolas_box.position = Vector2(margem, base_y + 52 * u)
	_bolas_box.add_theme_constant_override("separation", int(14 * u))
	# mapa dos pinos (canto)
	var ms := 190 * u
	_mapa.size = Vector2(ms, ms * 0.86)
	_mapa.position = Vector2(T.x - ms - margem, base_y + 8 * u) if retrato else Vector2(T.x - ms - margem, margem + 300 * u)
	for n in _mapa_pontos:
		var pos := Pinos.posicao_do_pino(n)
		var d: Panel = _mapa_pontos[n]
		var r := 24 * u
		d.size = Vector2(r, r)
		var fx := pos.x / (Mundo.ESPACO_PINOS * 1.5)  # -1..1
		var fy := (Mundo.Z_PINO1 - pos.z) / (Mundo.FILEIRA * 3.0)  # 0..1 (fundo em cima)
		d.position = Vector2(ms / 2 + fx * ms * 0.36 - r / 2, ms * 0.86 * (0.78 - fy * 0.56) - r / 2)
	# toque e convite
	_toque.position = Vector2.ZERO
	_toque.size = T
	var y_aviso := T.y - (330 if retrato else 210) * u
	_tamanho_rotulo(_aviso, 84 * u)
	_aviso.label_settings.outline_size = int(20 * u)
	_aviso.size = Vector2(T.x, 120 * u)
	_aviso.position = Vector2(0, y_aviso)
	_aviso.pivot_offset = _aviso.size / 2
	_tamanho_rotulo(_aviso_sub, 44 * u)
	_aviso_sub.label_settings.outline_size = int(11 * u)
	_aviso_sub.size = Vector2(T.x, 64 * u)
	_aviso_sub.position = Vector2(0, y_aviso + 112 * u)
	_aviso_sub.pivot_offset = _aviso_sub.size / 2
	_tamanho_rotulo(_sequencia, 40 * u)
	_sequencia.label_settings.outline_size = int(10 * u)
	_sequencia.size = Vector2(T.x if retrato else larg, 56 * u)
	_sequencia.position = Vector2(0 if retrato else margem, base_y + 100 * u)
	_sequencia.pivot_offset = _sequencia.size / 2
	# atração
	var lw: float = min(T.x * 0.9, 980 * u) if retrato else T.x * 0.36
	var lt := _logo.texture
	var lh: float = lw * (float(lt.get_height()) / float(lt.get_width()) if lt else 0.4)
	_logo.size = Vector2(lw, lh)
	if retrato:
		_logo.position = Vector2((T.x - lw) / 2, T.y * 0.06)
	else:
		_logo.position = Vector2(T.x * 0.03, T.y * 0.05)
	_logo.pivot_offset = _logo.size / 2
	_tamanho_rotulo(_aperte, 96 * u)
	_aperte.label_settings.outline_size = int(22 * u)
	_aperte.size = Vector2(T.x, 130 * u)
	_aperte.position = Vector2(0, T.y * (0.8 if retrato else 0.72))
	_aperte.pivot_offset = _aperte.size / 2
	_tamanho_rotulo(_recorde, 42 * u)
	_recorde.label_settings.outline_size = int(10 * u)
	_recorde.size = Vector2(T.x, 60 * u)
	_recorde.position = Vector2(0, _aperte.position.y + 130 * u)
	_tamanho_rotulo(_creditos, 32 * u)
	_creditos.label_settings.outline_size = int(8 * u)
	_creditos.size = Vector2(T.x, 50 * u)
	_creditos.position = Vector2(0, T.y - 64 * u)
	# modal
	var mw: float = min(T.x * 0.86, 860 * u)
	_modal.size = Vector2(mw, 560 * u)
	_modal.position = (T - _modal.size) / 2
	_modal.add_theme_stylebox_override("panel", caixa(Color(0.18, 0.06, 0.38, 0.94), 44 * u, 7 * u, Color("#BFF3FF")))
	_tamanho_rotulo(_modal_titulo, 70 * u)
	_modal_titulo.label_settings.outline_size = int(16 * u)
	_modal_titulo.size = Vector2(mw, 120 * u)
	_modal_titulo.position = Vector2(0, 40 * u)
	_tamanho_rotulo(_modal_texto, 42 * u)
	_modal_texto.label_settings.outline_size = int(10 * u)
	_modal_texto.size = Vector2(mw - 80 * u, 260 * u)
	_modal_texto.position = Vector2(40 * u, 170 * u)
	_modal_barra_fundo.size = Vector2(mw - 120 * u, 24 * u)
	_modal_barra_fundo.position = Vector2(60 * u, 470 * u)
	_modal_barra.size = Vector2(_modal_barra.size.x, 24 * u)
	_modal_barra.position = _modal_barra_fundo.position
	# seleção
	var t := _selecao.get_node("titulo") as Label
	_tamanho_rotulo(t, 84 * u)
	t.label_settings.outline_size = int(18 * u)
	t.size = Vector2(T.x, 120 * u)
	t.position = Vector2(0, T.y * 0.08)
	for i in 2:
		var l := _sel_nomes[i]
		_tamanho_rotulo(l, 76 * u)
		l.label_settings.outline_size = int(16 * u)
		l.size = Vector2(T.x / 2, 110 * u)
		l.position = Vector2(i * T.x / 2, T.y * (0.66 if retrato else 0.74))
	_tamanho_rotulo(_sel_texto, 42 * u)
	_sel_texto.label_settings.outline_size = int(10 * u)
	_sel_texto.size = Vector2(T.x, 140 * u)
	_sel_texto.position = Vector2(0, T.y * (0.78 if retrato else 0.86))
	# inatividade
	_inativo.size = Vector2(mw, 600 * u)
	_inativo.position = (T - _inativo.size) / 2
	_inativo.add_theme_stylebox_override("panel", caixa(Color(0.18, 0.06, 0.38, 0.95), 44 * u, 7 * u, Color("#BFF3FF")))
	_tamanho_rotulo(_inativo_texto, 54 * u)
	_inativo_texto.label_settings.outline_size = int(12 * u)
	_inativo_texto.size = _inativo.size
	_inativo_texto.position = Vector2.ZERO


func _process(delta: float) -> void:
	_tempo += delta
	# placar: pontos contando
	for c in _cartoes:
		if c.get("usado", false) and c["valor"] < float(c["alvo"]):
			c["valor"] = min(float(c["alvo"]), c["valor"] + delta * max(60.0, (float(c["alvo"]) - c["valor"]) * 3.0))
			(c["pontos"] as Label).text = str(int(c["valor"]))
	if _aviso.visible:
		_aviso.scale = Vector2.ONE * (1.0 + sin(_tempo * 5.0) * 0.05)
		_aviso_sub.modulate.a = 0.6 + 0.4 * absf(sin(_tempo * 2.6))
	if _atracao.visible:
		_logo.scale = Vector2.ONE * (1.0 + sin(_tempo * 2.2) * 0.025)
		_logo.rotation = sin(_tempo * 1.3) * 0.02
		_aperte.modulate.a = 0.55 + 0.45 * abs(sin(_tempo * 3.0))
		_aperte.scale = Vector2.ONE * (1.0 + sin(_tempo * 3.0) * 0.04)
	if _replay_ponto.visible:
		_replay_ponto.modulate.a = 1.0 if fposmod(_tempo, 1.0) < 0.6 else 0.15
