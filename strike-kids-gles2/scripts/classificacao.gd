class_name Classificacao
extends Reference

## CLASSIFICAÇÃO DO DIA: os melhores de hoje, cada um com a SUA FOTO (a da
## câmera da máquina; sem câmera, o mascote com que jogou). Aparece no fim
## da partida ("você ficou em 2º lugar hoje!") e na tela de atração.
## Vira a cada dia; o operador zera junto com os recordes.
##
## Fica em user://classificacao.json; as fotos em user://fotos/rank_*.png.

const ARQUIVO := "user://classificacao.json"
const MAXIMO := 10


## Godot 3: sem "static var" — o estado da classe fica em Compat.estado:
## cache (a classificação lida), versao (a última pedida) e, para a linha
## de trabalho, a trava e a versão já gravada (em "gravacao", que só ela
## mexe, sempre com a trava).
static func _estado() -> Dictionary:
	var e := Compat.estado("classificacao")
	if not e.has("trava"):
		e["cache"] = {}
		e["versao"] = 0
		e["gravacao"] = {"gravada": 0}
		e["trava"] = Mutex.new()
	return e


static func hoje() -> String:
	return Time.get_date_string_from_system()


static func _ler() -> Dictionary:
	var e := _estado()
	if not (e["cache"] as Dictionary).empty():
		return e["cache"]
	var d := {}
	if Compat.existe_arquivo(ARQUIVO):
		var j = parse_json(Compat.ler_texto(ARQUIVO))
		if j is Dictionary:
			d = j
	if str(d.get("dia", "")) != hoje():
		_apagar_fotos(d.get("lista", []))
		d = {"dia": hoje(), "lista": []}
	e["cache"] = d
	return d


## Grava numa linha de trabalho separada (no fim da partida, gravar na
## hora dava um tranco na TV Box), sempre na ordem certa.
static func _gravar(d: Dictionary) -> void:
	var e := _estado()
	e["cache"] = d
	e["versao"] = int(e["versao"]) + 1
	var texto := JSON.print(d, " ", true)
	Tarefas.rodar(_Gravador.new(), "gravar", [texto, int(e["versao"]), e["trava"], e["gravacao"]])


## Godot 3: sem lambda — este objeto faz a gravação na linha de trabalho.
class _Gravador:
	extends Reference

	func gravar(texto: String, v: int, trava: Mutex, gravacao: Dictionary) -> void:
		trava.lock()
		if v > int(gravacao["gravada"]):
			var f := File.new()
			if f.open(ARQUIVO, File.WRITE) == OK:
				f.store_string(texto)
				f.close()
				gravacao["gravada"] = v
		trava.unlock()


static func _apagar_fotos(lista: Array) -> void:
	for e in lista:
		var c := str((e as Dictionary).get("foto", ""))
		if c != "" and Compat.existe_arquivo(c):
			Compat.apagar(c)


## Os de hoje, do melhor para o pior: [{pontos, personagem, foto, hora}].
static func lista() -> Array:
	return (_ler()["lista"] as Array).duplicate(true)


## Registra os jogadores da partida. entradas: [{pontos, personagem,
## chave_foto}]. Volta a posição de cada um no dia (1 = primeiro).
static func registrar(entradas: Array) -> Array:
	var d := _ler()
	var todos: Array = d["lista"]
	var hora := Time.get_time_string_from_system().substr(0, 5)
	var novos := []
	for i in entradas.size():
		var e: Dictionary = entradas[i]
		var id := "%d_%d" % [int(Time.get_unix_time_from_system()), i]
		var r := {"pontos": int(e["pontos"]), "personagem": str(e["personagem"]), "foto": "", "hora": hora, "id": id,
			"chave_foto": str(e.get("chave_foto", ""))}
		novos.append(r)
		todos.append(r)
	# maior pontuação primeiro; empate: quem fez antes fica na frente
	var ordem := todos.duplicate()
	var criterio := _Ordem.new()
	criterio.todos = todos
	ordem.sort_custom(criterio, "antes")
	var posicoes := []
	for r in novos:
		posicoes.append(ordem.find(r) + 1)
	var fica := Compat.fatia(ordem, 0, MAXIMO)
	_apagar_fotos(Compat.fatia(ordem, MAXIMO))
	for r in novos:
		if fica.has(r) and str(r["chave_foto"]) != "":
			r["foto"] = Fotos.gravar(str(r["chave_foto"]), "rank_%s.png" % r["id"])
		r.erase("chave_foto")
	d["lista"] = fica
	_gravar(d)
	return posicoes


## Godot 3: sort_custom pede um objeto (sem lambda); este guarda a lista
## de todos para o desempate.
class _Ordem:
	extends Reference
	var todos: Array

	func antes(a, b) -> bool:
		if int(a["pontos"]) != int(b["pontos"]):
			return int(a["pontos"]) > int(b["pontos"])
		return todos.find(a) < todos.find(b)


static func zerar() -> void:
	var d := _ler()
	_apagar_fotos(d["lista"])
	_gravar({"dia": hoje(), "lista": []})
