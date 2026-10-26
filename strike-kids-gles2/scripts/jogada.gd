class_name Jogada
extends Reference

## O PLANEJADOR DA JOGADA — ele só escolhe a LINHA da bola. Quem derruba os
## pinos é a física de verdade: a bola bate, os pinos voam, batem uns
## nos outros, nas paredes, e caem. Nenhum pino é empurrado "de mentira".
##
## A BOLA VAI PARA ONDE A CRIANÇA JOGOU (6.5): o sensor diz por onde a bola
## passou e ela segue por ali até os pinos —
##   Z (A) = canto esquerdo: pega o 4, o 7 e o 8 (2 ou 3 pinos)
##   X (S) = lado esquerdo: o 2, o 4, o 5, o 7, o 8... (uns 6 ou 7)
##   C (D) = CENTRO: o "bolso" entre o 1 e o 3 (ou o 1 e o 2) — o strike
##   V (F) e B (G) = o mesmo do lado direito.
## Antes a mira era sempre o strike e o sensor só mudava a chance: jogando
## no canto saía strike. A dificuldade escolhida pelo operador define o
## quanto a bola se espalha em volta da linha (e, sem para-choques, a
## chance de ir para a canaleta pelos cantos).
## No centro as linhas vêm de uma tabela de jogadas simuladas com a mesma
## física (tools/testes/calibrar.gd -> dados/tabela_jogadas.json): o jogo
## sorteia quão boa foi a jogada e pega uma linha do bolso que, na
## simulação, rendeu aquilo.

## por onde a bola passa na linha de falta (z = 0,35)
const LINHA := {"Z": -0.43, "X": -0.21, "C": 0.0, "V": 0.21, "B": 0.43}
## por onde ela passa na fileira do pino 1 (fora do centro): o canto pega
## 4-7-8 (com para-choques ela não passa de 0,52 — encosta neles); o lado,
## 2-4-5-7-8 (tools/testes/calibrar.gd: média 3 e 7 pinos)
const MIRA := {"Z": -0.5, "X": -0.28, "V": 0.28, "B": 0.5}
## quanto a linha se espalha (metros, para cada lado) por dificuldade
const ESPALHA := {"facil": 0.03, "normal": 0.05, "dificil": 0.08}
const ARQUIVO := "res://dados/tabela_jogadas.json"

## Chance (%) de cada resultado na 1ª bola NO CENTRO, por dificuldade.
## Chave = pinos derrubados.
const TABELA := {
	"facil": {"C": {10: 60, 9: 14, 8: 10, 7: 8, 6: 5, 5: 3}},
	"normal": {"C": {10: 42, 9: 18, 8: 14, 7: 11, 6: 8, 5: 5, 4: 2}},
	"dificil": {"C": {10: 28, 9: 18, 8: 16, 7: 14, 6: 10, 5: 8, 4: 6}},
}

## Sem para-choques: chance (%) de canaleta, por dificuldade e posição
## (cantos e lados; no centro, nunca)
const CANALETA := {"facil": {"Z": 10, "X": 0}, "normal": {"Z": 20, "X": 3}, "dificil": {"Z": 30, "X": 6}}

var zona := "C"
var origem_x := 0.0         # por onde a bola passa na linha de falta (z = 0,35)
var alvo_x := 0.0           # para onde ela vai (na altura do pino 1)
var velocidade := 7.9
var efeito := 0.0           # gancho (força lateral)
var esperado := -1          # quantos pinos a simulação derrubou com essa linha
var canaleta := false

## Só para testes e para gravar o vídeo de divulgação: resultados desejados
## em sequência (quantos pinos caem). Vazio = sorteio normal.
## (Godot 3: sem "static var" — a lista mora no Compat.estado.)
static func forcar() -> Array:
	var e := Compat.estado("jogada")
	if not e.has("forcar"):
		e["forcar"] = []
	return e["forcar"]


## zona -> [{xt, v, e, resultados: [n...], entrada}]
static func _grupos() -> Dictionary:
	var e := Compat.estado("jogada")
	if not e.has("grupos"):
		e["grupos"] = {}
	return e["grupos"]


var strike_provavel: bool setget , _strike_provavel


func _strike_provavel() -> bool:
	return esperado == 10


static func planejar(z: String, em_pe: Array, primeira_bola: bool, dificuldade: String, protecao: bool) -> Reference:
	var j = load("res://scripts/jogada.gd").new()
	j.zona = z
	var linha: float = LINHA.get(z, 0.0)
	var dif: String = dificuldade if TABELA.has(dificuldade) else "facil"
	var desejado := -1
	var forcados := forcar()
	if not forcados.empty():
		desejado = Compat.iclamp(int(forcados.pop_front()), 0, em_pe.size())
	if primeira_bola and em_pe.size() == 10:
		# resultado pedido (testes, vídeo de divulgação): a linha da tabela
		if desejado >= 0:
			if desejado == 0 and not protecao:
				_canaleta(j, linha)
				return j
			if _da_tabela(j, z, desejado, protecao):
				return j
		elif z == "C":
			if _da_tabela(j, z, _sortear(TABELA[dif]["C"]), protecao):
				return j
		else:
			var lado := "Z" if z in ["Z", "B"] else "X"
			if not protecao and randi() % 100 < int(CANALETA[dif][lado]):
				_canaleta(j, linha)
				return j
			_na_linha(j, z, dif, protecao)
			return j
	_resto(j, z, em_pe, dif, desejado, protecao)
	return j


## A bola segue a linha da posição do sensor (espalhando um pouco).
static func _na_linha(j, z: String, dif: String, protecao: bool) -> void:
	var e: float = ESPALHA[dif]
	j.origem_x = LINHA[z]
	j.alvo_x = _limite(float(MIRA.get(z, 0.0)) + rand_range(-e, e), protecao)
	j.velocidade = rand_range(7.4, 8.6)
	j.efeito = 0.0
	j.esperado = -1


static func _limite(x: float, protecao: bool) -> float:
	return clamp(x, -0.58 if protecao else -0.62, 0.58 if protecao else 0.62)


static func _sortear(tabela: Dictionary) -> int:
	var total := 0
	for k in tabela:
		total += int(tabela[k])
	var r: int = randi() % Compat.imax(total, 1)
	for k in tabela:
		r -= int(tabela[k])
		if r < 0:
			return int(k)
	return 0


static func _canaleta(j, linha: float) -> void:
	var lado: float = sign(linha) if linha != 0.0 else (1.0 if randf() < 0.5 else -1.0)
	j.canaleta = true
	j.esperado = 0
	j.origem_x = clamp(linha + lado * 0.08, -0.5, 0.5)
	j.alvo_x = lado * 0.95
	j.velocidade = rand_range(6.8, 7.4)


# ---------------------------------------------------------------- 1ª bola
## Lê a tabela e já deixa pronta a escolha de cada pedido (zona, pinos,
## para-choques): chamado na preparação (por trás da capa de carregamento).
## Ler e organizar as quase 4 mil jogadas na primeira bola (a da abertura)
## dava um tranco de quase um segundo na TV Box; escolher a linha na hora
## de cada arremesso, outro menor.
static func preparar() -> void:
	_carregar()


## zona|pinos|para-choques -> as linhas que melhor rendem aquilo
static func _melhores() -> Dictionary:
	var e := Compat.estado("jogada")
	if not e.has("melhores"):
		e["melhores"] = {}
	return e["melhores"]


static func _carregar() -> void:
	var grupos := _grupos()
	if not grupos.empty():
		return
	if not Compat.existe_arquivo(ARQUIVO):
		push_warning("Jogada: sem tabela de calibração (%s)" % ARQUIVO)
		return
	var dados = parse_json(Compat.ler_texto(ARQUIVO))
	if typeof(dados) != TYPE_DICTIONARY:
		return
	var idx := {}
	for r in dados.get("jogadas", []):
		# [zona, x0, xt, v, efeito, n, caidos, x_entrada]
		var chave := _chave(str(r[0]), float(r[2]), float(r[3]), float(r[4]))
		if not idx.has(chave):
			idx[chave] = {"zona": str(r[0]), "xt": float(r[2]), "v": float(r[3]), "e": float(r[4]),
				"resultados": [], "entrada": float(r[7]) if r.size() > 7 else float(r[2])}
			if not grupos.has(str(r[0])):
				grupos[str(r[0])] = []
			grupos[str(r[0])].append(idx[chave])
		idx[chave]["resultados"].append(int(r[5]))
	# a física é caótica: um tiquinho de diferença muda o resultado. Por isso
	# cada linha olha também as vizinhas (2 cm para cada lado): só conta como
	# "linha de strike" a que derruba tudo mesmo errando um pouquinho.
	for chave in idx:
		var g: Dictionary = idx[chave]
		var amostra: Array = g["resultados"].duplicate()
		for dx in [-0.02, 0.02]:
			var viz := _chave(g["zona"], float(g["xt"]) + dx, g["v"], g["e"])
			if idx.has(viz):
				amostra.append_array(idx[viz]["resultados"])
		g["amostra"] = amostra
	# a nota de cada linha para cada pedido de pinos: acertar conta 1, errar
	# por um pino conta 0,35 (contagem de quantas vezes deu cada número)
	for z in grupos:
		for g in grupos[z]:
			var conta := []
			conta.resize(12)
			for i in 12:
				conta[i] = 0
			for r in g["amostra"]:
				conta[Compat.iclamp(int(r), 0, 10)] += 1
			var notas := PoolRealArray()
			var tam := float(max((g["amostra"] as Array).size(), 1))
			for n in 11:
				var vizinhos: int = conta[n + 1] + (conta[n - 1] if n > 0 else 0)
				notas.append((float(conta[n]) + 0.35 * float(vizinhos)) / tam)
			g["notas"] = notas
	var melhores := _melhores()
	for z in grupos:
		for n in 11:
			for protecao in [true, false]:
				var melhor := -1.0
				var opcoes := []
				for g in grupos[z]:
					if not protecao and (abs(float(g["entrada"])) > 0.5 or abs(float(g["xt"])) > 0.5):
						continue  # essa linha encostava no para-choque
					var nota: float = g["notas"][n]
					if nota > melhor + 0.001:
						melhor = nota
						opcoes = [g]
					elif abs(nota - melhor) <= 0.001:
						opcoes.append(g)
				melhores["%s|%d|%d" % [z, n, int(protecao)]] = opcoes


static func _chave(z: String, xt: float, v: float, e: float) -> String:
	return "%s|%.2f|%.1f|%.2f" % [z, stepify(xt, 0.01), v, e]


## Pega na tabela uma linha da zona que costuma render `n` pinos (a mais
## "garantida", contando as vizinhas).
static func _da_tabela(j, z: String, n: int, protecao: bool) -> bool:
	_carregar()
	var opcoes: Array = _melhores().get("%s|%d|%d" % [z, Compat.iclamp(n, 0, 10), int(protecao)], [])
	if opcoes.empty():
		return false
	var g: Dictionary = opcoes[randi() % opcoes.size()]
	j.origem_x = LINHA[z]
	j.alvo_x = g["xt"]
	j.velocidade = g["v"]
	j.efeito = g["e"]
	j.esperado = n
	return true


static func _media(a: Array) -> float:
	var s := 0.0
	for x in a:
		s += float(x)
	return s / max(a.size(), 1.0)


# ---------------------------------------------------------------- bolas seguintes
## A bola (raio 0,14) pega o pino que passa a menos de 0,22 m do centro
## dela. Com 2 cm de folga, mirando no MEIO, ela pega de uma vez todos os
## pinos que cabem numa faixa de 2 x ALCANCE (um pino só, 3-6, 1-3-6,
## 3-6-10, 2-4-7...). Antes ela mirava no pino da frente, pelo lado,
## contando que ele derrubasse os outros: 3-6, 3-6-10, 1-3-6 e 7-10 ficavam
## de pé em 1 de cada 6 bolas "certeiras" (tools/testes/poucos_pinos.gd).
const ALCANCE := 0.2


## As bolas seguintes também vão para onde a criança jogou. Uma ajudinha:
## se tem pino em pé perto da linha (até AJUDA), a bola passa pelo MEIO da
## faixa (2 x ALCANCE) que pega mais deles — senão ela segue a linha e
## passa direto (pinos do outro lado ficam de pé: tem que mirar).
const AJUDA := 0.15


static func _resto(j, z: String, em_pe: Array, dif: String, desejado: int, protecao: bool) -> void:
	var linha: float = LINHA.get(z, 0.0)
	var na_mira: float = MIRA.get(z, 0.0)
	j.origem_x = clamp(linha, -0.45, 0.45)
	j.velocidade = rand_range(8.0, 8.8)
	j.efeito = 0.0
	if em_pe.empty():
		j.alvo_x = na_mira
		return
	# o pino "chave" (o mais da frente; empate: o mais central)
	var chave: int = em_pe[0]
	for n in em_pe:
		var p := Pinos.posicao_do_pino(n)
		var pc := Pinos.posicao_do_pino(chave)
		if p.z > pc.z + 0.01 or (abs(p.z - pc.z) < 0.01 and abs(p.x) < abs(pc.x)):
			chave = n
	# cada pino na conta da mira: a bola vem em linha reta da origem (z =
	# 0,35) até alvo_x (no pino 1) e segue torta assim até as fileiras de
	# trás — o x da mira que passa pelo pino n
	var vai := 0.35 - Medidas.Z_PINO1
	var ax := {}
	for n in em_pe:
		var p := Pinos.posicao_do_pino(n)
		var d := Medidas.Z_PINO1 - p.z
		ax[n] = (p.x + j.origem_x * d / vai) / (1.0 + d / vai)
	# a faixa que pega mais pinos — só as que passam perto da linha (ou
	# qualquer uma, quando o resultado foi pedido: testes)
	var mira := na_mira
	var nota_melhor := -1.0
	var cabem := 0
	var largura := 0.0
	for a in em_pe:
		var x0: float = ax[a]
		var lo := 9.0
		var hi := -9.0
		var nota := 0.0
		var dentro := 0
		for n in em_pe:
			var x: float = ax[n]
			if x >= x0 - 0.001 and x <= x0 + 2.0 * ALCANCE:
				dentro += 1
				lo = min(lo, x)
				hi = max(hi, x)
				nota += 1.5 if n == chave else 1.0
		var meio := (lo + hi) * 0.5
		if desejado < 0 and abs(meio - na_mira) > AJUDA + (hi - lo) * 0.5:
			continue
		if nota > nota_melhor:
			nota_melhor = nota
			mira = meio
			cabem = dentro
			largura = hi - lo
	# um pino só (ou um atrás do outro): em cheio, um pouquinho de cada lado
	if cabem > 0 and largura < 0.02:
		mira += rand_range(-0.03, 0.03)
	var e: float = ESPALHA[dif]
	if desejado >= 0:
		if desejado >= em_pe.size():
			j.alvo_x = _limite(mira + rand_range(-0.015, 0.015), protecao)
			j.esperado = cabem
		else:
			# erra para o lado de fora do grupo (raspando ou passando direto)
			var fora := sign(mira) if mira != 0.0 else (1.0 if randf() < 0.5 else -1.0)
			j.alvo_x = _limite(mira + fora * (0.45 if desejado == 0 else rand_range(0.1, 0.32)), protecao)
			j.esperado = -1
		return
	j.alvo_x = _limite(mira + rand_range(-e, e), protecao)
	j.esperado = cabem if cabem > 0 else -1
