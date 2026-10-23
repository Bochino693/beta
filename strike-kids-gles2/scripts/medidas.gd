class_name Medidas
extends Reference

## MEDIDAS DO MUNDO 3D (pista, pinos, fosso, camadas da física).
##
## Edição OpenGL ES 2.0: no Godot 3 duas classes não podem se citar uma à
## outra (o Mundo usa Bola, Pinos e Temas; eles usavam as medidas do Mundo).
## As medidas moram aqui, numa classe sem dependências; o Mundo repete os
## mesmos nomes (const X = Medidas.X) para o código dele não mudar.
##
## Linha de falta em z = 0; os pinos em z = -10,5 (pista infantil, mais
## curta que a de adulto: a bola chega rápido); a pista vai para -Z.

const MEIA_LARGURA := 0.675
const CANALETA := 0.25
const Z_PINO1 := -10.5
const ESPACO_PINOS := 0.38
const FILEIRA := 0.329
const Z_FIM_DECK := -11.95
const Z_FUNDO := -13.7
## para-choques: 10 pedaços de 0,96 m a partir da linha de falta — acabam
## em z = -9,8, antes da barra varredora (z = -10) e do fosso
const N_BUMPERS := 10
## ALÇAPÃO no chão do fosso: o vão das duas portinhas (scripts/maquina.gd
## abre depois da varrida e os pinos caem). Embaixo, um POÇO fundo de
## verdade, com paredes e fundo que seguram os pinos.
const ALCAPAO_X := 0.9
const ALCAPAO_Z0 := -12.0
const ALCAPAO_Z1 := -13.62
const POCO_FUNDO := -1.75

const CAMADA_MUNDO := 1
const CAMADA_PINOS := 2
const CAMADA_BOLA := 4
const CAMADA_PISO_BOLA := 8
const CAMADA_PISO_PINOS := 16
const CAMADA_SO_PINOS := 32      # parede que segura os pinos mas deixa a bola passar (caçapa)
## topo da boca da caçapa das bolas (no fundo do fosso)
const Y_BOCA := 0.28
const LARGURA_BOCA := 1.5
## retorno de bolas (perto de quem joga)
const RETORNO := Vector3(2.35, 0, 5.2)
const ALTURA_PODIO := 0.152
const BALAO_POS := Vector3(-1.75, 2.2, -7.5)
const N_TIRAS := 7
const Y_CHAO_FOSSO := -0.14


## Onde um objeto movido pela física APARECE neste quadro (interpolado
## entre dois passos). No quadro de um teletransporte (bola saindo da mão,
## pino recolocado) o Godot ainda devolve o lugar antigo: aí vale o atual.
static func na_tela(n: Spatial) -> Transform:
	if not n.is_physics_interpolated_and_enabled():
		return n.global_transform
	var t := n.get_global_transform_interpolated()
	var g := n.global_transform
	if t.origin.distance_squared_to(g.origin) > 1.0:
		return g
	return t


# ================================================================ física
## ATRITO E QUIQUE NA BULLET. No Godot 4 (Jolt) o par de corpos usava o
## MENOR atrito dos dois e a SOMA dos quiques; a Bullet do Godot 3
## MULTIPLICA os dois valores. Os números de cada corpo são convertidos
## para que os pares que importam saiam como pedidos:
##   pino x pino: atrito 0,38, quique 0,2;  bola x pino: 0,12 e 0,3.
## PINO DE MADEIRA, PESADO (versão 6.1): com quique 0,5 os pinos ainda
## pareciam de plástico — davam 40 a 70 quiques por jogada, giravam até 10
## voltas por segundo e não paravam em 3 s. Com 0,2 entre eles, metade do
## quique da superfície no chão e nas paredes e o giro amortecido, eles
## batem, tombam, deslizam um pouco e param, como pino de verdade.
const QUIQUE_PINO_SOMA := 0.0   # a parte de cada pino na soma (o Godot 4 somava)
const QUIQUE_PINO_SUPERFICIE := 0.5  # pino x chão/parede: metade do quique da superfície
const ATRITO_PINO := 0.6164     # sqrt(0.38)
const QUIQUE_PINO := 0.4472     # sqrt(0.2)
const ATRITO_BOLA := 0.1947     # 0.12 / ATRITO_PINO
const QUIQUE_BOLA := 0.6708     # 0.3 / QUIQUE_PINO
## a gravidade nos pinos (x 1): o pino que voa desce logo e o que tomba cai
## firme, sem flutuar — parece pesado (a bola não muda)
const GRAVIDADE_PINO := 1.5


## Material de uma superfície parada, com o atrito e o quique que ela tinha
## no Godot 4. quem = quem encosta nela: "pinos", "bola" ou "todos" (aí
## fica no meio do caminho entre o certo para os pinos e para a bola).
static func material(atrito: float, quique: float, quem := "todos") -> PhysicsMaterial:
	var fp: float = min(atrito, 0.38) / ATRITO_PINO
	var fb: float = min(atrito, 0.12) / ATRITO_BOLA
	var rp: float = min(quique * QUIQUE_PINO_SUPERFICIE + QUIQUE_PINO_SOMA, 1.0) / QUIQUE_PINO
	var rb: float = min(quique + 0.12, 1.0) / QUIQUE_BOLA
	var pm := PhysicsMaterial.new()
	if quem == "pinos":
		pm.friction = fp
		pm.bounce = rp
	elif quem == "bola":
		pm.friction = fb
		pm.bounce = rb
	else:
		pm.friction = (fp + fb) * 0.5
		pm.bounce = (rp + rb) * 0.5
	# nenhum par passa de quique 1 (não ganha energia)
	pm.bounce = min(pm.bounce, 1.0 / QUIQUE_PINO)
	return pm
