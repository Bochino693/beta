class_name Jogada
extends RefCounted

## O PLANEJADOR DA JOGADA.
##
## O sensor diz POR ONDE a bola passou (5 posições). A partir disso e da
## dificuldade escolhida pelo operador, o jogo decide quantos pinos caem
## (tabela de chances abaixo), escolhe QUAIS (os mais perto do caminho da
## bola, do jeito que cairiam de verdade) e calcula a linha da bola. A
## física faz o resto; os pinos "planejados" que resistirem levam um
## empurrãozinho e os outros ficam "teimosos". Assim o resultado é justo,
## ajustável e sempre bonito de ver.
##
##   Z = esquerda   X = meio-esquerda   C = CENTRO   V = meio-direita   B = direita

const LINHA := {"Z": -0.43, "X": -0.21, "C": 0.0, "V": 0.21, "B": 0.43}

## Chance (%) de cada resultado na 1ª bola, por posição e dificuldade.
## Chave = pinos derrubados.
const TABELA := {
	"facil": {
		"C": {10: 58, 9: 16, 8: 12, 7: 9, 6: 5},
		"X": {10: 16, 9: 16, 8: 20, 7: 20, 6: 14, 5: 9, 4: 5},
		"Z": {5: 8, 4: 14, 3: 30, 2: 28, 1: 14, 0: 6},
	},
	"normal": {
		"C": {10: 40, 9: 20, 8: 16, 7: 12, 6: 8, 5: 4},
		"X": {10: 9, 9: 14, 8: 18, 7: 20, 6: 18, 5: 12, 4: 9},
		"Z": {4: 10, 3: 26, 2: 30, 1: 20, 0: 14},
	},
	"dificil": {
		"C": {10: 25, 9: 22, 8: 18, 7: 15, 6: 12, 5: 8},
		"X": {10: 5, 9: 10, 8: 16, 7: 20, 6: 20, 5: 16, 4: 13},
		"Z": {3: 20, 2: 32, 1: 28, 0: 20},
	},
}

## Chance (%) de derrubar TODOS os que sobraram (spare), conforme a bola
## passa perto do grupo de pinos.
const SPARE := {"facil": [70, 35, 8], "normal": [55, 25, 5], "dificil": [40, 15, 3]}

var zona := "C"
var derrubar: Array = []    # números dos pinos planejados para cair
var origem_x := 0.0         # onde a bola sai (linha de falta)
var alvo_x := 0.0           # para onde ela vai (nos pinos)
var velocidade := 7.6
var efeito := 0.0           # gancho
var canaleta := false       # bola vai para a canaleta
var strike_planejado := false

## Só para testes e para gravar o vídeo de divulgação: resultados forçados
## em sequência (quantos pinos caem). Vazio = sorteio normal.
static var forcar: Array = []


static func planejar(z: String, em_pe: Array, primeira_bola: bool, dificuldade: String, protecao: bool) -> Jogada:
	var j := Jogada.new()
	j.zona = z
	var linha: float = LINHA.get(z, 0.0)
	var tab_zona := "C" if z == "C" else ("X" if z in ["X", "V"] else "Z")
	var n := 0
	if primeira_bola and em_pe.size() == 10:
		n = _sortear(TABELA.get(dificuldade, TABELA["facil"])[tab_zona])
	else:
		n = _sortear_resto(linha, em_pe, dificuldade)
	if not forcar.is_empty():
		n = int(forcar.pop_front())
		if n < 0 or n > em_pe.size():
			n = em_pe.size()
	n = clampi(n, 0, em_pe.size())
	if n == 0 and protecao:
		# com para-choques a bola sempre volta para a pista: ao menos 1
		n = min(1, em_pe.size())
	j.derrubar = _escolher(linha, em_pe, n)
	j.strike_planejado = primeira_bola and n == 10
	j.velocidade = randf_range(7.2, 8.2) if z == "C" else randf_range(6.6, 7.6)
	if n == 0:
		j.canaleta = true
		j.origem_x = linha * 0.9 + 0.1 * signf(linha if linha != 0.0 else 1.0)
		var lado: float = signf(linha) if linha != 0.0 else (1.0 if randf() < 0.5 else -1.0)
		j.alvo_x = lado * 0.95
		j.velocidade = randf_range(6.2, 7.0)
		return j
	if j.strike_planejado:
		# entra no "bolso" entre o pino 1 e o 3 (ou 1 e 2), com um leve gancho
		var bolso := 0.075 if randf() < 0.65 else -0.075
		j.origem_x = clamp(linha + bolso * 2.5, -0.35, 0.35)
		j.alvo_x = bolso
		j.efeito = -signf(j.origem_x - bolso) * 0.25
		return j
	# alvo: centro dos pinos planejados, puxado para os da frente
	var soma := 0.0
	var peso := 0.0
	for num in j.derrubar:
		var p := Pinos.posicao_do_pino(num)
		var fileira := int(round((Mundo.Z_PINO1 - p.z) / Mundo.FILEIRA))
		var w := 1.0 / (1.0 + fileira * 1.5)
		soma += p.x * w
		peso += w
	j.alvo_x = soma / max(peso, 0.0001)
	j.origem_x = clamp(linha, -0.45, 0.45)
	# a bola não pode mirar "dentro" de pino que deve ficar: desvia um pouco
	j.alvo_x = clamp(j.alvo_x, -0.5, 0.5)
	return j


static func _sortear(tabela: Dictionary) -> int:
	var total := 0
	for k in tabela:
		total += int(tabela[k])
	var r: int = randi() % maxi(total, 1)
	for k in tabela:
		r -= int(tabela[k])
		if r < 0:
			return int(k)
	return 0


static func _sortear_resto(linha: float, em_pe: Array, dificuldade: String) -> int:
	if em_pe.is_empty():
		return 0
	var xmin := 9.0
	var xmax := -9.0
	for n in em_pe:
		var x := Pinos.posicao_do_pino(n).x
		xmin = min(xmin, x)
		xmax = max(xmax, x)
	var dist := 0.0
	if linha < xmin:
		dist = xmin - linha
	elif linha > xmax:
		dist = linha - xmax
	var chances: Array = SPARE.get(dificuldade, SPARE["facil"])
	var chance: int = chances[0] if dist < 0.12 else (chances[1] if dist < 0.32 else chances[2])
	if randi() % 100 < chance:
		return em_pe.size()
	# parte: os que estão ao alcance
	var alcance := 0
	for n in em_pe:
		if abs(Pinos.posicao_do_pino(n).x - linha) < 0.42:
			alcance += 1
	if alcance == 0:
		return 0 if randi() % 100 < 55 else 1
	return randi_range(max(1, alcance - 2), alcance) if alcance < em_pe.size() else randi_range(1, em_pe.size() - 1)


## Os n pinos mais "naturais" de cair: perto da linha da bola e na frente.
static func _escolher(linha: float, em_pe: Array, n: int) -> Array:
	var lista := []
	for num in em_pe:
		var p := Pinos.posicao_do_pino(num)
		var fileira := (Mundo.Z_PINO1 - p.z) / Mundo.FILEIRA
		var custo: float = abs(p.x - linha) * 1.0 + fileira * 0.08 + randf() * 0.06
		lista.append([custo, num])
	lista.sort_custom(func(a, b): return a[0] < b[0])
	var r := []
	for i in min(n, lista.size()):
		r.append(lista[i][1])
	return r
