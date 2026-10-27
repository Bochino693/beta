class_name Temas
extends Spatial

## OS 4 CENÁRIOS — um por rodada (e a atração vai passando por todos).
## Cada um tem céu, luz, neblina, terreno e cores da pista próprios (CONFIG,
## aplicado por Mundo.aplicar_tema) e um grupo de decoração que se mexe:
##   parque — Parque de Diversões: roda-gigante, carrossel, tendas de circo, balões
##   espaco — Viagem ao Espaço: planeta com anel, foguetes, disco voador
##   mar    — Fundo do Mar: navio pirata naufragado, corais, algas, peixinhos, bolhas
##   dinos  — Selva dos Dinos: vulcão, dino pescoçudo, palmeiras, pterossauros

## a Selva dos Dinos é sempre a PRIMEIRA fase (e o começo da atração);
## depois Parque, Espaço e Mar
const ORDEM := ["dinos", "parque", "espaco", "mar"]

const CONFIG := {
	"parque": {
		"ceu": [Color("#2F7FFF"), Color("#6CBBFF"), Color("#E4F4FF"), Color("#8CD18C")],
		"ambiente": Color(0.62, 0.7, 0.86), "ambiente_forca": 0.68,
		"neblina": Color(0.84, 0.92, 1.0), "neblina_densidade": 0.0035,
		"sol": Color(1.0, 0.95, 0.86), "sol_forca": 0.9,
		"fundo": [Color("#3A1C8C"), Color("#7A3FD6")], "halo": Color("#FFD6F4"),
		"portal": [Color("#FFC21A"), Color("#E8384F")], "gabinete": Color("#E8384F"), "coluna": Color("#1E62C8"), "neon": Color("#FF4FC8"),
		"parede": Color("#2A63C4"),
		"placa": Color("#2F63E0"), "divisoria": Color("#FFB627"), "faixa": Color("#E8384F"),
		# canaleta de doce (listras rosa e creme, lábios amarelos) e para-choques de bala
		"canaleta_modo": 0, "canaleta": [Color("#FF6FAE"), Color("#FFF3E2"), Color("#FFD23F")],
		"bumper": [Color("#FFFFFF"), Color("#FF3B50")],
		"chao": [Color("#6BCB5D"), Color("#5BB54E"), Color("#FFFFFF"), Color("#FFE873")], "chao_modo": 0,
	},
	"espaco": {
		"ceu": [Color("#040A26"), Color("#0E2560"), Color("#2C6AB8"), Color("#14244E")],
		"estrelas": 1.0, "nebulosa": Color("#2FC8FF"), "cor_sol": Color("#CFE0FF"), "forca_sol": 0.35,
		"ambiente": Color(0.6, 0.7, 1.0), "ambiente_forca": 0.78,
		"neblina": Color(0.14, 0.24, 0.5), "neblina_densidade": 0.0045,
		"sol": Color(0.9, 0.94, 1.0), "sol_forca": 0.92,
		"fundo": [Color("#0B1450"), Color("#2A3FB0")], "halo": Color("#9FE8FF"),
		"portal": [Color("#4FD8FF"), Color("#3B2FA8")], "gabinete": Color("#3B3FA8"), "coluna": Color("#6A3FD0"), "neon": Color("#4FE3FF"),
		"parede": Color("#3B4FC8"),
		"placa": Color("#5A3FD8"), "divisoria": Color("#4FD8FF"), "faixa": Color("#FF9F2E"),
		# canaleta de nave (metal com luzes correndo) e para-choques azul e branco
		"canaleta_modo": 1, "canaleta": [Color("#26357A"), Color("#9FB4FF"), Color("#4FE3FF")],
		"bumper": [Color("#FFFFFF"), Color("#3B8BFF")],
		"chao": [Color("#9AA8C4"), Color("#8494B3"), Color("#C3CEE2"), Color("#E2F5FF")], "chao_modo": 1,
	},
	"mar": {
		"ceu": [Color("#0A4F86"), Color("#1A94C0"), Color("#86E6DE"), Color("#E8D29A")],
		"raios": 1.0, "cor_sol": Color("#E6FFF8"), "forca_sol": 0.5,
		"ambiente": Color(0.5, 0.82, 0.92), "ambiente_forca": 0.72,
		"neblina": Color(0.32, 0.72, 0.84), "neblina_densidade": 0.0105,
		"sol": Color(0.88, 1.0, 0.96), "sol_forca": 0.86,
		"fundo": [Color("#064A70"), Color("#0FA0B8")], "halo": Color("#C8FFF4"),
		"portal": [Color("#2EE6C8"), Color("#FF7A5C")], "gabinete": Color("#0E8C9C"), "coluna": Color("#FF7A5C"), "neon": Color("#5CFFD8"),
		"parede": Color("#18A6B8"),
		"placa": Color("#1A9BD0"), "divisoria": Color("#FF8A5C"), "faixa": Color("#2EC4B6"),
		# canaleta de água (reflexos e bolhinhas) e para-choques coral
		"canaleta_modo": 2, "canaleta": [Color("#0C86A6"), Color("#56E0EA"), Color("#E9FFFB")],
		"bumper": [Color("#FFFFFF"), Color("#FF7A5C")],
		"chao": [Color("#F0C47C"), Color("#E0AC62"), Color("#FF9A86"), Color("#7CD2E0")], "chao_modo": 2,
	},
	"dinos": {
		"ceu": [Color("#3FA7E8"), Color("#9BD8F0"), Color("#FFE4AE"), Color("#6BBF59")],
		"cor_sol": Color("#FFE7B0"),
		"ambiente": Color(0.72, 0.72, 0.62), "ambiente_forca": 0.68,
		"neblina": Color(0.92, 0.9, 0.78), "neblina_densidade": 0.0045,
		"sol": Color(1.0, 0.93, 0.8), "sol_forca": 0.92,
		"fundo": [Color("#14501E"), Color("#3E9A2E")], "halo": Color("#FFF2A8"),
		"portal": [Color("#9BE04A"), Color("#FF8A1E")], "gabinete": Color("#8A5228"), "coluna": Color("#2E9A3E"), "neon": Color("#B6FF3B"),
		"parede": Color("#3E9A3A"),
		"placa": Color("#2FA046"), "divisoria": Color("#FF9F2E"), "faixa": Color("#8BD33F"),
		# canaleta de bambu e para-choques amarelo e verde
		"canaleta_modo": 3, "canaleta": [Color("#6DBB45"), Color("#D4F58A"), Color("#F2D27A")],
		"bumper": [Color("#FFE65A"), Color("#2E9A3E")],
		"chao": [Color("#46A44E"), Color("#57B948"), Color("#FF9F33"), Color("#FFE65A")], "chao_modo": 3,
	},
}

const CORES_BICHOS := [Color("#FF9F2E"), Color("#FFD43B"), Color("#4FD8FF"), Color("#FF4B5C"), Color("#8DFF6A"), Color("#2E7BFF")]

## Lugares de destaque perto da pista (vistos de perto nas jogadas): x, z, giro, escala
## o baú do tesouro (mar): ao lado da pista, à direita, no meio do caminho
const BAU_PERTO := Vector3(1.75, 0.0, -4.4)
const DESTAQUES := [[-2.55, -1.2, 0.3], [2.7, -2.7, -0.4], [-3.9, 3.4, 0.4], [3.9, 2.6, 0.0],
	[2.3, -6.0, 2.0], [-2.3, -6.8, 1.0], [-2.4, -4.2, 0.0], [2.45, -8.7, 0.5]]

var mundo  # o Mundo (sem tipo: no Godot 3 Mundo e Temas não podem se citar)
var atual := ""
var grupos := {}
var _anim := {}          # tema -> [{no, tipo, ...}]
var _mats := {}
var _t := 0.0
## cenário LEVE (Mundo.leve): metade da decoração, sem contorno, luz por
## vértice (toon_leve) e menos partículas
var leve := false
## detalhes extras (6.7, menu do operador): vento nas plantas, enfeites perto
## da pista que se mexem e borboletas
var detalhes := true
var _malhas_vento := {}
var _mats_leve: Array = []
## SONS DE AMBIENTE (6.9): cada fase tem as suas VOZES — a baleia, o
## pterodáctilo, o dino, o vulcão, o carrossel, o disco voador... Cada uma
## toca quando o bicho/objeto está NA TELA, sai do lado em que ele está
## (Sons.tocar_em) e vem JUNTO com uma ação dele (o dino levanta a cabeça
## e ruge, o vulcão treme e solta mais fumaça, o carrossel acelera com a
## musiquinha, a baleia bate o rabo cantando). Organizado: um som de
## ambiente de cada vez, com uma folga entre eles, mais baixo que os sons
## da jogada — e só quando o principal deixa (som_ambiente: na espera da
## jogada, na abertura e nas telas; não durante a bola, o resultado e o
## replay).
var som_ambiente := false
var _vozes := {}          # tema -> [{no, som, cada, prox, vol, tom, acao, item}]
var _relogio := 0.0
var _prox_amb := 4.0
const AMB_FOLGA := Vector2(3.0, 5.5)
const AMB_VOLUME := 0.6


func construir(m) -> void:
	mundo = m
	leve = m.leve
	detalhes = m.detalhes
	for nome in ORDEM:
		var g := Spatial.new()
		g.name = nome
		g.visible = false
		add_child(g)
		grupos[nome] = g
		_anim[nome] = []
		_vozes[nome] = []
		_duplas[nome] = []
		_trocaveis[nome] = []
		_ocupado[nome] = []
	_parque()
	_espaco()
	_mar()
	_dinos()
	# atrás de quem joga (a câmera vira para o mascote): o próprio cenário
	_atras("parque", [["carrossel", 0.9], ["tenda", 1.0], ["arvore_verde", 1.4], ["pirulito", 1.3], ["arvore_laranja", 1.4], ["cupcake", 1.5]])
	_atras("espaco", [["foguete", 1.1], ["pedra_lua", 1.7], ["cristal", 1.5], ["cristal", 1.1], ["pedra_lua", 1.3], ["foguete", 0.9]])
	_atras("mar", [["coral_roxo", 1.5], ["concha", 1.3], ["alga", 1.6], ["coral", 1.5], ["alga", 1.3], ["estrela_mar", 1.4]])
	_atras("dinos", [["palmeira", 1.1], ["samambaia", 1.5], ["ovo_dino", 1.3], ["pedra", 1.4], ["palmeira", 0.95], ["flor_gigante", 1.4]])
	# o que fica parado em cada cenário vira poucas malhas (uma por material)
	for nome in ORDEM:
		var fora: Array = []
		for item in _anim[nome]:
			for k in ["no", "roda", "particulas"]:
				if item.has(k):
					fora.append(item[k])
			if item.has("cabines"):
				fora.append_array(item["cabines"])
		for v in _vozes[nome]:
			fora.append(v["no"])
		# os dois níveis: as peças paradas que têm uma versão mais leve
		# ficam no nó "alto" e a gêmea dela (a mais leve) no nó "leve"; cada
		# nó vira os lotes dele. As que se mexem trocam de malha.
		var parado := {}
		for n in fora:
			parado[n] = false
		var g: Spatial = grupos[nome]
		var alto := Spatial.new()
		alto.name = "alto"
		g.add_child(alto)
		var lev := Spatial.new()
		lev.name = "leve"
		lev.visible = false
		g.add_child(lev)
		for d in _duplas[nome]:
			var mi: MeshInstance = d[0]
			if parado.has(mi) or mi.get_parent() != g or mi.get_child_count() > 0:
				_trocaveis[nome].append(d)
				continue
			var gemea := mi.duplicate() as MeshInstance
			gemea.mesh = d[2]
			lev.add_child(gemea)
			g.remove_child(mi)
			alto.add_child(mi)
		lev.visible = true
		Lote.juntar(alto, fora)
		Lote.juntar(lev, fora)
		lev.visible = false
		Lote.juntar(g, fora + [alto, lev])
	nivel_cenario(cenario_leve)


## O NÍVEL DO CENÁRIO (7.0): alto (as versões caprichadas) ou leve (um passo
## mais leve em cada peça). Trocar é só mostrar um nó e esconder o outro.
func nivel_cenario(leve_: bool) -> void:
	cenario_leve = leve_
	for nome in grupos:
		var g: Spatial = grupos[nome]
		if g.has_node("alto"):
			(g.get_node("alto") as Spatial).visible = not leve_
			(g.get_node("leve") as Spatial).visible = leve_
		for d in _trocaveis[nome]:
			(d[0] as MeshInstance).mesh = d[2] if leve_ else d[1]


## Uma peça de fora do cenário que também troca de malha com o nível (7.4:
## o pterodáctilo da placa da selva, mundo.gd — no leve, o do meio).
func trocavel(tema: String, mi: MeshInstance, alto: Mesh, leve_: Mesh) -> void:
	_trocaveis[tema].append([mi, alto, leve_])
	mi.mesh = leve_ if cenario_leve else alto


func mostrar(nome: String) -> void:
	atual = nome
	for k in grupos:
		(grupos[k] as Spatial).visible = k == nome
		for item in _anim[k]:
			if item.has("particulas"):
				(item["particulas"] as CPUParticles).emitting = k == nome


static func proximo(nome: String) -> String:
	return ORDEM[(ORDEM.find(nome) + 1) % ORDEM.size()]


# ================================================================ peças
func _mat(contorno: float, tinta: Color, extra := {}) -> ShaderMaterial:
	if leve:
		contorno = 0.0
	var chave := "%s|%s|%s" % [contorno, tinta.to_html(), str(extra)]
	if not _mats.has(chave):
		var p := {"borda": 0.16, "tinta": tinta}
		p.merge(extra, true)
		_mats[chave] = _toon(contorno, p)
	return _mats[chave]


## Material de um MODELO do cenário: os que têm desenho usam o ATLAS (uma
## textura com o desenho de todos, assado dos modelos originais por
## tools/modelos_texturizados.py) e o toon leve com textura — a forma com
## poucos triângulos e o desenho na imagem. Todos com o MESMO material: o
## Lote junta os parados num desenho por região. Sem mapa UV (as peças de
## uma cor só), o toon de sempre (cor nos vértices).
## 7.0: UM ATLAS POR FASE (atlas_<fase>.png), cada um com a imagem inteira
## para os objetos da fase — os que aparecem em duas fases ficam no mesmo
## lugar nas duas imagens (tools/modelos_texturizados.py: TEMAS_DO_OBJETO).
const ATLAS := "res://texturas/cenario/atlas_%s.png"
## (a fase de cada objeto, para quem pede o material sem dizer a fase)
const TEMA_DO_MODELO := {"ptero": "dinos", "dino": "dinos", "vulcao": "dinos", "palmeira": "dinos",
	"samambaia": "dinos", "flor_gigante": "dinos", "ovo_dino": "dinos", "pedra": "dinos",
	"saturno": "espaco", "foguete": "espaco", "ovni": "espaco", "planeta": "espaco",
	"estrela_3d": "espaco", "cristal": "espaco", "pedra_lua": "espaco",
	"navio": "mar", "bau": "mar", "bau_tampa": "mar", "coral": "mar", "coral_roxo": "mar", "alga": "mar",
	"estrela_mar": "mar", "concha": "mar", "peixe": "mar", "peixe_azul": "mar", "peixe_amarelo": "mar",
	"agua_viva": "mar", "tartaruga": "mar", "anemona": "mar", "tricera": "dinos", "satelite": "espaco"}


static func tema_do_modelo(nome: String) -> String:
	return TEMA_DO_MODELO.get(nome, "parque")


func _mat_modelo(nome: String, contorno: float, tinta: Color, extra := {}, vento := false, tema := "") -> ShaderMaterial:
	var malha = load("res://modelos/cenario/%s.res" % nome)
	if not (malha is ArrayMesh and (malha as ArrayMesh).surface_get_format(0) & Mesh.ARRAY_FORMAT_TEX_UV):
		return _mat(contorno, tinta, extra)
	if tema == "":
		tema = tema_do_modelo(nome)
	var chave := "atlas_%s%s|%s|%s" % [tema, "_vento" if vento else "", tinta.to_html(), str(extra)]
	if not _mats.has(chave):
		var m := ShaderMaterial.new()
		m.shader = Materiais.shader("res://shaders/toon_leve_tex_vento.shader" if vento else "res://shaders/toon_leve_tex.shader")
		m.set_meta("atlas", true)
		m.set_shader_param("textura", load(ATLAS % tema))
		var p := {"borda": 0.16, "tinta": tinta}
		p.merge(extra, true)
		for k in p:
			if k != "especular" and k != "tamanho_especular":
				m.set_shader_param(k, p[k])
		_mats_leve.append(m)
		_mats[chave] = m
		_aplicar_luz([m])
	return _mats[chave]


## O MATERIAL DO PTERODÁCTILO QUE BATE AS ASAS (7.0, toon_leve_tex_asas): o
## do atlas da fase com as asas girando no ombro; um para cada bicho (cada
## um bate no seu ritmo — asa_tempo, a cada quadro).
func mat_asas(tema: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = Materiais.shader("res://shaders/toon_leve_tex_asas.shader")
	m.set_meta("atlas", true)
	m.set_shader_param("textura", load(ATLAS % tema))
	m.set_shader_param("borda", 0.16)
	m.set_shader_param("tinta", Color.white)
	_mats_leve.append(m)
	_aplicar_luz([m])
	return m


## Toon do cenário: o completo (luz por pixel, contorno) ou o leve (luz por
## vértice; o brilho especular não existe nele).
func _toon(contorno: float, p: Dictionary) -> ShaderMaterial:
	if not leve:
		return Materiais.toon(false, contorno, p)
	var m := ShaderMaterial.new()
	m.shader = Materiais.shader("res://shaders/toon_leve.shader")
	for k in p:
		if k != "especular" and k != "tamanho_especular":
			m.set_shader_param(k, p[k])
	_mats_leve.append(m)
	return m


## Quantas peças de um tipo no cenário leve (pelo menos uma): 65% (7.0;
## eram 45% — as peças de longe agora são bem mais leves, ~18% dos
## triângulos, e o que pesa fica perto da pista).
func _q(n: int) -> int:
	return Compat.imax(1, int(round(n * 0.65))) if leve else n


## A luz da cena para a decoração leve (Mundo.aplicar_tema): para onde está o
## sol, cor x força do sol e do ambiente e a neblina (cores lineares).
func luz(sol_dir: Vector3, sol_cor: Vector3, ambiente: Vector3, neblina_cor: Vector3, neblina_densidade: float) -> void:
	_luz_atual = [sol_dir, sol_cor, ambiente, neblina_cor, neblina_densidade]
	_aplicar_luz(_mats_leve)


## (a luz do cenário de agora: um material criado depois já sai com ela)
var _luz_atual := []


func _aplicar_luz(mats: Array) -> void:
	if _luz_atual.empty():
		return
	var sol_dir: Vector3 = _luz_atual[0]
	var sol_cor: Vector3 = _luz_atual[1]
	var ambiente: Vector3 = _luz_atual[2]
	var neblina_cor: Vector3 = _luz_atual[3]
	var neblina_densidade: float = _luz_atual[4]
	var neblina_tela := _tela_g4(neblina_cor)
	for m in mats:
		m.set_shader_param("sol_dir", sol_dir)
		m.set_shader_param("sol_cor", sol_cor)
		m.set_shader_param("ambiente", ambiente)
		m.set_shader_param("neblina_cor", neblina_cor)
		m.set_shader_param("neblina_tela", neblina_tela)
		m.set_shader_param("neblina_densidade", neblina_densidade)
		if m.has_meta("atlas"):
			_fatores(m, sol_cor, ambiente)


## A LUZ DO MATERIAL JÁ COMO SAI NA TELA (toon_leve_tex): no sol, na
## sombra, o quanto a borda clara soma em cada uma e a das partes que
## brilham — as contas que eram feitas em cada vértice, iguais em todos.
const MEIO := 0.25
const TELA_MEIO := 0.276307


func _fatores(m: ShaderMaterial, sol: Vector3, amb: Vector3) -> void:
	var tinta: Color = _param(m, "tinta", Color.white)
	var lm: float = _param(m, "luz_minima", 0.0)
	var cb: Color = _param(m, "cor_borda", Color(1.0, 0.95, 0.9))
	var borda: float = _param(m, "borda", 0.35)
	var brilho: float = _param(m, "brilho_luz", 1.4)
	var tin := _s2l(Vector3(tinta.r, tinta.g, tinta.b)) * MEIO
	var b := _s2l(Vector3(cb.r, cb.g, cb.b)) * borda
	var no_sol := amb + sol
	var na_sombra := amb + sol * lm
	var f_sol := _tela_g4(tin * no_sol) / TELA_MEIO
	var f_sombra := _tela_g4(tin * na_sombra) / TELA_MEIO
	m.set_shader_param("f_sol", f_sol)
	m.set_shader_param("f_sombra", f_sombra)
	m.set_shader_param("f_borda_sol", _tela_g4(tin * (no_sol + b)) / TELA_MEIO - f_sol)
	m.set_shader_param("f_borda_sombra", _tela_g4(tin * (na_sombra + b)) / TELA_MEIO - f_sombra)
	m.set_shader_param("f_acesa", _tela_g4(tin * (no_sol + Vector3.ONE * brilho)) / TELA_MEIO)


## A força da luz própria (as partes "acesas": lava, cristais) de um
## material do atlas, com a luz do cenário de agora.
func _acender(m: ShaderMaterial, brilho: float) -> void:
	if _luz_atual.empty():
		return
	var tinta: Color = _param(m, "tinta", Color.white)
	var tin := _s2l(Vector3(tinta.r, tinta.g, tinta.b)) * MEIO
	var no_sol: Vector3 = _luz_atual[2] + _luz_atual[1]
	m.set_shader_param("f_acesa", _tela_g4(tin * (no_sol + Vector3.ONE * brilho)) / TELA_MEIO)


static func _param(m: ShaderMaterial, nome: String, padrao):
	var v = m.get_shader_param(nome)
	return padrao if v == null else v


static func _s2l(c: Vector3) -> Vector3:
	return c * (c * (c * 0.305306011 + Vector3.ONE * 0.682171111) + Vector3.ONE * 0.012522878)


## A cor linear como sai na tela (a tela_g4 dos shaders leves: curva do
## Godot 4 + cor viva), aqui na CPU para o que é igual em todos os vértices.
static func _tela_g4(c: Vector3) -> Vector3:
	var x := Vector3(clamp(c.x, 0.0, 1.25), clamp(c.y, 0.0, 1.25), clamp(c.z, 0.0, 1.25))
	x = x * (Vector3.ONE * 1.2094 - x * (Vector3.ONE * 0.015 + x * 0.25))
	var lum := x.dot(Vector3(0.299, 0.587, 0.114))
	var sat: float = max(x.x, max(x.y, x.z)) - min(x.x, min(x.y, x.z))
	x = Vector3.ONE * lum + (x - Vector3.ONE * lum) * (1.14 + 0.34 * (1.0 - sat))
	x = x * 1.08 - Vector3.ONE * 0.045
	return Vector3(clamp(x.x, 0.0, 1.0), clamp(x.y, 0.0, 1.0), clamp(x.z, 0.0, 1.0))


## Um objeto do cenário (res://modelos/cenario/<nome>.res) no grupo do tema.
## AS TRÊS VERSÕES DE CADA OBJETO (7.0): <nome>.res (de perto, a mais
## caprichada), <nome>_meio.res (~45% dos triângulos) e <nome>_longe.res
## (~18%), todas com o mesmo desenho (tools/modelos_texturizados.py). A
## escolha é pelo TAMANHO NA TELA: o raio da peça dividido pela distância
## até a pista (de onde a câmera olha) — acima de PERTO, a de perto; abaixo
## de LONGE, a de longe. De longe a peça ocupa poucos pixels: os
## triângulos a mais só pesariam na placa de vídeo.
## E DOIS NÍVEIS DE CENÁRIO: o ALTO (o normal) e o LEVE, um passo mais
## leve em cada peça (a de perto vira a do meio...). O governador do
## quadro (principal.gd) passa para o leve se a TV Box não segurar os
## quadros com o alto; "Detalhes extras" desligado também. As peças
## paradas têm as duas versões, cada uma no seu lote (os nós "alto" e
## "leve" de cada fase, um visível de cada vez); as que se mexem trocam de
## malha (nivel_cenario).
const PERTO := 0.26
const LONGE := 0.115
const SUFIXOS := ["", "_meio", "_longe"]
var cenario_leve := false
var _duplas := {}         # tema -> [[peça, malha do alto, malha do leve]]
var _trocaveis := {}      # tema -> as duplas que trocam de malha (as que se mexem)


func _malha_nivel(nome: String, raio: float, dist: float, passos: int) -> Mesh:
	var nivel := 0 if raio >= PERTO * dist else (1 if raio >= LONGE * dist else 2)
	nivel = Compat.imin(nivel + passos, 2)
	while nivel > 0:
		var c := "res://modelos/cenario/%s%s.res" % [nome, SUFIXOS[nivel]]
		if ResourceLoader.exists(c):
			return load(c) as Mesh
		nivel -= 1
	return load("res://modelos/cenario/%s.res" % nome) as Mesh


func _obj(tema: String, nome: String, pos: Vector3, rot_y := 0.0, esc := 1.0, contorno := 0.0,
		tinta := Color.white, pai: Spatial = null, dist_lod := -1.0) -> MeshInstance:
	var mi := MeshInstance.new()
	var caminho := "res://modelos/cenario/%s.res" % nome
	var m_leve: Mesh = null
	if ResourceLoader.exists(caminho):
		mi.mesh = load(caminho)
		# (as peças penduradas em outra ficam de perto, a não ser que venha a
		# distância de onde ela fica de verdade: as cabines da roda-gigante, os
		# pterodáctilos que voam em volta de um centro)
		var raio: float = mi.mesh.get_aabb().size.length() * 0.5 * esc
		var dist := dist_lod if dist_lod >= 0.0 else (_ate_pista(pos) if pai == null else 0.0)
		mi.mesh = _malha_nivel(nome, raio, dist, 0)
		m_leve = _malha_nivel(nome, raio, dist, 1)
	var extra := {}
	if tinta == Color.white and TINTA_MODELO.has(nome):
		tinta = TINTA_MODELO[nome][0]
		extra = TINTA_MODELO[nome][1]
	var vento: bool = detalhes and VENTO.has(nome) and mi.mesh != null and pai == null and _ate_pista(pos) < VENTO_PERTO
	if vento:
		mi.mesh = _com_vento(mi.mesh, VENTO[nome])
		m_leve = _com_vento(m_leve, VENTO[nome])
	if m_leve != null and m_leve != mi.mesh:
		_duplas[tema].append([mi, mi.mesh, m_leve])
	mi.material_override = _mat_modelo(nome, contorno, tinta, extra, vento, tema)
	mi.translation = pos
	mi.rotation.y = rot_y
	mi.scale = Vector3.ONE * esc
	# sombra só dos que ficam colados na pista (os de longe não precisam)
	if abs(pos.x) > 3.6 or pos.z < -15.0 or pos.z > 4.0 or pos.y > 1.5:
		mi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	(pai if pai != null else grupos[tema] as Spatial).add_child(mi)
	if nome == "bau":
		_tampa_do_bau(tema, mi)
	return mi


## A TINTA PRÓPRIA de um modelo (7.0): debaixo d'água a luz verde-azulada
## deixava o ouro do baú verde-limão; a tinta quente devolve o dourado e a
## madeira, e a frente dele (virada para quem joga, contra o sol do mar)
## não fica escura demais na sombra. É só uma conta na luz do material,
## nada a mais por pixel. [tinta, parâmetros do material]
## (7.2: o Saturno com a sombra mais clara — de baixo, da pista, a metade
## de baixo dele fica na sombra e escurecia as cores)
const TINTA_MODELO := {"bau": [Color(1.3, 1.0, 0.82), {"luz_minima": 0.6}],
	"saturno": [Color.white, {"luz_minima": 0.64}]}


## VENTO NAS PLANTAS (detalhes extras): [metros que o topo anda, rapidez].
## Balançam no shader (toon_leve_tex_vento.shader) e continuam juntas no
## Lote. Só as de perto da pista (a menos de VENTO_PERTO metros), onde o
## balanço aparece: com um material a mais em cada região do cenário, as
## peças que sobravam sozinhas não se juntavam (até 36 desenhos a mais no
## parque); perto da pista são 1 ou 2 regiões.
const VENTO_PERTO := 9.0
const VENTO := {"palmeira": [0.11, 1.1], "samambaia": [0.05, 1.7], "flor_gigante": [0.06, 1.4],
	"arvore_verde": [0.05, 1.0], "arvore_laranja": [0.05, 1.0], "arvore_escura": [0.05, 1.0],
	"alga": [0.13, 1.2], "coral": [0.025, 0.9], "coral_roxo": [0.03, 0.9]}


## A malha da planta com o quanto cada vértice balança no UV2: nada no pé,
## crescendo com o quadrado da altura até `cfg[0]` metros no topo; y = a
## rapidez. Feita uma vez por malha (a de perto e a de longe).
func _com_vento(m: Mesh, cfg: Array) -> Mesh:
	if _malhas_vento.has(m):
		return _malhas_vento[m]
	var arr := m.surface_get_arrays(0)
	var v: PoolVector3Array = arr[Mesh.ARRAY_VERTEX]
	var caixa := m.get_aabb()
	var alt: float = max(caixa.size.y, 0.001)
	var uv2 := PoolVector2Array()
	uv2.resize(v.size())
	for i in v.size():
		var w: float = clamp((v[i].y - caixa.position.y) / alt, 0.0, 1.0)
		uv2[i] = Vector2(float(cfg[0]) * w * w, float(cfg[1]))
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	var nova := ArrayMesh.new()
	nova.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_malhas_vento[m] = nova
	return nova


## Distância (no chão) até a pista, da linha de falta (z = 4, com quem
## joga) até os pinos (z = -10): de onde a câmera olha.
static func _ate_pista(pos: Vector3) -> float:
	var dz: float = max(pos.z - 4.0, max(-10.0 - pos.z, 0.0))
	# (7.0) a altura também afasta: a nuvem, o pterodáctilo e o planeta lá
	# no alto, bem em cima da pista, ficam pequenos na tela
	return Vector3(pos.x, max(pos.y - 2.0, 0.0), dz).length()


## O BAÚ DO TESOURO: o corpo (com o tesouro dentro: ouro, moedas e joias que
## brilham) e a TAMPA, uma peça à parte com a origem na dobradiça
## (tools/modelos_texturizados.py). 7.0: o baú começa FECHADO e é uma das
## "vozes" do cenário — na vez dele (com ele na tela) a tampa abre com um
## pulinho, o brilho toca e sobem faíscas douradas; fica aberto um tempinho
## mostrando o tesouro, fecha e, mais tarde, abre de novo. A tampa segue o
## corpo onde ele estiver (assentado no chão).
const BAU_DOBRADICA := Vector3(0.0, 0.452, -0.297)
const BAU_ABERTO := -1.85         # giro da tampa aberta (rad), para trás
const BAU_ABRINDO := 0.9          # s abrindo
const BAU_FECHANDO := 0.55        # s fechando
const BAU_MOSTRA := 5.5           # s aberto, mostrando o tesouro


func _tampa_do_bau(tema: String, corpo: MeshInstance) -> void:
	var caminho := "res://modelos/cenario/bau_tampa.res"
	if not ResourceLoader.exists(caminho):
		return
	var t := MeshInstance.new()
	t.mesh = load(caminho)
	t.material_override = corpo.material_override
	t.cast_shadow = corpo.cast_shadow
	corpo.get_parent().add_child(t)
	t.transform = corpo.transform * Transform(Basis(), BAU_DOBRADICA)
	var item := {"tipo": "bau", "no": t, "corpo": corpo, "k": 0.0, "dir": 0, "mostra": 0.0, "faiscas": null}
	if detalhes:
		var f := _particulas(tema, Vector3.ZERO, "faisca", 14, 1.3, 0.16, true)
		f.one_shot = true
		f.explosiveness = 0.6
		f.direction = Vector3.UP
		f.spread = 35.0
		f.gravity = Vector3(0, -1.2, 0)
		Efeitos.faixa(f, "initial_velocity", 1.0, 1.8)
		f.color = Color(1.0, 0.86, 0.35)
		item["faiscas"] = f
	_animar(tema, item)
	_voz(tema, corpo, "brilho", 12.0, 20.0, 0.75, "abrir", item)


func _chao(x: float, z: float) -> float:
	return mundo._altura_terreno(x, z)


func _animar(tema: String, item: Dictionary) -> void:
	_anim[tema].append(item)


## NADA ATRAVESSANDO NADA, TUDO NO CHÃO (7.0): cada peça posta no cenário
## marca o lugar dela (um círculo do tamanho da PEGADA dela, pela caixa do
## modelo e a escala) e nenhuma outra nasce dentro — antes o espaçamento era
## fixo (2,6 m) e o vulcão, o dino, as palmeiras e as pedras se atravessavam.
## E a peça é ASSENTADA no terreno: inclina um pouco com o morro (no
## máximo INCLINA_MAX) e desce até a parte mais baixa debaixo dela encostar
## no chão — nenhum pé no ar.
var _ocupado := {}        # tema -> [[centro (Vector2), raio]]
const INCLINA_MAX := 0.16
const FOLGA_PEGADA := 0.25


## O raio da pegada (no chão) de um modelo com a escala `esc`.
func _pegada(nome: String, esc: float) -> float:
	var c := "res://modelos/cenario/%s.res" % nome
	if not ResourceLoader.exists(c):
		return 0.5 * esc
	var caixa: AABB = (load(c) as Mesh).get_aabb()
	var rx: float = max(abs(caixa.position.x), abs(caixa.end.x))
	var rz: float = max(abs(caixa.position.z), abs(caixa.end.z))
	return sqrt(rx * rx + rz * rz) * 0.82 * esc


func _ocupar(tema: String, centro: Vector2, raio: float) -> void:
	_ocupado[tema].append([centro, raio])


func _livre(tema: String, centro: Vector2, raio: float) -> bool:
	for o in _ocupado[tema]:
		if (o[0] as Vector2).distance_to(centro) < float(o[1]) + raio + FOLGA_PEGADA:
			return false
	return true


## Põe a peça `mi` (já com a escala e o giro) no chão em (x, z): inclina com
## o morro e encosta a parte mais baixa debaixo dela no terreno; `enterrar`:
## quanto ela afunda além disso (as bases largas, um pouquinho).
func _assentar(mi: Spatial, x: float, z: float, raio: float, enterrar := 0.04) -> void:
	var r: float = max(raio * 0.7, 0.15)
	# a subida do terreno debaixo da peça (tangente) e para onde ela sobe
	var g := Vector2(_chao(x + r, z) - _chao(x - r, z), _chao(x, z + r) - _chao(x, z - r)) / (2.0 * r)
	var subida := g.length()
	var dir := g / subida if subida > 0.0001 else Vector2.ZERO
	var ang: float = min(atan(subida), INCLINA_MAX)
	# o que é alto e fino (árvore, palmeira, pirulito) cresce de pé: quase
	# não inclina (o pé desce um pouco mais no morro, nenhum fica no ar)
	if mi is MeshInstance and (mi as MeshInstance).mesh != null:
		var caixa := (mi as MeshInstance).mesh.get_aabb()
		if caixa.size.y > 1.6 * max(caixa.size.x, caixa.size.z):
			ang *= 0.3
	var giro := mi.transform.basis
	if ang > 0.001:
		var normal := Vector3(-dir.x * sin(ang), cos(ang), -dir.y * sin(ang))
		giro = Basis(Vector3.UP.cross(normal).normalized(), ang) * giro
	# a base inclinada sobe tan(ang) por metro na direção da subida: a
	# altura que deixa todos os pontos dela no chão ou abaixo dele
	var t := tan(ang)
	var y := _chao(x, z)
	for k in 12:
		var a: float = TAU * k / 12.0
		var q := Vector2(cos(a), sin(a)) * r
		y = min(y, _chao(x + q.x, z + q.y) - t * q.dot(dir))
	mi.transform = Transform(giro, Vector3(x, y - enterrar, z))


## Espalha objetos pelo terreno, longe da pista (mesma regra do parque),
## sem atravessar nenhuma peça já posta (evitar: mais lugares ocupados,
## Vector2 com raio 1,3 m ou [Vector2, raio]).
func _espalhar(tema: String, tipos: Array, qtd: int, semente: int, escala := {}, evitar: Array = []) -> void:
	var rnd := RandomNumberGenerator.new()
	rnd.seed = semente
	for u in evitar:
		if u is Vector2:
			_ocupar(tema, u, 1.3)
		else:
			_ocupar(tema, u[0], float(u[1]))
	var colocados := 0
	var tentativas := 0
	while colocados < qtd and tentativas < 4000:
		tentativas += 1
		var s := -1.0 if rnd.randf() < 0.5 else 1.0
		var x := s * rnd.randf_range(3.6, 15.0)
		var z := rnd.randf_range(-34.0, 7.0)
		if z > -2.0 and abs(x) < 5.0:
			continue
		var tipo: String = tipos[rnd.randi() % tipos.size()]
		var esc := rnd.randf_range(0.9, 1.35) * float(escala.get(tipo, 1.0))
		var r := _pegada(tipo, esc)
		var p := Vector2(x, z)
		if not _livre(tema, p, r):
			continue
		_ocupar(tema, p, r)
		var mi := _obj(tema, tipo, Vector3(x, 0, z), rnd.randf() * TAU, esc)
		_assentar(mi, x, z, r)
		colocados += 1


## Uma peça grande num lugar escolhido (os destaques de cada fase: vulcão,
## navio, dinos, carrossel, castelo...): assentada no chão e marcando o
## lugar dela. Avisa (no console) se ela atravessa outra já posta.
func _grande(tema: String, nome: String, x: float, z: float, giro := 0.0, esc := 1.0, contorno := 0.0,
		enterrar := 0.06, inclinar := true) -> MeshInstance:
	var r := _pegada(nome, esc)
	if not _livre(tema, Vector2(x, z), r - FOLGA_PEGADA):
		push_warning("cenário %s: %s em (%.1f, %.1f) encosta em outra peça" % [tema, nome, x, z])
	_ocupar(tema, Vector2(x, z), r)
	var mi := _obj(tema, nome, Vector3(x, 0, z), giro, esc, contorno)
	if inclinar:
		_assentar(mi, x, z, r, enterrar)
	else:
		mi.translation = Vector3(x, _mais_baixo(x, z, r * 0.7) - enterrar, z)
	return mi


## Um enfeite num lugar escolhido, SÓ se ali estiver livre (não atravessa
## nada do que já foi posto); assentado no chão.
func _talvez(tema: String, nome: String, x: float, z: float, giro := 0.0, esc := 1.0, contorno := 0.0) -> MeshInstance:
	var r := _pegada(nome, esc)
	if not _livre(tema, Vector2(x, z), r):
		return null
	_ocupar(tema, Vector2(x, z), r)
	var mi := _obj(tema, nome, Vector3(x, 0, z), giro, esc, contorno)
	_assentar(mi, x, z, r, 0.02)
	return mi


## A altura mais baixa do terreno num círculo (o que não pode inclinar
## encosta ali: nada fica no ar).
## A altura que deixa a QUILHA de uma peça comprida (já girada e escalada,
## pontos do modelo de z = de até z = ate, largura ±meia) toda no chão ou
## abaixo dele: nenhum pedaço dela fica no ar.
func _pousar_quilha(mi: Spatial, de: float, ate: float, meia: float) -> float:
	var y := INF
	var b := mi.transform.basis
	for k in 8:
		var z: float = lerp(de, ate, k / 7.0)
		for l in [-meia, 0.0, meia]:
			var w := b.xform(Vector3(l, 0, z))
			y = min(y, _chao(mi.translation.x + w.x, mi.translation.z + w.z) - w.y)
	return y


func _mais_baixo(x: float, z: float, r: float) -> float:
	var y := _chao(x, z)
	for k in 12:
		var a: float = TAU * k / 12.0
		y = min(y, _chao(x + cos(a) * r, z + sin(a) * r))
	return y


func _destaques(tema: String, itens: Array) -> Array:
	# itens: [nome, escala, contorno] na ordem de DESTAQUES (assentados no
	# chão e marcando o lugar: o que vem depois não nasce dentro deles)
	var feitos := []
	for i in Compat.imin(itens.size(), DESTAQUES.size()):
		var d: Array = DESTAQUES[i]
		var it: Array = itens[i]
		var x: float = d[0]
		var z: float = d[1]
		var r := _pegada(it[0], float(it[1]))
		_ocupar(tema, Vector2(x, z), r)
		var mi := _obj(tema, it[0], Vector3(x, -0.02, z), d[2], it[1], it[2] if it.size() > 2 else 0.0)
		if not (z > 0.0 and abs(x) < 3.3):
			_assentar(mi, x, z, r, 0.02)
		feitos.append(mi)
	return feitos


## ENFEITES QUE SE MEXEM (detalhes extras): alguns dos destaques, os que
## ficam pertinho da pista, ganham uma animação própria — `qual` diz o
## índice em DESTAQUES e o jeito ("pular", "chocar", "levitar", "girar",
## "olhar", "pulsar"). Cada um sai do Lote (um desenho a mais): poucos.
func _vida(tema: String, feitos: Array, qual: Dictionary) -> void:
	if not detalhes:
		return
	var i := 0
	for k in qual:
		var no: Spatial = feitos[k]
		var item := {"tipo": qual[k], "no": no, "base": no.translation, "giro": no.rotation.y, "fase": i * 1.37, "cada": 3.6 + i * 0.7}
		match qual[k]:
			"pular":
				item["altura"] = 0.16
			"chocar":
				item["cada"] = 4.5 + i * 1.1
			"levitar":
				item["vel"] = 0.9 + 0.2 * i
			"girar":
				item["vel"] = 0.35 if i % 2 == 0 else -0.3
			"olhar":
				item["vel"] = 0.5 + 0.15 * i
			"brilhar":
				# (cada cristal com o material dele: a luz própria pulsa sozinha)
				var mi := no as MeshInstance
				var m := (mi.material_override as ShaderMaterial).duplicate() as ShaderMaterial
				m.set_meta("atlas", true)
				mi.material_override = m
				_mats_leve.append(m)
				_aplicar_luz([m])
				item["mat"] = m
		_animar(tema, item)
		i += 1


## Lugares atrás da mureta dos jogadores (x, z, giro).
const ATRAS := [[-5.4, 10.6, 0.4], [5.3, 11.2, -0.5], [-2.5, 12.9, 0.2], [2.6, 13.6, -0.2], [-8.6, 13.2, 0.8], [8.4, 12.4, -0.9]]


func _atras(tema: String, itens: Array) -> void:
	for i in Compat.imin(itens.size(), ATRAS.size()):
		var a: Array = ATRAS[i]
		var x: float = a[0]
		var z: float = a[1]
		_obj(tema, itens[i][0], Vector3(x, _chao(x, z) - 0.05, z), PI + float(a[2]), float(itens[i][1]))


func _torres(tema: String, nome: String, esc := 1.0, contorno := 0.004) -> void:
	for s in [-1.0, 1.0]:
		var x: float = s * 2.75
		_ocupar(tema, Vector2(x, Medidas.Z_FUNDO + 0.4), _pegada(nome, esc))
		_obj(tema, nome, Vector3(x, -0.02, Medidas.Z_FUNDO + 0.4), -s * deg2rad(25.0), esc, contorno)


## Uma peça comprida (o navio, o arco-íris, a roda-gigante): círculos de
## `raio` ao longo dela, de `a` até `b`.
func _ocupar_linha(tema: String, a: Vector2, b: Vector2, raio: float) -> void:
	var n := Compat.imax(int(ceil(a.distance_to(b) / raio)), 1)
	for i in n + 1:
		_ocupar(tema, a.linear_interpolate(b, float(i) / n), raio)


func _particulas(tema: String, pos: Vector3, textura: String, qtd: int, vida: float, tam: float, somar := false) -> CPUParticles:
	var p := CPUParticles.new()
	p.amount = qtd
	p.lifetime = vida
	p.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(tam, tam)
	q.material = Materiais.particula(textura, somar)
	p.mesh = q
	p.translation = pos
	p.emitting = false
	(grupos[tema] as Spatial).add_child(p)
	_animar(tema, {"tipo": "nada", "particulas": p})
	return p


# ================================================================ PARQUE
func _parque() -> void:
	var T := "parque"
	# (7.0: primeiro as peças grandes, cada uma marcando o lugar dela; depois
	# os destaques perto da pista; por último as espalhadas, que não nascem
	# dentro de nenhuma)
	# arco-íris com lâmpadas e torres de circo
	_obj(T, "arco_iris", Vector3(0, -0.05, Medidas.Z_FUNDO - 0.5), 0.0, 0.95, 0.0, Color.white)
	_ocupar_linha(T, Vector2(-3.1, Medidas.Z_FUNDO - 0.5), Vector2(3.1, Medidas.Z_FUNDO - 0.5), 0.45)
	var R := 3.0 * 0.95 - 0.42 * 0.95 - 0.08
	var pontos: Array = []
	for i in 40:
		var a: float = PI * (i + 0.5) / 40.0
		pontos.append(Vector3(cos(a) * R, sin(a) * R - 0.05, Medidas.Z_FUNDO - 0.5 + 0.38))
	grupos[T].add_child(mundo.lampadas_em(pontos, 100))
	_torres(T, "torre")
	# CASTELO de conto de fadas no alto do morro, lá no fundo à direita (7.0:
	# era uma pintura no fundo; agora é 3D como o resto)
	_grande(T, "castelo", 14.5, -49.0, -0.35, 1.15, 0.0, 0.3)
	# roda-gigante (gira) com as cabines sempre de pé
	var rx := -6.8
	var rz := -27.0
	var rg := Spatial.new()
	rg.translation = Vector3(rx, _mais_baixo(rx, rz, 2.0) - 0.05, rz)
	rg.rotation.y = 0.35
	grupos[T].add_child(rg)
	var ao_lado := Vector2(cos(0.35), -sin(0.35)) * 3.4
	_ocupar_linha(T, Vector2(rx, rz) - ao_lado, Vector2(rx, rz) + ao_lado, 1.3)
	_obj(T, "roda_base", Vector3.ZERO, 0.0, 1.0, 0.0, Color.white, rg)
	var eixo := Spatial.new()
	eixo.translation = Vector3(0, 4.6, 0)
	rg.add_child(eixo)
	var roda := _obj(T, "roda", Vector3.ZERO, 0.0, 1.0, 0.0, Color.white, eixo)
	var cabines := []
	var longe_roda := _ate_pista(rg.translation + Vector3(0, 4.6, 0))
	for i in 8:
		var c := _obj(T, "cabine", Vector3.ZERO, 0.0, 1.0, 0.0, CORES_BICHOS[i % CORES_BICHOS.size()], eixo, longe_roda)
		cabines.append(c)
	_animar(T, {"tipo": "roda", "roda": roda, "cabines": cabines, "raio": 3.8, "vel": 0.16})
	# carrossel (gira devagar, sem inclinar) e tendas
	var car := _grande(T, "carrossel", 6.4, -21.0, 0.0, 1.2, 0.0, 0.05, false)
	var gira_car := {"tipo": "girar", "no": car, "vel": 0.5}
	_animar(T, gira_car)
	_voz(T, car, "amb_carrossel", 16.0, 26.0, 0.7, "musica", gira_car)
	_grande(T, "tenda", -9.5, -13.0, 0.6, 1.1, 0.0, 0.08)
	_grande(T, "tenda", 10.5, -33.0, -0.4, 1.3, 0.0, 0.08)
	var car2 := _grande(T, "carrossel", -12.5, -39.0, 0.0, 1.0, 0.0, 0.05, false)
	_animar(T, {"tipo": "girar", "no": car2, "vel": -0.35})
	var d := _destaques(T, [["pirulito", 0.75, 0.004], ["pirulito", 0.85, 0.004], ["presente", 0.8, 0.004], ["cupcake", 0.75, 0.004],
		["bengala", 0.9], ["bengala", 0.9], ["cogumelo", 0.9], ["donut", 0.85]])
	# pirulitos virando de um lado para o outro, presente e cogumelo pulando,
	# cupcake fofinho e a rosquinha girando
	_vida(T, d, {0: "olhar", 1: "olhar", 2: "pular", 3: "pulsar", 6: "pular", 7: "girar"})
	# (7.0) POSTES DE LUZ dos dois lados da pista (a lâmpada brilha), com
	# canteiros de flores e arbustos floridos entre eles
	for z in [1.0, -3.6, -8.2]:
		for s_ in [-1.0, 1.0]:
			_talvez(T, "poste", s_ * 3.55, z, PI / 2 * s_, 1.0)
	for p_ in [[-3.3, -2.4], [3.4, -5.6], [-3.6, -9.6], [3.7, 0.2], [-4.6, 1.0], [4.8, -1.5]]:
		_talvez(T, "flores" if int(p_[1]) % 2 == 0 else "arbusto", p_[0], p_[1], p_[0] * 0.7, 0.9)
	_espalhar(T, ["arvore_verde", "arvore_laranja", "arvore_escura", "pirulito", "cogumelo", "bengala",
		"presente", "donut", "cupcake", "arvore_verde", "arvore_escura", "arvore_laranja", "arbusto", "flores",
		"arbusto", "flores"], _q(60), 2026,
		{"arvore_verde": 1.25, "arvore_laranja": 1.25, "arvore_escura": 1.25, "arbusto": 1.1})
	_nuvens(T, 14, 77)
	_baloes(T)
	_borboletas(T, 3 if leve else 5, 31)


func _nuvens(tema: String, qtd: int, semente: int) -> void:
	var rnd := RandomNumberGenerator.new()
	rnd.seed = semente
	var mat := _toon(0.0, {"borda": 0.6, "luz_minima": 0.5, "cor_borda": Color(0.9, 0.96, 1)})
	for i in _q(qtd):
		var lado := -1.0 if i % 2 == 0 else 1.0
		var pos := Vector3(lado * rnd.randf_range(4.0, 22.0), rnd.randf_range(6.0, 15.0), rnd.randf_range(-60.0, -8.0))
		var esc := rnd.randf_range(1.2, 2.6)
		pos.y = _altura_nuvem(tema, pos, esc)
		var n := _obj(tema, "nuvem", pos, 0.0, esc)
		n.material_override = mat
		n.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
		n.rotation.y = rnd.randf() * TAU
		_animar(tema, {"tipo": "nuvem", "no": n, "vel": rnd.randf_range(0.15, 0.4)})


## A altura de uma NUVEM (7.2: elas iam de 6 a 15 m e, andando de um lado
## ao outro, raspavam nos morros e no vulcão — de longe pareciam pousadas no
## chão). A nuvem anda de x = -30 a 30 (_process, "nuvem"): a base dela fica
## pelo menos 6 m acima do ponto mais alto do terreno em todo o caminho e
## acima das peças altas (vulcão, castelo, roda-gigante) que estão na mesma
## faixa de z. (Malha: base em y = 0,26, meia largura 2, meia fundura 0,95.)
func _altura_nuvem(tema: String, pos: Vector3, esc: float) -> float:
	var base := pos.y + 6.0
	for k in 31:
		base = max(base, _chao(-30.0 + 2.0 * k, pos.z) + 6.0)
	var meia_z := 0.95 * esc
	for c in (grupos[tema] as Spatial).get_children():
		if not (c is MeshInstance) or (c as MeshInstance).mesh == null:
			continue
		var caixa: AABB = (c as Spatial).transform.xform((c as MeshInstance).mesh.get_aabb())
		if caixa.size.y < 4.0:
			continue
		if abs(caixa.position.z + caixa.size.z * 0.5 - pos.z) < caixa.size.z * 0.5 + meia_z:
			base = max(base, caixa.end.y + 2.0)
	return base - 0.26 * esc


func _baloes(tema: String) -> void:
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 91
	var mb: Mesh = load("res://modelos/cenario/balao.res")
	var cores := [Color("#FF4B5C"), Color("#FFD43B"), Color("#4FC3F7"), Color("#5ED16A"), Color("#2E7BFF"), Color("#FF9F2E")]
	var linha_mat := _toon(0.0, {"tinta": Color("#FFFFFF"), "borda": 0.0})
	for i in (8 if leve else 16):
		var b := Spatial.new()
		var mi := MeshInstance.new()
		mi.mesh = mb
		mi.material_override = _mat_modelo("balao", 0.0, cores[i % cores.size()], {"borda": 0.6, "especular": 0.8, "tamanho_especular": 0.95}, false, tema)
		b.add_child(mi)
		var fio := MeshInstance.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.004
		cm.bottom_radius = 0.004
		cm.height = 0.9
		cm.radial_segments = 4
		fio.mesh = cm
		fio.translation.y = -0.45
		fio.material_override = linha_mat
		b.add_child(fio)
		var lado := -1.0 if i % 2 == 0 else 1.0
		var base := Vector3(lado * rnd.randf_range(1.8, 5.5), rnd.randf_range(2.2, 4.8), rnd.randf_range(-19.0, -4.0))
		if i < 4:
			base = Vector3(lado * rnd.randf_range(2.0, 2.8), rnd.randf_range(2.6, 3.4), Medidas.Z_FUNDO + rnd.randf_range(0.0, 1.5))
		b.translation = base
		b.scale = Vector3.ONE * rnd.randf_range(0.8, 1.15)
		grupos[tema].add_child(b)
		_animar(tema, {"tipo": "boiar", "no": b, "base": base, "fase": rnd.randf() * TAU, "vel": rnd.randf_range(0.6, 1.1),
			"amp": Vector3(0.12, 0.18, 0.0), "balanco": 0.12})


# ================================================================ ESPAÇO
func _espaco() -> void:
	var T := "espaco"
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 404
	# SATURNO atrás dos pinos, por cima do letreiro (7.2: no lugar do planeta
	# azul com anel de arco-íris, que parecia um adesivo e saiu; o Saturno
	# ficava lá no fundo do céu). Caprichado: a versão de perto sempre (9.000
	# triângulos, textura 2048 — tools/modelos_texturizados.py: ALVO). O anel
	# vem inclinado para a frente na malha (tools/cenario_sdf/temas.py) e aqui
	# inclina mais ~19° para a pista (que o vê de baixo): aparece a face de
	# cima do anel, dourada, numa elipse aberta, e ele tomba de leve para a
	# direita.
	# Gira em volta do eixo do ANEL: o anel fica sempre igual e as faixas do
	# planeta é que passam. A LUA fica lá no alto, à direita (Mundo.ASTROS):
	# o Saturno perto, a lua longe — a profundidade, sem um tapar o outro.
	var sat := _obj(T, "saturno", Vector3(0.3, 6.4, Medidas.Z_FUNDO - 3.6), 0.0, 1.75, 0.0, Color.white, null, 0.0)
	sat.rotation = Vector3(0.33, 0.0, -0.2)
	_animar(T, {"tipo": "girar_proprio", "no": sat, "vel": 0.1, "eixo": Vector3(-0.218, 0.891, 0.398).normalized()})
	# dois foguetes em pé no chão, ao lado do gabinete, inteiros à vista
	# (atrás das colunas só aparecia a pontinha das aletas)
	for s in [-1.0, 1.0]:
		_grande(T, "foguete", s * 3.35, -11.0, -s * deg2rad(35.0), 0.95, 0.004, 0.03, false)
	# disco voador passeando por cima do fim da pista: na FRENTE do Saturno
	# e acima do letreiro (nunca atravessa o planeta nem some atrás do arco),
	# inclinando nas curvas como um aviãozinho
	var ovni := _obj(T, "ovni", Vector3(0, 5.0, -12.1), 0.0, 1.0, 0.004)
	var voo_ovni := {"tipo": "passeio", "no": ovni, "centro": Vector3(0, 5.0, -12.1), "raio": Vector3(3.1, 0.25, 0.65),
		"vel": 0.3, "girar": 1.6, "ang": 0.0}
	_animar(T, voo_ovni)
	_voz(T, ovni, "amb_ovni", 12.0, 20.0, 0.75, "balancar", voo_ovni)
	# (7.0) um SATÉLITE fofinho dando a volta no céu, girando devagar
	var sat2 := _obj(T, "satelite", Vector3(0, 9.0, -20.0), 0.0, 1.3, 0.003)
	sat2.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	_animar(T, {"tipo": "orbita", "no": sat2, "centro": Vector3(0.0, 9.5, -22.0), "raio": Vector2(10.0, 7.0),
		"sobe": 0.6, "girar": 0.25, "vel": 0.12, "fase": 1.0})
	# planetinhas coloridos no céu
	for i in _q(8):
		var lado := -1.0 if i % 2 == 0 else 1.0
		var pos := Vector3(lado * rnd.randf_range(6.0, 22.0), rnd.randf_range(5.0, 15.0), rnd.randf_range(-58.0, -14.0))
		var pl := _obj(T, "planeta", pos, rnd.randf() * TAU, rnd.randf_range(1.6, 4.2), 0.0, CORES_BICHOS[i % CORES_BICHOS.size()])
		pl.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
		_animar(T, {"tipo": "girar", "no": pl, "vel": rnd.randf_range(0.05, 0.2)})
	# estrelas fofas flutuando ao lado da pista
	for i in _q(6):
		var lado := -1.0 if i % 2 == 0 else 1.0
		var base := Vector3(lado * rnd.randf_range(2.1, 3.4), rnd.randf_range(2.2, 3.8), rnd.randf_range(-17.0, -3.0))
		var e := _obj(T, "estrela_3d", base, 0.0, rnd.randf_range(0.6, 0.9), 0.003)
		# balança de um lado para o outro (girando inteira ela ficava de
		# perfil, um palitinho amarelo)
		var boia := {"tipo": "boiar", "no": e, "base": base, "fase": rnd.randf() * TAU, "vel": rnd.randf_range(0.7, 1.1),
			"amp": Vector3(0.0, 0.2, 0.0), "olhar": -lado * 0.35, "vira": 0.45}
		_animar(T, boia)
		if i < 3:
			_voz(T, e, "amb_estrela", 14.0, 24.0, 0.55, "piruetar", boia)
	var d := _destaques(T, [["cristal", 0.9, 0.004], ["cristal", 1.0, 0.004], ["pedra_lua", 1.0, 0.004], ["cristal", 0.8, 0.004],
		["pedra_lua", 1.1], ["cristal", 1.0], ["pedra_lua", 1.0], ["cristal", 1.1]])
	# os cristais de perto da pista BRILHAM (7.0: não flutuam mais — paradinhos
	# no chão, só a luz deles pulsa, cada um no seu tempo)
	_vida(T, d, {0: "brilhar", 1: "brilhar", 3: "brilhar", 5: "brilhar", 7: "brilhar"})
	_espalhar(T, ["cristal", "pedra_lua", "cristal", "pedra_lua", "pedra_lua", "foguete"], _q(46), 77,
		{"cristal": 1.3, "pedra_lua": 1.6, "foguete": 0.8})
	# estrelas cadentes de vez em quando (faíscas que atravessam o céu)
	var cad := _particulas(T, Vector3(0, 13.0, -30.0), "faisca", 3, 1.6, 0.6, true)
	cad.emission_shape = CPUParticles.EMISSION_SHAPE_BOX
	cad.emission_box_extents = Vector3(14, 3, 8)
	cad.direction = Vector3(1, -0.35, 0)
	cad.spread = 5.0
	cad.gravity = Vector3.ZERO
	Efeitos.faixa(cad, "initial_velocity", 14.0, 18.0)
	cad.color = Color(1.0, 0.95, 0.8)


# ================================================================ FUNDO DO MAR
func _mar() -> void:
	var T := "mar"
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 505
	# NAVIO PIRATA naufragado, inteiro, pousado na areia À ESQUERDA do
	# gabinete, de lado para quem olha (6.8; antes ficava escondido atrás do
	# gabinete, só os mastros por cima do arco): na espera, na escolha e no
	# fim ele aparece inteiro, de perfil, emoldurando o gabinete; na vista
	# da pista, a proa, os mastros e a bandeira de caveira à esquerda. Do
	# outro lado ficam a baleia (no alto) e o baú (perto da pista).
	# (7.0) POUSADO NO ALTO DO MORRO: em x = -6 o casco ficava na rampa entre
	# a pista e o morro (2,7 m de desnível de uma ponta à outra) e, posto
	# com os pés no chão, sumia enterrado. No alto do morro o chão é quase
	# plano: a quilha encosta inteira na areia, de proa um pouquinho para
	# baixo (como o morro desce para a pista).
	var nx := -9.5
	var nz := -22.5
	var giro := deg2rad(90.0)
	var navio := _obj(T, "navio", Vector3(nx, 0, nz), giro, 1.05, 0.004)
	navio.rotation = Vector3(deg2rad(4.0), giro, 0.0)
	navio.translation.y = _pousar_quilha(navio, -2.0, 1.5, 0.6) + 0.06
	# (o comprido do navio, girado: nada nasce dentro dele)
	var proa := Vector2(sin(giro), cos(giro)) * 1.05
	_ocupar_linha(T, Vector2(nx, nz) + proa * -3.0, Vector2(nx, nz) + proa * 4.1, 1.3)
	# o BAÚ DO TESOURO pertinho da pista, do lado direito, virado para quem
	# joga (lá atrás dos jogadores e no canto ninguém via): começa FECHADO,
	# abre a tampa e mostra as moedas e as joias, fecha e abre de novo
	_grande(T, "bau", BAU_PERTO.x, BAU_PERTO.z, -0.5, 0.75, 0.004, 0.02, false)
	# corais no lugar das torres
	for s_ in [-1.0, 1.0]:
		_ocupar(T, Vector2(s_ * 2.75, Medidas.Z_FUNDO + 0.4), 1.1)
	_obj(T, "coral", Vector3(-2.75, -0.02, Medidas.Z_FUNDO + 0.4), deg2rad(25.0), 2.1, 0.004)
	_obj(T, "coral_roxo", Vector3(2.75, -0.02, Medidas.Z_FUNDO + 0.4), deg2rad(-25.0), 2.3, 0.004)
	var d := _destaques(T, [["coral", 0.8, 0.004], ["alga", 0.8, 0.0], ["estrela_mar", 1.0, 0.004], ["concha", 0.8, 0.004],
		["coral_roxo", 0.9], ["alga", 0.9], ["concha", 0.5], ["estrela_mar", 1.0]])
	# (7.0) ANÊMONAS cor-de-rosa perto da pista
	for p_ in [[-3.4, -3.0], [3.5, -7.2], [-3.7, 0.8], [3.6, 1.5]]:
		_talvez(T, "anemona", p_[0], p_[1], p_[0], 1.2, 0.003)
	_espalhar(T, ["coral", "coral_roxo", "alga", "alga", "estrela_mar", "concha", "pedra", "coral", "anemona",
		"anemona"], _q(60), 31,
		{"coral": 1.5, "coral_roxo": 1.5, "alga": 1.3, "estrela_mar": 1.6, "concha": 0.7, "pedra": 1.2, "anemona": 1.4})
	# conchas abrindo e fechando de leve e o navio balançando no fundo
	_vida(T, d, {3: "pulsar", 6: "pulsar"})
	if detalhes:
		_animar(T, {"tipo": "navio", "no": navio, "base": navio.rotation})
	# algas balançando na correnteza (as dos destaques e mais algumas). As de
	# perto da pista, com os detalhes extras, balançam no shader (vento): a
	# malha delas é outra (com o UV2) e elas ficam no Lote
	for g in grupos[T].get_children():
		if g is MeshInstance and (g as MeshInstance).mesh != null and (g as MeshInstance).mesh.resource_path.get_file().begins_with("alga"):
			_animar(T, {"tipo": "alga", "no": g, "fase": rnd.randf() * TAU, "base": (g as Spatial).rotation})
	# CARDUMES de peixinhos (6.9): cada cardume de uma espécie, com as cores
	# dela (palhaço, azul, amarelo) — eram bolotas brancas tingidas; 4 de 4
	# (eram 5 de 5: cada peixe é um desenho a mais e eles têm mais forma)
	var especies := ["peixe", "peixe_azul", "peixe_amarelo", "peixe"]
	for c in (3 if leve else 4):
		var centro := Vector3((-1.0 if c % 2 == 0 else 1.0) * rnd.randf_range(3.0, 7.0), rnd.randf_range(2.6, 5.5), rnd.randf_range(-20.0, -4.0))
		var especie: String = especies[c % especies.size()]
		var vel := rnd.randf_range(0.25, 0.45) * (1.0 if c % 2 == 0 else -1.0)
		for k in (3 if leve else 4):
			var p := _obj(T, especie, centro, 0.0, rnd.randf_range(0.75, 1.05), 0.003)
			_animar(T, {"tipo": "peixe", "no": p, "centro": centro + Vector3(rnd.randf_range(-0.4, 0.4), rnd.randf_range(-0.3, 0.3), 0),
				"raio": Vector2(rnd.randf_range(2.2, 3.0), rnd.randf_range(1.4, 2.0)), "vel": vel, "fase": k * 0.22, "nado": rnd.randf() * TAU})
			if k == 0:
				_voz(T, p, "amb_peixe", 12.0, 22.0, 0.6)
	# águas-vivas subindo e descendo
	for i in _q(7):
		var lado := -1.0 if i % 2 == 0 else 1.0
		var base := Vector3(lado * rnd.randf_range(2.2, 5.0), rnd.randf_range(2.4, 5.2), rnd.randf_range(-19.0, -2.0))
		var cor: Color = [Color("#FFB36B"), Color("#9FF0C8"), Color("#8FE9FF")][i % 3]
		var av := _obj(T, "agua_viva", base, 0.0, rnd.randf_range(0.7, 1.0), 0.003, cor)
		_animar(T, {"tipo": "agua_viva", "no": av, "base": base, "fase": rnd.randf() * TAU, "vel": rnd.randf_range(0.8, 1.2)})
	# a BALEIA canta lá no alto (ela é do Mundo, desenhada no céu)
	_voz(T, _emissor(T, Vector3(4.0, 16.0, -40.0)), "amb_baleia", 17.0, 27.0, 0.75, "baleia")
	# tartarugas atravessando o mar lá no alto
	# (a primeira passa mais perto e mais baixo, bem à vista de quem joga)
	for i in _q(2):
		var tt := _obj(T, "tartaruga", Vector3(0, 5.6 + i * 3.0, -17.0 - i * 13.0), PI / 2 * (1 if i == 0 else -1), 1.5 + i * 0.7)
		_animar(T, {"tipo": "atravessar", "no": tt, "vel": 1.1 * (1 if i == 0 else -1), "limite": 28.0})
	# bolhas subindo
	for i in (3 if leve else 8):
		var lado := -1.0 if i % 2 == 0 else 1.0
		var pos := Vector3(lado * rnd.randf_range(1.8, 6.0), 0.1, rnd.randf_range(-18.0, 1.0))
		var b := _particulas(T, pos, "bolha", 10, 4.0, 0.16)
		if i % 3 == 0:
			_voz(T, _emissor(T, pos + Vector3(0, 1.5, 0)), "amb_bolhas", 9.0, 16.0, 0.5)
		b.direction = Vector3.UP
		b.spread = 12.0
		b.gravity = Vector3(0, 0.25, 0)
		Efeitos.faixa(b, "initial_velocity", 0.5, 0.9)
		Efeitos.faixa_escala(b, 0.4, 1.4)
		b.emission_shape = CPUParticles.EMISSION_SHAPE_SPHERE
		b.emission_sphere_radius = 0.25
		b.color = Color(0.85, 1.0, 1.0, 0.85)


# ================================================================ SELVA DOS DINOS
func _dinos() -> void:
	var T := "dinos"
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 606
	# VULCÃO fumegando À ESQUERDA do gabinete, inteiro à vista de quem joga
	# (6.9; antes ficava bem atrás do gabinete, como o navio do mar, e só
	# a fumaça aparecia); o menor, do outro lado
	var vx := -11.0
	var vz := -36.0
	var vulcao := _grande(T, "vulcao", vx, vz, 0.3, 2.1, 0.0, 0.4, false)
	_grande(T, "vulcao", 17.0, -46.0, -0.5, 1.1, 0.0, 0.3, false)
	var fum := _particulas(T, vulcao.translation + Vector3(0.0, 10.6, 0.0), "fumaca", 8 if leve else 14, 5.0, 2.4)
	# de vez em quando ele ronca, treme e solta fumaça mais depressa
	var ronco := {"tipo": "vulcao", "no": vulcao, "base": vulcao.translation, "fumaca": fum, "tremer": 0.0}
	_animar(T, ronco)
	_voz(T, vulcao, "amb_vulcao", 18.0, 28.0, 0.8, "tremer", ronco)
	fum.direction = Vector3(0.25, 1, 0)
	fum.spread = 18.0
	fum.gravity = Vector3(0.15, 0.15, 0)
	Efeitos.faixa(fum, "initial_velocity", 0.8, 1.3)
	Efeitos.faixa_escala(fum, 0.8, 1.6)
	var cf := Curve.new()
	cf.add_point(Vector2(0, 0.4))
	cf.add_point(Vector2(1, 1.6))
	fum.scale_amount_curve = cf
	var gf := Gradient.new()
	gf.set_color(0, Color(0.95, 0.9, 0.95, 0.85))
	gf.set_color(1, Color(0.85, 0.85, 0.95, 0.0))
	fum.color_ramp = gf
	# palmeiras no lugar das torres
	_torres(T, "palmeira", 0.85, 0.0)
	# dino pescoçudo à direita do gabinete, olhando a pista (7.0: longe da
	# palmeira, que atravessava a cabeça dele) + outro, maior, à esquerda,
	# na frente do vulcão (antes ele ficava DENTRO do vulcão)
	var dino := _grande(T, "dino", 5.4, -17.8, -0.85, 1.0, 0.004, 0.03, false)
	var resp1 := {"tipo": "respirar", "no": dino, "fase": 0.0, "giro": dino.rotation.y}
	_animar(T, resp1)
	var dino2 := _grande(T, "dino", -5.6, -21.5, 0.75, 1.45, 0.0, 0.04, false)
	var resp2 := {"tipo": "respirar", "no": dino2, "fase": 1.7, "giro": dino2.rotation.y}
	_animar(T, resp2)
	# o dino levanta a cabeça e ruge (o de perto mais vezes)
	_voz(T, dino, "amb_dino", 13.0, 20.0, 0.85, "rugir", resp1)
	_voz(T, dino2, "amb_dino", 20.0, 30.0, 0.7, "rugir", resp2, 0.85)
	_voz(T, _emissor(T, Vector3(-3.6, 2.5, -9.0)), "amb_passaros", 11.0, 19.0, 0.55)
	_voz(T, _emissor(T, Vector3(4.2, 2.8, -15.0)), "amb_passaros", 13.0, 21.0, 0.5)
	# pterossauros voando em círculos
	# (7.0: batendo as asas — mat_asas — e o corpo subindo e descendo no ritmo)
	for i in _q(3):
		var esc_p := rnd.randf_range(0.9, 1.3)
		var tom := rnd.randf_range(0.9, 1.1)
		var centro := Vector3(rnd.randf_range(-3.0, 3.0), rnd.randf_range(6.0, 8.5), rnd.randf_range(-22.0, -9.0))
		# (o detalhe pela distância do centro do voo, lá no alto)
		var p := _obj(T, "ptero", Vector3.ZERO, 0.0, esc_p, 0.003, Color.white, null, _ate_pista(centro))
		var ma := mat_asas(T)
		p.material_override = ma
		_voz(T, p, "amb_ptero", 10.0, 18.0, 0.7, "", null, tom)
		_animar(T, {"tipo": "voo", "no": p, "centro": centro,
			"raio": rnd.randf_range(4.0, 7.0), "vel": rnd.randf_range(0.25, 0.4) * (1.0 if i % 2 == 0 else -1.0), "fase": rnd.randf() * TAU,
			"mat": ma, "asas": rnd.randf_range(5.5, 7.0)})
	var d := _destaques(T, [["samambaia", 1.0, 0.004], ["flor_gigante", 1.0, 0.004], ["ovo_dino", 1.0, 0.004], ["flor_gigante", 0.9, 0.004],
		["samambaia", 1.2], ["pedra", 1.0], ["ovo_dino", 1.0], ["samambaia", 1.1]])
	# (o vulcão, os dinos e as palmeiras do gabinete já marcaram o lugar
	# deles: nada nasce dentro)
	# (7.0) um FILHOTE DE TRICERÁTOPS à esquerda da pista, olhando quem joga
	var tri := _grande(T, "tricera", -5.0, -8.5, 0.95, 1.0, 0.004, 0.03, false)
	var resp3 := {"tipo": "respirar", "no": tri, "fase": 0.9, "giro": tri.rotation.y}
	_animar(T, resp3)
	_voz(T, tri, "amb_dino", 15.0, 24.0, 0.7, "rugir", resp3, 1.35)
	for p_ in [[3.5, -4.6], [-3.5, 1.2], [3.8, 1.8], [-3.4, -11.2]]:
		_talvez(T, "arbusto", p_[0], p_[1], p_[0], 0.95)
	_espalhar(T, ["palmeira", "samambaia", "pedra", "flor_gigante", "samambaia", "palmeira", "ovo_dino", "pedra",
		"arbusto", "arbusto"], _q(60), 2027,
		{"palmeira": 1.0, "samambaia": 1.4, "pedra": 1.3, "flor_gigante": 1.3, "ovo_dino": 1.2, "arbusto": 1.2})
	# os ovos de dinossauro tremem de vez em quando (alguém quer nascer!)
	_vida(T, d, {2: "chocar", 6: "chocar"})
	_borboletas(T, 3 if leve else 5, 47)
	_nuvens(T, 10, 88)


# ================================================================ borboletas
## BORBOLETAS (detalhes extras) voando sem pressa dos lados da pista, à vista
## de quem joga: cada uma é uma malha de 28 triângulos (cor nos vértices) e
## um desenho; as asas batem no shader (borboleta.shader).
const CORES_BORBOLETA := [[Color("#FFE14D"), Color("#FF7A1A")], [Color("#FFB3E6"), Color("#C22EFF")],
	[Color("#9BF0FF"), Color("#1E7BFF")], [Color("#C8FF8A"), Color("#2DB84A")]]
var _malhas_borboleta := []
var _mat_borboleta: ShaderMaterial


func _borboletas(tema: String, qtd: int, semente: int) -> void:
	if not detalhes:
		return
	if _malhas_borboleta.empty():
		for par in CORES_BORBOLETA:
			_malhas_borboleta.append(_malha_borboleta(par[0], par[1]))
		_mat_borboleta = ShaderMaterial.new()
		_mat_borboleta.shader = Materiais.shader("res://shaders/borboleta.shader")
	var rnd := RandomNumberGenerator.new()
	rnd.seed = semente
	for i in qtd:
		var mi := MeshInstance.new()
		mi.mesh = _malhas_borboleta[(i + semente) % _malhas_borboleta.size()]
		mi.material_override = _mat_borboleta
		mi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
		# grandonas, de desenho (asa de ~0,6 m): de quem joga dá para ver o bater
		mi.scale = Vector3.ONE * rnd.randf_range(2.8, 3.4)
		grupos[tema].add_child(mi)
		var lado := -1.0 if i % 2 == 0 else 1.0
		var centro := Vector3(lado * rnd.randf_range(1.9, 2.7), rnd.randf_range(0.9, 1.6), rnd.randf_range(-6.5, -1.0))
		_animar(tema, {"tipo": "borboleta", "no": mi, "centro": centro,
			"raio": Vector3(rnd.randf_range(0.3, 0.6), 0.3, rnd.randf_range(0.8, 1.5)),
			"vel": rnd.randf_range(0.35, 0.55), "fase": rnd.randf() * TAU})


## Um voo sem pressa, em laços, sempre olhando para onde vai.
func _borboleta(item: Dictionary) -> void:
	var no: Spatial = item["no"]
	var f: float = item["fase"]
	var r: Vector3 = item["raio"]
	var t := _t * float(item["vel"]) + f
	no.translation = (item["centro"] as Vector3) + Vector3(sin(t) * r.x,
		sin(t * 2.3 + f) * r.y * 0.5 + sin(_t * 4.1 + f) * 0.03, sin(t * 0.7 + f * 0.5) * r.z)
	var dx := cos(t) * r.x
	var dz := 0.7 * cos(t * 0.7 + f * 0.5) * r.z
	no.rotation = Vector3(0.0, atan2(dx, dz), 0.0)


## Asas de cima e de baixo (leque a partir do corpo, a cor do meio para a
## da beirada) dos dois lados e o corpinho. Olha para +Z; as asas ficam no
## plano XZ (o shader as levanta).
static func _malha_borboleta(meio: Color, beirada: Color) -> ArrayMesh:
	var cima := [Vector2(0.0, 0.012), Vector2(0.03, 0.062), Vector2(0.068, 0.082), Vector2(0.094, 0.062),
		Vector2(0.09, 0.022), Vector2(0.05, -0.004), Vector2(0.004, -0.006)]
	var baixo := [Vector2(0.004, -0.006), Vector2(0.05, -0.012), Vector2(0.07, -0.04), Vector2(0.056, -0.07),
		Vector2(0.026, -0.064), Vector2(0.004, -0.03)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for lado in [1.0, -1.0]:
		for asa in [[cima, Vector2(0.04, 0.03)], [baixo, Vector2(0.03, -0.03)]]:
			var pontos: Array = asa[0]
			var c: Vector2 = asa[1]
			for k in pontos.size():
				var a: Vector2 = pontos[k]
				var b: Vector2 = pontos[(k + 1) % pontos.size()]
				var tri := [[c, meio], [a, beirada], [b, beirada]]
				if lado < 0.0:
					tri = [[c, meio], [b, beirada], [a, beirada]]
				for par in tri:
					var p: Vector2 = par[0]
					st.add_color(par[1])
					st.add_normal(Vector3.UP)
					st.add_vertex(Vector3(p.x * lado, 0.0, p.y))
	# corpinho (um losango escuro em cima das asas)
	var corpo := Color("#4A2E2A")
	for tri in [[Vector3(0, 0.003, 0.04), Vector3(0.007, 0.003, 0.0), Vector3(-0.007, 0.003, 0.0)],
			[Vector3(-0.007, 0.003, 0.0), Vector3(0.007, 0.003, 0.0), Vector3(0, 0.003, -0.055)]]:
		for v in tri:
			st.add_color(corpo)
			st.add_normal(Vector3.UP)
			st.add_vertex(v)
	return st.commit()


# ================================================================ animação
## Uma voz de ambiente da fase: `som` (sons/amb_*.wav) sai de `no` a cada
## `cada_min`..`cada_max` s (se ele estiver na tela), com a `acao` junto
## (no item da animação dele).
func _voz(tema: String, no: Spatial, som: String, cada_min: float, cada_max: float, vol := 0.6,
		acao := "", item = null, tom := 1.0) -> void:
	_vozes[tema].append({"no": no, "som": som, "cada": Vector2(cada_min, cada_max),
		"prox": rand_range(2.0, cada_min), "vol": vol, "tom": tom, "acao": acao, "item": item})


## Um ponto parado de onde sai um som (passarinhos, bolhas, a baleia).
func _emissor(tema: String, pos: Vector3) -> Spatial:
	var e := Spatial.new()
	e.translation = pos
	(grupos[tema] as Spatial).add_child(e)
	return e


## O ponto está na tela (na frente da câmera, dentro do quadro com folga)?
func _na_tela(no: Spatial) -> bool:
	var cam := get_viewport().get_camera()
	if cam == null or not no.is_inside_tree():
		return false
	var p := no.global_transform.origin
	if cam.is_position_behind(p):
		return false
	var t := cam.unproject_position(p)
	var r := get_viewport().get_visible_rect().size
	return t.x > -r.x * 0.05 and t.x < r.x * 1.05 and t.y > -r.y * 0.05 and t.y < r.y * 1.05


## O MAESTRO DOS SONS DE AMBIENTE: na vez (folga desde o último), toca a
## voz mais atrasada entre as que estão na tela, com a ação dela.
func _sons_ambiente(delta: float) -> void:
	_relogio += delta
	if not som_ambiente or not detalhes or _relogio < _prox_amb:
		return
	var escolhida = null
	for v in _vozes[atual]:
		if _relogio >= float(v["prox"]) and (escolhida == null or float(v["prox"]) < float(escolhida["prox"])) \
				and _na_tela(v["no"]):
			escolhida = v
	if escolhida == null:
		return
	var v: Dictionary = escolhida
	# (o Sons pelo caminho, não pelo nome: as ferramentas -s do Godot 3 leem
	# as classes antes dos autoloads)
	var sons := get_node_or_null("/root/Sons")
	if sons:
		sons.tocar_em(v["no"], v["som"], AMB_VOLUME * float(v["vol"]), float(v["tom"]) * rand_range(0.96, 1.04))
	match v["acao"]:
		"rugir":
			v["item"]["rugir"] = 1.5
		"tremer":
			v["item"]["tremer"] = 2.0
		"musica":
			v["item"]["musica"] = 5.0
		"balancar":
			v["item"]["balancar"] = 2.2
		"piruetar":
			v["item"]["pirueta"] = 1.0
		"abrir":
			if int(v["item"]["dir"]) == 0:
				v["item"]["dir"] = 1
				v["item"]["mostra"] = BAU_MOSTRA
		"baleia":
			if mundo and mundo.has_method("baleia_cantar"):
				mundo.baleia_cantar(3.5)
	var c: Vector2 = v["cada"]
	v["prox"] = _relogio + rand_range(c.x, c.y)
	_prox_amb = _relogio + rand_range(AMB_FOLGA.x, AMB_FOLGA.y)


func _process(delta: float) -> void:
	if atual == "":
		return
	_t = fposmod(_t + delta, 3600.0)
	_sons_ambiente(delta)
	for item in _anim[atual]:
		match item["tipo"]:
			"girar":
				var vel: float = item["vel"]
				if float(item.get("musica", 0.0)) > 0.0:
					# com a musiquinha o carrossel gira um pouco mais depressa
					item["musica"] = float(item["musica"]) - delta
					vel *= 1.0 + 0.6 * clamp(float(item["musica"]), 0.0, 1.0)
				(item["no"] as Spatial).rotate_y(vel * delta)
			"nuvem":
				var no: Spatial = item["no"]
				no.translation.x += float(item["vel"]) * delta
				if no.translation.x > 30.0:
					no.translation.x = -30.0
			"boiar":
				var no: Spatial = item["no"]
				var f: float = item["fase"]
				var v: float = item["vel"]
				var amp: Vector3 = item["amp"]
				no.translation = (item["base"] as Vector3) + Vector3(sin(_t * 0.5 * v + f) * amp.x, sin(_t * 0.9 * v + f * 2.0) * amp.y, 0)
				if item.has("balanco"):
					no.rotation.z = sin(_t * 0.7 * v + f) * float(item["balanco"])
				if item.has("girar"):
					no.rotation.y += float(item["girar"]) * delta
				if item.has("vira"):
					no.rotation.y = float(item["olhar"]) + sin(_t * 0.6 * v + f) * float(item["vira"])
				if float(item.get("pirueta", 0.0)) > 0.0:
					# o brilhinho: uma pirueta inteira
					item["pirueta"] = float(item["pirueta"]) - delta
					var u := 1.0 - clamp(float(item["pirueta"]), 0.0, 1.0)
					no.rotation.y += TAU * (u * u * (3.0 - 2.0 * u))
			"girar_proprio":
				(item["no"] as Spatial).rotate_object_local(item["eixo"], float(item["vel"]) * delta)
			"passeio":
				# uma volta deitada e achatada (x larga, z curta) com um sobe e
				# desce em "8"; o disco gira no próprio eixo e inclina para o
				# lado da curva
				var no: Spatial = item["no"]
				var a: float = _t * float(item["vel"])
				var r: Vector3 = item["raio"]
				no.translation = (item["centro"] as Vector3) + Vector3(sin(a) * r.x, sin(2.0 * a) * r.y, cos(a) * r.z)
				item["ang"] = fposmod(float(item["ang"]) + float(item["girar"]) * delta, TAU)
				var balanco := 0.0
				if float(item.get("balancar", 0.0)) > 0.0:
					# "uuu-uuu": o disco balança de um lado para o outro
					item["balancar"] = float(item["balancar"]) - delta
					balanco = sin(_t * 14.0) * 0.18 * clamp(float(item["balancar"]), 0.0, 1.0)
				no.transform.basis = Basis(Vector3(0, 0, 1), -cos(a) * 0.2 + balanco) * Basis(Vector3.UP, float(item["ang"]))
			"bau":
				# abre com um pulinho (passa um pouco e volta, como tampa que
				# bate no batente), mostra o tesouro e fecha de uma vez
				var dir := int(item["dir"])
				var k: float = item["k"]
				if dir > 0:
					if k < 1.0:
						k = min(k + delta / BAU_ABRINDO, 1.0)
						if k >= 1.0 and item["faiscas"] != null:
							(item["faiscas"] as CPUParticles).restart()
					else:
						item["mostra"] = float(item["mostra"]) - delta
						if float(item["mostra"]) <= 0.0:
							item["dir"] = -1
				elif dir < 0:
					k = max(k - delta / BAU_FECHANDO, 0.0)
					if k <= 0.0:
						item["dir"] = 0
				item["k"] = k
				var giro: float
				if dir >= 0:
					var u := k - 1.0
					giro = BAU_ABERTO * (1.0 + 2.70158 * u * u * u + 1.70158 * u * u) if k > 0.0 else 0.0
				else:
					giro = BAU_ABERTO * k * k
				var corpo: Spatial = item["corpo"]
				(item["no"] as Spatial).transform = corpo.transform * Transform(Basis(Vector3.RIGHT, giro), BAU_DOBRADICA)
				if item["faiscas"] != null:
					(item["faiscas"] as Spatial).transform = Transform(Basis(), corpo.transform.xform(Vector3(0, 0.7, 0)))
			"roda":
				var roda: Spatial = item["roda"]
				roda.rotation.z += float(item["vel"]) * delta
				var cab: Array = item["cabines"]
				for i in cab.size():
					var a: float = roda.rotation.z + TAU * i / cab.size()
					(cab[i] as Spatial).translation = Vector3(cos(a), sin(a), 0) * float(item["raio"])
					(cab[i] as Spatial).rotation.z = sin(_t * 1.3 + i) * 0.06
			"orbita":
				var no: Spatial = item["no"]
				var a: float = _t * float(item["vel"]) + float(item["fase"])
				var r: Vector2 = item["raio"]
				no.translation = (item["centro"] as Vector3) + Vector3(cos(a) * r.x, sin(_t * 1.1) * float(item["sobe"]), sin(a) * r.y)
				no.rotation.y += float(item["girar"]) * delta
				no.rotation.z = sin(_t * 0.9) * 0.08
			"alga":
				var no: Spatial = item["no"]
				var f: float = item["fase"]
				var b: Vector3 = item["base"]
				no.rotation = b + Vector3(sin(_t * 0.8 + f) * 0.07, 0, sin(_t * 1.1 + f * 1.7) * 0.09)
			"peixe":
				var no: Spatial = item["no"]
				var v: float = item["vel"]
				var a: float = _t * v - float(item["fase"]) * sign(v)
				var r: Vector2 = item["raio"]
				var c: Vector3 = item["centro"]
				no.translation = c + Vector3(cos(a) * r.x, sin(_t * 1.7 + float(item["nado"])) * 0.12, sin(a) * r.y)
				# olha para onde está nadando (+Z do modelo) e rebola o rabinho
				var dir := Vector3(-sin(a) * r.x, 0, cos(a) * r.y) * sign(v)
				no.rotation.y = atan2(dir.x, dir.z) + sin(_t * 9.0 + float(item["nado"])) * 0.12
			"agua_viva":
				var no: Spatial = item["no"]
				var f: float = item["fase"]
				var v: float = item["vel"]
				var pulso := sin(_t * 2.2 * v + f)
				no.translation = (item["base"] as Vector3) + Vector3(0, sin(_t * 0.6 * v + f) * 0.5, 0)
				no.scale = Vector3(1.0 + pulso * 0.06, 1.0 - pulso * 0.08, 1.0 + pulso * 0.06) * _escala_base(item)
			"atravessar":
				var no: Spatial = item["no"]
				no.translation.x += float(item["vel"]) * delta
				var lim: float = item["limite"]
				if no.translation.x > lim:
					no.translation.x = -lim
				elif no.translation.x < -lim:
					no.translation.x = lim
				no.translation.y += sin(_t * 0.8) * 0.003
			"respirar":
				var no: Spatial = item["no"]
				var f: float = item["fase"]
				no.rotation.y = float(item["giro"]) + sin(_t * 0.35 + f) * 0.12
				no.rotation.z = sin(_t * 0.9 + f) * 0.025
				if float(item.get("rugir", 0.0)) > 0.0:
					# RAWR: empina, estica o pescoço e volta
					item["rugir"] = float(item["rugir"]) - delta
					var u := 1.0 - clamp(float(item["rugir"]) / 1.5, 0.0, 1.0)
					var k := sin(PI * u)
					no.rotation.x = -0.12 * k
					no.scale = Vector3(1.0, 1.0 + 0.05 * k, 1.0) * _escala_base(item)
				elif no.rotation.x != 0.0:
					no.rotation.x = 0.0
					no.scale = Vector3.ONE * _escala_base(item)
			"vulcao":
				# o ronco: treme um pouquinho e a fumaça sai mais depressa
				var no: Spatial = item["no"]
				var fum: CPUParticles = item["fumaca"]
				if float(item["tremer"]) > 0.0:
					item["tremer"] = float(item["tremer"]) - delta
					var k: float = clamp(float(item["tremer"]), 0.0, 1.0)
					no.translation = (item["base"] as Vector3) + Vector3(sin(_t * 41.0), 0, cos(_t * 37.0)) * 0.05 * k
					fum.speed_scale = 1.0 + 1.6 * k
				elif fum.speed_scale != 1.0:
					no.translation = item["base"]
					fum.speed_scale = 1.0
			"voo":
				var no: Spatial = item["no"]
				var v: float = item["vel"]
				var a: float = _t * v + float(item["fase"])
				var r: float = item["raio"]
				# as asas batem (o shader) e o corpo sobe quando elas descem;
				# de vez em quando ele plana (as asas abertas, quase paradas)
				var batida := fposmod(_t * float(item["asas"]) + float(item["fase"]), TAU)
				var planar: float = clamp(sin(_t * 0.37 + float(item["fase"])) * 3.0 - 1.5, 0.0, 1.0)
				var m_asas: ShaderMaterial = item["mat"]
				m_asas.set_shader_param("asa_tempo", batida)
				m_asas.set_shader_param("asa_amplitude", 0.55 * (1.0 - 0.75 * planar))
				var sobe := -cos(batida) * 0.06 * (1.0 - planar)
				no.translation = (item["centro"] as Vector3) + Vector3(cos(a) * r, sin(_t * 1.4 + float(item["fase"])) * 0.4 + sobe, sin(a) * r)
				var dir := Vector3(-sin(a), 0, cos(a)) * sign(v)
				no.rotation = Vector3(0, atan2(dir.x, dir.z), -sign(v) * 0.35 + sin(_t * 3.0) * 0.05)
			"pular":
				# de tempos em tempos um pulinho: estica subindo e amassa ao cair
				var no: Spatial = item["no"]
				var e := _escala_base(item)
				var ciclo := fposmod(_t + float(item["fase"]), float(item["cada"]))
				var base: Vector3 = item["base"]
				if ciclo < 0.5:
					var k := sin(PI * ciclo / 0.5)
					no.translation = base + Vector3(0, k * float(item["altura"]), 0)
					no.scale = Vector3(1.0 - 0.05 * k, 1.0 + 0.08 * k, 1.0 - 0.05 * k) * e
				elif ciclo < 0.85:
					var u := (ciclo - 0.5) / 0.35
					var k := sin(PI * u) * (1.0 - u)
					no.translation = base
					no.scale = Vector3(1.0 + 0.12 * k, 1.0 - 0.16 * k, 1.0 + 0.12 * k) * e
				elif ciclo < 0.85 + delta * 2.0:
					no.scale = Vector3.ONE * e
			"chocar":
				# o ovo treme de vez em quando (balança e para)
				var no: Spatial = item["no"]
				var ciclo := fposmod(_t + float(item["fase"]), float(item["cada"]))
				var giro: float = item["giro"]
				if ciclo < 1.1:
					var u := ciclo / 1.1
					var k := (1.0 - u) * sin(u * TAU * 3.5)
					no.rotation = Vector3(k * 0.05, giro, k * 0.12)
				elif ciclo < 1.1 + delta * 2.0:
					no.rotation = Vector3(0, giro, 0)
			"levitar":
				var no: Spatial = item["no"]
				var v: float = item["vel"]
				no.translation = (item["base"] as Vector3) + Vector3(0, 0.08 + sin(_t * v + float(item["fase"])) * 0.07, 0)
				no.rotation.y += 0.25 * v * delta
			"brilhar":
				# o cristal fica parado no chão; só a luz dele pulsa devagar
				var k := 0.5 + 0.5 * sin(_t * 1.6 + float(item["fase"]) * 2.3)
				_acender(item["mat"], 0.8 + 1.8 * k * k)
			"olhar":
				# vira de um lado para o outro (girando inteiro, de perfil, o
				# pirulito virava um palito)
				var no: Spatial = item["no"]
				no.rotation.y = float(item["giro"]) + sin(_t * float(item["vel"]) + float(item["fase"])) * 0.4
			"pulsar":
				# respira: um pouquinho mais baixo e largo, e volta
				var no: Spatial = item["no"]
				var k := sin(_t * 1.6 + float(item["fase"]))
				no.scale = Vector3(1.0 + 0.03 * k, 1.0 - 0.05 * k, 1.0 + 0.03 * k) * _escala_base(item)
			"navio":
				# o navio naufragado balança de leve na correnteza
				var no: Spatial = item["no"]
				var b: Vector3 = item["base"]
				no.rotation = b + Vector3(sin(_t * 0.37) * 0.015, 0, sin(_t * 0.5) * 0.025)
			"borboleta":
				_borboleta(item)


func _escala_base(item: Dictionary) -> float:
	if not item.has("escala"):
		item["escala"] = (item["no"] as Spatial).scale.x
	return float(item["escala"])
