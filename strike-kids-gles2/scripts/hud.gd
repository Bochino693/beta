class_name Hud
extends Control

## TUDO O QUE É 2D POR CIMA DO 3D: placar, mapa dos pinos, o convite
## "ROLE A BOLA!", letreiros (STRIKE!...), faixa "VEZ DE...", nome do
## cenário, modo replay e as telas de atração, escolha, fim e inatividade.
## Não há setinhas nem alvos na tela: a mira é sempre o STRIKE.
##
## Responsivo: tudo é reposicionado em `layout()` conforme a tela (em pé ou
## deitada). Unidade "u" = lado menor / 1080.
##
## Visual: placas com volume (Painel3D: degradê, verniz, lateral e sombra,
## como os objetos 3D) e contorno azul-marinho. A marca Lazer & Sport só
## aparece na abertura (e, no 3D, sutil em cada cenário: ver Mundo).
##
## EDIÇÃO OPENGL ES 2.0 (Godot 3): textos sem LabelSettings — cada texto usa
## a DynamicFont do seu tamanho e contorno (ver rotulo()).

const COR_BOB := Color("#169BD5")
const COR_MIA := Color("#FF7A21")
const DESTAQUE := Color("#FFC21A")
const ESCALA_ARTE := 1.6       # letreiros gerados em 1,6x (nítidos em 4K)
const MARINHO := Color("#0B1F45")   # contornos e textos escuros
const AZUL := Color("#1A4FA8")      # placas azuis
const CREME := Color("#FFF6A8")
const ZONAS := ["Z", "X", "C", "V", "B"]
const MARCA := "res://ui/marca/"
## posição das peças dentro da logo inteira (tools/arte/gerar_marca.py)
const CENTRO_ALVO := Vector2(0.4752, 0.2780)
const CENTRO_PLACA := Vector2(0.5, 0.7792)
const PROPORCAO_LOGO := 1698.0 / 2560.0

## nomes das fontes (Compat.fonte): no Godot 3 cada tamanho é uma DynamicFont
var fonte := "fredoka_700"
var fonte_titulo := "titan_one"
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
var _mapa: Painel3D
var _mapa_pontos := {}
var _toque: Control
var _aviso: Label
var _aviso_sub: Label
var _cenario: TextureRect
var _sequencia: Label
var _centro: Control
var _faixa: Painel3D
var _faixa_texto: Label
var _faixa_avatar: TextureRect
var _atracao: Control
var _logo: TextureRect
var _aperte: Label
var _aperte_botao: Painel3D
var _recorde: Label
var _recorde_placa: Painel3D
var _creditos: Label
# quantos vão jogar
var _jog: Control
var _jog_veu: ColorRect
var _jog_painel: Painel3D
var _jog_titulo: Label
var _jog_cartoes: Array = []      # Painel3D
var _jog_dica: Label
var _jog_trilho: Painel3D
var _jog_barra: Painel3D
var _jog_n := 1
# escolha do personagem
var _selecao: Control
var _sel_titulo: Painel3D
var _sel_placas: Array = []       # Painel3D
var _sel_nomes: Array = []        # Label
var _sel_dica: Painel3D
var _sel_texto: Label
var _sel_destaque := 0
var _sel_sensores: Control
var _fim: Control
var _fim_vez := 0          # cada fim de jogo mostrado (os letreiros atrasados conferem)
var _inativo: Painel3D
var _inativo_texto: Label
var _aviso_android: Painel3D
var _aviso_android_texto: Label
var _tempo := 0.0
var _convite := false
var _retratos := {}
# fotos das crianças (câmera da máquina)
var _foto_tela: Control
var _foto_fundo: ColorRect
var _foto_titulo: Label
var _foto_sub: Label
var _foto_circulo: TextureRect
var _foto_selo: TextureRect
var _foto_numero: Label
var _foto_destaque: TextureRect
var _rec_foto: TextureRect
var _shader_foto: Shader
# marca Lazer & Sport
var _marca_tela: Control
var _marca_fundo: TextureRect
var _marca_games: TextureRect
var _marca_veu: TextureRect
var _marca_alvo: TextureRect
var _marca_placa: TextureRect
var _marca_texto: Label


func montar(textura_3d: Texture) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for p in ["bob", "mia"]:
		_retratos[p] = Materiais.textura("retrato_" + p)
	tela3d = TextureRect.new()
	tela3d.texture = textura_3d
	tela3d.expand = true
	tela3d.stretch_mode = TextureRect.STRETCH_SCALE
	_filtrar(textura_3d)   # imagem 3D (sem mipmaps)
	var m3d := ShaderMaterial.new()
	m3d.shader = load("res://shaders/tela3d.shader")
	tela3d.material = m3d
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
	_montar_jogadores()
	_montar_selecao()
	_fim = Control.new()
	_fim.visible = false
	_fim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fim)
	_montar_inatividade()
	_montar_aviso_android()
	_montar_fotos()
	_montar_etapas()
	_montar_marca()
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# escondido quando transparente: um retângulo da tela inteira desenhado
	# à toa a cada quadro custa caro na TV Box
	_flash.visible = false
	add_child(_flash)
	layout()


# ================================================================ peças
## Godot 3: o contorno vem na medida do Godot 4 (LabelSettings.outline_size)
## e vira o contorno da DynamicFont 4x menor — o Godot 4 passa
## outline_size x 16 ao FreeType e o Godot 3 passa outline_size x 64 (em
## 1/64 de pixel): o mesmo número desenharia um contorno 4x mais grosso.
const CONTORNO_G4_PARA_G3 := 0.25
## sombra dos textos (a do LabelSettings do Godot 4)
const SOMBRA := Color(0.0, 0.05, 0.15, 0.45)
## Godot 3: cada tamanho de fonte guarda as letras numa página de
## nextpow2(tamanho x 8) pixels; acima disto (x u) o texto é desenhado
## menor e esticado (ver _rotulo_grande).
const FONTE_MAX := 128.0


## f: nome da fonte (Compat.fonte); vazio = `fonte`. contorno na medida do
## Godot 4. Godot 3: sem LabelSettings — Compat.estilo_rotulo põe a fonte
## do tamanho, a cor e o contorno; a sombra é a do próprio Label.
func rotulo(texto: String, tam: float, cor := Color.white, contorno := 0.0, cor_contorno := MARINHO, f := "") -> Label:
	var l := Label.new()
	l.text = texto
	Compat.estilo_rotulo(l, f if f != "" else fonte, int(tam), cor, _contorno_g3(contorno), cor_contorno)
	l.set_meta("contorno", contorno)
	_sombra(l, SOMBRA, tam * 0.06)
	l.align = Label.ALIGN_CENTER
	l.valign = Label.VALIGN_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _contorno_g3(contorno: float) -> int:
	if contorno <= 0.0:
		return 0
	return Compat.imax(int(round(contorno * CONTORNO_G4_PARA_G3)), 1)


## Sombra do texto (Godot 4: shadow_color/shadow_offset; o shadow_size, o
## contorno da sombra, não existe no Godot 3: a sombra é só a letra
## deslocada). Só nos textos SEM contorno: com contorno, o Godot 3 desenharia
## o contorno de novo, deslocado e opaco (e no Godot 4 ela ficava quase toda
## escondida atrás do contorno). Sem `cor`/`dy`: mantém os de antes.
func _sombra(l: Label, cor = null, dy := -1.0) -> void:
	if not l.has_meta("sombra"):
		l.set_meta("sombra", [SOMBRA, 0.0])
	var s: Array = l.get_meta("sombra")
	if cor != null:
		s[0] = cor
	if dy >= 0.0:
		s[1] = dy
	var e: Array = l.get_meta("estilo")
	l.add_color_override("font_color_shadow", s[0] if int(e[3]) == 0 else Color(0, 0, 0, 0))
	l.add_constant_override("shadow_offset_x", 0)
	l.add_constant_override("shadow_offset_y", int(round(s[1])))


## Troca tamanho, contorno (medida do Godot 4) e/ou cor de um texto já
## criado (Godot 4: mexia direto no label_settings). < 0 / null = mantém.
## Uma chamada só por mudança: cada combinação é uma DynamicFont.
func _estilo(l: Label, tam := -1.0, contorno := -1.0, cor = null) -> void:
	var e: Array = l.get_meta("estilo")
	if contorno >= 0.0:
		l.set_meta("contorno", contorno)
	Compat.estilo_rotulo(l, e[0], e[1] if tam < 0.0 else int(tam), e[2] if cor == null else cor,
			e[3] if contorno < 0.0 else _contorno_g3(contorno), e[4])
	_sombra(l)


## Largura de um texto na fonte atual do rótulo (Godot 3: a DynamicFont já
## é do tamanho; get_string_size não recebe tamanho).
func _largura_texto(l: Label, texto: String) -> float:
	return l.get_font("font").get_string_size(texto).x


## Godot 3: o filtro (imagem suave ao esticar) é da textura, não do nó — e a
## textura de um Viewport (o 3D, a câmera) nasce sem filtro.
func _filtrar(tex: Texture) -> void:
	if tex != null and not (tex.flags & Texture.FLAG_FILTER):
		tex.flags = tex.flags | Texture.FLAG_FILTER


func caixa(cor: Color, raio := 28.0, borda := 0.0, cor_borda := Color.white, sombra := 10.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = cor
	s.set_corner_radius_all(int(raio))
	if borda > 0.0:
		s.set_border_width_all(int(borda))
		s.border_color = cor_borda
	s.shadow_size = int(sombra)
	s.shadow_color = Color(0.0, 0.05, 0.15, 0.35)
	s.shadow_offset = Vector2(0, sombra * 0.4)
	s.anti_aliasing = true
	return s


func painel(cor: Color, raio := 28.0, borda := 0.0, cor_borda := Color.white) -> Panel:
	var p := Panel.new()
	p.add_stylebox_override("panel", caixa(cor, raio, borda, cor_borda))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Novo tamanho de letra (e, com `contorno` >= 0, o contorno junto: no
## Godot 3 cada combinação é uma fonte). A sombra acompanha o tamanho.
func _tamanho_rotulo(l: Label, tam: float, contorno := -1.0) -> void:
	var s: Array = l.get_meta("sombra")
	s[1] = tam * 0.06
	_estilo(l, tam, contorno)


## Diminui a letra até o texto caber na largura (nunca estoura a placa).
## Godot 3: mede o texto uma vez (na fonte atual) e faz a conta para os
## outros tamanhos — medir em cada tamanho criaria uma fonte nova e
## desenharia as letras de cada um.
func _caber(l: Label, tam: float, largura: float) -> void:
	var e: Array = l.get_meta("estilo")
	var por_px: float = _largura_texto(l, l.text) / max(float(e[1]), 1.0)
	var margem: float = l.get_meta("contorno")
	var t := tam
	while t > 12.0 and por_px * int(t) + margem > largura:
		t *= 0.94
	_estilo(l, t)


## Textos ENORMES (o "1"/"2" dos cartões, a contagem da foto). Godot 3: uma
## letra de 280 px ficaria numa página de 4096 x 4096 (32 MB, mais a do
## contorno, mandada de novo à placa de vídeo a cada letra nova). A letra é
## desenhada em até FONTE_MAX px (x u) e esticada (rect_scale) até `area`
## (o canto de cima fica em area.position, como o rótulo do Godot 4).
func _rotulo_grande(l: Label, tam: float, contorno: float, area: Rect2) -> void:
	var k: float = max(tam / (FONTE_MAX * max(u, 1.0)), 1.0)
	_tamanho_rotulo(l, tam / k, contorno / k)
	l.rect_size = area.size / k
	l.rect_pivot_offset = l.rect_size / 2
	l.rect_position = area.position + l.rect_size * (k - 1.0) / 2
	l.rect_scale = Vector2.ONE * k
	l.set_meta("escala", k)


# ================================================================ placar
func _montar_placar() -> void:
	for i in 2:
		var cor := COR_BOB if i == 0 else COR_MIA
		var p := Painel3D.new(cor, 34, 12, 6)
		add_child(p)
		var av := TextureRect.new()
		av.expand = true
		av.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		av.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(av)
		var selo := TextureRect.new()
		selo.expand = true
		selo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		selo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		selo.visible = false
		p.add_child(selo)
		var nome := rotulo("", 34, Color.white, 8)
		nome.align = Label.ALIGN_LEFT
		p.add_child(nome)
		var pts := rotulo("0", 64, Color("#FFF6A8"), 12, MARINHO, fonte_titulo)
		pts.align = Label.ALIGN_RIGHT
		p.add_child(pts)
		var rod := HBoxContainer.new()
		rod.alignment = BoxContainer.ALIGN_BEGIN
		rod.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(rod)
		_cartoes.append({"painel": p, "avatar": av, "selo": selo, "nome": nome, "pontos": pts, "rodadas": rod, "cor": cor, "valor": 0.0, "alvo": 0})
	_info = rotulo("", 34, Color.white, 9)
	add_child(_info)
	_bolas_box = HBoxContainer.new()
	_bolas_box.alignment = BoxContainer.ALIGN_CENTER
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
			var cor := COR_BOB if p == "bob" else COR_MIA
			var ft: Texture = Fotos.foto("j%d" % i)
			c["foto"] = ft != null
			c["avatar"].texture = ft if ft != null else _retratos.get(p)
			c["avatar"].material = material_foto(Color.white) if ft != null else null
			c["selo"].texture = _retratos.get(p)
			c["selo"].visible = ft != null
			c["cor"] = cor
			(c["painel"] as Painel3D).pintar(cor)
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
			cel.rect_min_size = Vector2(46, 46) * u
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
			var atual: bool = (i == placar.jogador_atual and r == placar.rodada_atual)
			# Godot 3: raio 1 px menor que a metade (com borda e fundo transparente,
			# o raio = metade deixava um risco claro no meio da bolinha)
			cel.add_stylebox_override("panel", caixa(cor_cel, 23 * u - 1.0, 4 * u if atual else 0.0, DESTAQUE, 0))
			if txt != "":
				var l := rotulo(txt, 26 * u, MARINHO)
				l.set_anchors_and_margins_preset(Control.PRESET_WIDE)
				cel.add_child(l)
			elif cor_cel == Color("#FFD43B"):
				var e := TextureRect.new()
				e.texture = Materiais.textura("estrela_placar")
				e.expand = true
				e.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				e.set_anchors_and_margins_preset(Control.PRESET_WIDE)
				e.mouse_filter = Control.MOUSE_FILTER_IGNORE
				cel.add_child(e)
			rod.add_child(cel)
		var ativo: bool = i == placar.jogador_atual
		var painel_c: Control = c["painel"]
		painel_c.modulate = Color(1, 1, 1, 1) if ativo or placar.jogadores.size() == 1 else Color(0.78, 0.78, 0.85, 0.9)
		painel_c.rect_scale = Vector2.ONE * (1.0 if ativo else 0.94)
	_info.text = "RODADA %d de %d" % [placar.rodada_atual + 1, placar.rodadas]
	for b in _bolas_box.get_children():
		b.queue_free()
	for k in placar.tentativas:
		var bola := Panel.new()
		bola.rect_min_size = Vector2(34, 34) * u
		var usada: bool = k < placar.bola_atual
		bola.add_stylebox_override("panel", caixa(Color(1, 1, 1, 0.25) if usada else _cor_atual(placar), 17 * u - 1.0, 3 * u, Color.white, 4))
		bola.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bolas_box.add_child(bola)


func _cor_atual(placar: Placar) -> Color:
	return COR_BOB if placar.atual()["personagem"] == "bob" else COR_MIA


# ================================================================ mapa dos pinos
func _montar_mapa() -> void:
	_mapa = Painel3D.new(AZUL, 26, 8, 4)
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
		d.add_stylebox_override("panel", caixa(Color.white if de_pe else Color(1, 1, 1, 0.12), 99, 3 if de_pe else 0, DESTAQUE, 0))


# ================================================================ convite e toque
## Sem luzes nem setas na tela. No PC/tablet dá para tocar na tela: a
## posição do toque (5 faixas, da esquerda para a direita) vale como o sensor.
func _montar_toque() -> void:
	_toque = Control.new()
	_toque.mouse_filter = Control.MOUSE_FILTER_STOP
	_toque.connect("gui_input", self, "_ao_tocar")
	_toque.visible = false
	add_child(_toque)
	_aviso = rotulo("ROLE A BOLA!", 64, Color("#FFF6A8"), 16, MARINHO, fonte_titulo)
	add_child(_aviso)
	_aviso.visible = false
	_aviso_sub = rotulo("mire no STRIKE!", 40, Color.white, 10, MARINHO)
	add_child(_aviso_sub)
	_aviso_sub.visible = false
	_cenario = TextureRect.new()
	_cenario.expand = true
	_cenario.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cenario.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cenario.visible = false
	add_child(_cenario)
	_sequencia = rotulo("", 40, Color("#FFF6A8"), 10, Color("#7A1E00"), fonte_titulo)
	_sequencia.visible = false
	add_child(_sequencia)


signal toque_sensor(zona)


func _ao_tocar(ev: InputEvent) -> void:
	var pos := Vector2(-1, -1)
	if ev is InputEventMouseButton and ev.pressed:
		pos = ev.position
	elif ev is InputEventScreenTouch and ev.pressed:
		pos = ev.position
	if pos.x < 0.0:
		return
	var i := Compat.iclamp(int(pos.x / max(rect_size.x, 1.0) * 5.0), 0, 4)
	emit_signal("toque_sensor", ZONAS[i])


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
	var T := rect_size
	var w: float = min(T.x * 0.86, 900.0 * u)
	var h: float = w * float(tex.get_height()) / float(tex.get_width())
	_cenario.rect_size = Vector2(w, h)
	_cenario.rect_position = Vector2((T.x - w) / 2, T.y * (0.3 if retrato else 0.24) - h / 2)
	_cenario.rect_pivot_offset = _cenario.rect_size / 2
	_cenario.visible = true
	_cenario.rect_scale = Vector2.ZERO
	_cenario.rect_rotation = rad2deg(-0.5)
	_cenario.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_cenario, "rect_scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_cenario, "rect_rotation", 0.0, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(dur)
	tw.tween_property(_cenario, "rect_scale", Vector2.ONE * 1.25, 0.3)
	tw.parallel().tween_property(_cenario, "modulate:a", 0.0, 0.3)
	tw.tween_callback(_cenario, "hide")


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
	tr.expand = true
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var T := rect_size
	var larg: float = min(T.x * 0.9, tex.get_width() / ESCALA_ARTE * u * 0.95)
	var alt := larg * tex.get_height() / tex.get_width()
	tr.rect_size = Vector2(larg, alt)
	tr.rect_position = Vector2((T.x - larg) / 2, T.y * altura - alt / 2)
	tr.rect_pivot_offset = tr.rect_size / 2
	tr.rect_scale = Vector2.ZERO
	tr.rect_rotation = -12.0
	_centro.add_child(tr)
	var tw := create_tween()
	tw.tween_property(tr, "rect_scale", Vector2.ONE * 1.18, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(tr, "rect_rotation", 3.0, 0.22)
	tw.tween_property(tr, "rect_scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(tr, "rect_rotation", 0.0, 0.18)
	tw.tween_property(tr, "rect_scale", Vector2.ONE * 1.05, dur * 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(tr, "rect_position:y", tr.rect_position.y - 120 * u, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(tr, "modulate:a", 0.0, 0.3)
	tw.tween_callback(tr, "queue_free")
	_estrelas_2d(tr.rect_position + tr.rect_size / 2, 26)
	if sub != "":
		var l := rotulo(sub, 58 * u, Color.white, 14 * u, MARINHO, fonte_titulo)
		l.rect_size = Vector2(T.x, 90 * u)
		l.rect_position = Vector2(0, tr.rect_position.y + alt + 10 * u)
		l.rect_pivot_offset = l.rect_size / 2
		l.rect_scale = Vector2.ZERO
		_centro.add_child(l)
		var t2 := create_tween()
		t2.tween_interval(0.18)
		t2.tween_property(l, "rect_scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t2.tween_interval(dur * 0.55)
		t2.tween_property(l, "modulate:a", 0.0, 0.3)
		t2.tween_callback(l, "queue_free")


## Texto grande simples (ex.: "7 PINOS!").
func texto_grande(texto: String, cor := Color("#FFF6A8"), dur := 1.4, altura := 0.38) -> void:
	var T := rect_size
	var l := rotulo(texto, 110 * u, cor, 22 * u, MARINHO, fonte_titulo)
	l.rect_size = Vector2(T.x, 160 * u)
	l.rect_position = Vector2(0, T.y * altura - 80 * u)
	l.rect_pivot_offset = l.rect_size / 2
	l.rect_scale = Vector2.ZERO
	_centro.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "rect_scale", Vector2.ONE * 1.12, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "rect_scale", Vector2.ONE, 0.15)
	tw.tween_interval(dur)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l, "queue_free")


## "+120" voando até o placar do jogador.
func pontos_voando(pontos: int, jogador: int) -> void:
	if jogador >= _cartoes.size():
		return
	var c: Dictionary = _cartoes[jogador]
	var p: Control = c["painel"]
	var l := rotulo("+%d" % pontos, 84 * u, Color("#FFF6A8"), 18 * u, MARINHO, fonte_titulo)
	l.rect_size = Vector2(400, 120) * u
	l.rect_position = Vector2(rect_size.x / 2 - 200 * u, rect_size.y * 0.5)
	l.rect_pivot_offset = l.rect_size / 2
	_centro.add_child(l)
	var destino := p.rect_position + p.rect_size / 2 - l.rect_size / 2
	var tw := create_tween()
	tw.tween_property(l, "rect_scale", Vector2.ONE * 1.2, 0.15)
	tw.tween_interval(0.35)
	tw.tween_property(l, "rect_position", destino, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(l, "rect_scale", Vector2.ONE * 0.5, 0.55)
	tw.tween_callback(self, "_pontos_chegaram", [l, p])


## O "+120" chegou no placar: some e o placar pula (Godot 3: sem lambda).
func _pontos_chegaram(l: Label, p: Control) -> void:
	l.queue_free()
	_pular(p)


func _pular(no: Control) -> void:
	no.rect_pivot_offset = no.rect_size / 2
	var tw := create_tween()
	tw.tween_property(no, "rect_scale", Vector2.ONE * 1.08, 0.08)
	tw.tween_property(no, "rect_scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


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
	# Godot 3: valor + "_random" no lugar de _min/_max — velocidade 450..900,
	# giro -360..360 e tamanho 0,12..0,3 (o sorteio do tamanho vai na direção
	# de 1,0: a fração é a parte do caminho até 1,0)
	p.initial_velocity = 900 * u
	p.initial_velocity_random = 0.5
	p.gravity = Vector2(0, 900 * u)
	p.angular_velocity = 360
	p.angular_velocity_random = 1.0
	p.scale_amount = 0.12 * u
	p.scale_amount_random = (0.3 * u - 0.12 * u) / max(1.0 - 0.12 * u, 0.01)
	if _estrelas_cor == null:
		_estrelas_cor = Gradient.new()
		_estrelas_cor.set_color(0, Color("#FFE14D"))
		_estrelas_cor.set_color(1, Color("#FF9F2E"))
		_estrelas_cor.add_point(0.5, Color("#7FE7FF"))
	p.color_initial_ramp = _estrelas_cor
	_centro.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.6).connect("timeout", p, "queue_free")


var _estrelas_cor: Gradient


func flash(cor := Color.white, forca := 0.7, dur := 0.35) -> void:
	_flash.color = Color(cor.r, cor.g, cor.b, forca)
	_flash.visible = true
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, dur)
	tw.tween_callback(_flash, "hide")


# ================================================================ faixa "VEZ DE"
func _montar_faixa() -> void:
	_faixa = Painel3D.new(COR_BOB, 40, 14, 7)
	_faixa.visible = false
	add_child(_faixa)
	_faixa_avatar = TextureRect.new()
	_faixa_avatar.expand = true
	_faixa_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_faixa_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_faixa.add_child(_faixa_avatar)
	_faixa_texto = rotulo("", 76, Color.white, 16, MARINHO, fonte_titulo)
	_faixa.add_child(_faixa_texto)


func faixa(personagem: String, texto: String, sub := "", foto: Texture = null) -> void:
	var cor := COR_BOB if personagem == "bob" else COR_MIA
	_faixa.pintar(cor)
	_faixa_avatar.texture = foto if foto != null else _retratos.get(personagem)
	_faixa_avatar.material = material_foto(Color.white) if foto != null else null
	_faixa_texto.text = texto + ("\n" + sub if sub != "" else "")
	var T := rect_size
	var h := 210 * u
	var w: float = min(T.x * 0.92, 980 * u)
	_faixa.rect_size = Vector2(w, h)
	if foto != null:
		_faixa_avatar.rect_size = Vector2(h * 1.05, h * 1.05)
		_faixa_avatar.rect_position = Vector2(-h * 0.05, -h * 0.12)
	else:
		_faixa_avatar.rect_size = Vector2(h * 1.25, h * 1.25)
		_faixa_avatar.rect_position = Vector2(-h * 0.15, -h * 0.35)
	_faixa_texto.rect_size = Vector2(w - h * 1.1, h)
	_faixa_texto.rect_position = Vector2(h * 1.05, 0)
	_tamanho_rotulo(_faixa_texto, (70 if sub == "" else 58) * u, 16 * u)
	var y := T.y * (0.3 if retrato else 0.36)
	_faixa.rect_position = Vector2(-w - 50 * u, y)
	_faixa.visible = true
	var tw := create_tween()
	tw.tween_property(_faixa, "rect_position:x", (T.x - w) / 2, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.25)
	tw.tween_property(_faixa, "rect_position:x", T.x + 50 * u, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(_faixa, "hide")


# ================================================================ replay
func _montar_replay() -> void:
	_tarja_cima = ColorRect.new()
	_tarja_baixo = ColorRect.new()
	for t in [_tarja_cima, _tarja_baixo]:
		t.color = Color(0.01, 0.03, 0.09, 1)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(t)
	_replay = TextureRect.new()
	_replay.texture = Materiais.textura("replay")
	_replay.expand = true
	_replay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_replay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_replay.visible = false
	add_child(_replay)
	_replay_ponto = painel(Color("#FF2E4D"), 99)
	_replay_ponto.visible = false
	add_child(_replay_ponto)


## Faixas pretas de cinema (abertura), sem o selo de replay.
func tarjas(ligado: bool) -> void:
	var T := rect_size
	var h := T.y * (0.09 if retrato else 0.1) if ligado else 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_tarja_cima, "rect_size:y", h, 0.4).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_tarja_baixo, "rect_size:y", h, 0.4).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_tarja_baixo, "rect_position:y", T.y - h, 0.4).set_trans(Tween.TRANS_QUAD)


func modo_replay(ligado: bool) -> void:
	var T := rect_size
	var h := T.y * (0.1 if retrato else 0.12) if ligado else 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_tarja_cima, "rect_size:y", h, 0.35).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_tarja_baixo, "rect_size:y", h, 0.35).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_tarja_baixo, "rect_position:y", T.y - h, 0.35).set_trans(Tween.TRANS_QUAD)
	_replay.visible = ligado
	_replay_ponto.visible = ligado
	# na demonstração (tela inicial) o logo grande sai da frente do selo REPLAY
	create_tween().tween_property(_logo, "modulate:a", 0.0 if ligado else 1.0, 0.3)
	var w := 420 * u
	_replay.rect_size = Vector2(w, w * 0.236)
	_replay.rect_position = Vector2(T.x - w - 40 * u, T.y * (0.1 if retrato else 0.12) * 0.5 - w * 0.118)
	_replay_ponto.rect_size = Vector2(34, 34) * u
	_replay_ponto.rect_position = _replay.rect_position + Vector2(-50 * u, w * 0.118 - 17 * u)
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
	_logo.expand = true
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_atracao.add_child(_logo)
	# botão amarelo com volume
	_aperte_botao = Painel3D.new(DESTAQUE, 70, 18, 8)
	_atracao.add_child(_aperte_botao)
	_aperte = rotulo("APERTE START", 88, MARINHO, 0, MARINHO, fonte_titulo)
	_sombra(_aperte, Color(1, 1, 1, 0.55))
	_aperte_botao.add_child(_aperte)
	# placa do recorde
	_recorde_placa = Painel3D.new(AZUL, 40, 10, 5)
	_atracao.add_child(_recorde_placa)
	_recorde = rotulo("", 40, CREME, 8)
	_recorde.align = Label.ALIGN_LEFT
	_recorde_placa.add_child(_recorde)
	_rec_foto = TextureRect.new()
	_rec_foto.expand = true
	_rec_foto.stretch_mode = TextureRect.STRETCH_SCALE
	_rec_foto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rec_foto.material = material_foto(DESTAQUE)
	_rec_foto.visible = false
	_recorde_placa.add_child(_rec_foto)
	_creditos = rotulo("", 30, Color.white, 8)
	_atracao.add_child(_creditos)
	_atracao.visible = false


func atracao(ligado: bool, recorde := "", creditos := "", foto_recorde: Texture = null, melhores := []) -> void:
	_atracao.visible = ligado
	_melhores_hoje = melhores
	# o quadro dos melhores só é montado de novo quando muda (montar a cada
	# volta da demonstração dava um tranco na TV Box)
	var chave := "%s|%s|%s|%s" % [str(melhores), recorde, str(rect_size), str(retrato)]
	if chave != _chave_melhores or (_melhores == null and not melhores.empty()):
		_chave_melhores = chave
		_montar_melhores(melhores, recorde)
	if not melhores.empty():
		recorde = ""
	_recorde.text = recorde
	_creditos.text = creditos
	_rec_foto.texture = foto_recorde
	_rec_foto.visible = foto_recorde != null and recorde != ""
	_recorde_placa.visible = recorde != ""
	if recorde != "":
		var larg := _largura_texto(_recorde, recorde)
		var h := 100 * u
		var d := 124 * u
		var foto_l := d * 0.82 if _rec_foto.visible else 0.0
		var w: float = min(larg + foto_l + 80 * u, rect_size.x * 0.94)
		_recorde_placa.rect_size = Vector2(w, h)
		var cx := _aperte_botao.rect_position.x + _aperte_botao.rect_size.x / 2
		_recorde_placa.rect_position = Vector2(clamp(cx - w / 2, 16 * u, rect_size.x - w - 16 * u), _aperte_botao.rect_position.y + _aperte_botao.rect_size.y + 34 * u)
		_recorde.rect_size = Vector2(w - foto_l - 50 * u, h - 10 * u)
		_recorde.rect_position = Vector2(foto_l + 30 * u, 0)
		_rec_foto.rect_size = Vector2(d, d)
		_rec_foto.rect_position = Vector2(-d * 0.3, (h - d) / 2 - 6 * u)
	if ligado:
		mostrar_placar(false)
		mostrar_sensores(false)


## "MELHORES DE HOJE" na atração: os 3 primeiros do dia, com a foto de
## cada um (chama a criançada: "olha eu ali!").
var _melhores: Control
var _melhores_hoje := []
var _chave_melhores := ""


func _montar_melhores(lista: Array, recorde: String) -> void:
	if _melhores != null:
		_melhores.queue_free()
		_melhores = null
	if lista.empty():
		return
	var T := rect_size
	var d := 150 * u
	var gap := 34 * u
	var w := lista.size() * d + (lista.size() - 1) * gap + 80 * u
	var cab_h := 70 * u
	var h := cab_h + d + 96 * u
	w = max(w, 560 * u)
	var p := Painel3D.new(Color("#0E2A5C"), 40, 14, 7)
	p.rect_size = Vector2(w, h)
	if retrato:
		var y := _aperte_botao.rect_position.y + _aperte_botao.rect_size.y + 34 * u
		p.rect_position = Vector2((T.x - w) / 2, min(y, T.y - h - 110 * u))
	else:
		p.rect_position = Vector2(T.x - w - 40 * u, T.y * 0.06)
	_atracao.add_child(p)
	_melhores = p
	var cab_txt := "MELHORES DE HOJE"
	var cab := rotulo(cab_txt, 42 * u, CREME, 10 * u, MARINHO, fonte_titulo)
	cab.rect_size = Vector2(w, cab_h)
	p.add_child(cab)
	_caber(cab, 42 * u, w - 40 * u)
	var x0 := (w - (lista.size() * d + (lista.size() - 1) * gap)) / 2
	for k in lista.size():
		var e: Dictionary = lista[k]
		var fr := TextureRect.new()
		var ft: Texture = Fotos.carregar(str(e.get("foto", "")))
		fr.texture = ft if ft != null else _retratos.get(str(e.get("personagem", "bob")))
		fr.expand = true
		fr.stretch_mode = TextureRect.STRETCH_SCALE
		fr.material = material_foto(_cor_medalha(k + 1))
		fr.rect_size = Vector2(d, d)
		fr.rect_position = Vector2(x0 + k * (d + gap), cab_h)
		p.add_child(fr)
		var md := 54 * u
		var med := Painel3D.new(_cor_medalha(k + 1), md / 2.0 / u, 5, 4)
		med.rect_size = Vector2(md, md)
		med.rect_position = fr.rect_position + Vector2(-md * 0.2, -md * 0.15)
		p.add_child(med)
		var ln := rotulo(str(k + 1), md * 0.56, MARINHO, 0, MARINHO, fonte_titulo)
		ln.rect_size = Vector2(md, md - 4 * u)
		med.add_child(ln)
		var lp := rotulo("%d" % int(e.get("pontos", 0)), 46 * u, Color.white, 10 * u, MARINHO, fonte_titulo)
		lp.rect_size = Vector2(d + gap, 60 * u)
		lp.rect_position = Vector2(fr.rect_position.x - gap / 2, cab_h + d + 8 * u)
		p.add_child(lp)


# ================================================================ etapas
## Faixa "1 JOGADORES › 2 AMIGO › 3 FOTO › 4 JOGAR" no alto das telas de
## preparação: a criança (e o pai) sabem em que passo estão.
const ETAPAS := ["JOGADORES", "AMIGO", "FOTO", "JOGAR"]
var _etapas: Control
var _etapas_pilulas: Array = []   # Painel3D


func _montar_etapas() -> void:
	_etapas = Control.new()
	_etapas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_etapas.visible = false
	add_child(_etapas)
	for i in ETAPAS.size():
		var p := Painel3D.new(AZUL, 30, 7, 4)
		_etapas.add_child(p)
		var l := rotulo("%d  %s" % [i + 1, ETAPAS[i]], 30, Color.white, 7, MARINHO)
		l.name = "texto"
		p.add_child(l)
		_etapas_pilulas.append(p)


## n = passo atual (1..4); 0 esconde. pulos: passos que não acontecem nesta
## partida (ex.: AMIGO com 2 jogadores) aparecem como feitos.
func etapa(n: int) -> void:
	_etapas.visible = n > 0
	for i in _etapas_pilulas.size():
		var p: Painel3D = _etapas_pilulas[i]
		var passo: int = i + 1
		var texto := p.get_node("texto") as Label
		if passo == n:
			p.pintar(DESTAQUE)
			p.modulate = Color.white
			_estilo(texto, -1.0, 0.0, MARINHO)
		elif passo < n:
			p.pintar(Color("#2DBE4E"))
			p.modulate = Color(1, 1, 1, 0.9)
			_estilo(texto, -1.0, 7 * u, Color.white)
		else:
			p.pintar(AZUL)
			p.modulate = Color(1, 1, 1, 0.75)
			_estilo(texto, -1.0, 7 * u, Color.white)


func _layout_etapas(T: Vector2) -> void:
	var gap := 12 * u
	var w: float = min((T.x - 40 * u - gap * 3) / 4.0, 250 * u)
	var h := 66 * u
	var x0 := (T.x - (w * 4 + gap * 3)) / 2
	for i in _etapas_pilulas.size():
		var p: Painel3D = _etapas_pilulas[i]
		p.rect_size = Vector2(w, h)
		p.rect_position = Vector2(x0 + i * (w + gap), 24 * u)
		var l := p.get_node("texto") as Label
		l.rect_size = Vector2(w, h - 8 * u)
		l.rect_position = Vector2.ZERO
		_caber(l, 30 * u, w - 20 * u)


## Os 5 sensores da máquina em miniatura (da esquerda para a direita),
## cada um com a cor do que ele faz nesta tela.
func _sensores(cores: Array, legendas: Array) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 5:
		var b := Panel.new()
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_stylebox_override("panel", caixa(cores[i], 99, 4, Color.white, 4))
		b.name = "s%d" % i
		c.add_child(b)
	for i in legendas.size():
		var l := rotulo(str(legendas[i][0]), 28, Color.white, 7, MARINHO)
		l.name = "l%d" % i
		l.set_meta("de", legendas[i][1])
		l.set_meta("ate", legendas[i][2])
		c.add_child(l)
	return c


func _layout_sensores(c: Control, largura: float) -> void:
	var d := 40 * u
	var passo: float = min(largura / 5.0, 76 * u)
	var x0 := (largura - passo * 4 - d) / 2
	for i in 5:
		var b := c.get_node("s%d" % i) as Panel
		b.rect_size = Vector2(d, d)
		b.rect_position = Vector2(x0 + i * passo, 0)
	for l in c.get_children():
		if l is Label:
			var de: int = l.get_meta("de")
			var ate: int = l.get_meta("ate")
			var xa := x0 + de * passo
			var xb := x0 + ate * passo + d
			_tamanho_rotulo(l, 26 * u, 7 * u)
			l.rect_size = Vector2(max(xb - xa, 120 * u), 36 * u)
			l.rect_position = Vector2((xa + xb) / 2 - l.rect_size.x / 2, d + 4 * u)
	c.rect_size = Vector2(largura, d + 44 * u)


# ================================================================ quantos vão jogar
## Igual ao Dragon Bowling (mesma máquina): START 1 vez = 1 jogador;
## START de novo (dentro do tempo) = 2 jogadores. A tela mostra isso com o
## botão START desenhado em cada cartão e a contagem para começar.
func _montar_jogadores() -> void:
	_jog = Control.new()
	_jog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_jog.visible = false
	add_child(_jog)
	# véu escuro por cima do 3D (que fica parado enquanto o modal está
	# aberto: principal.gd, _congelar_3d)
	_jog_veu = ColorRect.new()
	_jog_veu.color = Color(0.02, 0.05, 0.14, 0.42)
	_jog_veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_jog.add_child(_jog_veu)
	_jog_painel = Painel3D.new(AZUL, 50, 18, 8)
	_jog.add_child(_jog_painel)
	_jog_titulo = rotulo("QUANTOS VÃO JOGAR?", 70, CREME, 16, MARINHO, fonte_titulo)
	_jog_painel.add_child(_jog_titulo)
	for i in 2:
		var c := Painel3D.new(Color("#F2F7FF"), 40, 16, 6)
		_jog_painel.add_child(c)
		var num := rotulo(str(i + 1), 170, COR_BOB if i == 0 else COR_MIA, 22, MARINHO, fonte_titulo)
		num.name = "num"
		c.add_child(num)
		var leg := rotulo("JOGADOR" if i == 0 else "JOGADORES", 46, MARINHO, 0, MARINHO, fonte_titulo)
		leg.name = "leg"
		c.add_child(leg)
		for k in 2:
			var r := TextureRect.new()
			r.texture = _retratos["bob" if k == 0 else "mia"]
			r.expand = true
			r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			r.name = "retrato_%d" % k
			c.add_child(r)
		var mei := rotulo("ou" if i == 0 else "x", 40, MARINHO, 0, MARINHO, fonte_titulo)
		mei.name = "meio"
		c.add_child(mei)
		# como escolher: o botão START desenhado + quantas vezes
		var bt := Painel3D.new(Color("#E8384F"), 26, 7, 4)
		bt.name = "botao"
		c.add_child(bt)
		var bl := rotulo("START", 34, Color.white, 8, MARINHO, fonte_titulo)
		bl.name = "texto"
		bt.add_child(bl)
		var vezes := rotulo("1 VEZ" if i == 0 else "2 VEZES", 40, MARINHO, 0, MARINHO, fonte_titulo)
		vezes.align = Label.ALIGN_LEFT
		vezes.name = "vezes"
		c.add_child(vezes)
		_jog_cartoes.append(c)
	_jog_dica = rotulo("", 36, Color.white, 9)
	_jog_painel.add_child(_jog_dica)
	_jog_trilho = Painel3D.new(MARINHO.lightened(0.08), 17, 3, 3)
	_jog_trilho.sombra(0.0)
	_jog_painel.add_child(_jog_trilho)
	_jog_barra = Painel3D.new(DESTAQUE, 17, 5, 3)
	_jog_barra.sombra(0.0)
	_jog_trilho.add_child(_jog_barra)


## Tela "QUANTOS VÃO JOGAR?": dois cartões (1 ou 2), o escolhido brilha.
## fracao: tempo que falta (1 → 0); segundos: para a contagem escrita.
func jogadores(ligado: bool, n := 1, fracao := 0.0, segundos := 0) -> void:
	if ligado and not _jog.visible:
		_jog_painel.rect_pivot_offset = _jog_painel.rect_size / 2
		_jog_painel.rect_scale = Vector2.ONE * 0.75
		create_tween().tween_property(_jog_painel, "rect_scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_jog.visible = ligado
	if not ligado:
		return
	if n != _jog_n:
		_pular(_jog_cartoes[n - 1])
	_jog_n = n
	if n == 1:
		_jog_dica.text = "Vão jogar em 2? Aperte START de novo agora!\nSe não, começa com 1 jogador em %d..." % Compat.imax(segundos, 1)
	else:
		_jog_dica.text = "2 JOGADORES: BOB x MIA!\nPreparem-se..."
	_jog_barra.rect_size.x = max(_jog_trilho.rect_size.x * clamp(fracao, 0.0, 1.0), _jog_trilho.rect_size.y)
	_jog_barra.visible = fracao > 0.0
	for i in 2:
		var c: Painel3D = _jog_cartoes[i]
		c.modulate = Color.white if i == n - 1 else Color(0.78, 0.82, 0.9, 0.9)
		if i != n - 1:
			c.realcar(0.0)


func _layout_jogadores(T: Vector2) -> void:
	_jog_veu.rect_position = Vector2.ZERO
	_jog_veu.rect_size = T
	var mw: float = min(T.x * 0.92, 980 * u)
	var mh := 830 * u
	_jog_painel.rect_size = Vector2(mw, mh)
	_jog_painel.rect_position = (T - _jog_painel.rect_size) / 2 + Vector2(0, (50 if retrato else 30) * u)
	_jog_painel.rect_pivot_offset = _jog_painel.rect_size / 2
	_tamanho_rotulo(_jog_titulo, 70 * u, 16 * u)
	_jog_titulo.rect_size = Vector2(mw, 120 * u)
	_jog_titulo.rect_position = Vector2(0, 22 * u)
	_caber(_jog_titulo, 70 * u, mw - 60 * u)
	var gap := 36 * u
	var cw := (mw - gap * 3) / 2
	var ch := 470 * u
	for i in 2:
		var c: Painel3D = _jog_cartoes[i]
		c.rect_size = Vector2(cw, ch)
		c.rect_position = Vector2(gap + i * (cw + gap), 150 * u)
		c.rect_pivot_offset = c.rect_size / 2
		# o número enorme: desenhado menor e esticado (ver _rotulo_grande)
		_rotulo_grande(c.get_node("num") as Label, 170 * u, 22 * u, Rect2(0, 0, cw, 180 * u))
		var leg := c.get_node("leg") as Label
		_tamanho_rotulo(leg, 44 * u)
		leg.rect_size = Vector2(cw, 56 * u)
		leg.rect_position = Vector2(0, 172 * u)
		_caber(leg, 44 * u, cw - 30 * u)
		var rs := 112 * u
		for k in 2:
			var r := c.get_node("retrato_%d" % k) as TextureRect
			r.rect_size = Vector2(rs, rs)
			r.rect_position = Vector2(cw / 2 + (-rs - 20 * u if k == 0 else 20 * u), 232 * u)
		var mei := c.get_node("meio") as Label
		_tamanho_rotulo(mei, 38 * u)
		mei.rect_size = Vector2(cw, rs)
		mei.rect_position = Vector2(0, 232 * u)
		# botão START + "1 VEZ"/"2 VEZES", centralizados
		var bt := c.get_node("botao") as Painel3D
		var vezes := c.get_node("vezes") as Label
		var bw := 150 * u
		var bh := 60 * u
		_tamanho_rotulo(vezes, 38 * u)
		var vw := _largura_texto(vezes, vezes.text)
		var total := bw + 14 * u + vw
		var x0 := (cw - total) / 2
		bt.rect_size = Vector2(bw, bh)
		bt.rect_position = Vector2(x0, 372 * u)
		var bl := bt.get_node("texto") as Label
		_tamanho_rotulo(bl, 32 * u, 7 * u)
		bl.rect_size = Vector2(bw, bh - 7 * u)
		bl.rect_position = Vector2.ZERO
		vezes.rect_size = Vector2(vw + 10 * u, bh)
		vezes.rect_position = Vector2(x0 + bw + 14 * u, 372 * u - 4 * u)
	_tamanho_rotulo(_jog_dica, 34 * u, 9 * u)
	_jog_dica.rect_size = Vector2(mw - 40 * u, 100 * u)
	_jog_dica.rect_position = Vector2(20 * u, 636 * u)
	_jog_dica.autowrap = false
	_jog_trilho.rect_size = Vector2(mw - 140 * u, 34 * u)
	_jog_trilho.rect_position = Vector2(70 * u, 752 * u)
	_jog_barra.rect_size = Vector2(_jog_barra.rect_size.x, 34 * u)
	_jog_barra.rect_position = Vector2.ZERO


# ================================================================ escolha do personagem
func _montar_selecao() -> void:
	_selecao = Control.new()
	_selecao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selecao.visible = false
	add_child(_selecao)
	_sel_titulo = Painel3D.new(AZUL, 44, 14, 7)
	_selecao.add_child(_sel_titulo)
	var t := rotulo("ESCOLHA SEU AMIGO!", 76, CREME, 16, MARINHO, fonte_titulo)
	t.name = "titulo"
	_sel_titulo.add_child(t)
	for i in 2:
		var placa := Painel3D.new(COR_BOB if i == 0 else COR_MIA, 36, 14, 7)
		_selecao.add_child(placa)
		var l := rotulo("BOB" if i == 0 else "MIA", 70, Color.white, 16, MARINHO, fonte_titulo)
		placa.add_child(l)
		_sel_placas.append(placa)
		_sel_nomes.append(l)
	_sel_dica = Painel3D.new(MARINHO.lightened(0.12), 30, 8, 5)
	_sel_dica.modulate.a = 0.94
	_selecao.add_child(_sel_dica)
	_sel_texto = rotulo("", 36, Color.white, 9)
	_sel_dica.add_child(_sel_texto)
	# os 5 sensores: esquerda = Bob, meio = confirma, direita = Mia
	_sel_sensores = _sensores([COR_BOB, COR_BOB, DESTAQUE, COR_MIA, COR_MIA],
		[["BOB", 0, 1], ["OK", 2, 2], ["MIA", 3, 4]])
	_sel_dica.add_child(_sel_sensores)


## pes: onde ficam os pés de Bob e Mia na tela (a placa fica logo abaixo).
func selecao(ligado: bool, destaque := 0, texto := "", pes: Array = []) -> void:
	var entrou := ligado and not _selecao.visible
	_selecao.visible = ligado
	_sel_texto.text = texto
	if not ligado:
		return
	if entrou:
		_pular(_sel_titulo)
	if destaque != _sel_destaque:
		_pular(_sel_placas[destaque])
	_sel_destaque = destaque
	for i in 2:
		var p: Painel3D = _sel_placas[i]
		if pes.size() == 2:
			var pe: Vector2 = pes[i]
			p.rect_position = Vector2(clamp(pe.x - p.rect_size.x / 2, 12 * u, rect_size.x - p.rect_size.x - 12 * u), pe.y + 30 * u)
		p.rect_pivot_offset = p.rect_size / 2
		var alvo := 1.12 if i == destaque else 0.9
		p.rect_scale = p.rect_scale.linear_interpolate(Vector2.ONE * alvo, 0.25)
		p.modulate = Color.white if i == destaque else Color(0.8, 0.84, 0.92, 0.85)
		if i != destaque:
			p.realcar(0.0)


# ================================================================ fim de jogo
## dados: {jogadores: [{personagem, pontos, estrelas, strikes, spares}], vencedor, recorde: bool, recorde_valor}
## FIM DE JOGO + CLASSIFICAÇÃO: o cartão de cada jogador com a FOTO grande
## dele (ou o mascote), pontos, estrelas e a posição no dia; embaixo (em
## pé) ou ao lado (deitada) o quadro "CLASSIFICAÇÃO DE HOJE" com a foto de
## cada um — quem acabou de jogar aparece brilhando, com "VOCÊ!".
func tela_fim(ligado: bool, dados := {}) -> void:
	for f in _fim.get_children():
		f.queue_free()
	_fim.visible = ligado
	_fim_vez += 1
	if not ligado:
		return
	var vez := _fim_vez
	mostrar_placar(false)
	mostrar_sensores(false)
	var T := rect_size
	var bh := 116 * u
	var y_botao := T.y - bh - (110 if retrato else 34) * u
	var titulo := TextureRect.new()
	titulo.texture = Materiais.textura("fim_de_jogo")
	titulo.expand = true
	titulo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tw_l: float = min(T.x * 0.42, 440 * u) if retrato else 340 * u
	titulo.rect_size = Vector2(tw_l, tw_l * 0.61)
	titulo.rect_position = Vector2((T.x - tw_l) / 2, (40 if retrato else 14) * u)
	titulo.rect_pivot_offset = titulo.rect_size / 2
	titulo.rect_scale = Vector2.ZERO
	_fim.add_child(titulo)
	create_tween().tween_property(titulo, "rect_scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var y0 := titulo.rect_position.y + titulo.rect_size.y + 6 * u
	var area_c: Rect2
	var area_q: Rect2
	if retrato:
		area_c = Rect2(36 * u, y0, T.x - 72 * u, 590 * u)
		area_q = Rect2(36 * u, y0 + 620 * u, T.x - 72 * u, y_botao - (y0 + 620 * u) - 26 * u)
	else:
		var meio := T.x * 0.5
		area_c = Rect2(30 * u, y0, meio - 50 * u, y_botao - y0 - 20 * u)
		area_q = Rect2(meio + 20 * u, y0, meio - 50 * u, y_botao - y0 - 20 * u)
	var js: Array = dados.get("jogadores", [])
	for i in js.size():
		_cartao_fim(js[i], i, js.size(), area_c, dados.get("vencedor", -9) == i and js.size() > 1)
	_quadro_classificacao(dados.get("classificacao", []), js, area_q)
	# (só se ainda for este fim de jogo: com START logo, a partida nova já começou)
	if dados.get("vencedor", -9) == -1 and js.size() > 1:
		_atrasado(3.0, "_letreiro_do_fim", [vez, "empate", "", 2.5, 0.55])
	if dados.get("recorde", false):
		_atrasado(3.4, "_letreiro_do_fim", [vez, "novo_recorde", "%d PONTOS" % dados.get("recorde_valor", 0), 3.0, 0.42 if retrato else 0.3])
	# botão "jogar de novo"
	var bw: float = min(T.x * 0.92, 940 * u)
	var botao := Painel3D.new(DESTAQUE, 58, 14, 7)
	botao.rect_size = Vector2(bw, bh)
	botao.rect_position = Vector2((T.x - bw) / 2, y_botao)
	botao.name = "botao"
	_fim.add_child(botao)
	var ap := rotulo("APERTE START PARA JOGAR DE NOVO", 44 * u, MARINHO, 0, MARINHO, fonte_titulo)
	_sombra(ap, Color(1, 1, 1, 0.55))
	ap.rect_size = Vector2(bw, bh - 14 * u)
	ap.name = "aperte"
	botao.add_child(ap)
	_caber(ap, 44 * u, bw - 70 * u)


## Letreiro atrasado do fim de jogo (Godot 3: sem lambda): só se ainda for
## o mesmo fim de jogo.
func _letreiro_do_fim(vez: int, nome: String, sub: String, dur: float, altura: float) -> void:
	if vez == _fim_vez:
		letreiro(nome, sub, dur, altura)


## Cartão de um jogador: foto grande em cima, nome, pontos, estrelas e o
## lugar na classificação do dia.
func _cartao_fim(j: Dictionary, i: int, n: int, area: Rect2, venceu: bool) -> void:
	var cor := COR_BOB if j["personagem"] == "bob" else COR_MIA
	var gap := 26 * u
	var w: float = min((area.size.x - gap * (n - 1)) / n, 620 * u)
	var d: float = min(w * (0.5 if n == 1 else 0.56), 250 * u)
	var h: float = min(area.size.y - d * 0.42, 472 * u)
	var x := area.position.x + (area.size.x - (w * n + gap * (n - 1))) / 2 + i * (w + gap)
	var y := area.position.y + d * 0.42
	var c := Painel3D.new(cor, 44, 18, 8)
	c.rect_size = Vector2(w, h)
	c.rect_position = Vector2(x, y + 900 * u)
	_fim.add_child(c)
	var tw := create_tween()
	tw.tween_interval(0.3 + i * 0.2)
	tw.tween_property(c, "rect_position:y", y, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# foto (da câmera; sem câmera, o mascote)
	var ft: Texture = j.get("foto")
	var fr := TextureRect.new()
	fr.texture = ft if ft != null else _retratos.get(j["personagem"])
	fr.expand = true
	fr.stretch_mode = TextureRect.STRETCH_SCALE
	fr.material = material_foto(DESTAQUE if venceu else Color.white)
	fr.rect_size = Vector2(d, d)
	fr.rect_position = Vector2((w - d) / 2, -d * 0.42)
	fr.rect_pivot_offset = fr.rect_size / 2
	c.add_child(fr)
	if ft != null:
		# o mascote com quem jogou, no cantinho da foto
		var selo := TextureRect.new()
		selo.texture = _retratos.get(j["personagem"])
		selo.expand = true
		selo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		selo.rect_size = Vector2(d, d) * 0.4
		selo.rect_position = fr.rect_position + Vector2(d * 0.7, d * 0.62)
		c.add_child(selo)
	var yy := d * 0.6
	var nome := rotulo(str(j["personagem"]).to_upper(), 46 * u, Color.white, 10 * u, MARINHO, fonte_titulo)
	nome.rect_size = Vector2(w, 58 * u)
	nome.rect_position = Vector2(0, yy)
	c.add_child(nome)
	var pts := rotulo("0", 96 * u, CREME, 20 * u, MARINHO, fonte_titulo)
	pts.rect_size = Vector2(w, 100 * u)
	pts.rect_position = Vector2(0, yy + 44 * u)
	c.add_child(pts)
	var alvo := int(j["pontos"])
	# (a contagem é do próprio texto: some junto com ele)
	var tw2 := pts.create_tween()
	tw2.tween_interval(0.8 + i * 0.2)
	tw2.tween_method(self, "_contar_pontos", 0.0, float(alvo), 1.4, [pts]).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var leg := rotulo("PONTOS", 30 * u, Color.white, 7 * u)
	leg.rect_size = Vector2(w, 34 * u)
	leg.rect_position = Vector2(0, yy + 136 * u)
	c.add_child(leg)
	var ne := int(j.get("estrelas", 1))
	for k in 3:
		var e := TextureRect.new()
		e.texture = Materiais.textura("estrela_placar" if k < ne else "estrela_vazia")
		e.expand = true
		e.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var es: float = 64 * u if k == 1 else 54 * u
		e.rect_size = Vector2(es, es)
		e.rect_position = Vector2(w / 2 - es / 2 + (k - 1) * 72 * u, yy + 176 * u - (6 * u if k == 1 else 0.0))
		e.rect_pivot_offset = e.rect_size / 2
		e.rect_scale = Vector2.ZERO
		c.add_child(e)
		var tw3 := create_tween()
		tw3.tween_interval(2.2 + k * 0.25 + i * 0.1)
		tw3.tween_property(e, "rect_scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# lugar no dia (e quem venceu a partida de 2)
	var pos := int(j.get("posicao", 0))
	if pos > 0 or venceu:
		var fita_h := 58 * u
		var fita := Painel3D.new(DESTAQUE if venceu else _cor_medalha(pos), 28, 8, 5)
		fita.rect_size = Vector2(w * 0.88, fita_h)
		fita.rect_position = Vector2(w * 0.06, h - fita_h - 16 * u)
		c.add_child(fita)
		var txt := "%dº LUGAR HOJE!" % pos if pos <= 3 else "%dº LUGAR HOJE" % pos
		if venceu:
			txt = "VENCEU!  %dº HOJE" % pos if pos > 0 else "VENCEU!"
			pos = Compat.imin(pos, 3) if pos > 0 else 1
		var lf := rotulo(txt, 34 * u, MARINHO if pos <= 3 else Color.white, 0 if pos <= 3 else 7 * u, MARINHO, fonte_titulo)
		lf.rect_size = Vector2(w * 0.86, fita_h - 6 * u)
		fita.add_child(lf)
		_caber(lf, 34 * u, w * 0.8)
		fita.rect_pivot_offset = fita.rect_size / 2
		fita.rect_scale = Vector2.ZERO
		var tw5 := create_tween()
		tw5.tween_interval(2.8 + i * 0.15)
		tw5.tween_property(fita, "rect_scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if venceu:
		c.realcar(0.55)


## Os pontos do cartão contando (Godot 3: sem lambda no tween_method).
func _contar_pontos(v: float, rotulo_pontos: Label) -> void:
	rotulo_pontos.text = str(int(v))


func _cor_medalha(pos: int) -> Color:
	match pos:
		1:
			return Color("#FFC21A")
		2:
			return Color("#DCE6F2")
		3:
			return Color("#F0A25A")
	return AZUL


## Quadro "CLASSIFICAÇÃO DE HOJE": os 5 primeiros do dia, cada um com a sua
## foto; quem jogou agora e ficou mais para trás aparece numa linha a mais.
func _quadro_classificacao(lista: Array, js: Array, area: Rect2) -> void:
	if area.size.y < 200 * u:
		return
	var linhas := []
	for k in Compat.imin(5, lista.size()):
		linhas.append({"pos": k + 1, "e": lista[k]})
	for j in js:
		var pos := int(j.get("posicao", 0))
		if pos > 5:
			linhas.append({"pos": pos, "e": {"pontos": j["pontos"], "personagem": j["personagem"], "hora": ""}, "foto": j.get("foto")})
	var atuais := {}
	for j in js:
		atuais[int(j.get("posicao", 0))] = true
	var cab_h := 86 * u
	var gap := 12 * u
	var n := Compat.imax(linhas.size(), 1)
	var lh: float = clamp((area.size.y - cab_h - gap * (n + 1)) / n, 70 * u, 112 * u)
	var altura := cab_h + gap + n * (lh + gap)
	var quadro := Painel3D.new(Color("#0E2A5C"), 40, 14, 7)
	quadro.rect_size = Vector2(area.size.x, altura)
	quadro.rect_position = area.position
	quadro.modulate.a = 0.0
	_fim.add_child(quadro)
	create_tween().tween_property(quadro, "modulate:a", 1.0, 0.4).set_delay(1.0)
	var cab := rotulo("CLASSIFICAÇÃO DE HOJE", 50 * u, CREME, 12 * u, MARINHO, fonte_titulo)
	cab.rect_size = Vector2(area.size.x, cab_h)
	quadro.add_child(cab)
	_caber(cab, 50 * u, area.size.x - 60 * u)
	if lista.empty() and linhas.empty():
		return
	var lw := area.size.x - 36 * u
	for k in linhas.size():
		var l: Dictionary = linhas[k]
		var e: Dictionary = l["e"]
		var pos: int = l["pos"]
		var minha: bool = atuais.has(pos)
		var cor := Color("#2A63C4") if not minha else Color("#FFB627")
		var lin := Painel3D.new(cor, 26, 8, 4)
		lin.rect_size = Vector2(lw, lh)
		lin.rect_position = Vector2(18 * u, cab_h + gap + k * (lh + gap))
		quadro.add_child(lin)
		lin.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(1.2 + k * 0.12)
		tw.tween_property(lin, "modulate:a", 1.0, 0.25)
		# número (medalha para os 3 primeiros)
		var md := lh * 0.74
		var med := Painel3D.new(_cor_medalha(pos), md / 2.0 / u, 6, 4)
		med.rect_size = Vector2(md, md)
		med.rect_position = Vector2(12 * u, (lh - md) / 2 - 3 * u)
		lin.add_child(med)
		var ln := rotulo(str(pos), md * 0.55, MARINHO if pos <= 3 else Color.white, 0 if pos <= 3 else 6 * u, MARINHO, fonte_titulo)
		ln.rect_size = Vector2(md, md - 4 * u)
		med.add_child(ln)
		# foto da criança (ou o mascote)
		var fd := lh * 0.92
		var ft: Texture = l.get("foto")
		if ft == null:
			ft = Fotos.carregar(str(e.get("foto", "")))
		var fr := TextureRect.new()
		fr.texture = ft if ft != null else _retratos.get(str(e.get("personagem", "bob")))
		fr.expand = true
		fr.stretch_mode = TextureRect.STRETCH_SCALE
		fr.material = material_foto(Color.white)
		fr.rect_size = Vector2(fd, fd)
		fr.rect_position = Vector2(24 * u + md, (lh - fd) / 2 - 3 * u)
		lin.add_child(fr)
		var px := 24 * u + md + fd + 14 * u
		var quem := "com %s" % str(e.get("personagem", "")).to_upper()
		if str(e.get("hora", "")) != "":
			quem += "  ·  %s" % e["hora"]
		var lq := rotulo(quem, 30 * u, Color.white, 7 * u, MARINHO)
		lq.align = Label.ALIGN_LEFT
		lq.rect_size = Vector2(lw * 0.5, lh - 6 * u)
		lq.rect_position = Vector2(px, 0)
		lin.add_child(lq)
		if minha:
			var voce := rotulo("VOCÊ!", 34 * u, MARINHO, 0, MARINHO, fonte_titulo)
			voce.align = Label.ALIGN_LEFT
			voce.rect_size = Vector2(lw * 0.3, lh * 0.5)
			voce.rect_position = Vector2(px, -2 * u)
			lq.rect_position.y = lh * 0.36
			lq.rect_size.y = lh * 0.6
			_estilo(lq, -1.0, 0.0, MARINHO)
			lin.add_child(voce)
		var lp := rotulo(str(int(e.get("pontos", 0))), lh * 0.6, CREME if not minha else MARINHO, 0 if minha else 10 * u, MARINHO, fonte_titulo)
		lp.align = Label.ALIGN_RIGHT
		lp.rect_size = Vector2(lw * 0.3, lh - 6 * u)
		lp.rect_position = Vector2(lw * 0.7 - 24 * u, 0)
		lin.add_child(lp)


func fim_contagem(segundos: int) -> void:
	var ap := _fim.find_node("aperte", true, false) as Label
	if ap:
		ap.text = "APERTE START PARA JOGAR DE NOVO  (%d)" % segundos
		_caber(ap, 44 * u, ap.rect_size.x - 70 * u)
	var b := _fim.get_node_or_null("botao") as Control
	if b:
		b.rect_pivot_offset = b.rect_size / 2
		b.rect_scale = Vector2.ONE * (1.0 + sin(_tempo * 4.0) * 0.025)


## Chama o método `metodo` (com `args`) daqui a `t` segundos.
## Godot 3: sem lambda — nome do método + argumentos.
func _atrasado(t: float, metodo: String, args := []) -> void:
	get_tree().create_timer(t).connect("timeout", self, metodo, args)


# ================================================================ inatividade
func _montar_inatividade() -> void:
	_inativo = Painel3D.new(AZUL, 48, 18, 8)
	_inativo.visible = false
	add_child(_inativo)
	_inativo_texto = rotulo("", 52, Color.white, 12)
	_inativo_texto.autowrap = true
	_inativo.add_child(_inativo_texto)


## Aviso no alto da tela ANTES de uma janela de permissão do Android (ela
## congela a imagem do jogo; o aviso fica visível em volta dela): o que
## tocar para ela nunca mais aparecer. "" = some.
func _montar_aviso_android() -> void:
	_aviso_android = Painel3D.new(Color("#E8384F"), 36, 12, 7)
	_aviso_android.visible = false
	add_child(_aviso_android)
	_aviso_android_texto = rotulo("", 40, Color.white, 10)
	_aviso_android_texto.autowrap = true
	_aviso_android.add_child(_aviso_android_texto)


func aviso_android(texto: String) -> void:
	_aviso_android.visible = texto != ""
	_aviso_android_texto.text = texto


func inatividade(ligado: bool, segundos := 10) -> void:
	_inativo.visible = ligado
	_inativo_texto.text = "AINDA ESTÁ AÍ?\n\nRole a bola para continuar!\n\n%d" % segundos


# ================================================================ fotos (câmera da máquina)
func material_foto(cor_aro: Color) -> ShaderMaterial:
	if _shader_foto == null:
		_shader_foto = load("res://shaders/foto_redonda.shader")
	var m := ShaderMaterial.new()
	m.shader = _shader_foto
	m.set_shader_param("cor_aro", cor_aro)
	return m


func _montar_fotos() -> void:
	_foto_tela = Control.new()
	_foto_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foto_tela.visible = false
	add_child(_foto_tela)
	_foto_fundo = ColorRect.new()
	_foto_fundo.color = Color(0.01, 0.05, 0.14, 0.55)
	_foto_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foto_tela.add_child(_foto_fundo)
	_foto_titulo = rotulo("SORRIA!", 110, Color("#FFF6A8"), 24, MARINHO, fonte_titulo)
	_foto_tela.add_child(_foto_titulo)
	_foto_circulo = TextureRect.new()
	_foto_circulo.expand = true
	_foto_circulo.stretch_mode = TextureRect.STRETCH_SCALE
	_foto_circulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foto_tela.add_child(_foto_circulo)
	_foto_selo = TextureRect.new()
	_foto_selo.expand = true
	_foto_selo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_foto_selo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foto_tela.add_child(_foto_selo)
	_foto_numero = rotulo("", 280, Color.white, 44, MARINHO, fonte_titulo)
	_foto_tela.add_child(_foto_numero)
	_foto_sub = rotulo("", 46, Color.white, 12, MARINHO)
	_foto_sub.autowrap = true
	_foto_tela.add_child(_foto_sub)
	_foto_destaque = TextureRect.new()
	_foto_destaque.expand = true
	_foto_destaque.stretch_mode = TextureRect.STRETCH_SCALE
	_foto_destaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foto_destaque.visible = false
	add_child(_foto_destaque)


func _layout_fotos() -> void:
	var T := rect_size
	_foto_fundo.rect_size = T
	var d: float = min(T.x * 0.7, T.y * 0.44)
	var cy := T.y * (0.47 if retrato else 0.52)
	_foto_circulo.rect_size = Vector2(d, d)
	_foto_circulo.rect_position = Vector2((T.x - d) / 2, cy - d / 2)
	_foto_circulo.rect_pivot_offset = _foto_circulo.rect_size / 2
	var sd := d * 0.42
	_foto_selo.rect_size = Vector2(sd, sd)
	_foto_selo.rect_position = _foto_circulo.rect_position + Vector2(d * 0.74, d * 0.66)
	_tamanho_rotulo(_foto_titulo, 110 * u, 24 * u)
	_foto_titulo.rect_size = Vector2(T.x, 150 * u)
	_foto_titulo.rect_position = Vector2(0, cy - d / 2 - 190 * u)
	_foto_titulo.rect_pivot_offset = _foto_titulo.rect_size / 2
	# o número enorme: desenhado menor e esticado (ver _rotulo_grande)
	_rotulo_grande(_foto_numero, 280 * u, 44 * u, Rect2(0, cy - 180 * u, T.x, 360 * u))
	_tamanho_rotulo(_foto_sub, 46 * u, 12 * u)
	_foto_sub.rect_size = Vector2(T.x * 0.9, 140 * u)
	_foto_sub.rect_position = Vector2(T.x * 0.05, cy + d / 2 + 30 * u)


## Tela "SORRIA!": a câmera ao vivo num círculo, com o mascote do lado.
func foto_tela(ligado: bool, textura: Texture = null, personagem := "", titulo := "SORRIA!", sub := "") -> void:
	_foto_tela.visible = ligado
	if not ligado:
		return
	_layout_fotos()
	var cor := COR_BOB if personagem == "bob" else COR_MIA
	_foto_circulo.texture = textura
	_filtrar(textura)   # a câmera ao vivo vem de um Viewport
	_foto_circulo.material = material_foto(cor.lightened(0.35))
	_foto_selo.texture = _retratos.get(personagem)
	_foto_titulo.text = titulo
	_foto_sub.text = sub
	_foto_numero.text = ""
	_foto_circulo.rect_scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(_foto_circulo, "rect_scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pular(_foto_titulo)


func foto_contagem(n: int) -> void:
	_foto_numero.text = str(n) if n > 0 else ""
	if n > 0:
		# (o número é desenhado menor e esticado: escala de _rotulo_grande)
		var k: float = _foto_numero.get_meta("escala", 1.0)
		_foto_numero.rect_scale = Vector2.ONE * 1.6 * k
		_foto_numero.modulate.a = 1.0
		var tw := create_tween()
		tw.tween_property(_foto_numero, "rect_scale", Vector2.ONE * k, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_foto_numero, "modulate:a", 0.75, 0.6)


## A foto tirada (ou o mascote, se a câmera não mandou imagem).
func foto_pronta(foto: Texture, personagem: String) -> void:
	_foto_numero.text = ""
	if foto != null:
		_foto_circulo.texture = foto
		_foto_titulo.text = "QUE FOTO LINDA!"
		_foto_sub.text = ""
	else:
		_foto_circulo.texture = _retratos.get(personagem)
		_foto_titulo.text = "VAMOS JOGAR!"
		_foto_sub.text = "(a câmera não mandou imagem)"
	_pular(_foto_titulo)
	_foto_circulo.rect_scale = Vector2.ONE * 1.12
	create_tween().tween_property(_foto_circulo, "rect_scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_estrelas_2d(_foto_circulo.rect_position + _foto_circulo.rect_size / 2, 26)


## Foto da criança pulando na tela (no strike).
func foto_destaque(foto: Texture, cor: Color, dur := 1.6) -> void:
	if foto == null:
		return
	var T := rect_size
	var d: float = min(T.x * 0.36, 360.0 * u)
	_foto_destaque.texture = foto
	_foto_destaque.material = material_foto(cor.lightened(0.3))
	_foto_destaque.rect_size = Vector2(d, d)
	_foto_destaque.rect_position = Vector2((T.x - d) / 2, T.y * (0.56 if retrato else 0.58) - d / 2)
	_foto_destaque.rect_pivot_offset = _foto_destaque.rect_size / 2
	_foto_destaque.visible = true
	_foto_destaque.rect_scale = Vector2.ZERO
	_foto_destaque.rect_rotation = rad2deg(-0.6)
	_foto_destaque.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_foto_destaque, "rect_scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_foto_destaque, "rect_rotation", rad2deg(0.08), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_foto_destaque, "rect_rotation", rad2deg(-0.08), 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_foto_destaque, "rect_rotation", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(max(dur - 1.2, 0.1))
	tw.tween_property(_foto_destaque, "rect_scale", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(_foto_destaque, "hide")
	_estrelas_2d(_foto_destaque.rect_position + _foto_destaque.rect_size / 2, 22)


# ================================================================ marca Lazer & Sport
func _montar_marca() -> void:
	_marca_tela = Control.new()
	_marca_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marca_tela.visible = false
	add_child(_marca_tela)
	_marca_fundo = TextureRect.new()
	_marca_fundo.texture = load(MARCA + "fundo.png")
	_marca_fundo.expand = true
	_marca_fundo.stretch_mode = TextureRect.STRETCH_SCALE
	_marca_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marca_tela.add_child(_marca_fundo)
	var sh := load("res://shaders/brilho_marca.shader") as Shader
	for nome in ["placa", "alvo"]:
		var t := TextureRect.new()
		t.texture = load(MARCA + nome + ".png")
		t.expand = true
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_param("pos", -1.0)
		t.material = m
		if nome == "alvo":
			_marca_alvo = t
		else:
			_marca_placa = t
	# véu escuro redondo atrás da logo (quando ela aparece sobre o 3D)
	_marca_veu = TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.0, 0.03, 0.12, 0.72))
	g.set_color(1, Color(0.0, 0.03, 0.12, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	_marca_veu.texture = gt
	_marca_veu.expand = true
	_marca_veu.stretch_mode = TextureRect.STRETCH_SCALE
	_marca_veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marca_tela.add_child(_marca_veu)
	# o alvo fica atrás da placa (como na logo)
	_marca_tela.add_child(_marca_alvo)
	_marca_tela.add_child(_marca_placa)
	# selo GAMES embaixo da placa: LAZER & SPORT GAMES
	_marca_games = TextureRect.new()
	_marca_games.texture = load(MARCA + "games.png")
	_marca_games.expand = true
	_marca_games.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_marca_games.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marca_tela.add_child(_marca_games)
	_marca_texto = rotulo("apresenta", 52, Color(1, 1, 1, 0.92), 0, MARINHO)
	_marca_tela.add_child(_marca_texto)


func _layout_marca(T: Vector2) -> void:
	_marca_fundo.rect_size = T
	var lw: float = min(T.x * 0.82, T.y * 0.62 / PROPORCAO_LOGO)
	var lh := lw * PROPORCAO_LOGO
	var centro_y := 0.4 if _marca_veu.visible else 0.46
	var origem := Vector2((T.x - lw) / 2, T.y * centro_y - lh / 2)
	var ref := float(_marca_placa.texture.get_width())     # a placa tem a largura da logo inteira
	for par in [[_marca_alvo, CENTRO_ALVO], [_marca_placa, CENTRO_PLACA]]:
		var t: TextureRect = par[0]
		var centro: Vector2 = par[1]
		var tam: Vector2 = t.texture.get_size() * (lw / ref)
		t.rect_size = tam
		t.rect_position = origem + Vector2(lw, lh) * centro - tam / 2
		t.rect_pivot_offset = tam / 2
	var gw := lw * 0.46
	var gh := gw * 188.0 / 616.0
	_marca_games.rect_size = Vector2(gw, gh)
	_marca_games.rect_position = Vector2((T.x - gw) / 2, origem.y + lh + 10 * u)
	_marca_games.rect_pivot_offset = _marca_games.rect_size / 2
	var vw: float = max(T.x, T.y) * 1.25
	_marca_veu.rect_size = Vector2(vw, vw)
	_marca_veu.rect_position = origem + Vector2(lw, lh) * 0.5 - _marca_veu.rect_size / 2
	# (o shadow_size do Godot 4 não existe aqui: a sombra é a letra deslocada)
	_tamanho_rotulo(_marca_texto, 52 * u)
	_marca_texto.rect_size = Vector2(T.x, 80 * u)
	_marca_texto.rect_position = Vector2(0, origem.y + lh + gh + 26 * u)


## Abertura: a logo aparece (sobre o fundo azul da inicialização ou, com
## `sobre_3d`, por cima do strike da abertura), o dardo "acerta" o alvo
## (tremidinha + estrelas), sobe o selo GAMES, passa um brilho e entra
## "apresenta".
func marca(ligado: bool, na_hora := false, sobre_3d := false) -> void:
	if not ligado:
		if not _marca_tela.visible:
			return
		if na_hora:
			_marca_tela.visible = false
			return
		var tw := create_tween()
		tw.tween_property(_marca_tela, "modulate:a", 0.0, 0.4)
		tw.tween_callback(_marca_tela, "hide")
		return
	_marca_fundo.visible = not sobre_3d
	_marca_veu.visible = sobre_3d
	_layout_marca(rect_size)
	_marca_tela.visible = true
	_marca_tela.modulate.a = 1.0
	_marca_texto.modulate.a = 0.0
	_marca_alvo.rect_scale = Vector2.ONE
	_marca_games.visible = true
	_marca_games.rect_scale = Vector2.ZERO
	var tg := create_tween()
	tg.tween_interval(0.55)
	tg.tween_property(_marca_games, "rect_scale", Vector2(1.12, 1.12), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tg.tween_property(_marca_games, "rect_scale", Vector2.ONE, 0.18)
	if sobre_3d:
		# logo "estoura" na tela
		for t in [_marca_alvo, _marca_placa]:
			(t as Control).rect_scale = Vector2.ZERO
			var tp := create_tween()
			tp.tween_interval(0.0 if t == _marca_placa else 0.08)
			tp.tween_property(t, "rect_scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_marca_veu.modulate.a = 0.0
		create_tween().tween_property(_marca_veu, "modulate:a", 1.0, 0.3)
		_atrasado(0.12, "_estrelas_2d", [_marca_placa.rect_position + _marca_placa.rect_size * 0.5, 36])
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_property(_marca_alvo, "rect_scale", Vector2(1.07, 0.94), 0.07)
	tw.tween_property(_marca_alvo, "rect_scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_atrasado(0.32, "_estrelas_2d", [_marca_alvo.rect_position + _marca_alvo.rect_size * Vector2(0.43, 0.5), 30])
	for t in [_marca_placa, _marca_alvo]:
		var m := (t as TextureRect).material as ShaderMaterial
		m.set_shader_param("pos", -1.0)
		var tb := create_tween()
		tb.tween_interval(0.7 if t == _marca_placa else 0.6)
		tb.tween_method(self, "_brilho_marca", -0.4, 1.6, 0.9, [m]).set_trans(Tween.TRANS_SINE)
	var tt := create_tween()
	tt.tween_interval(1.0)
	tt.tween_property(_marca_texto, "modulate:a", 1.0, 0.4)


## O brilho passando pela logo (Godot 3: sem lambda no tween_method).
func _brilho_marca(v: float, m: ShaderMaterial) -> void:
	m.set_shader_param("pos", v)


# ================================================================ layout responsivo
func layout() -> void:
	var T: Vector2 = Tela.tamanho()
	rect_size = T
	rect_position = Vector2.ZERO
	retrato = T.y >= T.x
	u = min(T.x, T.y) / 1080.0
	tela3d.rect_position = Vector2.ZERO
	tela3d.rect_size = T
	_flash.rect_size = T
	_centro.rect_size = T
	_tarja_cima.rect_position = Vector2.ZERO
	_tarja_cima.rect_size = Vector2(T.x, _tarja_cima.rect_size.y)
	_tarja_baixo.rect_size = Vector2(T.x, _tarja_baixo.rect_size.y)
	_tarja_baixo.rect_position = Vector2(0, T.y - _tarja_baixo.rect_size.y)
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
		var p: Control = c["painel"]
		p.rect_size = Vector2(larg, alt)
		var x: float
		if usados == 1:
			x = (T.x - larg) / 2 if retrato else margem
		else:
			x = margem if i == 0 else T.x - larg - margem
		p.rect_position = Vector2(x, margem + 40 * u)
		p.rect_pivot_offset = p.rect_size / 2
		var av: TextureRect = c["avatar"]
		if c.get("foto", false):
			# foto da criança dentro do cartão + o mascote de "selo"
			av.rect_size = Vector2(alt * 0.86, alt * 0.86)
			av.rect_position = Vector2(alt * 0.07, alt * 0.07)
			var selo: TextureRect = c["selo"]
			selo.rect_size = Vector2(alt * 0.5, alt * 0.5)
			selo.rect_position = Vector2(alt * 0.55, alt * 0.52)
		else:
			av.rect_size = Vector2(alt * 1.15, alt * 1.15)
			av.rect_position = Vector2(-alt * 0.12, -alt * 0.32)
		var nome: Label = c["nome"]
		_tamanho_rotulo(nome, 42 * u, 10 * u)
		nome.rect_size = Vector2(larg - alt * 1.0, 54 * u)
		nome.rect_position = Vector2(alt * 0.98, 10 * u)
		var pts: Label = c["pontos"]
		_tamanho_rotulo(pts, 78 * u, 14 * u)
		pts.rect_size = Vector2(larg - alt * 1.0 - 20 * u, 88 * u)
		pts.rect_position = Vector2(alt * 0.98, 52 * u)
		pts.align = Label.ALIGN_LEFT
		var rod: HBoxContainer = c["rodadas"]
		rod.rect_position = Vector2(alt * 0.98, alt - 64 * u)
		rod.rect_size = Vector2(larg - alt, 50 * u)
		rod.add_constant_override("separation", int(8 * u))
	var base_y := margem + 40 * u + alt + 16 * u
	_tamanho_rotulo(_info, 34 * u, 9 * u)
	if retrato:
		_info.rect_size = Vector2(T.x, 48 * u)
		_info.rect_position = Vector2(0, base_y)
		_bolas_box.rect_size = Vector2(T.x, 40 * u)
		_bolas_box.rect_position = Vector2(0, base_y + 52 * u)
	else:
		_info.rect_size = Vector2(larg, 48 * u)
		_info.rect_position = Vector2(margem, base_y)
		_bolas_box.rect_size = Vector2(larg, 40 * u)
		_bolas_box.rect_position = Vector2(margem, base_y + 52 * u)
	_bolas_box.add_constant_override("separation", int(14 * u))
	# mapa dos pinos (canto)
	var ms := 190 * u
	_mapa.rect_size = Vector2(ms, ms * 0.86)
	_mapa.rect_position = Vector2(T.x - ms - margem, base_y + 8 * u) if retrato else Vector2(T.x - ms - margem, margem + 300 * u)
	for n in _mapa_pontos:
		var pos := Pinos.posicao_do_pino(n)
		var d: Panel = _mapa_pontos[n]
		var r := 24 * u
		d.rect_size = Vector2(r, r)
		var fx := pos.x / (Medidas.ESPACO_PINOS * 1.5)  # -1..1
		var fy := (Medidas.Z_PINO1 - pos.z) / (Medidas.FILEIRA * 3.0)  # 0..1 (fundo em cima)
		d.rect_position = Vector2(ms / 2 + fx * ms * 0.36 - r / 2, ms * 0.86 * (0.78 - fy * 0.56) - r / 2)
	# toque e convite
	_toque.rect_position = Vector2.ZERO
	_toque.rect_size = T
	var y_aviso := T.y - (330 if retrato else 210) * u
	_tamanho_rotulo(_aviso, 84 * u, 20 * u)
	_aviso.rect_size = Vector2(T.x, 120 * u)
	_aviso.rect_position = Vector2(0, y_aviso)
	_aviso.rect_pivot_offset = _aviso.rect_size / 2
	_tamanho_rotulo(_aviso_sub, 44 * u, 11 * u)
	_aviso_sub.rect_size = Vector2(T.x, 64 * u)
	_aviso_sub.rect_position = Vector2(0, y_aviso + 112 * u)
	_aviso_sub.rect_pivot_offset = _aviso_sub.rect_size / 2
	_tamanho_rotulo(_sequencia, 40 * u, 10 * u)
	_sequencia.rect_size = Vector2(T.x if retrato else larg, 56 * u)
	_sequencia.rect_position = Vector2(0 if retrato else margem, base_y + 100 * u)
	_sequencia.rect_pivot_offset = _sequencia.rect_size / 2
	# atração
	var lw: float = min(T.x * 0.9, 980 * u) if retrato else T.x * 0.36
	var lt := _logo.texture
	var lh: float = lw * (float(lt.get_height()) / float(lt.get_width()) if lt else 0.4)
	_logo.rect_size = Vector2(lw, lh)
	if retrato:
		_logo.rect_position = Vector2((T.x - lw) / 2, T.y * 0.05)
	else:
		_logo.rect_position = Vector2(T.x * 0.03, T.y * 0.05)
	_logo.rect_pivot_offset = _logo.rect_size / 2
	var bw: float = min(T.x * 0.78, 780 * u) if retrato else T.x * 0.34
	var bh := 150 * u
	_aperte_botao.rect_size = Vector2(bw, bh)
	if retrato:
		_aperte_botao.rect_position = Vector2((T.x - bw) / 2, T.y * 0.69)
	else:
		_aperte_botao.rect_position = Vector2(T.x * 0.03 + (lw - bw) / 2, T.y * 0.6)
	_aperte_botao.rect_pivot_offset = _aperte_botao.rect_size / 2
	_tamanho_rotulo(_aperte, 84 * u)
	_sombra(_aperte, null, 3 * u)
	_aperte.rect_size = Vector2(bw, bh - 18 * u)
	_aperte.rect_position = Vector2.ZERO
	_caber(_aperte, 84 * u, bw - 90 * u)
	_tamanho_rotulo(_recorde, 40 * u, 8 * u)
	_tamanho_rotulo(_creditos, 30 * u, 8 * u)
	_creditos.rect_size = Vector2(T.x, 46 * u)
	_creditos.rect_position = Vector2(0, T.y - (90 if retrato else 64) * u)
	# quantos vão jogar
	_layout_jogadores(T)
	_layout_etapas(T)
	# seleção
	var sw: float = min(T.x * 0.9, 900 * u)
	_sel_titulo.rect_size = Vector2(sw, 130 * u)
	_sel_titulo.rect_position = Vector2((T.x - sw) / 2, 112 * u)
	_sel_titulo.rect_pivot_offset = _sel_titulo.rect_size / 2
	var t := _sel_titulo.get_node("titulo") as Label
	_tamanho_rotulo(t, 74 * u, 16 * u)
	t.rect_size = Vector2(sw, 116 * u)
	t.rect_position = Vector2.ZERO
	for i in 2:
		var p: Painel3D = _sel_placas[i]
		p.rect_size = Vector2(330, 116) * u
		if p.rect_position == Vector2.ZERO:
			p.rect_position = Vector2(T.x * (0.27 if i == 0 else 0.73) - p.rect_size.x / 2, T.y * 0.64)
		var l: Label = _sel_nomes[i]
		_tamanho_rotulo(l, 70 * u, 16 * u)
		l.rect_size = Vector2(p.rect_size.x, p.rect_size.y - 14 * u)
		l.rect_position = Vector2.ZERO
	var dw: float = min(T.x * 0.9, 860 * u)
	var dh := 230 * u
	_sel_dica.rect_size = Vector2(dw, dh)
	_sel_dica.rect_position = Vector2((T.x - dw) / 2, T.y - dh - (60 if retrato else 24) * u)
	_tamanho_rotulo(_sel_texto, 34 * u, 9 * u)
	_sel_texto.rect_size = Vector2(dw, 100 * u)
	_sel_texto.rect_position = Vector2(0, 8 * u)
	_layout_sensores(_sel_sensores, min(dw - 80 * u, 420 * u))
	_sel_sensores.rect_position = Vector2((dw - _sel_sensores.rect_size.x) / 2, 112 * u)
	var mw: float = min(T.x * 0.86, 860 * u)
	# inatividade
	_inativo.rect_size = Vector2(mw, 600 * u)
	_inativo.rect_position = (T - _inativo.rect_size) / 2
	_aviso_android.rect_size = Vector2(min(T.x - 60 * u, 1500 * u), 230 * u)
	_aviso_android.rect_position = Vector2((T.x - _aviso_android.rect_size.x) / 2, 30 * u)
	_tamanho_rotulo(_aviso_android_texto, 40 * u, 10 * u)
	_aviso_android_texto.rect_size = _aviso_android.rect_size - Vector2(60 * u, 20 * u)
	_aviso_android_texto.rect_position = Vector2(30 * u, 10 * u)
	_tamanho_rotulo(_inativo_texto, 54 * u, 12 * u)
	_inativo_texto.rect_size = _inativo.rect_size
	_inativo_texto.rect_position = Vector2.ZERO
	if _foto_tela.visible:
		_layout_fotos()
	if _marca_tela.visible:
		_layout_marca(T)
	if _atracao.visible:
		atracao(true, _recorde.text, _creditos.text, _rec_foto.texture, _melhores_hoje)


func _process(delta: float) -> void:
	_tempo += delta
	# placar: pontos contando
	for c in _cartoes:
		if c.get("usado", false) and c["valor"] < float(c["alvo"]):
			c["valor"] = min(float(c["alvo"]), c["valor"] + delta * max(60.0, (float(c["alvo"]) - c["valor"]) * 3.0))
			(c["pontos"] as Label).text = str(int(c["valor"]))
	if _aviso.visible:
		_aviso.rect_scale = Vector2.ONE * (1.0 + sin(_tempo * 5.0) * 0.05)
		_aviso_sub.modulate.a = 0.6 + 0.4 * abs(sin(_tempo * 2.6))
	if _atracao.visible:
		_logo.rect_scale = Vector2.ONE * (1.0 + sin(_tempo * 2.2) * 0.025)
		_logo.rect_rotation = rad2deg(sin(_tempo * 1.3) * 0.02)
		_aperte_botao.rect_scale = Vector2.ONE * (1.0 + sin(_tempo * 3.0) * 0.035)
		_aperte_botao.realcar(0.35 + 0.35 * abs(sin(_tempo * 3.0)))
	if _jog.visible:
		_jog_cartoes[_jog_n - 1].realcar(0.7 + 0.3 * sin(_tempo * 6.0))
		_jog_cartoes[_jog_n - 1].rect_scale = Vector2.ONE * (1.05 + sin(_tempo * 6.0) * 0.015)
		_jog_cartoes[2 - _jog_n].rect_scale = Vector2.ONE * 0.94
	if _selecao.visible:
		_sel_placas[_sel_destaque].realcar(0.7 + 0.3 * sin(_tempo * 6.0))
	if _replay_ponto.visible:
		_replay_ponto.modulate.a = 1.0 if fposmod(_tempo, 1.0) < 0.6 else 0.15
