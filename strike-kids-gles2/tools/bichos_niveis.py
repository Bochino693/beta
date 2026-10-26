# -*- coding: utf-8 -*-
"""
NÍVEIS DE DETALHE DOS BICHINHOS (6.8): a versão de PERTO (HD) e a de LONGE
(leve) de cada bichinho e de cada roupinha, tiradas dos modelos ORIGINAIS
(26 a 37 mil triângulos cada bichinho; a versão do jogo, a do meio, tem
~7 mil — tools/malhas_leves.py).

    python3 -I tools/bichos_niveis.py <originais> <saida>

<originais>: a pasta do tools/malhas_leves.gd --exportar --origem=<modelos
originais> (indice.json + mXXXX.msh). Em <saida> ficam duas pastas, hd/ e
longe/, cada uma com o indice.json apontando para as cópias das cenas
(modelos/niveis/<bichinho>_hd.scn, ..._longe.scn; as roupinhas em
modelos/niveis/roupas/) e os .leve.msh simplificados. Depois:

    cp modelos/bob.scn modelos/niveis/bob_hd.scn   (etc., ver niveis.sh)
    godot3 --no-window --path . -s res://tools/malhas_leves.gd -- --importar <saida>/hd
    godot3 --no-window --path . -s res://tools/malhas_leves.gd -- --importar <saida>/longe

No jogo (Personagem._nivel) a malha de cada peça troca pelo tamanho do
bichinho na tela: HD nos closes (a comemoração, a escolha de perto), a do
meio no resto e a leve quando ele aparece pequenininho (a espera, de longe).
"""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import malhas_leves as ml  # noqa: E402

# triângulos de cada peça: [cabeça, corpo, fração das outras, mínimo, máximo] e o erro
NIVEIS = {
    "hd": {"cabeca": 7000, "corpo": 3200, "frac": 0.45, "min": 260, "max": 600, "erro": 0.005},
    "longe": {"cabeca": 1000, "corpo": 520, "frac": 0.12, "min": 70, "max": 130, "erro": 0.05},
}


def alvo(nivel, no, tris):
    n = NIVEIS[nivel]
    partes = no.split(":")[0].split("/")
    parte = partes[-2] if len(partes) >= 2 else ""
    if parte == "cabeca":
        return min(n["cabeca"], tris)
    if parte == "corpo":
        return min(n["corpo"], tris)
    return int(np.clip(tris * n["frac"], n["min"], n["max"]))


def destino(recurso, nivel):
    """res://modelos/bob.scn -> res://modelos/niveis/bob_hd.scn (roupas em niveis/roupas/)."""
    rel = recurso[len("res://modelos/"):]
    pasta, arq = os.path.split(rel)
    nome, ext = os.path.splitext(arq)
    return "res://modelos/niveis/%s%s_%s%s" % (pasta + "/" if pasta else "", nome, nivel, ext)


def principal(originais, saida):
    indice = json.load(open(os.path.join(originais, "indice.json")))
    bichos = [e for e in indice if e["recurso"].startswith("res://modelos/")
              and (e["recurso"].endswith("bob.scn") or e["recurso"].endswith("mia.scn") or "/roupas/" in e["recurso"])]
    for nivel in NIVEIS:
        pasta = os.path.join(saida, nivel)
        os.makedirs(pasta, exist_ok=True)
        novo_indice = []
        soma = {}
        for e in bichos:
            sups = ml.ler_msh(os.path.join(originais, e["id"] + ".msh"))
            leves = []
            for s in sups:
                tris = len(s["ind"]) // 3
                a = alvo(nivel, e["no"], tris)
                erro = NIVEIS[nivel]["erro"]
                r, _erro = ml.simplificar(s, a, erro)
                # peça cheia de detalhe (o chapéu do pirata) que o erro não
                # deixa chegar perto do alvo: aceita um pouco mais de erro
                while r is not None and len(r["ind"]) // 3 > a * 1.3 and erro < NIVEIS[nivel]["erro"] * 4:
                    erro *= 1.5
                    r, _erro = ml.simplificar(s, a, erro)
                leves.append(r if r is not None else s)
            novo_id = "%s_%s" % (nivel, e["id"])
            ml.gravar_msh(os.path.join(pasta, novo_id + ".leve.msh"), leves)
            rec = destino(e["recurso"], nivel)
            novo_indice.append({"id": novo_id, "recurso": rec, "no": e["no"], "superficies": []})
            soma[rec] = soma.get(rec, 0) + sum(len(s["ind"]) // 3 for s in leves)
        json.dump(novo_indice, open(os.path.join(pasta, "indice.json"), "w"), indent=1)
        for rec in sorted(soma):
            print("%-6s %-50s %6d triângulos" % (nivel, rec, soma[rec]))


if __name__ == "__main__":
    principal(sys.argv[1], sys.argv[2])
