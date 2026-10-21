class_name Painel3D
extends Control

## PLACA COM VOLUME das telas (placar, botões, cartões, faixas): frente com
## brilho de verniz, lateral mais escura, contorno azul-marinho e sombra.
## Os filhos (textos, fotos) ficam por cima, como num Panel.
##
## EDIÇÃO OPENGL ES 2.0: em vez do shader por pixel (a Mali-400 só faz conta
## de pixel em meia precisão: as bordas arredondadas sairiam serrilhadas),
## a placa é montada com caixas arredondadas prontas do motor (StyleBoxFlat,
## com antisserrilhado feito na própria malha), em camadas:
## sombra -> (halo do escolhido) -> contorno + lateral -> frente -> metade de
## cima mais clara -> verniz -> filete claro.

const MARINHO := Color("#0B1F45")

var _cor := Color("#1A4FA8")
var _cor_borda := MARINHO
var _brilho := 0.24
var _raio := 30.0
var _espessura := 10.0
var _borda := 5.0
var _realce := 0.0
var _sombra := 0.4
var _caixas := {}


func _init(cor := Color("#1A4FA8"), raio := 30.0, espessura := 10.0, borda := 5.0) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in ["sombra", "halo", "casca", "frente", "topo", "verniz", "filete"]:
		var sb := StyleBoxFlat.new()
		sb.anti_aliasing = true
		sb.anti_aliasing_size = 1.0
		sb.corner_detail = 10
		_caixas[k] = sb
	pintar(cor)
	formato(raio, espessura, borda)


## Cor principal (a frente, a lateral e o brilho saem dela).
func pintar(cor: Color, borda := MARINHO, brilho := 0.24) -> Painel3D:
	_cor = cor
	_cor_borda = borda
	_brilho = brilho
	update()
	return self


func formato(raio: float, espessura: float, borda: float) -> Painel3D:
	_raio = raio
	_espessura = espessura
	_borda = borda
	update()
	return self


## 0..1: halo amarelo de "escolhido".
func realcar(valor: float) -> void:
	if abs(valor - _realce) < 0.002:
		return
	_realce = valor
	update()


func sombra(forca: float) -> void:
	_sombra = forca
	update()


func _cantos(sb: StyleBoxFlat, r: float) -> void:
	sb.set_corner_radius_all(int(round(max(r, 0.0))))


func _draw() -> void:
	var t := rect_size
	if t.x < 2.0 or t.y < 2.0:
		return
	var r: float = min(_raio, min(t.x, t.y) * 0.5)
	var margem: float = max(12.0, _raio * 0.9 + _espessura)
	# sombra macia embaixo (a própria caixa só projeta a sombra)
	if _sombra > 0.0:
		var s: StyleBoxFlat = _caixas["sombra"]
		s.bg_color = Color(0.0, 0.03, 0.10, _sombra * 0.75)
		_cantos(s, r)
		s.shadow_color = Color(0.0, 0.03, 0.10, _sombra * 0.6)
		s.shadow_size = int(margem * 0.45)
		s.shadow_offset = Vector2.ZERO
		draw_style_box(s, Rect2(Vector2(margem * 0.1, margem * 0.35), t - Vector2(margem * 0.2, margem * 0.1)))
	# halo do item escolhido (por fora do contorno)
	if _realce > 0.0:
		var h: StyleBoxFlat = _caixas["halo"]
		var amarelo := Color(1.0, 0.84, 0.25)
		h.bg_color = Color(amarelo.r, amarelo.g, amarelo.b, 0.85 * _realce)
		_cantos(h, r + margem * 0.35)
		h.shadow_color = Color(amarelo.r, amarelo.g, amarelo.b, 0.6 * _realce)
		h.shadow_size = int(margem * 0.6)
		h.shadow_offset = Vector2.ZERO
		var e := margem * 0.3
		draw_style_box(h, Rect2(-Vector2(e, e), t + Vector2(e, e) * 2.0))
	# contorno escuro + lateral (a espessura embaixo)
	var c: StyleBoxFlat = _caixas["casca"]
	c.bg_color = _cor.darkened(0.52)
	c.border_color = _cor_borda
	c.set_border_width_all(int(round(_borda)))
	_cantos(c, r)
	draw_style_box(c, Rect2(Vector2.ZERO, t))
	# frente (acima da lateral)
	var base_f: float = max(t.y - _borda - _espessura, _borda + 2.0 * r)
	var frente_r := Rect2(Vector2(_borda, _borda), Vector2(t.x - 2.0 * _borda, base_f - _borda))
	var rf: float = max(r - _borda, 1.0)
	var f: StyleBoxFlat = _caixas["frente"]
	f.bg_color = _cor.darkened(0.08)
	_cantos(f, rf)
	draw_style_box(f, frente_r)
	# metade de cima um pouco mais clara (o degradê da frente)
	var tp: StyleBoxFlat = _caixas["topo"]
	tp.bg_color = _cor.lightened(0.16)
	_cantos(tp, rf)
	tp.corner_radius_bottom_left = int(rf * 0.6)
	tp.corner_radius_bottom_right = int(rf * 0.6)
	draw_style_box(tp, Rect2(frente_r.position, Vector2(frente_r.size.x, frente_r.size.y * 0.55)))
	# verniz: brilho branco na parte de cima
	if _brilho > 0.0:
		var v: StyleBoxFlat = _caixas["verniz"]
		v.bg_color = Color(1, 1, 1, _brilho * 0.55)
		var alt := frente_r.size.y
		var mx: float = r * 0.3 + _borda
		var vr := Rect2(frente_r.position + Vector2(mx, alt * 0.07), Vector2(frente_r.size.x - 2.0 * mx, alt * 0.36))
		_cantos(v, min(r * 0.75, vr.size.y * 0.5))
		draw_style_box(v, vr)
	# filete claro por dentro do contorno (no escolhido, amarelo)
	var fl: StyleBoxFlat = _caixas["filete"]
	fl.draw_center = false
	var aro := Color(1, 1, 1, 0.35).linear_interpolate(Color(1.0, 0.84, 0.25, 0.9), _realce)
	fl.border_color = aro
	fl.set_border_width_all(int(max(round(_borda * 0.5), 1.0)))
	var folga := _borda * 0.35 + 1.0
	_cantos(fl, max(rf - folga, 1.0))
	draw_style_box(fl, frente_r.grow(-folga))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		update()
