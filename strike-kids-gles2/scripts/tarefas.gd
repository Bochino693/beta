class_name Tarefas
extends Reference

## TRABALHO EM SEGUNDO PLANO (gravar no disco, ler as fotos, listar o USB):
## roda numa linha de trabalho separada, sem parar o jogo. Ao fechar, o jogo
## espera o que ainda estiver rodando — senão o trabalho continuaria mexendo
## em coisas que o motor já apagou e o jogo cairia ao sair.
##
## Godot 3: cada trabalho é uma Thread que chama alvo.metodo(args...).


class _Trabalho:
	extends Reference
	var alvo: Object
	var metodo := ""
	var args := []
	var linha := Thread.new()

	func executar(_dado) -> void:
		if is_instance_valid(alvo):
			alvo.callv(metodo, args)


static func _lista() -> Array:
	var e: Dictionary = Compat.estado("tarefas")
	if not e.has("lista"):
		e["lista"] = []
	return e["lista"]


static func rodar(alvo: Object, metodo: String, args := []) -> void:
	_recolher()
	var t := _Trabalho.new()
	t.alvo = alvo
	t.metodo = metodo
	t.args = args
	if t.linha.start(t, "executar") == OK:
		_lista().append(t)
	else:
		# sem linha livre: faz agora mesmo
		alvo.callv(metodo, args)


## Libera as que já terminaram (cada Thread precisa ser esperada uma vez;
## esperar uma que já terminou não para nada).
static func _recolher() -> void:
	var l := _lista()
	var i := 0
	while i < l.size():
		if not l[i].linha.is_alive():
			l[i].linha.wait_to_finish()
			l.remove(i)
		else:
			i += 1


## Fechando o jogo: espera tudo terminar.
static func esperar_todas() -> void:
	var l := _lista()
	for t in l:
		t.linha.wait_to_finish()
	l.clear()
