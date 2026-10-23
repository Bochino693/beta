# -*- coding: utf-8 -*-
"""
FONTES DO CENÁRIO EM ALTA (versão 6.4): os objetos dos 4 cenários feitos de
novo pelas FORMAS MATEMÁTICAS (SDF) do Strike Kids — as mesmas do Godot 4,
com os redesenhos da 6.4 —, numa grade bem mais fina (paleta.FINO), para o
assador (tools/modelos_texturizados.py) tirar delas a forma lisa e o
desenho nítido (olhos, bocas, listras, pintas).

    python3 -I tools/cenario_sdf/gerar.py <pasta_fontes> [nome1 nome2 ...]

Grava <pasta_fontes>/<nome>.msh (o formato do tools/malhas_leves.py, com a
frente dos triângulos no sentido do Godot) e o indice.json — a pasta serve
de <antigos> para o modelos_texturizados.py.
"""
import json
import multiprocessing as mp
import os
import sys
import time

import numpy as np

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
sys.path.insert(0, os.path.dirname(AQUI))

import decoracao  # noqa: E402
import temas  # noqa: E402
from malhas_leves import COLOR, NORMAL, TRIANGULOS, VERTEX, gravar_msh  # noqa: E402


def geradores():
    g = dict(temas.OBJETOS)
    g.update(decoracao.PECAS)
    return g


def _um(nome):
    t = time.time()
    f = geradores()[nome]
    r = f()
    if isinstance(r, dict):
        m = r[nome]
    else:
        m = r
    return nome, m, time.time() - t


def superficie(m):
    """Malha do modelador (frente anti-horária) -> superfície do .msh (frente
    horária, como o Godot desenha)."""
    ind = np.asarray(m.i, dtype=np.int64).reshape(-1, 3)[:, [0, 2, 1]].reshape(-1)
    arr = {VERTEX: np.asarray(m.v, np.float32), NORMAL: np.asarray(m.n, np.float32),
           COLOR: np.asarray(m.c, np.float32)}
    listas = (1 << VERTEX) | (1 << NORMAL) | (1 << COLOR)
    return {"prim": TRIANGULOS, "listas": listas, "arr": arr, "ind": ind.astype(np.uint32)}


def main():
    saida = sys.argv[1]
    os.makedirs(saida, exist_ok=True)
    todos = geradores()
    so = sys.argv[2:] or list(todos)
    for n in so:
        if n not in todos:
            sys.exit("objeto desconhecido: %s" % n)
    caminho = os.path.join(saida, "indice.json")
    indice = json.load(open(caminho)) if os.path.exists(caminho) else []
    with mp.get_context("fork").Pool(min(4, os.cpu_count() or 1)) as pool:
        for nome, m, dt in pool.imap_unordered(_um, so):
            gravar_msh(os.path.join(saida, nome + ".msh"), [superficie(m)])
            if not any(e["id"] == nome for e in indice):
                indice.append({"id": nome, "recurso": "res://modelos/cenario/%s.res" % nome, "no": "", "superficies": []})
            print("  %-14s %7d triângulos %7d vértices  (%.0f s)" % (nome, len(m.i) // 3 if m.i.ndim == 1 else len(m.i),
                                                                     len(m.v), dt), flush=True)
    json.dump(indice, open(caminho, "w"), indent=1)


if __name__ == "__main__":
    main()
