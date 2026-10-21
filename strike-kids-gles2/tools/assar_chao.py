"""Assa os DETALHES DO CHÃO de cada cenário (florzinhas do parque, crateras e
poeira da lua, conchinhas do mar, flores da selva) em texturas que se
repetem, com as mesmas contas do terreno_desenho.gdshaderinc do Godot 4.
Na Mali-400 o sorteio por pixel não tem precisão: o shader só lê a
textura (texturas/chao_<modo>.png) e mistura as cores do cenário.

    python3 -I tools/assar_chao.py texturas

Canais (peso de cada cor, somando no máximo 1): R = cor B do chão (fundo
da cratera), G = detalhe 1 (lin_c), B = detalhe 2 (lin_d); o shader faz
c += (lin_b - c) * R + (lin_c - c) * G + (lin_d - c) * B (conta linear:
os mipmaps dão a média certa de longe). O ladrilho tem "tamanho" metros
(múltiplo das grades do desenho: emenda sem costura).
"""
import os
import sys
import numpy as np
from PIL import Image

LADO = 1024
SS = 2

# modo -> tamanho do ladrilho (m) e o que tem nele
MODOS = {
    0: {"tamanho": 25.2, "pontos": [(0.9, 0.9, 0.06)]},             # parque: florzinhas
    1: {"tamanho": 22.4, "crateras": 3.2, "poeira": (0.7, 0.93, 0.025)},  # lua
    2: {"tamanho": 25.3, "pontos": [(1.1, 0.88, 0.045)]},           # mar: conchinhas
    3: {"tamanho": 25.0, "pontos": [(1.0, 0.9, 0.055)]},            # selva: flores
}


def fract(x):
    return x - np.floor(x)


def h2(px, py):
    p3x, p3y, p3z = fract(px * 0.1031), fract(py * 0.1031), fract(px * 0.1031)
    d = p3x * (p3y + 33.33) + p3y * (p3z + 33.33) + p3z * (p3x + 33.33)
    p3x, p3y, p3z = p3x + d, p3y + d, p3z + d
    return fract((p3x + p3y) * p3z)


def h22(px, py):
    p3x, p3y, p3z = fract(px * 0.1031), fract(py * 0.1030), fract(px * 0.0973)
    d = p3x * (p3y + 33.33) + p3y * (p3z + 33.33) + p3z * (p3x + 33.33)
    p3x, p3y, p3z = p3x + d, p3y + d, p3z + d
    # (p3.xx + p3.yz) * p3.zy
    return fract((p3x + p3y) * p3z), fract((p3x + p3z) * p3y)


def ponto(px, py, grade, chance, raio, w, periodo):
    """cobertura da bolinha da casinha e o sorteio (ladrilho: casinhas módulo periodo)."""
    cx, cy = np.floor(px / grade), np.floor(py / grade)
    qx, qy = np.mod(cx, periodo), np.mod(cy, periodo)
    r = h2(qx * 1.31, qy * 1.31)
    hx, hy = h22(qx, qy)
    centro_x = (cx + 0.2 + 0.6 * hx) * grade
    centro_y = (cy + 0.2 + 0.6 * hy) * grade
    d = np.hypot(px - centro_x, py - centro_y) - raio * (0.7 + 0.6 * fract(r * 13.0))
    cob = np.clip(0.5 - d / w, 0.0, 1.0)
    cob = np.where(r <= chance, 0.0, cob)
    return cob, fract(r * 7.0)


def assar(modo, cfg):
    T = cfg["tamanho"]
    n = LADO * SS
    s = (np.arange(n, dtype=np.float64) + 0.5) / n * T
    PX, PY = np.meshgrid(s, s)
    w = T / n * 1.2
    rB = np.zeros_like(PX)
    gC = np.zeros_like(PX)
    bD = np.zeros_like(PX)
    if "crateras" in cfg:
        g = cfg["crateras"]
        per = int(round(T / g))
        bx, by = np.floor(PX / g - 0.5), np.floor(PY / g - 0.5)
        for j in (0, 1):
            for i in (0, 1):
                qx, qy = bx + i, by + j
                mx, my = np.mod(qx, per), np.mod(qy, per)
                r = h2(mx * 2.7, my * 2.7)
                hx, hy = h22(mx, my)
                cx = (qx + 0.25 + 0.5 * hx) * g
                cy = (qy + 0.25 + 0.5 * hy) * g
                raio = 0.5 + 0.9 * fract(r * 9.0)
                d = np.hypot(PX - cx, PY - cy)
                tem = r > 0.45
                fundo = np.where(tem, np.clip(0.5 - (d - raio) / w, 0, 1), 0.0)
                borda = np.where(tem, np.clip(0.5 - (np.abs(d - raio * 1.08) - raio * 0.08) / w, 0, 1), 0.0)
                # mesma ordem do shader: mistura a cor B, depois a borda (C)
                rB = rB * (1 - fundo) + fundo
                gC = gC * (1 - fundo)
                rB = rB * (1 - borda)
                gC = gC * (1 - borda) + borda
        grade, chance, raio = cfg["poeira"]
        cob, _ = ponto(PX, PY, grade, chance, raio, w, int(round(T / grade)))
        rB, gC = rB * (1 - cob), gC * (1 - cob)
        bD = cob
    for grade, chance, raio in cfg.get("pontos", []):
        cob, sorteio = ponto(PX, PY, grade, chance, raio, w, int(round(T / grade)))
        d2 = (sorteio >= 0.5).astype(np.float64)
        gC = gC * (1 - cob) + cob * (1 - d2)
        bD = bD * (1 - cob) + cob * d2
    img = np.stack([rB, gC, bD], -1).reshape(LADO, SS, LADO, SS, 3).mean(axis=(1, 3))
    return np.round(np.clip(img, 0, 1) * 255).astype(np.uint8)


def main():
    pasta = sys.argv[1]
    for modo, cfg in MODOS.items():
        img = assar(modo, cfg)
        caminho = os.path.join(pasta, "chao_%d.png" % modo)
        Image.fromarray(img, "RGB").save(caminho, optimize=True)
        print("ok", caminho, "ladrilho de %.1f m" % cfg["tamanho"], "cobertura média", img.mean(axis=(0, 1)) / 255)


if __name__ == "__main__":
    main()
