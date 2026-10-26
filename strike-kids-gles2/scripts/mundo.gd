class_name Mundo
extends Spatial

## O MUNDO 3D: céu, sol, terreno com morros, a pista (madeira, canaletas,
## para-choques), o fundo dos pinos (veludo com estrelas, letreiro com
## lâmpadas) e os 4 CENÁRIOS (temas.gd): Parque de Diversões, Espaço,
## Fundo do Mar e Selva dos Dinos — um por rodada.
##
## Medidas: linha de falta em z = 0; os pinos em z = -10,5 (pista infantil,
## mais curta que a de adulto: a bola chega rápido); a pista vai para -Z.
##
## Marca Lazer & Sport (no 3D): sutil, uma em cada cenário (balãozinho no
## Parque, planetinha no Espaço, bolha no Mar, pterossauro nos Dinos).
## Pódios (escolha do personagem e foto) nas cores de Bob e Mia.
##
## Edição OpenGL ES 2.0 (Godot 3): as medidas moram em Medidas (os nomes
## continuam aqui, iguais); sem luz do motor (o sol e a luz ambiente de cada
## cenário vão para os shaders: Materiais.definir_luz); o céu é uma esfera
## desenhada no infinito (sem shader de céu no Godot 3).

const MEIA_LARGURA = Medidas.MEIA_LARGURA
const CANALETA = Medidas.CANALETA
const Z_PINO1 = Medidas.Z_PINO1
const ESPACO_PINOS = Medidas.ESPACO_PINOS
const FILEIRA = Medidas.FILEIRA
const Z_FIM_DECK = Medidas.Z_FIM_DECK
const Z_FUNDO = Medidas.Z_FUNDO
## para-choques: 10 pedaços de 0,96 m a partir da linha de falta — acabam
## em z = -9,8, antes da barra varredora (z = -10) e do fosso
const N_BUMPERS = Medidas.N_BUMPERS
## ALÇAPÃO no chão do fosso: o vão das duas portinhas (scripts/maquina.gd
## abre depois da varrida e os pinos caem). Embaixo, um POÇO fundo de
## verdade (o terreno tem um furo ali: tools/modelos/modelos.py, FURO_*),
## com paredes e fundo que seguram os pinos.
const ALCAPAO_X = Medidas.ALCAPAO_X
const ALCAPAO_Z0 = Medidas.ALCAPAO_Z0
const ALCAPAO_Z1 = Medidas.ALCAPAO_Z1
const POCO_FUNDO = Medidas.POCO_FUNDO

const CAMADA_MUNDO = Medidas.CAMADA_MUNDO
const CAMADA_PINOS = Medidas.CAMADA_PINOS
const CAMADA_BOLA = Medidas.CAMADA_BOLA
const CAMADA_PISO_BOLA = Medidas.CAMADA_PISO_BOLA
const CAMADA_PISO_PINOS = Medidas.CAMADA_PISO_PINOS
const CAMADA_SO_PINOS = Medidas.CAMADA_SO_PINOS
## topo da boca da caçapa das bolas (no fundo do fosso)
const Y_BOCA = Medidas.Y_BOCA
const LARGURA_BOCA = Medidas.LARGURA_BOCA
## retorno de bolas (perto de quem joga)
const RETORNO = Medidas.RETORNO
const ALTURA_PODIO = Medidas.ALTURA_PODIO
const BALAO_POS = Medidas.BALAO_POS
## metros de um ladrilho da textura de detalhes do chão de cada modo
## (texturas/chao_<modo>.png, tools/assar_chao.py)
const LADRILHO_CHAO := [25.2, 22.4, 25.3, 25.0]
## Bullet (Godot 3): a margem de colisão de uma forma CONVEXA fica do lado de
## FORA dela (tudo ficaria 4 cm mais gordo), e com margem menor que 4 cm o
## contato treme (uma bola parada em cima rola e cai). As peças convexas do
## cenário usam a forma ENCOLHIDA pela margem: com a margem, ela volta a ter
## o tamanho da peça desenhada (como no Godot 4). Caixas, cilindros e a
## meia-cana (trimesh) não têm esse problema.
const MARGEM_CONVEXA := 0.04

var ambiente: Environment
## o SOL: sem luz do motor na OpenGL ES 2 (na Mali-400 cada luz desenharia a
## cena de novo). É só um Spatial com a direção de antes (o sol fica no +Z
## dele: uma luz ilumina para o seu -Z); a cor e a força de cada cenário
## vão para os shaders em aplicar_tema (Materiais.definir_luz).
var sol: Spatial
## o CÉU: esfera com o ceu.shader, desenhada "no infinito", atrás de tudo
## (o Godot 3 não tem shader de céu)
var ceu: MeshInstance
var mat_pista: ShaderMaterial
var mat_piso: ShaderMaterial
var mat_lampadas: ShaderMaterial
var mat_fundo: ShaderMaterial
var mat_ceu: ShaderMaterial
var mat_placa: ShaderMaterial
var mat_divisoria: ShaderMaterial
var mat_faixa: ShaderMaterial
var mats_canaleta: Array = []
var mat_bumper: ShaderMaterial
var mat_terreno: ShaderMaterial
## o poço sem fundo do alçapão (as faixas das paredes correm na queda)
var mat_poco: ShaderMaterial
var mat_gabinete: ShaderMaterial
var mat_parede: ShaderMaterial
var mat_coluna: ShaderMaterial
var mat_friso: ShaderMaterial
var mat_portal: ShaderMaterial
var temas: Temas
var _ptero_simbolo: MeshInstance
var tema := ""
var _bumpers: Array = []
var balao: Spatial                # o símbolo do cenário de agora (Parque: o balão)
var mat_balao: ShaderMaterial
var _marcas := {}                # cenário -> o seu símbolo Lazer & Sport
var _bolhinhas: Array = []
var _podios: Array = []
var _mats_podio: Array = []
var _podio_destaque := -1
var _t := 0.0
var _luz := 0.0
var _luz_alvo := 0.0
var bola_z := 100.0
var bola: Spatial                 # a bola do jogo (as tiras da caçapa abrem quando ela passa)
var _tiras: MeshInstance
var mat_cortina: ShaderMaterial
var _abertura_tiras: PoolRealArray = PoolRealArray()
var _bola_volta: MeshInstance
var mat_boca_luz: ShaderMaterial
## o detalhe do chão de cada cenário (texturas/chao_0..3.png), carregado ao
## montar e guardado: trocar de cenário não lê nada do disco
var _texturas_chao: Array = []
## CENÁRIO LEVE (o padrão; menu do operador > "Cenário (fundo)"): o fundo
## mais barato para a TV Box rodar lisa — chão e decoração com a luz feita
## por vértice, metade da decoração, céu simples e sem neblina. A pista,
## os pinos, a máquina e os bichinhos são os mesmos do COMPLETO.
var leve := false


## Onde um objeto movido pela física APARECE neste quadro (Medidas.na_tela).
static func na_tela(n: Spatial) -> Transform:
	return Medidas.na_tela(n)


func construir() -> void:
	leve = Ajustes.cenario_leve()
	for i in LADRILHO_CHAO.size():
		_texturas_chao.append(load("res://texturas/chao_%d.png" % i))
	_ambiente()
	_sol()
	_astro_no_ceu()
	_terreno()
	_pista()
	_fundo_dos_pinos()
	_colunas()
	_marcas_dos_cenarios()
	_area_dos_jogadores()
	_montar_podios()
	temas = Temas.new()
	add_child(temas)
	temas.construir(self)
	# o pterossauro do símbolo da selva: o mesmo material dos do cenário
	# (com a textura deles; o símbolo é montado antes do cenário)
	_ptero_simbolo.material_override = temas._mat_modelo("ptero", 0.003, Color.white)
	# peças paradas com o mesmo material viram uma malha só (menos desenhos)
	# (o céu e o astro ficam de fora: são desenhados no infinito)
	var fora: Array = [temas, ceu, _astro]
	fora.append_array(_marcas.values())
	fora.append_array(_podios)
	fora.append_array(_bumpers)
	Lote.juntar(self, fora, 0.0)
	aplicar_tema(Temas.ORDEM[0])
	definir_protecao(Ajustes.protecao_canaleta())


## Troca o cenário: céu, luz, neblina, terreno, cores da pista e decoração.
func aplicar_tema(nome: String) -> void:
	if not Temas.CONFIG.has(nome):
		nome = "parque"
	tema = nome
	var c: Dictionary = Temas.CONFIG[nome]
	var ceu_cores: Array = c["ceu"]
	mat_ceu.set_shader_param("cor_topo", ceu_cores[0])
	mat_ceu.set_shader_param("cor_meio", ceu_cores[1])
	mat_ceu.set_shader_param("cor_horizonte", ceu_cores[2])
	mat_ceu.set_shader_param("cor_chao", ceu_cores[3])
	mat_ceu.set_shader_param("cor_sol", c.get("cor_sol", Color(1.0, 0.95, 0.75)))
	mat_ceu.set_shader_param("forca_sol", c.get("forca_sol", 1.0))
	mat_ceu.set_shader_param("estrelas", c.get("estrelas", 0.0))
	mat_ceu.set_shader_param("cor_nebulosa", c.get("nebulosa", Color(0.9, 0.4, 1.0)))
	mat_ceu.set_shader_param("raios", c.get("raios", 0.0))
	# o fundo (se algo não cobrir a tela) é o horizonte do céu
	ambiente.background_color = ceu_cores[2]
	# a pista e o piso não usam o cálculo de luz do motor (são leves): a luz
	# da cena (ambiente + sol batendo no chão) vai pronta para o shader
	var para_sol := sol.global_transform.basis.z.normalized() if sol.is_inside_tree() else Vector3(0.35, 0.79, 0.5)
	var forca_amb := float(c.get("ambiente_forca", 0.62))
	var forca_sol := float(c.get("sol_forca", 1.05))
	var amb: Color = _vezes(_linear(c["ambiente"]), forca_amb)
	# LUZ DE PALCO: a pista, o piso, as canaletas, os pinos, a bola e os
	# bichinhos ficam sob uma luz quase branca e quente em todo cenário (só
	# um toque da cor dele): a madeira continua madeira e o Bob continua
	# laranja. A cor de cada cenário (o verde-água do mar, o azul do
	# espaço) fica no céu, no chão e na decoração em volta — com a luz do
	# cenário inteira na pista, a madeira do mar saía verde-limão.
	var k_palco := float(c.get("palco_tinta", PALCO_TINTA))
	var amb_p := _misturar(_vezes(_linear(PALCO_AMB), PALCO_AMB_FORCA), amb, k_palco)
	var sol_p := _misturar(_vezes(_linear(PALCO_SOL), PALCO_SOL_FORCA), _vezes(_linear(c["sol"]), forca_sol), k_palco)
	var sobe := max(para_sol.y, 0.0)
	var luz_cena := Vector3(amb_p.r + sol_p.r * sobe, amb_p.g + sol_p.g * sobe, amb_p.b + sol_p.b * sobe)
	# a pista faz a conta em luz linear (textura assada) e recebe a luz
	# convertida; o piso e as canaletas fazem as contas cruas (tela_g4)
	var luz_tela := _linear_v(luz_cena)
	# chão e decoração: a luz da cena vai pronta para o shader (por
	# vértice no leve, por pixel na decoração do completo)
	var sol_lin: Color = _vezes(_linear(c["sol"]), forca_sol)
	var sol_cor := Vector3(sol_lin.r, sol_lin.g, sol_lin.b)
	var amb_v := Vector3(amb.r, amb.g, amb.b)
	# a luz de PALCO (sol + ambiente, lineares e com a força) vai para os
	# toons, a bola e os para-choques (Materiais): pinos, bichinhos, bola,
	# gabinete; a decoração do cenário recebe a luz do cenário (temas.luz)
	Materiais.definir_luz(para_sol, Vector3(sol_p.r, sol_p.g, sol_p.b), Vector3(amb_p.r, amb_p.g, amb_p.b))
	# a neblina do fundo (por vértice, no chão e na decoração, como no
	# cenário leve do Godot 4: é ela que deixa o mar verde-água ao longe)
	var nb: Color = _linear(c["neblina"])
	var neblina := Vector3(nb.r, nb.g, nb.b)
	var densidade := float(c.get("neblina_densidade", 0.0045))
	for m in [mat_terreno]:
		m.set_shader_param("sol_dir", para_sol)
		m.set_shader_param("sol_cor", sol_cor)
		m.set_shader_param("ambiente", amb_v)
		m.set_shader_param("neblina_cor", neblina)
		m.set_shader_param("neblina_densidade", densidade)
	temas.luz(para_sol, sol_cor, amb_v, neblina, densidade)
	mat_pista.set_shader_param("luz_cena", luz_tela)
	mat_piso.set_shader_param("luz_cena", luz_cena)
	# o verniz reflete o céu entre o horizonte e o meio (só o horizonte, bem
	# claro, desbotava a madeira lá no fundo)
	for m in [mat_pista, mat_piso]:
		m.set_shader_param("cor_ceu", (ceu_cores[1] as Color).linear_interpolate(ceu_cores[2], 0.55))
	mat_pista.set_shader_param("dir_sol", para_sol)
	var f: Array = c["fundo"]
	mat_fundo.set_shader_param("cor_a", f[0])
	mat_fundo.set_shader_param("cor_b", f[1])
	mat_fundo.set_shader_param("cor_halo", c["halo"])
	mat_boca_luz.set_shader_param("emissao", (c["halo"] as Color) * 0.9)
	mat_cortina.set_shader_param("linha", float(LINHA_CORTINA.find(nome)))
	mat_placa.set_shader_param("tinta", c["placa"])
	var portal: Array = c["portal"]
	# a pista: neon das bordas e o reflexo do portal no verniz
	mat_pista.set_shader_param("cor_luz", c.get("neon", portal[0]))
	mat_pista.set_shader_param("cor_reflexo_a", portal[0])
	mat_pista.set_shader_param("cor_reflexo_b", portal[1])
	mat_portal.set_shader_param("cor_a", portal[0])
	mat_portal.set_shader_param("cor_b", portal[1])
	mat_gabinete.set_shader_param("tinta", c["gabinete"])
	mat_coluna.set_shader_param("tinta", c["coluna"])
	mat_parede.set_shader_param("tinta", c["parede"])
	mat_divisoria.set_shader_param("tinta", c["divisoria"])
	mat_faixa.set_shader_param("tinta", c["faixa"])
	var cc: Array = c["canaleta"]
	for m in mats_canaleta:
		m.set_shader_param("modo", int(c["canaleta_modo"]))
		m.set_shader_param("cor_a", cc[0])
		m.set_shader_param("cor_b", cc[1])
		m.set_shader_param("cor_c", cc[2])
		m.set_shader_param("luz_cena", luz_cena)
	var bp: Array = c["bumper"]
	mat_bumper.set_shader_param("cor_a", bp[0])
	mat_bumper.set_shader_param("cor_b", bp[1])
	var chao: Array = c["chao"]
	var modo_chao := int(c["chao_modo"])
	mat_terreno.set_shader_param("modo", modo_chao)
	# florzinhas, crateras e poeira, conchinhas: textura que se repete
	# (tools/assar_chao.py), uma por cenário — as 4 já carregadas (ler do
	# disco e mandar para a placa de vídeo na troca de cenário travava)
	mat_terreno.set_shader_param("detalhe", _texturas_chao[modo_chao])
	mat_terreno.set_shader_param("detalhe_tile", LADRILHO_CHAO[modo_chao])
	# cores do chão: lineares (OpenGL ES 2.0: os dois shaders do chão fazem
	# a conta em linear e convertem para a tela; no Godot 4 o completo
	# recebia a cor convertida duas vezes por causa da conta do motor)
	for i in 4:
		var l: Color = _cor_do_chao(chao[i])
		mat_terreno.set_shader_param(["lin_a", "lin_b", "lin_c", "lin_d"][i], Vector3(l.r, l.g, l.b))
	# a terra da selva: o detalhe 2 x a terra do Godot 4 (cenário leve)
	mat_terreno.set_shader_param("terra", Vector3(0.45, 0.32, 0.17))
	_mostrar_marca(nome)
	_mostrar_astro(nome)
	temas.mostrar(nome)


## A luz de palco (pista, pinos, bola, bichinhos): branca e quente em todo
## cenário, com PALCO_TINTA da luz do cenário misturada (cada cenário pode
## ter "palco_tinta" no Temas.CONFIG).
const PALCO_SOL := Color(1.0, 0.96, 0.9)
const PALCO_SOL_FORCA := 1.05
const PALCO_AMB := Color(0.66, 0.72, 0.86)
const PALCO_AMB_FORCA := 0.62
const PALCO_TINTA := 0.2


## a + (b - a) * k, nas três cores (alfa 1).
static func _misturar(a: Color, b: Color, k: float) -> Color:
	return Color(lerp(a.r, b.r, k), lerp(a.g, b.g, k), lerp(a.b, b.b, k), 1.0)


## Cor do chão para o shader: linear, como no cenário leve do Godot 4 (o
## shader faz as mesmas contas e, como lá, converte a cor que entrega mais
## uma vez antes da curva de tela: o verde fechado da selva, o azul da lua).
func _cor_do_chao(c: Color) -> Color:
	return _linear(c)


## Cor sRGB -> linear (a mesma conta do srgb_to_linear() do Godot 4, que o
## Color do Godot 3 não tem).
static func _linear(c: Color) -> Color:
	return Color(_canal_linear(c.r), _canal_linear(c.g), _canal_linear(c.b), c.a)


## O mesmo para uma luz (Vector3; vale acima de 1).
static func _linear_v(v: Vector3) -> Vector3:
	return Vector3(_canal_linear(v.x), _canal_linear(v.y), _canal_linear(v.z))


static func _canal_linear(v: float) -> float:
	return v * (1.0 / 12.92) if v < 0.04045 else pow((v + 0.055) * (1.0 / (1.0 + 0.055)), 2.4)


## Cor x força (o alfa fica 1).
static func _vezes(c: Color, forca: float) -> Color:
	return Color(c.r * forca, c.g * forca, c.b * forca, 1.0)


# ================================================================ sol e lua
## SOL E LUA COM ROSTINHO no céu: sol no Parque, nos Dinos e no Mar (visto
## de dentro d'água, mais azulado) e a lua no Espaço. Um quadradinho sempre
## de frente para a câmera, desenhado NA DIREÇÃO do sol do céu e sempre à
## mesma distância da câmera (astro.shader) — como o céu, ele fica "no
## infinito": por mais que a câmera passeie (pinos, caçapa, trilhos), o
## rostinho fica exatamente onde o céu desenha o brilho do sol, e atrás de
## todo o cenário. Os raios giram e o rosto pisca no próprio shader.
## As 3 imagens (pequenas) ficam carregadas desde o começo: trocar de
## cenário não lê nada do disco.
## [imagem, onde fica visto da área de jogo, tamanho (m) a ~67 m, tinta]
const ASTROS := {
	"parque": ["sol", Vector3(9.8, 25.2, -59.4), 8.5, Color(1, 1, 1, 1)],
	"dinos": ["sol", Vector3(9.8, 25.2, -59.4), 8.5, Color(1, 1, 1, 1)],
	"mar": ["sol", Vector3(9.8, 25.2, -59.4), 8.0, Color(0.86, 1.0, 1.0, 0.82)],
	"espaco": ["lua", Vector3(-1.1, 26.3, -59.7), 7.2, Color(1, 1, 1, 1)],
}
## de onde as posições acima foram escolhidas (a área de jogo)
const ASTRO_REFERENCIA := Vector3(0.0, 1.2, 2.4)
## distância do rostinho até a câmera: atrás de tudo do cenário e antes do
## fim da visão da câmera (160 m)
const ASTRO_DISTANCIA := 140.0
var _astro: MeshInstance
var _mat_astro: ShaderMaterial
var _img_astro := {}


func _astro_no_ceu() -> void:
	for n in ["sol", "lua", "sol_raios"]:
		_img_astro[n] = load("res://ui/ceu/%s.png" % n)
	_mat_astro = ShaderMaterial.new()
	_mat_astro.shader = load("res://shaders/astro.shader")
	_mat_astro.set_shader_param("distancia", ASTRO_DISTANCIA)
	# o primeiro dos transparentes: o que estiver na frente (bolhas,
	# partículas) é desenhado por cima dele
	_mat_astro.render_priority = Material.RENDER_PRIORITY_MIN
	_astro = MeshInstance.new()
	_astro.name = "astro"
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	_astro.mesh = q
	_astro.material_override = _mat_astro
	_astro.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	# o shader coloca o quadrado longe, na frente da câmera: a caixa de
	# visibilidade cobre toda a visão (nunca some por engano)
	_astro.set_custom_aabb(AABB(Vector3(-400, -400, -400), Vector3(800, 800, 800)))
	add_child(_astro)


func _mostrar_astro(nome: String) -> void:
	var a: Array = ASTROS.get(nome, ASTROS["parque"])
	var e_sol: bool = a[0] == "sol"
	var rel: Vector3 = (a[1] as Vector3) - ASTRO_REFERENCIA
	var dir := rel.normalized()
	_mat_astro.set_shader_param("rosto", _img_astro[a[0]])
	_mat_astro.set_shader_param("raios", _img_astro["sol_raios"] if e_sol else null)
	_mat_astro.set_shader_param("usa_raios", 1.0 if e_sol else 0.0)
	_mat_astro.set_shader_param("tinta", a[3])
	_mat_astro.set_shader_param("direcao", dir)
	# o mesmo tamanho na tela que teria a ~67 m, agora a ASTRO_DISTANCIA
	_mat_astro.set_shader_param("tamanho", float(a[2]) * ASTRO_DISTANCIA / rel.length())
	# o brilho do sol do céu fica bem atrás dele, de qualquer ponto de vista
	mat_ceu.set_shader_param("dir_sol", dir)


# ================================================================ ambiente
## O CÉU E O FUNDO. O Godot 3 (OpenGL ES 2) não tem shader de céu: o céu é
## uma esfera com o ceu.shader (ceu_leve.shader no cenário leve), que a
## desenha no infinito, atrás de tudo — as estrelas vêm de uma textura que
## segue a UV da esfera; o fundo da tela é só a cor do horizonte.
## Sem luz ambiente do motor (a cena não tem luz nenhuma: os shaders recebem
## a luz do cenário), sem brilho (glow), sem tonemap nem ajuste de cor (cada
## um é uma passada a mais na tela inteira) e sem a neblina do motor (ver
## aplicar_qualidade).
func _ambiente() -> void:
	var we := WorldEnvironment.new()
	ambiente = Environment.new()
	mat_ceu = ShaderMaterial.new()
	mat_ceu.shader = load("res://shaders/ceu_leve.shader" if leve else "res://shaders/ceu.shader")
	mat_ceu.set_shader_param("mapa_estrelas", load("res://texturas/estrelas_ceu.png"))
	ceu = MeshInstance.new()
	ceu.name = "ceu"
	var esfera := SphereMesh.new()
	esfera.radius = 1.0
	esfera.height = 2.0
	# (o degradê é por pixel; por vértice só a nebulosa e os raios do mar,
	# que mudam devagar: 48 x 24 basta — na Mali-400/450 o que pesa são os
	# vértices)
	esfera.radial_segments = 48
	esfera.rings = 24
	ceu.mesh = esfera
	ceu.material_override = mat_ceu
	# o shader leva a esfera para longe, em volta da câmera: nunca sai do quadro
	ceu.extra_cull_margin = 16384.0
	ceu.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	add_child(ceu)
	ambiente.background_mode = Environment.BG_COLOR
	ambiente.background_color = Color("#E4F4FF")
	ambiente.ambient_light_color = Color.black
	ambiente.ambient_light_energy = 0.0
	ambiente.ambient_light_sky_contribution = 0.0
	ambiente.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	ambiente.tonemap_exposure = 1.0
	ambiente.glow_enabled = false
	ambiente.adjustment_enabled = false
	ambiente.fog_enabled = false
	we.environment = ambiente
	add_child(we)


## O sol: só a direção (ver `sol`).
func _sol() -> void:
	sol = Spatial.new()
	sol.name = "sol"
	sol.rotation_degrees = Vector3(-52, 28, 0)
	add_child(sol)


## Qualidade (o sol NÃO faz sombra de verdade em nenhuma. Pinos, bola e
## bichinhos têm sombrinha pintada no chão, que acompanha cada um).
## Edição OpenGL ES 2.0: sem brilho (glow) e sem a neblina do motor em
## nenhuma — no Godot 3 não dá para tirar a neblina de um material só: ela
## pintaria o céu (desenhado longe) e passaria de novo no chão e na
## decoração, que fazem a própria neblina no shader (mesma cor e densidade).
## O que a do motor ainda pintava (pista, portal, bichinhos) fica perto da
## câmera, onde ela quase não aparecia.
func aplicar_qualidade(_q: String) -> void:
	ambiente.glow_enabled = false
	ambiente.fog_enabled = false


# ================================================================ terreno
func _terreno() -> void:
	# um relevo só; o desenho do chão de cada cenário sai do shader (nítido)
	# o desenho do chão é o mesmo nas duas versões (terreno_leve.shader no
	# leve, terreno.shader no completo), com os mesmos parâmetros
	mat_terreno = ShaderMaterial.new()
	mat_terreno.shader = load("res://shaders/terreno_leve.shader" if leve else "res://shaders/terreno.shader")
	var t := MeshInstance.new()
	t.mesh = load("res://modelos/terreno.res")
	t.material_override = mat_terreno
	t.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	add_child(t)
	# chão de segurança (nada cai para sempre)
	var chao := StaticBody.new()
	var cs := CollisionShape.new()
	cs.shape = PlaneShape.new()
	chao.add_child(cs)
	chao.translation.y = POCO_FUNDO - 0.85   # abaixo do poço do alçapão
	chao.collision_layer = CAMADA_MUNDO
	add_child(chao)


# ================================================================ pista
func _caixa(tam: Vector3, pos: Vector3, mat: Material, colisao := true, sombra := false, atrito := 0.4, quique := 0.2,
		quem := "todos") -> MeshInstance:
	var mi := MeshInstance.new()
	var bm := CubeMesh.new()
	bm.size = tam
	mi.mesh = bm
	mi.material_override = mat
	mi.translation = pos
	if not sombra:
		mi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	if colisao:
		_corpo_caixa(tam, pos, atrito, quique, quem)
	return mi


## Corpo parado com uma forma pronta (a do próprio desenho da peça).
## atrito e quique: os do Godot 4; `quem` encosta nela ("bola", "pinos" ou
## "todos") — Medidas.material converte para a conta da Bullet.
func _corpo_forma(forma: Shape, pos: Vector3, atrito := 0.4, quique := 0.2, quem := "todos") -> StaticBody:
	var sb := StaticBody.new()
	var cs := CollisionShape.new()
	cs.shape = forma
	sb.add_child(cs)
	sb.translation = pos
	sb.collision_layer = CAMADA_MUNDO
	sb.collision_mask = 0
	sb.physics_material_override = Medidas.material(atrito, quique, quem)
	add_child(sb)
	return sb


func _corpo_caixa(tam: Vector3, pos: Vector3, atrito := 0.4, quique := 0.2, quem := "todos") -> StaticBody:
	var bs := BoxShape.new()
	# Godot 3: a caixa é dada pela METADE do tamanho
	bs.extents = tam * 0.5
	return _corpo_forma(bs, pos, atrito, quique, quem)


func _pista() -> void:
	# --- tábuas da pista (com marcações e luzes)
	mat_pista = ShaderMaterial.new()
	mat_pista.shader = load("res://shaders/pista.shader")
	# OpenGL ES 2.0: a decoração parada (madeira, marcações, estrelas
	# apagadas) vem pronta numa textura (tools/assar_pista.py), do começo
	# do deck (z = 0,1) até o fim (Z_FIM_DECK)
	mat_pista.set_shader_param("pista_pronta", load("res://texturas/pista_pronta.png"))
	mat_pista.set_shader_param("z_pino1", Z_PINO1)
	mat_pista.set_shader_param("meia_largura", MEIA_LARGURA)
	mat_pista.set_shader_param("z_inicio", 0.1)
	mat_pista.set_shader_param("z_fim", Z_FIM_DECK)
	var comp := 0.1 - Z_FIM_DECK
	var deck := _caixa(Vector3(MEIA_LARGURA * 2, 0.2, comp), Vector3(0, -0.1, 0.1 - comp / 2), mat_pista, false, false)
	deck.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	# física: duas peças INTEIRAS (sem emendas, que fariam a bola pular):
	# a da bola é lisa (óleo); a dos pinos tem atrito de madeira seca, para
	# eles não escorregarem como no gelo. Cada uma só "existe" para quem pisa.
	var cb := 1.2 - Z_FIM_DECK
	var piso_bola := _corpo_caixa(Vector3(MEIA_LARGURA * 2, 0.2, cb), Vector3(0, -0.1, 1.2 - cb / 2), 0.05, 0.05, "bola")
	piso_bola.collision_layer = CAMADA_PISO_BOLA
	var piso_pinos := _corpo_caixa(Vector3(MEIA_LARGURA * 2, 0.2, cb), Vector3(0, -0.1, 1.2 - cb / 2), 0.42, 0.1, "pinos")
	piso_pinos.collision_layer = CAMADA_PISO_PINOS

	# --- área de aproximação (onde o personagem corre): madeira leve
	mat_piso = ShaderMaterial.new()
	mat_piso.shader = load("res://shaders/piso.shader")
	mat_piso.set_shader_param("madeira", Materiais.textura("madeira"))
	var aprox := _caixa(Vector3(6.6, 0.2, 6.2), Vector3(0, -0.101, 3.2), mat_piso, true, false, 0.8, 0.0, "bola")
	aprox.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	# faixa colorida nas bordas da aproximação
	mat_faixa = Materiais.cor_toon(Color("#FF9F2E"))
	for s in [-1, 1]:
		_caixa(Vector3(0.12, 0.04, 6.2), Vector3(s * 3.3, 0.0, 3.2), mat_faixa, false, false)

	# --- canaletas: meia-cana de verdade (perfil liso, 56 segmentos na
	# curva), lábios no nível da pista; começam na linha de falta
	var perfil_c := Perfis.canaleta(CANALETA / 2.0)
	# mais escura no fundo da calha, clara nos lábios: lê-se a curva de longe
	# (Godot 3: sem Vector4 — Perfis.extrudar recebe os 4 números num Quat)
	var malha_c := Perfis.extrudar(perfil_c, Z_FIM_DECK, 0.1, true, true, 50.0, Quat(-0.15, -0.005, 0.5, 1.05))
	# a colisão é a mesma meia-cana do desenho (bola e pinos rolam e param
	# dentro da calha, encostados na parede curva), com menos gomos: 14 na
	# curva e 6 em cada lábio (a diferença para o desenho fica abaixo de
	# 1 mm). Cada gomo vira triângulos do comprimento da pista inteira e a
	# física testa todos os que encostam no pino ou na bola, a cada passo:
	# com os 56 + 16 do desenho era a maior parte do custo da física — na TV
	# Box a jogada travava.
	var forma_c := Perfis.extrudar(Perfis.canaleta(CANALETA / 2.0, 0.018, 0.05, 14, 6), Z_FIM_DECK, 0.1).create_trimesh_shape()
	for s in [-1, 1]:
		var x: float = s * (MEIA_LARGURA + CANALETA / 2)
		# o desenho de cada cenário (shaders/canaleta.shader; Temas.CONFIG)
		var mcan := ShaderMaterial.new()
		mcan.shader = load("res://shaders/canaleta.shader")
		mcan.set_shader_param("centro", MEIA_LARGURA + CANALETA / 2)
		mats_canaleta.append(mcan)
		var can := MeshInstance.new()
		can.mesh = malha_c
		can.material_override = mcan
		can.translation = Vector3(x, 0.0, 0.0)
		can.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
		can.name = "canaleta_%d" % s
		add_child(can)
		_corpo_forma(forma_c, Vector3(x, 0.0, 0.0), 0.2, 0.1)
		# divisória (capping) arredondada entre a canaleta e o gramado: vai
		# dos pinos até a linha de falta (não invade a área do jogador)
		if mat_divisoria == null:
			mat_divisoria = Materiais.cor_toon(Color("#FFB627"), 0.0, {"borda": 0.25, "especular": 0.4})
		var largura_cap := 0.32
		var xc: float = s * (MEIA_LARGURA + CANALETA + 0.036 + largura_cap / 2)
		var cap := MeshInstance.new()
		cap.mesh = Perfis.extrudar(Perfis.retangulo(largura_cap, 0.34, 0.06, Vector2(0, -0.07)), Z_PINO1 + 0.2, 0.1)
		cap.material_override = mat_divisoria
		cap.translation = Vector3(xc, 0.0, 0.0)
		cap.name = "divisoria_%d" % s
		add_child(cap)
		# colisão = o próprio desenho (quinas arredondadas, mesmo lugar)
		_corpo_forma(_forma_retangulo(largura_cap, 0.34, 0.06, Vector2(0, -0.07), Z_PINO1 + 0.2, 0.1), cap.translation, 0.3, 0.3)
		# faixinha de luz em cima da divisória
		var luzes := _caixa(Vector3(0.05, 0.012, -Z_PINO1 - 0.3), Vector3(xc, 0.104, (Z_PINO1 + 0.2) / 2.0 + 0.05),
			Materiais.cor_toon(Color("#FFFFFF"), 0.0, {"emissao": Color(0.35, 0.85, 1.0), "borda": 0.0}), false, false)
		luzes.name = "luz_divisoria_%d" % s

	# --- para-choques (bumpers) listrados de doce: só as listras (os
	# efeitos animados ficam POR BAIXO, na calha — canaleta.shader)
	# cápsula simples + listras pelo shader (nítidas em 4K e levinhas)
	var mb := _capsula_em_pe(0.07, 1.14, 10, 2)
	var mat_b := ShaderMaterial.new()
	mat_b.shader = load("res://shaders/doce_listrado.shader")
	# a luz do cenário por vértice, como nos toons (Materiais.definir_luz)
	Materiais.registrar(mat_b)
	mat_bumper = mat_b
	if Materiais.contornos_ligados():
		var contorno_b := ShaderMaterial.new()
		contorno_b.shader = Materiais.shader(Materiais.CONTORNO)
		contorno_b.set_shader_param("espessura", 0.003)
		contorno_b.set_shader_param("usa_cor_vertice", 0.0)
		mat_b.next_pass = contorno_b
	for s in [-1, 1]:
		var grupo := Spatial.new()
		grupo.name = "bumpers_%d" % s
		add_child(grupo)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mb
		# terminam ANTES da máquina de pinos (como num boliche de verdade): a
		# barra varredora desce e varre ali sem encostar neles
		var n: int = N_BUMPERS
		mm.instance_count = n
		for i in n:
			mm.set_instance_transform(i, Transform(Basis(Vector3.RIGHT, PI / 2), Vector3(s * 0.735, 0.1, -0.6 - i * 0.96)))
		var mmi := MultiMeshInstance.new()
		mmi.multimesh = mm
		mmi.material_override = mat_b
		grupo.add_child(mmi)
		var sb := StaticBody.new()
		var cs := CollisionShape.new()
		var cap := CylinderShape.new()
		cap.radius = 0.075
		cap.height = n * 0.96 + 0.2
		cs.shape = cap
		cs.rotation_degrees.x = 90
		cs.translation = Vector3(s * 0.735, 0.1, -0.6 - (n - 1) * 0.96 / 2)
		sb.add_child(cs)
		sb.collision_layer = CAMADA_MUNDO
		sb.collision_mask = 0
		# (quem bate neles é a bola: Medidas.material converte para a Bullet)
		sb.physics_material_override = Medidas.material(0.1, 0.55, "bola")
		sb.name = "fisica"
		grupo.add_child(sb)
		_bumpers.append(grupo)


## CÁPSULA EM PÉ (eixo Y e `altura` total, como a CapsuleMesh do Godot 4; a
## do Godot 3 é deitada no eixo Z e o mid_height é só a parte reta). Com
## meia volta em Y o UV.x dá a volta igual ao do Godot 4: o
## doce_listrado.shader desenha as listras pela posição Y e pelo UV.x.
static func _capsula_em_pe(raio: float, altura: float, gomos: int, aneis: int) -> ArrayMesh:
	var c := CapsuleMesh.new()
	c.radius = raio
	c.mid_height = max(altura - 2.0 * raio, 0.0)
	c.radial_segments = gomos
	c.rings = aneis
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(c, 0, Transform(Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, -PI / 2), Vector3.ZERO))
	return st.commit()


## TOROIDE (o Godot 3 não tem TorusMesh): a mesma malha do Godot 4 — deitado
## no plano XZ, `aneis` gomos na volta grande e `gomos` na volta do tubo.
static func _toro(raio_dentro: float, raio_fora: float, aneis: int, gomos: int) -> ArrayMesh:
	var r_min: float = min(raio_dentro, raio_fora)
	var r_max: float = max(raio_dentro, raio_fora)
	var raio := (r_max - r_min) * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in aneis + 1:
		var inci := float(i) / float(aneis)
		var angi := inci * TAU
		var ni := Vector2(-sin(angi), -cos(angi))
		for j in gomos + 1:
			var incj := float(j) / float(gomos)
			var angj := incj * TAU
			var nj := Vector2(-cos(angj), sin(angj))
			var nk := nj * raio + Vector2(r_min + raio, 0.0)
			st.add_normal(Vector3(ni.x * nj.x, nj.y, ni.y * nj.x))
			st.add_uv(Vector2(inci, incj))
			st.add_vertex(Vector3(ni.x * nk.x, nk.y, ni.y * nk.x))
	for i in range(1, aneis + 1):
		var antes: int = (i - 1) * (gomos + 1)
		var esta: int = i * (gomos + 1)
		for j in range(1, gomos + 1):
			st.add_index(esta + j - 1)
			st.add_index(antes + j)
			st.add_index(antes + j - 1)
			st.add_index(esta + j - 1)
			st.add_index(esta + j)
			st.add_index(antes + j)
	return st.commit()


func definir_protecao(ligada: bool) -> void:
	for g in _bumpers:
		g.visible = ligada
		var sb := g.get_node("fisica") as StaticBody
		sb.collision_layer = CAMADA_MUNDO if ligada else 0


# ================================================================ fundo dos pinos
## Peça lisa feita por perfil (scripts/perfis.gd).
func _peca(perfil: PoolVector2Array, z0: float, z1: float, mat: Material, nome := "", sombra := false) -> MeshInstance:
	var mi := MeshInstance.new()
	mi.mesh = Perfis.extrudar(perfil, z0, z1)
	mi.material_override = mat
	if not sombra:
		mi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	if nome != "":
		mi.name = nome
	add_child(mi)
	return mi


## Peça de perfil retangular (Perfis.retangulo) que também é parede: o
## desenho e um corpo parado com a mesma forma (colisão = o próprio desenho).
func _peca_solida(largura: float, altura: float, raio: float, centro: Vector2, z0: float, z1: float, mat: Material,
		atrito: float, quique: float, nome := "", quem := "todos") -> MeshInstance:
	var mi := _peca(Perfis.retangulo(largura, altura, raio, centro), z0, z1, mat, nome)
	_corpo_forma(_forma_retangulo(largura, altura, raio, centro, z0, z1), Vector3.ZERO, atrito, quique, quem)
	return mi


## A forma convexa de colisão de uma peça Perfis.retangulo(...) de z0 a z1,
## do tamanho da peça desenhada: encolhida pela margem, que a devolve ao
## tamanho certo (ver MARGEM_CONVEXA; peça fina usa a margem que couber).
## Quinas com 3 gomos (o desenho tem 10): a forma fica com 32 pontos em vez
## de 88 — a física procura o ponto mais longe a cada teste — e a margem
## arredonda o resto.
static func _forma_retangulo(largura: float, altura: float, raio: float, centro: Vector2, z0: float, z1: float) -> Shape:
	var m: float = min(MARGEM_CONVEXA, min(raio, min(largura, altura) * 0.45))
	var malha := Perfis.extrudar(Perfis.retangulo(largura - 2.0 * m, altura - 2.0 * m, raio - m, centro, 3), z0 + m, z1 - m)
	var forma := malha.create_convex_shape()
	forma.margin = m
	return forma


## O POÇO embaixo do alçapão: caixa virada do avesso (de cima só aparecem
## o fundo e as paredes de dentro) com o shader do poço (escurece com a
## fundura, faixas de luz), mais as paredes e o fundo de colisão — os pinos
## caem, batem e ficam lá embaixo até a máquina recolher.
func _poco_do_alcapao() -> void:
	var x := ALCAPAO_X - 0.003
	var z0 := ALCAPAO_Z0 - 0.003
	var z1 := ALCAPAO_Z1 + 0.003
	var topo := Y_CHAO_FOSSO + 0.0025
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/poco.shader")
	mat_poco = mat
	mat.set_shader_param("y_topo", Y_CHAO_FOSSO)
	mat.set_shader_param("y_fundo", POCO_FUNDO)
	var poco := MeshInstance.new()
	var pb := CubeMesh.new()
	pb.size = Vector3(x * 2.0, topo - POCO_FUNDO, z0 - z1)
	pb.flip_faces = true
	poco.mesh = pb
	poco.material_override = mat
	poco.translation = Vector3(0, (topo + POCO_FUNDO) / 2.0, (z0 + z1) / 2.0)
	poco.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	poco.name = "poco_alcapao"
	add_child(poco)
	var alto := (Y_CHAO_FOSSO - 0.04) - POCO_FUNDO
	var yc := (Y_CHAO_FOSSO - 0.04 + POCO_FUNDO) / 2.0
	# (só os pinos caem no poço)
	for s in [-1, 1]:
		_corpo_caixa(Vector3(0.1, alto, z0 - z1 + 0.2), Vector3(s * (x + 0.05), yc, (z0 + z1) / 2.0), 0.5, 0.25, "pinos")
	_corpo_caixa(Vector3(x * 2.0 + 0.2, alto, 0.1), Vector3(0, yc, z0 + 0.05), 0.5, 0.25, "pinos")
	_corpo_caixa(Vector3(x * 2.0 + 0.2, alto, 0.1), Vector3(0, yc, z1 - 0.05), 0.5, 0.25, "pinos")
	_corpo_caixa(Vector3(x * 2.0 + 0.2, 0.2, z0 - z1 + 0.2), Vector3(0, POCO_FUNDO - 0.1, (z0 + z1) / 2.0), 0.6, 0.3, "pinos")


## A CAÇAPA e o PORTAL no fim da pista: paredes laterais acolchoadas (os
## pinos batem e voltam), cortina pregueada nas cores do cenário com um
## halo de luz atrás dos pinos, e por fora um gabinete alto (esconde a
## máquina de pinos) com o letreiro STRIKE KIDS e, em cima, um ARCO de
## raios coloridos com lâmpadas — o fundo da pista é um portal de parque,
## nas cores de cada cenário. De qualquer ângulo é uma máquina inteira.
func _fundo_dos_pinos() -> void:
	var fosso := Materiais.cor_toon(Color("#16336E"), 0.0, {"borda": 0.3})
	mat_parede = Materiais.cor_toon(Color("#2A63C4"), 0.0, {"borda": 0.3, "especular": 0.25})
	mat_friso = Materiais.cor_toon(Color("#FFB627"), 0.0, {"borda": 0.25, "especular": 0.5})
	mat_gabinete = Materiais.cor_toon(Color("#E8384F"), 0.004, {"borda": 0.35, "especular": 0.12, "luz_minima": 0.3})
	var z_frente := Z_PINO1 + 0.9
	# paredes laterais (kickbacks): visual arredondado + a mesma colisão de antes.
	# A face de dentro fica a 0,955 do meio: a bola (raio 0,14) corre na
	# canaleta apoiada nos lábios, com o centro em 0,8, e passa sem raspar —
	# a 0,925 ela batia na quina da frente da parede e voltava para a pista
	# (ou saía voando por cima da divisória)
	for s in [-1, 1]:
		var x: float = s * (MEIA_LARGURA + CANALETA + 0.09)
		# colisão = o próprio desenho (o friso de cima também segura os pinos)
		# (acolchoadas: o pino bate e volta para a pista, mas sem pular)
		_peca_solida(0.12, 1.0, 0.05, Vector2(x, 0.35), Z_FUNDO, z_frente, mat_parede, 0.3, 0.2, "parede_%d" % s)
		_peca_solida(0.17, 0.07, 0.034, Vector2(x, 0.875), Z_FUNDO, z_frente + 0.02, mat_friso, 0.3, 0.2)
	# fosso: o chão EM VOLTA do alçapão (frente, fundo e beiradas; as
	# portinhas são da máquina de pinos) e o poço escuro embaixo delas
	var y_f := Y_CHAO_FOSSO - 0.1
	var meio_z := (ALCAPAO_Z0 + ALCAPAO_Z1) / 2.0
	var comp := ALCAPAO_Z0 - ALCAPAO_Z1
	_caixa(Vector3(2.0, 0.2, Z_FIM_DECK - ALCAPAO_Z0), Vector3(0, y_f, (Z_FIM_DECK + ALCAPAO_Z0) / 2), fosso, true, false, 0.9, 0.0)
	_caixa(Vector3(2.0, 0.2, ALCAPAO_Z1 - Z_FUNDO), Vector3(0, y_f, (ALCAPAO_Z1 + Z_FUNDO) / 2), fosso, true, false, 0.9, 0.0)
	for s in [-1, 1]:
		_caixa(Vector3(1.0 - ALCAPAO_X, 0.2, comp), Vector3(s * (1.0 + ALCAPAO_X) / 2.0, y_f, meio_z), fosso, true, false, 0.9, 0.0)
	_poco_do_alcapao()
	_cacapa_das_bolas()
	# cortina pregueada (estrelinhas + halo atrás dos pinos) em cima da boca
	mat_fundo = ShaderMaterial.new()
	mat_fundo.shader = load("res://shaders/fundo_estrelas.shader")
	var fundo := MeshInstance.new()
	fundo.mesh = Perfis.cortina(2.2, 1.95, 11, 0.07)
	fundo.material_override = mat_fundo
	fundo.translation = Vector3(0, Y_BOCA + 0.08 + 0.975, Z_FUNDO + 0.04)
	fundo.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	fundo.name = "cortina"
	add_child(fundo)
	# parede de trás: em cima vale para tudo; embaixo (a boca) só para os
	# pinos — a bola passa e cai na caçapa
	# (a frente de cada parede fica na frente do que se vê: as pregas da
	# cortina chegam a 7,5 cm e as tiras da boca a 3,6 cm da parede — o
	# pino para encostando nelas, sem entrar)
	_corpo_caixa(Vector3(2.4, 1.6, 0.2), Vector3(0, Y_BOCA + 0.8, Z_FUNDO + 0.075 - 0.1), 0.9, 0.0)
	var so_pinos := _corpo_caixa(Vector3(2.4, 0.9, 0.2), Vector3(0, Y_BOCA - 0.45, Z_FUNDO + 0.04 - 0.1), 0.9, 0.0, "pinos")
	so_pinos.collision_layer = CAMADA_SO_PINOS
	# teto escuro do fosso (esconde a parte de cima, vista de dentro)
	_caixa(Vector3(2.3, 0.1, -Z_FUNDO + Z_PINO1 + 0.7), Vector3(0, 2.12, (Z_PINO1 + 0.7 + Z_FUNDO) / 2),
		Materiais.cor_toon(Color("#0B1B3A"), 0.0, {"borda": 0.0}), false, false)
	# gabinete por fora: laterais, teto e fundo — alto, esconde a máquina
	var z_tras := Z_FUNDO - 0.95
	var z_masc := Z_PINO1 + 0.68
	for s in [-1, 1]:
		# um pino que voa por cima da parede bate no gabinete (não atravessa)
		_peca_solida(0.34, 3.7, 0.12, Vector2(s * 1.23, 1.55), z_tras + 0.3, z_masc, mat_gabinete, 0.4, 0.1, "gabinete_lado_%d" % s, "pinos")
	_peca(Perfis.retangulo(2.8, 0.32, 0.1, Vector2(0, 3.24)), z_tras + 0.3, z_masc, mat_gabinete, "gabinete_teto")
	# (o fundo é uma chapa atrás do túnel da caçapa: inteiro, até a cortina,
	# ele enchia o túnel e a bola entrava numa parede colorida)
	_peca(Perfis.retangulo(2.9, 3.75, 0.22, Vector2(0, 1.53)), z_tras, z_tras + 0.35, mat_gabinete, "gabinete_fundo")
	_peca(Perfis.retangulo(2.96, 0.09, 0.04, Vector2(0, 3.42)), z_tras - 0.03, z_masc, mat_friso)
	# letreiro (masking) acima dos pinos, com o logo e lâmpadas. A placa é
	# iluminada por dentro (luz mínima cheia): virada para longe do sol ela
	# ficava na sombra, quase preta — uma mancha escura atrás do logo
	mat_placa = Materiais.cor_toon(Color("#1E3FA0"), 0.004, {"borda": 0.15, "luz_minima": 1.0})
	_peca(Perfis.retangulo(2.7, 0.95, 0.07, Vector2(0, 1.85)), Z_PINO1 + 0.68, Z_PINO1 + 0.82, mat_placa, "placa")
	_peca(Perfis.retangulo(2.8, 1.05, 0.09, Vector2(0, 1.85)), Z_PINO1 + 0.66, Z_PINO1 + 0.78, mat_friso)
	var logo_tex := Materiais.textura("logo")
	if logo_tex != null:
		var logo := MeshInstance.new()
		var lq := QuadMesh.new()
		var asp := float(logo_tex.get_width()) / float(logo_tex.get_height())
		lq.size = Vector2(min(2.5, 0.86 * asp), min(2.5, 0.86 * asp) / asp)
		logo.mesh = lq
		logo.material_override = _mat_logo_letreiro(logo_tex)
		logo.translation = Vector3(0, 1.86, Z_PINO1 + 0.83)
		logo.name = "logo"
		add_child(logo)
	# ARCO em cima do letreiro: leque de raios nas cores do cenário (a frente)
	# sobre uma chapa escura, e a moldura amarela atrás
	mat_portal = ShaderMaterial.new()
	mat_portal.shader = load("res://shaders/raios.shader")
	var chapa := Materiais.cor_toon(Color("#2A1E3A"), 0.0, {"borda": 0.2})
	_peca(_perfil_arco(1.42, 2.22, 2.45, 0.86), Z_PINO1 + 0.69, Z_PINO1 + 0.79, chapa)
	var arco := MeshInstance.new()
	arco.mesh = _leque_raios(1.42, 2.22, 2.45, 0.86, 22, Z_PINO1 + 0.792)
	arco.material_override = mat_portal
	arco.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	arco.name = "arco"
	add_child(arco)
	_peca(_perfil_arco(1.52, 2.2, 2.45, 0.96), Z_PINO1 + 0.66, Z_PINO1 + 0.76, mat_friso)
	# lâmpadas: contorno do letreiro e do arco
	var pontos: Array = []
	var zc := Z_PINO1 + 0.83
	for i in 26:
		pontos.append(Vector3(-1.3 + i * 0.104, 1.41, zc))
	for i in 9:
		pontos.append(Vector3(-1.33, 1.41 + i * 0.11, zc))
		pontos.append(Vector3(1.33, 1.41 + i * 0.11, zc))
	for i in 31:
		var a: float = PI * float(i) / 30.0
		pontos.append(Vector3(cos(a) * 1.47, 2.45 + sin(a) * 0.91, zc - 0.02))
	mat_lampadas = ShaderMaterial.new()
	mat_lampadas.shader = load("res://shaders/lampadas.shader")
	add_child(lampadas_em(pontos))


## Material do logo dos letreiros: a imagem sem luz, misturada com a placa
## pela transparência dela (o filtro com mipmaps vem da importação). Com o
## fundo RECORTADO (alpha scissor) a sombra suave embaixo das letras virava
## um bloco escuro duro em volta do logo — a "marca preta" do letreiro.
static func _mat_logo_letreiro(logo_tex: Texture) -> SpatialMaterial:
	var ml := SpatialMaterial.new()
	ml.flags_unshaded = true
	ml.flags_transparent = true
	ml.albedo_texture = logo_tex
	return ml


## CAÇAPA DAS BOLAS: no fundo do fosso, embaixo da cortina, uma boca
## escura com moldura e cortina de tiras de borracha. A bola rola até lá,
## empurra as tiras e some no túnel (depois volta no retorno de bolas, perto
## de quem joga). Os pinos batem na boca e ficam no fosso.
const N_TIRAS = Medidas.N_TIRAS
## a faixa de cada cenário em texturas/cortina_bola.png
const LINHA_CORTINA := ["parque", "espaco", "mar", "dinos"]
const Y_CHAO_FOSSO = Medidas.Y_CHAO_FOSSO


func _cacapa_das_bolas() -> void:
	var escuro := SpatialMaterial.new()
	escuro.flags_unshaded = true
	escuro.albedo_color = Color("#05070D")
	var borracha := Materiais.cor_toon(Color("#20263A"), 0.0, {"borda": 0.3, "luz_minima": 0.35})
	var meia := LARGURA_BOCA / 2.0
	var alto := Y_BOCA - Y_CHAO_FOSSO
	var fundo := 0.55
	# túnel: chão (a bola rola para dentro), paredes, teto e fundo — escuros
	# (só a bola entra nele)
	_caixa(Vector3(LARGURA_BOCA + 0.2, 0.2, fundo), Vector3(0, Y_CHAO_FOSSO - 0.1, Z_FUNDO - fundo / 2), escuro, true, false, 0.3, 0.0, "bola")
	for s in [-1, 1]:
		_caixa(Vector3(0.1, alto + 0.1, fundo), Vector3(s * (meia + 0.05), Y_CHAO_FOSSO + alto / 2, Z_FUNDO - fundo / 2), escuro, true, false,
			0.4, 0.2, "bola")
	_caixa(Vector3(LARGURA_BOCA + 0.2, 0.1, fundo), Vector3(0, Y_BOCA + 0.05, Z_FUNDO - fundo / 2), escuro, false, false)
	_caixa(Vector3(LARGURA_BOCA + 0.2, alto + 0.2, 0.1), Vector3(0, Y_CHAO_FOSSO + alto / 2, Z_FUNDO - fundo - 0.05), escuro, true, false,
		0.4, 0.2, "bola")
	# dos lados da boca, a parede de borracha (até as paredes da caçapa)
	for s in [-1, 1]:
		var x0 := meia + 0.06
		var x1 := MEIA_LARGURA + CANALETA + 0.06
		_caixa(Vector3(x1 - x0, alto + 0.14, 0.12), Vector3(s * (x0 + x1) / 2.0, Y_CHAO_FOSSO + (alto + 0.14) / 2.0 - 0.07, Z_FUNDO - 0.02),
			borracha, false, false)
	# moldura amarela em volta da boca + filete de luz em cima (colidem
	# como são: os pinos param nelas; a bola passa no vão do meio)
	_peca_solida(LARGURA_BOCA + 0.26, 0.12, 0.05, Vector2(0, Y_BOCA + 0.06), Z_FUNDO - 0.04, Z_FUNDO + 0.1, mat_friso, 0.5, 0.2)
	for s in [-1, 1]:
		_peca_solida(0.13, alto + 0.12, 0.05, Vector2(s * (meia + 0.065), Y_CHAO_FOSSO + (alto + 0.12) / 2.0 - 0.02),
			Z_FUNDO - 0.04, Z_FUNDO + 0.1, mat_friso, 0.5, 0.2)
	mat_boca_luz = Materiais.cor_toon(Color("#FFFFFF"), 0.0, {"emissao": Color(0.6, 0.9, 1.0), "borda": 0.0})
	_caixa(Vector3(LARGURA_BOCA, 0.025, 0.02), Vector3(0, Y_BOCA + 0.005, Z_FUNDO + 0.105), mat_boca_luz, false, false)
	# CORTINA de tiras de borracha com o desenho do cenário (6.3): as 7
	# tiras numa malha só (um desenho); cada uma gira presa em cima, para
	# DENTRO, no shader (shaders/cortina.shader; tools/cortina_bola.py)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var larg_tira := LARGURA_BOCA / N_TIRAS
	var alto_tira := alto - 0.03
	for i in N_TIRAS:
		# 3 mm de vão entre as tiras (lê-se a borracha) — atrás é o túnel escuro
		var x0: float = -meia + larg_tira * i + 0.0015
		var x1: float = x0 + larg_tira - 0.003
		var cantos := [Vector3(x0, 0, 0), Vector3(x1, 0, 0), Vector3(x1, -alto_tira, 0), Vector3(x0, -alto_tira, 0)]
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		# (Godot 3: a frente é a do sentido horário)
		for k in [0, 1, 2, 0, 2, 3]:
			st.add_normal(Vector3.BACK)
			st.add_uv(uvs[k])
			st.add_uv2(Vector2(i, 0))
			st.add_vertex(cantos[k])
	mat_cortina = ShaderMaterial.new()
	mat_cortina.shader = load("res://shaders/cortina.shader")
	mat_cortina.set_shader_param("desenho", load("res://texturas/cortina_bola.png"))
	_tiras = MeshInstance.new()
	_tiras.mesh = st.commit()
	_tiras.material_override = mat_cortina
	_tiras.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	_tiras.translation = Vector3(0, Y_BOCA - 0.015, Z_FUNDO + 0.03)
	_tiras.name = "cortina_bola"
	add_child(_tiras)
	# (Godot 3: o resize não zera os números novos)
	_abertura_tiras = PoolRealArray()
	for i in N_TIRAS:
		_abertura_tiras.append(0.0)
	_mexer_tiras(0.0)


## As tiras abrem (giram para DENTRO, presas em cima) quando a bola passa.
func _mexer_tiras(delta: float) -> void:
	var meia := LARGURA_BOCA / 2.0
	var pb: Vector3 = bola.global_translation if bola != null and bola.visible else Vector3(100, 100, 100)
	var mexeu := delta <= 0.0
	for i in N_TIRAS:
		var x: float = -meia + LARGURA_BOCA * (float(i) + 0.5) / N_TIRAS
		var alvo := 0.0
		# abrem ANTES de a bola chegar (e depressa): ela nunca encosta nelas
		if abs(pb.z - Z_FUNDO) < 0.8 and abs(pb.x - x) < 0.3 and pb.y < Y_BOCA:
			alvo = 1.25
		var a: float = _abertura_tiras[i]
		var novo: float = move_toward(a, alvo, delta * (14.0 if alvo > a else 2.2))
		if novo != a or mexeu:
			_abertura_tiras[i] = novo
			mat_cortina.set_shader_param("a%d" % i, novo)


## A bola que caiu na caçapa sai rolando de baixo da capota do retorno de
## bolas e encosta nas outras.
func retorno_bola(mat: Material) -> void:
	if _bola_volta == null:
		_bola_volta = MeshInstance.new()
		var sm := SphereMesh.new()
		sm.radius = Bola.RAIO
		sm.height = Bola.RAIO * 2.0
		sm.radial_segments = 20
		sm.rings = 10
		_bola_volta.mesh = sm
		_bola_volta.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
		add_child(_bola_volta)
	_bola_volta.material_override = mat
	_bola_volta.visible = true
	_bola_volta.translation = RETORNO + Vector3(0, 0.69, 0.62)
	_bola_volta.rotation = Vector3.ZERO
	var tw := create_tween()
	tw.tween_property(_bola_volta, "translation:z", RETORNO.z + 0.26, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_bola_volta, "rotation:x", -4.0, 0.55).set_ease(Tween.EASE_OUT)
	tw.tween_property(_bola_volta, "translation:z", RETORNO.z + 0.29, 0.08)
	tw.tween_property(_bola_volta, "translation:z", RETORNO.z + 0.26, 0.1)


## Esconde a bola do retorno (ela vai para a mão do bichinho).
func guardar_retorno() -> void:
	if _bola_volta:
		_bola_volta.visible = false


## Leque de raios do arco: do meio da base (0, y0) até o contorno do arco
## (laterais retas até yc + meia-elipse), `setores` raios alternando cor.
## COLOR.r = qual das 2 cores; COLOR.g = 0 no centro, 1 na borda.
static func _leque_raios(r: float, y0: float, yc: float, alto: float, setores: int, z: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sub := 4
	var centro := Vector3(0, y0, z)
	for k in setores:
		var cor := Color(float(k % 2), 1.0, 0.0)
		var cor_c := Color(float(k % 2), 0.0, 0.0)
		for j in sub:
			var a0: float = PI * (float(k) + float(j) / sub) / setores
			var a1: float = PI * (float(k) + float(j + 1) / sub) / setores
			var p0 := _borda_do_arco(a0, r, y0, yc, alto)
			var p1 := _borda_do_arco(a1, r, y0, yc, alto)
			# frente virada para +Z (horário visto de +Z: centro, p1, p0)
			for v in [[centro, cor_c], [Vector3(p1.x, p1.y, z), cor], [Vector3(p0.x, p0.y, z), cor]]:
				st.add_color(v[1])
				st.add_normal(Vector3(0, 0, 1))
				st.add_vertex(v[0])
	return st.commit()


## Onde o raio de ângulo `ang` (saindo do meio da base) encontra o contorno
## do arco (Godot 3: sem lambda).
static func _borda_do_arco(ang: float, r: float, y0: float, yc: float, alto: float) -> Vector2:
	var d := Vector2(cos(ang), sin(ang))
	# laterais retas (x = ±r, até yc)
	if abs(d.x) > 1e-4:
		var t_lado: float = r / abs(d.x)
		var y_lado := y0 + t_lado * d.y
		if y_lado <= yc:
			return Vector2(t_lado * d.x, y_lado)
	# meia-elipse: (x/r)² + ((y - yc)/alto)² = 1, com x = t·dx, y = y0 + t·dy
	var a := (d.x * d.x) / (r * r) + (d.y * d.y) / (alto * alto)
	var b := 2.0 * (y0 - yc) * d.y / (alto * alto)
	var c := (y0 - yc) * (y0 - yc) / (alto * alto) - 1.0
	var t := (-b + sqrt(max(b * b - 4.0 * a * c, 0.0))) / (2.0 * a)
	return Vector2(t * d.x, y0 + t * d.y)


## Contorno do arco: base reta em y0, laterais até yc e meia-elipse
## (raio r na largura, `alto` na altura) por cima. Anti-horário.
static func _perfil_arco(r: float, y0: float, yc: float, alto: float) -> PoolVector2Array:
	var p := PoolVector2Array()
	p.append(Vector2(r, y0))
	for i in 49:
		var a: float = PI * float(i) / 48.0
		p.append(Vector2(cos(a) * r, yc + sin(a) * alto))
	p.append(Vector2(-r, y0))
	return p


## Colunas dos dois lados do letreiro, com faixas de lâmpadas: fecham a
## frente do gabinete da máquina (cor do cenário).
func _colunas() -> void:
	var zc := Z_PINO1 + 0.75
	var pontos: Array = []
	mat_coluna = Materiais.cor_toon(Color("#1E62C8"), 0.004, {"borda": 0.35, "especular": 0.3})
	for s in [-1, 1]:
		var x: float = s * 1.93
		_peca(Perfis.retangulo(1.16, 3.0, 0.14, Vector2(x, 1.15)), zc - 0.07, zc + 0.07, mat_coluna, "coluna_%d" % s)
		_peca(Perfis.retangulo(1.26, 0.12, 0.05, Vector2(x, 2.7)), zc - 0.09, zc + 0.09, mat_friso)
		for i in 23:
			pontos.append(Vector3(x - s * 0.5, 0.2 + i * 0.1, zc + 0.08))
			pontos.append(Vector3(x + s * 0.5, 0.2 + i * 0.1, zc + 0.08))
	add_child(lampadas_em(pontos, 50))


## O SÍMBOLO DA LAZER & SPORT EM TODO CENÁRIO, sutil, flutuando ao lado
## da pista (sempre no mesmo lugar, boiando de leve), cada um do jeito do
## cenário: o balãozinho (Parque), o planetinha com anel (Espaço), a bolha
## (Fundo do Mar) e o pterossauro segurando a plaquinha (Selva dos Dinos).
func _marcas_dos_cenarios() -> void:
	_marcas["parque"] = _balao_marca()
	_marcas["espaco"] = _planeta_marca()
	_marcas["mar"] = _bolha_marca()
	_marcas["dinos"] = _ptero_marca()
	for k in _marcas:
		(_marcas[k] as Spatial).visible = false
	balao = _marcas["parque"]


func _novo_simbolo(nome: String, escala: float) -> Spatial:
	var n := Spatial.new()
	n.name = nome
	n.translation = BALAO_POS
	n.scale = Vector3.ONE * escala
	add_child(n)
	return n


## Material com a logo (sem fundo) estampada na frente da peça (+Z).
## largura: da logo, nas medidas da própria malha; esticar_y: a escala Y
## da peça (para a logo não sair esticada).
func _mat_logo(tinta: Color, largura: float, centro := Vector2.ZERO, esticar_y := 1.0, extra := {}) -> ShaderMaterial:
	var p := {"usa_rosto": true, "rosto": load("res://ui/marca/lazer_sport.png"), "rosto_grade": Vector2(1, 1),
		"rosto_celula": Vector2.ZERO, "rosto_centro": centro,
		"rosto_tamanho": Vector2(largura, largura * 1698.0 / 2560.0 / esticar_y), "borda": 0.4, "faixa": 0.12, "luz_minima": 0.38,
		"especular": 0.3, "tamanho_especular": 0.985, "tinta": tinta}
	p.merge(extra, true)
	return Materiais.toon(true, 0.004, p)


func _esfera(raio := 1.0, gomos := 24) -> SphereMesh:
	var sm := SphereMesh.new()
	sm.radius = raio
	sm.height = raio * 2.0
	sm.radial_segments = gomos
	sm.rings = gomos / 2
	return sm


func _peca_simbolo(pai: Spatial, malha: Mesh, mat: Material, pos := Vector3.ZERO) -> MeshInstance:
	var mi := MeshInstance.new()
	mi.mesh = malha
	mi.material_override = mat
	mi.translation = pos
	mi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	pai.add_child(mi)
	return mi


## Parque: o balãozinho com a logo (~60 cm).
func _balao_marca() -> Spatial:
	var b := _novo_simbolo("balao_marca", 0.3)
	mat_balao = _mat_logo(Color("#E8384F"), 1.32, Vector2(0.0, 0.06), 1.12)
	var corpo := _peca_simbolo(b, _esfera(), mat_balao)
	corpo.scale = Vector3(1.0, 1.12, 1.0)
	# nó e cordão
	var cm := CylinderMesh.new()
	cm.top_radius = 0.025
	cm.bottom_radius = 0.09
	cm.height = 0.14
	cm.radial_segments = 12
	_peca_simbolo(b, cm, mat_balao, Vector3(0, -1.17, 0))
	var cc := CylinderMesh.new()
	cc.top_radius = 0.012
	cc.bottom_radius = 0.012
	cc.height = 4.2
	cc.radial_segments = 6
	_peca_simbolo(b, cc, Materiais.cor_toon(Color("#FFFFFF"), 0.0, {"borda": 0.0, "luz_minima": 0.6}), Vector3(0, -1.24 - 2.1, 0))
	return b


## Espaço: um planetinha roxo com anel amarelo e a logo na frente.
func _planeta_marca() -> Spatial:
	var b := _novo_simbolo("planeta_marca", 0.27)
	_peca_simbolo(b, _esfera(), _mat_logo(Color("#7B61FF"), 1.3, Vector2.ZERO, 1.0,
		{"borda": 0.7, "cor_borda": Color("#9FE8FF")}))
	# o anel passa por baixo da logo (inclinado para a frente)
	# (Godot 3: sem TorusMesh — o mesmo toroide, feito aqui)
	var anel := _toro(1.32, 1.62, 48, 8)
	var a := _peca_simbolo(b, anel, Materiais.cor_toon(Color("#FFD43B"), 0.003, {"borda": 0.5, "luz_minima": 0.5}))
	a.rotation_degrees = Vector3(32, 0, -12)
	a.scale = Vector3(1.0, 0.35, 1.0)
	return b


## Fundo do Mar: uma bolha com a logo dentro e bolhinhas subindo.
func _bolha_marca() -> Spatial:
	var b := _novo_simbolo("bolha_marca", 0.3)
	_peca_simbolo(b, _esfera(), _mat_logo(Color("#C9F4FF"), 1.25, Vector2.ZERO, 1.0,
		{"borda": 1.3, "cor_borda": Color(1, 1, 1), "luz_minima": 0.75, "especular": 0.45, "tamanho_especular": 0.985}))
	var mb := Materiais.cor_toon(Color("#DDF8FF"), 0.0, {"borda": 1.4, "cor_borda": Color(1, 1, 1), "luz_minima": 0.8})
	for i in 4:
		var bi := _peca_simbolo(b, _esfera(1.0, 12), mb)
		bi.scale = Vector3.ONE * (0.12 + 0.05 * (i % 2))
		_bolhinhas.append(bi)
	return b


## Selva dos Dinos: um pterossauro batendo asas, segurando a plaquinha de
## madeira com a logo.
func _ptero_marca() -> Spatial:
	var b := _novo_simbolo("ptero_marca", 1.0)
	var moldura := CubeMesh.new()
	moldura.size = Vector3(0.74, 0.52, 0.05)
	_peca_simbolo(b, moldura, Materiais.cor_toon(Color("#7A4A22"), 0.003, {"borda": 0.25}), Vector3(0, 0, -0.012))
	var placa := CubeMesh.new()
	placa.size = Vector3(0.68, 0.46, 0.05)
	_peca_simbolo(b, placa, _mat_logo(Color("#FFE9C2"), 0.62, Vector2.ZERO, 1.0, {"borda": 0.2, "especular": 0.0}))
	# cordinhas até os pés do pterossauro
	var mc := Materiais.cor_toon(Color("#5A3A1A"), 0.0, {"borda": 0.0, "luz_minima": 0.5})
	for lado in [-1.0, 1.0]:
		var c := CylinderMesh.new()
		c.top_radius = 0.006
		c.bottom_radius = 0.006
		c.height = 0.36
		c.radial_segments = 5
		var mi := _peca_simbolo(b, c, mc, Vector3(lado * 0.17, 0.4, 0.0))
		mi.rotation.z = lado * 0.45
	_ptero_simbolo = _peca_simbolo(b, load("res://modelos/cenario/ptero.res"), null, Vector3(0, 0.66, 0.02))
	_ptero_simbolo.scale = Vector3.ONE * 0.62
	_ptero_simbolo.name = "ptero"
	return b


func _mostrar_marca(nome: String) -> void:
	for k in _marcas:
		(_marcas[k] as Spatial).visible = k == nome
	balao = _marcas.get(nome, _marcas["parque"])


# ================================================================ área dos jogadores
## Atrás de quem joga: tapete, uma mureta nas cores do cenário (por cima
## dela aparece o cenário — o parque, o fundo do mar...), o letreiro STRIKE
## KIDS em dois postes, sofás e o retorno de bolas. Quando a câmera vira
## para o mascote, o fundo é o próprio cenário, sem chão infinito.
func _area_dos_jogadores() -> void:
	var z_parede := 7.7
	var marinho := Materiais.cor_toon(Color("#123A7A"), 0.004, {"borda": 0.3, "especular": 0.2})
	var azul := Materiais.cor_toon(Color("#1E62C8"), 0.0, {"borda": 0.3})
	var vermelho := Materiais.cor_toon(Color("#E8384F"), 0.004, {"borda": 0.3, "especular": 0.3})
	var tapete := Materiais.cor_toon(Color("#1B3E86"), 0.0, {"borda": 0.15})
	# tapete entre a área de aproximação e a mureta (+ friso amarelo)
	_caixa(Vector3(9.6, 0.06, z_parede - 6.3), Vector3(0, -0.03, (6.3 + z_parede) / 2), tapete, false, false)
	_caixa(Vector3(6.6, 0.065, 0.07), Vector3(0, -0.03, 6.33), mat_friso, false, false)
	# mureta (cor do cenário) com friso amarelo em cima
	_peca(Perfis.retangulo(9.6, 1.1, 0.12, Vector2(0, 0.55)), z_parede, z_parede + 0.3, mat_gabinete, "mureta")
	_peca(Perfis.retangulo(9.7, 0.1, 0.05, Vector2(0, 1.12)), z_parede - 0.03, z_parede + 0.33, mat_friso)
	# letreiro STRIKE KIDS em dois postes, virado para a pista, com lâmpadas
	for s in [-1, 1]:
		_peca(Perfis.retangulo(0.16, 3.0, 0.07, Vector2(s * 1.9, 1.5)), z_parede - 0.2, z_parede - 0.04, mat_coluna)
	_peca(Perfis.retangulo(4.0, 1.75, 0.16, Vector2(0, 2.55)), z_parede - 0.18, z_parede - 0.06, mat_placa, "placa_fundo")
	var logo_tex := Materiais.textura("logo")
	var pontos: Array = []
	if logo_tex != null:
		var lq := QuadMesh.new()
		var lw := 3.0
		lq.size = Vector2(lw, lw * float(logo_tex.get_height()) / float(logo_tex.get_width()))
		var logo := MeshInstance.new()
		logo.mesh = lq
		logo.material_override = _mat_logo_letreiro(logo_tex)
		logo.rotation_degrees.y = 180
		logo.translation = Vector3(0, 2.55, z_parede - 0.2)
		logo.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
		add_child(logo)
		for i in 30:
			var x: float = -1.85 + i * (3.7 / 29.0)
			pontos.append(Vector3(x, 3.35, z_parede - 0.21))
			pontos.append(Vector3(x, 1.75, z_parede - 0.21))
	add_child(lampadas_em(pontos, 200))
	# sofás vermelhos encostados na mureta
	for s in [-1, 1]:
		var sofa := Spatial.new()
		sofa.translation = Vector3(s * 3.4, 0, z_parede - 0.42)
		sofa.rotation_degrees.y = 90
		add_child(sofa)
		for parte in [[Perfis.retangulo(0.66, 0.42, 0.12, Vector2(0.0, 0.21)), 0.0],
				[Perfis.retangulo(0.2, 0.86, 0.09, Vector2(-0.27, 0.43)), 0.0],
				[Perfis.retangulo(0.66, 0.6, 0.1, Vector2(0.0, 0.3)), 1.0]]:
			var mi := MeshInstance.new()
			if parte[1] == 0.0:
				mi.mesh = Perfis.extrudar(parte[0], -1.1, 1.1)
			else:
				mi.mesh = Perfis.extrudar(parte[0], -0.12, 0.12)
			mi.material_override = vermelho if parte[1] == 0.0 else marinho
			sofa.add_child(mi)
			if parte[1] == 1.0:
				var outro := mi.duplicate() as MeshInstance
				mi.translation.z = -1.2
				outro.translation.z = 1.2
				sofa.add_child(outro)
	# retorno de bolas (como num boliche de verdade), do lado direito
	var ret := Spatial.new()
	ret.translation = RETORNO
	add_child(ret)
	var corpo := MeshInstance.new()
	corpo.mesh = Perfis.extrudar(Perfis.retangulo(0.56, 0.5, 0.1, Vector2(0, 0.25)), -0.8, 0.8)
	corpo.material_override = marinho
	ret.add_child(corpo)
	var capo := MeshInstance.new()
	capo.mesh = Perfis.extrudar(Perfis.retangulo(0.6, 0.5, 0.24, Vector2(0, 0.62)), 0.25, 0.8)
	capo.material_override = azul
	ret.add_child(capo)
	var trilho := MeshInstance.new()
	trilho.mesh = Perfis.extrudar(Perfis.retangulo(0.5, 0.06, 0.03, Vector2(0, 0.53)), -0.78, 0.3)
	trilho.material_override = mat_friso
	ret.add_child(trilho)
	var cores := [Color("#169BD5"), Color("#FF7A21"), Color("#2DBE4E")]
	for i in 3:
		var b := MeshInstance.new()
		var sm := SphereMesh.new()
		sm.radius = 0.13
		sm.height = 0.26
		sm.radial_segments = 16
		sm.rings = 8
		b.mesh = sm
		b.material_override = Materiais.cor_toon(cores[i], 0.003, {"borda": 0.4, "especular": 0.8})
		b.translation = Vector3(0, 0.69, -0.62 + i * 0.29)
		ret.add_child(b)


# ================================================================ pódios
func _montar_podios() -> void:
	for i in 2:
		var g := Spatial.new()
		g.visible = false
		g.name = "podio_%d" % i
		add_child(g)
		var cor := Color("#169BD5") if i == 0 else Color("#FF7A21")
		var base := MeshInstance.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.4
		cm.bottom_radius = 0.45
		cm.height = 0.14
		cm.radial_segments = 48
		cm.rings = 1
		base.mesh = cm
		base.translation.y = 0.07
		base.material_override = Materiais.cor_toon(cor, 0.004, {"borda": 0.35})
		g.add_child(base)
		var tampa := MeshInstance.new()
		var ct := CylinderMesh.new()
		ct.top_radius = 0.37
		ct.bottom_radius = 0.37
		ct.height = 0.012
		ct.radial_segments = 48
		ct.rings = 1
		tampa.mesh = ct
		tampa.translation.y = 0.146
		tampa.material_override = Materiais.cor_toon(Color("#F4F8FF"), 0.0, {"borda": 0.2})
		g.add_child(tampa)
		# anel de luz em volta da tampa (acende no escolhido)
		# (Godot 3: sem TorusMesh — o mesmo toroide, feito aqui)
		var aro := MeshInstance.new()
		aro.mesh = _toro(0.37, 0.405, 64, 10)
		aro.translation.y = 0.142
		var ma := Materiais.cor_toon(Color("#FFD43B"), 0.0, {"borda": 0.0, "emissao": Color(0, 0, 0)})
		aro.material_override = ma
		aro.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
		g.add_child(aro)
		_podios.append(g)
		_mats_podio.append(ma)


## Liga/desliga os pódios (posições no chão) e acende o do escolhido.
func podios(ligar: bool, posicoes: Array = [], destaque := -1) -> void:
	for i in _podios.size():
		var g: Spatial = _podios[i]
		var ia := not g.visible
		g.visible = ligar and i < posicoes.size()
		if g.visible:
			g.translation = posicoes[i]
			if ia:
				g.scale = Vector3(1, 0.2, 1)
				create_tween().tween_property(g, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_podio_destaque = destaque


## Lâmpada: bolinha de 64 triângulos (são centenas delas na tela).
## (Godot 3: sem "static var" — a malha fica guardada em Compat.estado)
static func _malha_lampada() -> SphereMesh:
	var e := Compat.estado("mundo")
	if not e.has("lampada"):
		var l := SphereMesh.new()
		l.radius = 0.07
		l.height = 0.14
		# (227 lâmpadas: 36 triângulos cada — de longe ninguém vê a diferença)
		l.radial_segments = 6
		l.rings = 2
		e["lampada"] = l
	return e["lampada"]


## Fileira de lâmpadas (MultiMesh) que piscam com o material comum.
func lampadas_em(pontos: Array, fase0 := 0) -> MultiMeshInstance:
	var cores := [Color("#FFE14D"), Color("#FF9F2E"), Color("#4FD8FF"), Color("#8DFF6A")]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	# Godot 3: os formatos antes do número de cópias
	mm.color_format = MultiMesh.COLOR_FLOAT
	mm.custom_data_format = MultiMesh.CUSTOM_DATA_FLOAT
	mm.mesh = _malha_lampada()
	mm.instance_count = pontos.size()
	for i in pontos.size():
		mm.set_instance_transform(i, Transform(Basis().scaled(Vector3.ONE * 0.75), pontos[i]))
		mm.set_instance_color(i, cores[i % cores.size()])
		mm.set_instance_custom_data(i, Color(float(i + fase0), 0, 0, 0))
	var mmi := MultiMeshInstance.new()
	mmi.multimesh = mm
	mmi.material_override = mat_lampadas
	mmi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	return mmi


# ================================================================ decoração
func _objeto(nome: String, pos: Vector3, rot_y := 0.0, escala := 1.0, contorno := 0.0, pai: Node = null) -> MeshInstance:
	var mi := MeshInstance.new()
	var caminho := "res://modelos/cenario/%s.res" % nome
	if not ResourceLoader.exists(caminho):
		push_warning("modelo que falta: " + caminho)
		return mi
	mi.mesh = load(caminho)
	mi.material_override = Materiais.toon(false, contorno, {"borda": 0.3})
	mi.translation = pos
	mi.rotation.y = rot_y
	mi.scale = Vector3.ONE * escala
	# só os objetos perto da pista fazem sombra (economiza a placa de vídeo)
	if abs(pos.x) > 4.5 or pos.z < -18.0:
		mi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	(pai if pai != null else self).add_child(mi)
	return mi


## Mesma fórmula do tools/modelos/modelos.py (gerar_terreno), para apoiar
## os objetos no chão.
func _altura_terreno(x: float, z: float) -> float:
	var morros := [[-9, -20, 6, 2.2], [10, -26, 7, 2.6], [-14, -42, 9, 3.4], [15, -48, 10, 3.8], [0, -64, 16, 5.0],
		[-20, -10, 6, 1.8], [21, -8, 7, 2.2], [-26, -30, 9, 4.0], [27, -34, 10, 4.5], [-6, -52, 6, 2.0], [6, -58, 7, 2.4]]
	var h := 0.0
	for m in morros:
		h += m[3] * exp(-((x - m[0]) * (x - m[0]) + (z - m[1]) * (z - m[1])) / (2.0 * m[2] * m[2]))
	var p: float = clamp((abs(x) - 3.2) / 4.0, 0.0, 1.0)
	p = p * p * (3.0 - 2.0 * p)
	return h * p + 0.06 * sin(x * 0.7) * sin(z * 0.55) * p - 0.02 - 0.22 * (1.0 - p)


# ================================================================ animação
func acender_pista(ligar: bool) -> void:
	_luz_alvo = 1.0 if ligar else 0.0


func _process(delta: float) -> void:
	if mat_pista == null:
		return
	_t = fposmod(_t + delta, 3600.0)
	_luz = move_toward(_luz, _luz_alvo, delta * 2.5)
	mat_pista.set_shader_param("luz", _luz)
	var fase := fposmod(_t * 2.2, 1.0)
	mat_pista.set_shader_param("fase", fase)
	# o tempo das canaletas já numa volta (canaleta.shader)
	for m in mats_canaleta:
		m.set_shader_param("fase", fposmod(_t * 1.3, 1.0))
		m.set_shader_param("onda1", fposmod(_t * 1.7, TAU))
		m.set_shader_param("onda2", fposmod(_t * 2.2, TAU))
		m.set_shader_param("bolhas", fposmod(_t * 0.12, 3.52))
	mat_pista.set_shader_param("fase_lenta", fposmod(_t * 0.75, 1.0))
	mat_pista.set_shader_param("pulso", 0.5 + 0.5 * sin(_t * 3.1))
	if mat_piso:
		mat_piso.set_shader_param("pulso", 0.5 + 0.5 * sin(_t * 3.1))
	mat_pista.set_shader_param("bola_z", bola_z)
	mat_lampadas.set_shader_param("fase", fposmod(_t * 0.9, 100.0))
	# o símbolo do cenário flutua — sobe e desce, vai e volta e balança
	if balao.visible:
		_mexer_marca()
	mat_fundo.set_shader_param("fase", fposmod(_t * 0.4, 100.0))
	mat_portal.set_shader_param("pulso", sin(_t * 2.2))
	_mexer_tiras(delta)
	for i in _mats_podio.size():
		var on := 0.0
		if i == _podio_destaque:
			on = 0.75 + 0.25 * sin(_t * 6.0)
		_mats_podio[i].set_shader_param("emissao", Color(1.0, 0.75, 0.15) * on * 1.6)


func _mexer_marca() -> void:
	balao.translation = BALAO_POS + Vector3(sin(_t * 0.31) * 0.18, sin(_t * 0.8) * 0.14, sin(_t * 0.23) * 0.1)
	match tema:
		"espaco":
			balao.rotation = Vector3(sin(_t * 0.4) * 0.06, sin(_t * 0.3) * 0.35, sin(_t * 0.5) * 0.05)
		"mar":
			var pulso := sin(_t * 2.0)
			balao.rotation = Vector3(0, sin(_t * 0.35) * 0.25, sin(_t * 0.6) * 0.06)
			balao.scale = Vector3(1.0 + pulso * 0.03, 1.0 - pulso * 0.03, 1.0 + pulso * 0.03) * 0.3
			for i in _bolhinhas.size():
				# sobem em volta da bolha e recomeçam embaixo
				var f: float = fposmod(_t * 0.22 + i * 0.25, 1.0)
				var a: float = i * 1.9 + _t * 0.4
				var bi: Spatial = _bolhinhas[i]
				bi.translation = Vector3(cos(a) * 1.25, -1.0 + f * 3.4, sin(a) * 0.5 + 0.3)
				bi.visible = f < 0.92
		"dinos":
			balao.rotation = Vector3(sin(_t * 0.7) * 0.05, sin(_t * 0.4) * 0.22, sin(_t * 0.9) * 0.06)
			var pt := balao.get_node("ptero") as Spatial
			# bate asas: o corpo sobe e desce um tiquinho, inclinando
			pt.translation.y = 0.66 + sin(_t * 5.0) * 0.025
			pt.rotation.x = sin(_t * 5.0) * 0.08
		_:
			balao.rotation = Vector3(sin(_t * 0.5) * 0.05, sin(_t * 0.45) * 0.3, sin(_t * 0.6) * 0.08)


## Modo das lâmpadas: 0 corrida, 1 piscando todas (strike!), 2 alternado.
func lampadas(modo: int) -> void:
	mat_lampadas.set_shader_param("modo", modo)
