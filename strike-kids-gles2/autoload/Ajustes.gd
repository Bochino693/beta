extends Node

## AJUSTES DO OPERADOR, RECORDE E CONTADORES — gravados na TV Box
## (user://ajustes.cfg). Mudados na tela do operador (botão de
## configuração > AJUSTES DO JOGO).

signal mudaram

const ARQUIVO := "user://ajustes.cfg"

const DIFICULDADES := ["facil", "normal", "dificil"]
const QUALIDADES := ["auto", "alta", "media", "baixa"]

## Valores de fábrica.
const PADRAO := {
	"jogo": {
		"rodadas": 3,            # rodadas por jogador
		"tentativas": 3,         # bolas por rodada (como no Dragon Bowling)
		"dificuldade": "facil",
		"velocidade": 130,       # ritmo do jogo (%): 130 = tudo 30% mais rápido (a física das jogadas não muda)
		"protecao_canaleta": true,  # para-choques nas canaletas (bumpers)
		"replay_strike": true,
		"modo_livre": true,      # sem crédito: START sempre começa
		"creditos_por_partida": 1,
		"tempo_inatividade": 45, # segundos sem jogar até o aviso
		"demo": true,
		"foto": true,            # foto das crianças com a câmera da máquina
		"camera_giro": 0,        # 0, 90, 180, 270 (câmera montada de lado)
		"camera_espelho": true,  # espelha a imagem (a criança se vê como no espelho)
	},
	"som": {
		"musica": 0.8,
		"efeitos": 1.0,
		"som_na_demo": true,
	},
	"arduino": {
		"porta_invertida": false,     # a trava abre quando devia fechar? troca aqui
		"sensores_invertidos": false, # sensores ligados da direita para a esquerda
	},
	"video": {
		"qualidade": "auto",
		"cenario": "",             # fundo: "leve" ou "completo" ("" = o padrão desta versão, strike/video/cenario)
		"nitidez": "auto",         # resolução do 3D: auto (sobe e desce sozinha) ou 100%/90%/80%/70% fixa
		"fator": 1.0,              # o último fator automático bom (começa dele ao ligar)
		"medidor": false,          # painel de desempenho na tela (F3 no PC)
		"qualidade_auto": "",      # o que o TESTE DE DESEMPENHO recomendou
		"testar": false,           # pedido do menu: rodar o teste ao voltar
	},
}

var _cfg := ConfigFile.new()
var creditos := 0


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	_cfg.load(ARQUIVO)


func valor(secao: String, chave: String):
	return _cfg.get_value(secao, chave, PADRAO.get(secao, {}).get(chave))


## GRAVAR SEM PARAR O JOGO: gravar no disco da TV Box leva alguns ms (às
## vezes bem mais) — no meio da partida (contador de strikes, fichas) isso
## era um tranco. As gravações do mesmo quadro viram uma só, e o arquivo é
## escrito numa linha de trabalho separada (sempre na ordem certa).
var _salvar_pendente := false
var _versao := 0
var _gravada := 0
var _trava := Mutex.new()


func _salvar() -> void:
	if not _salvar_pendente:
		_salvar_pendente = true
		call_deferred("_salvar_agora")


func _salvar_agora() -> void:
	_salvar_pendente = false
	_versao += 1
	var v := _versao
	# Godot 3: o ConfigFile não tem encode_to_text — a linha de trabalho
	# grava uma cópia, tirada aqui (no quadro do jogo)
	Tarefas.rodar(self, "_escrever", [_copia(), v])


## Os ajustes de agora, copiados (a linha de trabalho grava a cópia enquanto
## o jogo continua mexendo no _cfg).
func _copia() -> ConfigFile:
	var c := ConfigFile.new()
	for secao in _cfg.get_sections():
		for chave in _cfg.get_section_keys(secao):
			var v = _cfg.get_value(secao, chave)
			if v is Dictionary or v is Array:
				v = v.duplicate(true)
			c.set_value(secao, chave, v)
	return c


func _escrever(cfg: ConfigFile, v: int) -> void:
	_trava.lock()
	if v > _gravada:
		if cfg.save(ARQUIVO) == OK:
			_gravada = v
	_trava.unlock()


## Fechando o jogo: grava na hora o que estiver pendente.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_QUIT_REQUEST or what == NOTIFICATION_PREDELETE or what == NOTIFICATION_EXIT_TREE:
		# (no PREDELETE as linhas já foram esperadas na saída da árvore, e a
		# Tela já limpou o estado do Compat: não mexe nele de novo)
		if what != NOTIFICATION_PREDELETE:
			Tarefas.esperar_todas()
		if _salvar_pendente:
			_salvar_pendente = false
			_versao += 1
			# (nenhuma linha de trabalho rodando: grava o próprio _cfg)
			_escrever(_cfg, _versao)


func definir(secao: String, chave: String, v) -> void:
	_cfg.set_value(secao, chave, v)
	_salvar()
	emit_signal("mudaram")


func restaurar_padrao() -> void:
	for secao in PADRAO:
		for chave in PADRAO[secao]:
			_cfg.set_value(secao, chave, PADRAO[secao][chave])
	_salvar()
	emit_signal("mudaram")


# ---------------------------------------------------------------- atalhos
func rodadas() -> int:
	return Compat.iclamp(int(valor("jogo", "rodadas")), 1, 10)


## Ritmo do jogo: 1,0 = tempo real; 1,3 = tudo 30% mais rápido.
func velocidade() -> float:
	return clamp(float(valor("jogo", "velocidade")) / 100.0, 0.5, 2.0)


## CENÁRIO (fundo) LEVE: chão e decoração mais simples e sem neblina, para a
## TV Box rodar lisa. O padrão vem do project.godot (strike/video/cenario:
## "leve" nesta versão; o pacote da versão ALTA traz "completo"); o
## operador troca no menu. STRIKE_CENARIO=leve|completo vale nos testes.
func cenario_leve() -> bool:
	if OS.has_environment("STRIKE_CENARIO"):
		return OS.get_environment("STRIKE_CENARIO") != "completo"
	return cenario() == "leve"


func cenario() -> String:
	var c := str(valor("video", "cenario"))
	if c in ["leve", "completo"]:
		return c
	# Godot 3: get_setting não tem valor padrão
	var padrao := "leve"
	if ProjectSettings.has_setting("strike/video/cenario"):
		padrao = str(ProjectSettings.get_setting("strike/video/cenario"))
	return "completo" if padrao == "completo" else "leve"


func tentativas() -> int:
	return Compat.iclamp(int(valor("jogo", "tentativas")), 1, 3)


func dificuldade() -> String:
	var d := str(valor("jogo", "dificuldade"))
	return d if d in DIFICULDADES else "facil"


func protecao_canaleta() -> bool:
	return bool(valor("jogo", "protecao_canaleta"))


func modo_livre() -> bool:
	return bool(valor("jogo", "modo_livre"))


# ---------------------------------------------------------------- créditos
func adicionar_credito() -> void:
	creditos += 1
	contar("moedas")


func pode_comecar() -> bool:
	return modo_livre() or creditos >= int(valor("jogo", "creditos_por_partida"))


func gastar_creditos() -> void:
	if not modo_livre():
		creditos = Compat.imax(0, creditos - int(valor("jogo", "creditos_por_partida")))


# ---------------------------------------------------------------- recorde
func recorde(jogadores: int) -> Dictionary:
	return _cfg.get_value("recorde", "j%d" % jogadores, {"pontos": 0, "quem": ""})


## Grava se for recorde. Retorna true se bateu.
func registrar_pontos(jogadores: int, pontos: int, quem: String) -> bool:
	var r := recorde(jogadores)
	if pontos > int(r.get("pontos", 0)):
		_cfg.set_value("recorde", "j%d" % jogadores, {"pontos": pontos, "quem": quem})
		_salvar()
		return true
	return false


## Guarda o caminho da foto de quem fez o recorde.
func definir_foto_recorde(jogadores: int, caminho: String) -> void:
	var r := recorde(jogadores)
	r["foto"] = caminho
	_cfg.set_value("recorde", "j%d" % jogadores, r)
	_salvar()


func zerar_recordes() -> void:
	if _cfg.has_section("recorde"):
		_cfg.erase_section("recorde")
	_salvar()
	Classificacao.zerar()
	Fotos.apagar_recordes()


# ---------------------------------------------------------------- contadores
func contar(chave: String, quanto := 1) -> void:
	_cfg.set_value("contadores", chave, int(_cfg.get_value("contadores", chave, 0)) + quanto)
	_salvar()


func contador(chave: String) -> int:
	return int(_cfg.get_value("contadores", chave, 0))
