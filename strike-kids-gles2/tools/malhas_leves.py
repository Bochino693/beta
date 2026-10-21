# -*- coding: utf-8 -*-
"""
MALHAS LEVES PARA A MALI-400/450 (TV Box TX9) — o meio do caminho do
tools/malhas_leves.gd (que tira e devolve as malhas do projeto).

    python3 tools/malhas_leves.py <pasta>

Na Mali-400/450 o que mais pesa são os vértices: o processador de vértices
é um só e calcula TODOS os vértices da faixa de cada desenho. Os modelos
vieram do Godot 4 (TV Box com Mali-G31) com 3 a 5 vezes mais triângulos do
que essa placa desenha a 60 quadros por segundo: cada bichinho com 27 a 37
mil, cada pino com 2.400, o cenário de cada fase com 90 a 140 mil.

Cada peça é simplificada pelo meshoptimizer olhando a POSIÇÃO, a NORMAL e
a COR (com o alfa, que marca a máscara do rosto e as partes que brilham):
as partes lisas viram triângulos maiores e as bordas de cor (roupas,
listras, pintas, o rosto) continuam no lugar; bordas abertas (peças
cortadas no chão, juntas) ficam presas. Depois só os vértices usados
ficam, em ordem (a placa calcula todos os da faixa do desenho).

O alvo de cada peça (triângulos) está em `alvo()`. O original fica em
<pasta>/mXXXX.msh; o leve sai em <pasta>/mXXXX.leve.msh.
"""
import json
import os
import struct
import sys

import ctypes

import numpy as np
import meshoptimizer as mo
from meshoptimizer._loader import lib as _lib

# a ligação Python declara errado os tipos desta função: declarados aqui
_P = ctypes.c_void_p
_lib.meshopt_simplifyWithAttributes.argtypes = [
    _P, _P, ctypes.c_size_t, _P, ctypes.c_size_t, ctypes.c_size_t, _P, ctypes.c_size_t,
    _P, ctypes.c_size_t, _P, ctypes.c_size_t, ctypes.c_float, ctypes.c_uint, _P]
_lib.meshopt_simplifyWithAttributes.restype = ctypes.c_size_t

# listas do Godot 3 (Mesh.ARRAY_*) e colunas de cada uma
VERTEX, NORMAL, TANGENT, COLOR, TEX_UV, TEX_UV2 = 0, 1, 2, 3, 4, 5
COLUNAS = {VERTEX: 3, NORMAL: 3, TANGENT: 4, COLOR: 4, TEX_UV: 2, TEX_UV2: 2}
TRIANGULOS = 4   # Mesh.PRIMITIVE_TRIANGLES

PESO_NORMAL = 0.35
PESO_COR = 2.0
PESO_ALFA = 3.0     # máscara do rosto e o que brilha: borda bem guardada
PESO_UV = 1.0

# peças do cenário que aparecem grandes na tela (a decoração de destaque)
GRANDES = ("vulcao", "navio", "carrossel", "roda", "torre", "planeta_anel", "arco_iris")
# peças repetidas muitas vezes em cada fase: alvo próprio
POR_PECA = {"lampada": 64, "balao": 180, "nuvem": 200, "cabine": 260, "navio": 2000,
            "estrela_3d": 220, "peixe": 300, "agua_viva": 340, "ovo_dino": 520, "pedra": 320,
            "pedra_lua": 300, "samambaia": 620, "palmeira": 600, "flor_gigante": 420}


def alvo(recurso, no, tris):
    """Quantos triângulos a peça deve ter (e o erro aceito, fração do tamanho)."""
    arq = recurso.rsplit("/", 1)[-1]
    nome = arq.rsplit(".", 1)[0]
    if "/roupas/" in recurso or arq in ("bob.scn", "mia.scn"):
        # "./corpo/cabeca/malha:mesh" -> "cabeca"
        partes = no.split(":")[0].split("/")
        parte = partes[-2] if len(partes) >= 2 else nome
        if parte == "cabeca":
            return 2600, 0.012
        if parte == "corpo":
            return 1300, 0.012
        return int(np.clip(tris * 0.3, 180, 320)), 0.015
    if arq == "pino.res":
        return 640, 0.008
    if arq == "terreno.res":
        return 6000, 0.01
    if "/cenario/" in recurso:
        if nome in POR_PECA:
            return POR_PECA[nome], 0.08
        teto = 900 if nome in GRANDES else 520
        return int(np.clip(tris * 0.25, 150, teto)), 0.08
    return tris, 0.0


def ler_msh(caminho):
    with open(caminho, "rb") as f:
        blob = f.read()
    assert blob[:4] == b"SKL1", caminho
    pos = 4
    (n_sup,) = struct.unpack_from("<I", blob, pos)
    pos += 4
    sups = []
    for _ in range(n_sup):
        prim, nv, listas = struct.unpack_from("<III", blob, pos)
        pos += 12
        arr = {}
        for t in (VERTEX, NORMAL, TANGENT, COLOR, TEX_UV, TEX_UV2):
            if listas & (1 << t):
                k = COLUNAS[t]
                arr[t] = np.frombuffer(blob, dtype="<f4", count=nv * k, offset=pos).reshape(nv, k).copy()
                pos += nv * k * 4
        (ni,) = struct.unpack_from("<I", blob, pos)
        pos += 4
        ind = np.frombuffer(blob, dtype="<u4", count=ni, offset=pos).copy()
        pos += ni * 4
        sups.append({"prim": prim, "listas": listas, "arr": arr, "ind": ind})
    return sups


def gravar_msh(caminho, sups):
    saida = bytearray(b"SKL1")
    saida += struct.pack("<I", len(sups))
    for s in sups:
        nv = len(s["arr"][VERTEX])
        saida += struct.pack("<III", s["prim"], nv, s["listas"])
        for t in (VERTEX, NORMAL, TANGENT, COLOR, TEX_UV, TEX_UV2):
            if s["listas"] & (1 << t):
                saida += np.ascontiguousarray(s["arr"][t], dtype="<f4").tobytes()
        saida += struct.pack("<I", len(s["ind"]))
        saida += np.ascontiguousarray(s["ind"], dtype="<u4").tobytes()
    with open(caminho, "wb") as f:
        f.write(bytes(saida))


def simplificar(s, alvo_tris, erro):
    """Devolve a superfície simplificada (ou None, se não precisa) e o erro."""
    arr = s["arr"]
    ind = s["ind"].astype(np.uint32)
    if s["prim"] != TRIANGULOS or len(ind) // 3 <= alvo_tris:
        return None, 0.0
    pos = np.ascontiguousarray(arr[VERTEX], dtype=np.float32)
    colunas = []
    pesos = []
    if NORMAL in arr:
        colunas.append(arr[NORMAL])
        pesos += [PESO_NORMAL] * 3
    if COLOR in arr:
        colunas.append(arr[COLOR])
        pesos += [PESO_COR] * 3 + [PESO_ALFA]
    if TEX_UV in arr:
        colunas.append(arr[TEX_UV])
        pesos += [PESO_UV] * 2
    destino = np.zeros_like(ind)
    erro_saida = np.zeros(1, dtype=np.float32)
    if colunas:
        attrs = np.ascontiguousarray(np.hstack(colunas), dtype=np.float32)
        w = np.array(pesos, dtype=np.float32)
        ind = np.ascontiguousarray(ind)
        qtd = _lib.meshopt_simplifyWithAttributes(
            destino.ctypes.data, ind.ctypes.data, len(ind), pos.ctypes.data, len(pos), 12,
            attrs.ctypes.data, attrs.shape[1] * 4, w.ctypes.data, len(w), None,
            alvo_tris * 3, erro, mo.SIMPLIFY_LOCK_BORDER, erro_saida.ctypes.data)
    else:
        qtd = mo.simplify(destino, ind, pos, target_index_count=alvo_tris * 3, target_error=erro,
                          options=mo.SIMPLIFY_LOCK_BORDER, result_error=erro_saida)
    novos = destino[:qtd].copy()
    if qtd == 0:
        return None, 0.0
    # ordem boa para o cache de vértices
    otim = np.zeros_like(novos)
    mo.optimize_vertex_cache(otim, novos, vertex_count=len(pos))
    # só os vértices usados, na ordem em que aparecem (a Mali-400/450
    # calcula TODOS os vértices da faixa do desenho)
    _, primeiro = np.unique(otim, return_index=True)
    seq = otim[np.sort(primeiro)].astype(np.int64)
    ordem = np.full(len(pos), -1, dtype=np.int64)
    ordem[seq] = np.arange(len(seq))
    novo_arr = {t: a[seq] for t, a in arr.items()}
    return {"prim": s["prim"], "listas": s["listas"], "arr": novo_arr,
            "ind": ordem[otim].astype(np.uint32)}, float(erro_saida[0])


def main():
    pasta = sys.argv[1]
    with open(os.path.join(pasta, "indice.json"), encoding="utf-8") as f:
        indice = json.load(f)
    antes_total = depois_total = 0
    for e in indice:
        if any(s["ossos"] or s["formas"] for s in e["superficies"]):
            print("  (pulada: tem ossos ou formas)", e["recurso"], e["no"])
            continue
        sups = ler_msh(os.path.join(pasta, e["id"] + ".msh"))
        tris = sum(len(s["ind"]) // 3 for s in sups)
        meta, erro = alvo(e["recurso"], e["no"], tris)
        if meta >= tris:
            continue
        novas = []
        mudou = False
        erros = []
        for s in sups:
            # cada superfície com a sua parte do alvo
            parte = max(12, int(round(meta * (len(s["ind"]) // 3) / max(tris, 1))))
            n, err = simplificar(s, parte, erro)
            # parou longe do alvo (o limite de erro segurou: pintas, listras)?
            # aceita um pouco mais de erro, até 2,5 vezes o limite
            limite = erro
            while n is not None and len(n["ind"]) // 3 > parte * 1.15 and limite < erro * 2.5:
                limite *= 1.35
                n, err = simplificar(s, parte, limite)
            if n is None:
                novas.append(s)
            else:
                novas.append(n)
                mudou = True
                erros.append(err)
        if not mudou:
            continue
        depois = sum(len(s["ind"]) // 3 for s in novas)
        antes_total += tris
        depois_total += depois
        gravar_msh(os.path.join(pasta, e["id"] + ".leve.msh"), novas)
        v0 = sum(len(s["arr"][VERTEX]) for s in sups)
        v1 = sum(len(s["arr"][VERTEX]) for s in novas)
        print("  %-28s %-44s %6d -> %5d tri  %6d -> %5d vert  erro %.4f" % (
            e["recurso"].replace("res://modelos/", ""), e["no"].replace(":mesh", "")[-44:], tris, depois,
            v0, v1, max(erros) if erros else 0.0))
    print("TOTAL %d -> %d triângulos (%.0f%%)" % (antes_total, depois_total, 100.0 * depois_total / max(antes_total, 1)))


if __name__ == "__main__":
    main()
