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
	"video": {
		"qualidade": "auto",
	},
}

var _cfg := ConfigFile.new()
var creditos := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cfg.load(ARQUIVO)


func valor(secao: String, chave: String):
	return _cfg.get_value(secao, chave, PADRAO.get(secao, {}).get(chave))


func definir(secao: String, chave: String, v) -> void:
	_cfg.set_value(secao, chave, v)
	_cfg.save(ARQUIVO)
	mudaram.emit()


func restaurar_padrao() -> void:
	for secao in PADRAO:
		for chave in PADRAO[secao]:
			_cfg.set_value(secao, chave, PADRAO[secao][chave])
	_cfg.save(ARQUIVO)
	mudaram.emit()


# ---------------------------------------------------------------- atalhos
func rodadas() -> int:
	return clampi(int(valor("jogo", "rodadas")), 1, 10)


func tentativas() -> int:
	return clampi(int(valor("jogo", "tentativas")), 1, 3)


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
		creditos = max(0, creditos - int(valor("jogo", "creditos_por_partida")))


# ---------------------------------------------------------------- recorde
func recorde(jogadores: int) -> Dictionary:
	return _cfg.get_value("recorde", "j%d" % jogadores, {"pontos": 0, "quem": ""})


## Grava se for recorde. Retorna true se bateu.
func registrar_pontos(jogadores: int, pontos: int, quem: String) -> bool:
	var r := recorde(jogadores)
	if pontos > int(r.get("pontos", 0)):
		_cfg.set_value("recorde", "j%d" % jogadores, {"pontos": pontos, "quem": quem})
		_cfg.save(ARQUIVO)
		return true
	return false


## Guarda o caminho da foto de quem fez o recorde.
func definir_foto_recorde(jogadores: int, caminho: String) -> void:
	var r := recorde(jogadores)
	r["foto"] = caminho
	_cfg.set_value("recorde", "j%d" % jogadores, r)
	_cfg.save(ARQUIVO)


func zerar_recordes() -> void:
	if _cfg.has_section("recorde"):
		_cfg.erase_section("recorde")
	_cfg.save(ARQUIVO)
	Classificacao.zerar()
	Fotos.apagar_recordes()


# ---------------------------------------------------------------- contadores
func contar(chave: String, quanto := 1) -> void:
	_cfg.set_value("contadores", chave, int(_cfg.get_value("contadores", chave, 0)) + quanto)
	_cfg.save(ARQUIVO)


func contador(chave: String) -> int:
	return int(_cfg.get_value("contadores", chave, 0))
