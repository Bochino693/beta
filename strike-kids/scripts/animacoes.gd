class_name Animacoes
extends RefCounted

## ANIMAÇÕES DOS PERSONAGENS (poses-chave).
##
## Cada animação: duração, se repete, as poses-chave no tempo e eventos.
## Ângulos em graus, no espaço do personagem (ele olha para +Z):
##   braco_*.x  negativo = levanta para a FRENTE, positivo = para trás
##   braco_e.z  positivo = abre para fora (braço esquerdo fica em +X)
##   braco_d.z  negativo = abre para fora
##   antebraco  x negativo = dobra o cotovelo (mão vem para a frente)
##   coxa.x     negativo = perna para a frente (sempre em relação ao chão)
##   canela.x   positivo = dobra o joelho
##   corpo.x    positivo = inclina para a frente
##   cabeca.x   positivo = olha para baixo; cabeca.y positivo = vira p/ esquerda
## Extras: "altura" (sobe/desce o corpo, metros), "frente" (anda para a
## frente, metros — usado na corrida do arremesso), "giro" (gira o corpo
## inteiro em Y, graus), "voo" (sobe o personagem todo, metros).

const PARADO := {
	"braco_e": Vector3(0, 0, 8), "braco_d": Vector3(0, 0, -8),
	"antebraco_e": Vector3(-12, 0, 0), "antebraco_d": Vector3(-12, 0, 0),
}

const PRONTO := {
	"braco_d": Vector3(-48, 0, -4), "antebraco_d": Vector3(-78, 0, 6),
	"braco_e": Vector3(-42, 0, 14), "antebraco_e": Vector3(-72, 0, -18),
	"corpo": Vector3(6, 0, 0), "cabeca": Vector3(4, 0, 0),
	"coxa_e": Vector3(-5, 0, 0), "canela_e": Vector3(10, 0, 0),
	"coxa_d": Vector3(-5, 0, 0), "canela_d": Vector3(10, 0, 0), "altura": -0.012,
}


static func _p(base: Dictionary, mudancas: Dictionary) -> Dictionary:
	var d := base.duplicate()
	for k in mudancas:
		d[k] = mudancas[k]
	return d


static var _cache := {}


static func pegar(nome: String) -> Dictionary:
	if _cache.is_empty():
		_montar()
	return _cache.get(nome, _cache["parado"])


static func _montar() -> void:
	_cache["parado"] = {
		"dur": 4.0, "loop": true,
		"chaves": [
			[0.0, PARADO],
			[2.0, _p(PARADO, {"braco_e": Vector3(4, 0, 11), "braco_d": Vector3(4, 0, -11), "corpo": Vector3(2, 0, 0),
				"cabeca": Vector3(3, 0, 2), "altura": -0.008})],
			[4.0, PARADO],
		],
	}
	_cache["pronto"] = {
		"dur": 2.0, "loop": true,
		"chaves": [
			[0.0, PRONTO],
			[1.0, _p(PRONTO, {"altura": -0.025, "corpo": Vector3(8, 0, 0), "canela_e": Vector3(14, 0, 0), "canela_d": Vector3(14, 0, 0),
				"coxa_e": Vector3(-7, 0, 0), "coxa_d": Vector3(-7, 0, 0)})],
			[2.0, PRONTO],
		],
	}
	# ---------------------------------------------------- o ARREMESSO
	# passada de 3 passos: empurra a bola, desce, vai lá atrás, desliza e solta.
	var p1 := {
		"braco_d": Vector3(-40, 0, -6), "antebraco_d": Vector3(-25, 0, 0),
		"braco_e": Vector3(-30, 0, 20), "antebraco_e": Vector3(-30, 0, 0),
		"coxa_d": Vector3(-28, 0, 0), "canela_d": Vector3(10, 0, 0),
		"coxa_e": Vector3(14, 0, 0), "canela_e": Vector3(28, 0, 0),
		"corpo": Vector3(8, 0, 0), "altura": -0.02, "frente": 0.45,
	}
	var p2 := {
		"braco_d": Vector3(12, 0, -4), "antebraco_d": Vector3(-5, 0, 0),
		"braco_e": Vector3(-15, 0, 40), "antebraco_e": Vector3(-20, 0, 0),
		"coxa_e": Vector3(-30, 0, 0), "canela_e": Vector3(12, 0, 0),
		"coxa_d": Vector3(16, 0, 0), "canela_d": Vector3(32, 0, 0),
		"corpo": Vector3(12, 0, 0), "altura": -0.03, "frente": 1.05,
	}
	var p3 := {
		"braco_d": Vector3(78, 0, -4), "antebraco_d": Vector3(0, 0, 0),
		"braco_e": Vector3(-25, 0, 60), "antebraco_e": Vector3(-15, 0, 0),
		"coxa_d": Vector3(-32, 0, 0), "canela_d": Vector3(18, 0, 0),
		"coxa_e": Vector3(22, 0, 0), "canela_e": Vector3(40, 0, 0),
		"corpo": Vector3(24, 0, -4), "cabeca": Vector3(-16, 0, 0), "altura": -0.06, "frente": 1.7,
	}
	var p4 := {
		"braco_d": Vector3(-18, 0, -4), "antebraco_d": Vector3(-8, 0, 0),
		"braco_e": Vector3(-10, 0, 80), "antebraco_e": Vector3(-10, 0, 0),
		"coxa_e": Vector3(-58, 0, 0), "canela_e": Vector3(72, 0, 0),
		"coxa_d": Vector3(42, 0, 0), "canela_d": Vector3(12, 0, 0),
		"corpo": Vector3(32, 0, -6), "cabeca": Vector3(-30, 0, 0), "altura": -0.19, "frente": 2.35,
	}
	var p5 := _p(p4, {"braco_d": Vector3(-128, 0, -8), "antebraco_d": Vector3(-25, 0, 0),
		"braco_e": Vector3(-5, 0, 82), "corpo": Vector3(26, 0, -4), "cabeca": Vector3(-24, 0, 0),
		"altura": -0.17, "frente": 2.5})
	var p6 := _p(p5, {"braco_d": Vector3(-112, 0, -10), "antebraco_d": Vector3(-35, 0, 0), "frente": 2.55,
		"cabeca": Vector3(-20, 0, 0)})
	_cache["arremesso"] = {
		"dur": 2.0, "loop": false,
		"chaves": [[0.0, PRONTO], [0.28, p1], [0.55, p2], [0.8, p3], [1.02, p4], [1.3, p5], [2.0, p6]],
		"eventos": [[0.28, "som", "passo"], [0.55, "som", "passo"], [0.8, "som", "passo"], [1.0, "soltar", null],
			[0.0, "expressao", "concentrado"], [1.0, "expressao", "surpreso"]],
	}
	# depois de soltar: fica olhando a bola, na pose final
	_cache["assistindo"] = {
		"dur": 1.6, "loop": true,
		"chaves": [[0.0, _p(p6, {"frente": 0.0})], [0.8, _p(p6, {"frente": 0.0, "altura": -0.15, "braco_d": Vector3(-100, 0, -12)})],
			[1.6, _p(p6, {"frente": 0.0})]],
	}
	# ---------------------------------------------------- STRIKE: pulão com pirueta e festa!
	var agacha := _p(PARADO, {"altura": -0.13, "coxa_e": Vector3(-35, 0, 0), "canela_e": Vector3(65, 0, 0),
		"coxa_d": Vector3(-35, 0, 0), "canela_d": Vector3(65, 0, 0), "corpo": Vector3(18, 0, 0),
		"braco_e": Vector3(25, 0, 25), "braco_d": Vector3(25, 0, -25)})
	var voando := {"voo": 0.5, "braco_e": Vector3(-168, 0, 18), "braco_d": Vector3(-168, 0, -18),
		"antebraco_e": Vector3(-10, 0, 0), "antebraco_d": Vector3(-10, 0, 0),
		"coxa_e": Vector3(-30, 0, 4), "canela_e": Vector3(60, 0, 0), "coxa_d": Vector3(-20, 0, -4), "canela_d": Vector3(70, 0, 0),
		"corpo": Vector3(-8, 0, 0), "cabeca": Vector3(-15, 0, 0)}
	var aterrissa := _p(agacha, {"altura": -0.09, "braco_e": Vector3(-130, 0, 50), "braco_d": Vector3(-130, 0, -50)})
	var vibra1 := _p(PARADO, {"braco_d": Vector3(-150, 0, -30), "antebraco_d": Vector3(-70, 0, 0), "braco_e": Vector3(-20, 0, 30),
		"corpo": Vector3(-4, 0, -6), "altura": -0.02})
	var vibra2 := _p(vibra1, {"braco_d": Vector3(-175, 0, -20), "antebraco_d": Vector3(-20, 0, 0), "voo": 0.08})
	_cache["comemora_strike"] = {
		"dur": 3.1, "loop": false,
		"chaves": [
			[0.0, PARADO], [0.2, agacha],
			[0.42, _p(voando, {"voo": 0.45, "giro": 120.0})],
			[0.62, _p(voando, {"voo": 0.6, "giro": 260.0})],
			[0.82, _p(voando, {"voo": 0.4, "giro": 360.0})],
			[1.0, _p(aterrissa, {"giro": 360.0})],
			[1.25, _p(vibra1, {"giro": 360.0})], [1.45, _p(vibra2, {"giro": 360.0})], [1.65, _p(vibra1, {"giro": 360.0})],
			[1.85, _p(vibra2, {"giro": 360.0})], [2.05, _p(vibra1, {"giro": 360.0})],
			[2.3, _p(agacha, {"giro": 360.0, "altura": -0.06})],
			[2.55, _p(voando, {"giro": 360.0, "voo": 0.22})],
			[3.1, _p(PARADO, {"giro": 360.0})],
		],
		"eventos": [[0.0, "expressao", "empolgado"], [0.2, "jatos", true], [0.2, "som", "jato"], [2.7, "jatos", false],
			[1.1, "expressao", "risada"]],
	}
	# ---------------------------------------------------- feliz (spare, boa jogada): pulinho + palmas
	var palma_junta := _p(PARADO, {"braco_e": Vector3(-72, 0, -12), "antebraco_e": Vector3(-48, -20, -25),
		"braco_d": Vector3(-72, 0, 12), "antebraco_d": Vector3(-48, 20, 25), "corpo": Vector3(4, 0, 0)})
	var palma_abre := _p(palma_junta, {"braco_e": Vector3(-70, 0, 14), "braco_d": Vector3(-70, 0, -14), "altura": 0.02})
	_cache["feliz"] = {
		"dur": 1.9, "loop": false,
		"chaves": [
			[0.0, PARADO],
			[0.18, _p(agacha, {"altura": -0.07})],
			[0.38, _p(PARADO, {"voo": 0.22, "braco_e": Vector3(-130, 0, 45), "braco_d": Vector3(-130, 0, -45), "canela_e": Vector3(40, 0, 0), "canela_d": Vector3(40, 0, 0)})],
			[0.6, _p(PARADO, {"altura": -0.04})],
			[0.75, palma_junta], [0.9, palma_abre], [1.05, palma_junta], [1.2, palma_abre], [1.35, palma_junta],
			[1.9, PARADO],
		],
		"eventos": [[0.0, "expressao", "feliz"], [0.75, "som", "palma"], [1.05, "som", "palma"], [1.35, "som", "palma"]],
	}
	# ---------------------------------------------------- triste (errou): cabeça baixa, balança
	var baixa := _p(PARADO, {"cabeca": Vector3(26, 0, 0), "corpo": Vector3(10, 0, 0), "braco_e": Vector3(6, 0, 3), "braco_d": Vector3(6, 0, -3),
		"altura": -0.03})
	_cache["triste"] = {
		"dur": 2.0, "loop": false,
		"chaves": [[0.0, PARADO], [0.3, baixa], [0.6, _p(baixa, {"cabeca": Vector3(24, -22, 0)})], [0.9, _p(baixa, {"cabeca": Vector3(24, 22, 0)})],
			[1.2, _p(baixa, {"cabeca": Vector3(20, 0, 0)})], [1.5, baixa],
			[2.0, _p(PARADO, {"braco_e": Vector3(-20, 0, 40), "braco_d": Vector3(-20, 0, -40), "antebraco_e": Vector3(-80, 0, 0), "antebraco_d": Vector3(-80, 0, 0)})]],
		"eventos": [[0.0, "expressao", "triste"], [1.6, "expressao", "concentrado"]],
	}
	# ---------------------------------------------------- torcida (o outro jogando)
	var t1 := _p(PARADO, {"braco_e": Vector3(-155, 0, 28), "antebraco_e": Vector3(-30, 0, 0), "braco_d": Vector3(-110, 0, -40), "antebraco_d": Vector3(-70, 0, 0)})
	var t2 := _p(PARADO, {"braco_d": Vector3(-155, 0, -28), "antebraco_d": Vector3(-30, 0, 0), "braco_e": Vector3(-110, 0, 40), "antebraco_e": Vector3(-70, 0, 0),
		"voo": 0.08})
	_cache["torcida"] = {
		"dur": 1.0, "loop": true,
		"chaves": [[0.0, t1], [0.25, _p(t1, {"voo": 0.06})], [0.5, t2], [0.75, _p(t2, {"voo": 0.0, "altura": -0.03})], [1.0, t1]],
	}
	# ---------------------------------------------------- dança de robô (atração / fim)
	var d1 := _p(PARADO, {"braco_e": Vector3(-90, 0, 20), "antebraco_e": Vector3(-90, 0, 0), "braco_d": Vector3(-5, 0, -35), "antebraco_d": Vector3(-95, 0, 0),
		"corpo": Vector3(0, 12, 8), "cabeca": Vector3(0, -12, -8), "coxa_e": Vector3(0, 0, 8), "coxa_d": Vector3(0, 0, 4)})
	var d2 := _p(PARADO, {"braco_d": Vector3(-90, 0, -20), "antebraco_d": Vector3(-90, 0, 0), "braco_e": Vector3(-5, 0, 35), "antebraco_e": Vector3(-95, 0, 0),
		"corpo": Vector3(0, -12, -8), "cabeca": Vector3(0, 12, 8), "coxa_e": Vector3(0, 0, -4), "coxa_d": Vector3(0, 0, -8)})
	_cache["danca"] = {
		"dur": 2.0, "loop": true,
		"chaves": [[0.0, d1], [0.5, _p(d1, {"altura": -0.05, "canela_e": Vector3(25, 0, 0), "canela_d": Vector3(25, 0, 0)})], [1.0, d2],
			[1.5, _p(d2, {"altura": -0.05, "canela_e": Vector3(25, 0, 0), "canela_d": Vector3(25, 0, 0)})], [2.0, d1]],
	}
	# ---------------------------------------------------- acenar (oi!)
	var a1 := _p(PARADO, {"braco_d": Vector3(-10, 0, -150), "antebraco_d": Vector3(0, 0, -25), "cabeca": Vector3(0, 0, 6)})
	var a2 := _p(a1, {"antebraco_d": Vector3(0, 0, 25), "cabeca": Vector3(0, 0, -4)})
	_cache["acenar"] = {"dur": 1.0, "loop": true, "chaves": [[0.0, a1], [0.25, a2], [0.5, a1], [0.75, a2], [1.0, a1]]}
	# ---------------------------------------------------- andar
	var w1 := _p(PARADO, {"coxa_e": Vector3(-26, 0, 0), "canela_e": Vector3(8, 0, 0), "coxa_d": Vector3(22, 0, 0), "canela_d": Vector3(30, 0, 0),
		"braco_e": Vector3(25, 0, 10), "braco_d": Vector3(-25, 0, -10), "altura": -0.015})
	var w2 := _p(PARADO, {"coxa_d": Vector3(-26, 0, 0), "canela_d": Vector3(8, 0, 0), "coxa_e": Vector3(22, 0, 0), "canela_e": Vector3(30, 0, 0),
		"braco_d": Vector3(25, 0, -10), "braco_e": Vector3(-25, 0, 10), "altura": -0.015})
	_cache["andar"] = {"dur": 0.7, "loop": true, "chaves": [[0.0, w1], [0.175, _p(PARADO, {"altura": 0.02})], [0.35, w2], [0.525, _p(PARADO, {"altura": 0.02})], [0.7, w1]]}
	# ---------------------------------------------------- vitória: pulinhos de alegria, braços para cima
	var v_baixo := _p(agacha, {"altura": -0.08, "braco_e": Vector3(-150, 0, 40), "braco_d": Vector3(-150, 0, -40)})
	var v_alto := _p(voando, {"voo": 0.32})
	_cache["vitoria"] = {
		"dur": 1.4, "loop": true,
		"chaves": [[0.0, v_baixo], [0.35, v_alto], [0.7, v_baixo], [1.05, _p(v_alto, {"giro": 0.0, "voo": 0.25, "corpo": Vector3(-6, 0, 10)})],
			[1.4, v_baixo]],
	}
	# ---------------------------------------------------- escolhido (seleção de personagem)
	_cache["escolhido"] = {
		"dur": 1.4, "loop": false,
		"chaves": [[0.0, PARADO], [0.15, _p(agacha, {"altura": -0.06})],
			[0.4, _p(PARADO, {"voo": 0.28, "braco_d": Vector3(-170, 0, -15), "antebraco_d": Vector3(-10, 0, 0), "braco_e": Vector3(10, 0, 30),
				"canela_e": Vector3(50, 0, 0), "canela_d": Vector3(20, 0, 0)})],
			[0.75, _p(PARADO, {"altura": -0.03, "braco_d": Vector3(-160, 0, -20)})],
			[1.4, _p(PARADO, {"braco_d": Vector3(-150, 0, -30), "antebraco_d": Vector3(-40, 0, 0)})]],
		"eventos": [[0.0, "expressao", "empolgado"], [1.2, "expressao", "piscadinha"]],
	}
	# ---------------------------------------------------- quase (ficou 1 pino): mãos na cabeça
	_cache["quase"] = {
		"dur": 1.7, "loop": false,
		"chaves": [[0.0, PARADO],
			[0.3, _p(PARADO, {"braco_e": Vector3(-150, 0, 50), "antebraco_e": Vector3(-110, 0, 0), "braco_d": Vector3(-150, 0, -50), "antebraco_d": Vector3(-110, 0, 0),
				"corpo": Vector3(-6, 0, 0), "cabeca": Vector3(-10, 0, 0)})],
			[1.2, _p(PARADO, {"braco_e": Vector3(-150, 0, 50), "antebraco_e": Vector3(-115, 0, 0), "braco_d": Vector3(-150, 0, -50), "antebraco_d": Vector3(-115, 0, 0),
				"corpo": Vector3(-4, 0, 0), "cabeca": Vector3(-6, 0, 8)})],
			[1.7, PARADO]],
		"eventos": [[0.0, "expressao", "surpreso"]],
	}
