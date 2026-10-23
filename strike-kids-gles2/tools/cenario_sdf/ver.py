# -*- coding: utf-8 -*-
"""
VER UM MODELO SEM ABRIR O GODOT (só no PC): desenha um .msh (as fontes do
gerar.py ou as malhas leves do assador, com a textura do atlas) numa
imagem, com uma luz parecida com a do jogo — para conferir os redesenhos
depressa.

    python3 -I tools/cenario_sdf/ver.py saida.png arq.msh [arq2.msh ...]
        [--atlas=atlas.png] [--giro=30] [--alto=15] [--tam=640] [--lado=3]

Várias malhas lado a lado (mesma escala de cada uma: cada uma enquadrada).
"""
import math
import os
import sys

import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(AQUI))
from malhas_leves import COLOR, NORMAL, TEX_UV, VERTEX, ler_msh  # noqa: E402

LUZ = np.array([0.35, 0.79, 0.5])
LUZ = LUZ / np.linalg.norm(LUZ)


def s2l(c):
    return c * (c * (c * 0.305306011 + 0.682171111) + 0.012522878)


def desenhar(sup, tam, giro, alto, atlas=None, fundo=(108, 214, 92)):
    v = sup["arr"][VERTEX].astype(np.float64)
    n = sup["arr"][NORMAL].astype(np.float64) if NORMAL in sup["arr"] else np.zeros_like(v)
    c = sup["arr"][COLOR][:, :3].astype(np.float64) if COLOR in sup["arr"] else np.ones_like(v)
    uv = sup["arr"].get(TEX_UV)
    f = sup["ind"].reshape(-1, 3).astype(np.int64)
    # câmera olhando o centro da caixa, de frente (+z) girada
    lo, hi = v.min(0), v.max(0)
    centro = (lo + hi) / 2
    raio = np.linalg.norm(hi - lo) / 2
    g, a = math.radians(giro), math.radians(alto)
    d = np.array([math.sin(g) * math.cos(a), math.sin(a), math.cos(g) * math.cos(a)])
    olho = centro + d * raio * 3.2
    fwd = (centro - olho) / np.linalg.norm(centro - olho)
    dir_ = np.cross(fwd, [0, 1, 0])
    dir_ /= np.linalg.norm(dir_)
    cima = np.cross(dir_, fwd)
    q = v - olho
    x, y, z = q @ dir_, q @ cima, q @ fwd
    foco = tam / (2 * math.tan(math.radians(20)))
    sx = tam / 2 + foco * x / z
    sy = tam / 2 - foco * y / z
    img = np.zeros((tam, tam, 3))
    img[:] = np.array(fundo) / 255.0
    zb = np.full((tam, tam), np.inf)
    luz = 0.42 + 0.7 * np.clip(n @ LUZ, 0, 1)
    tex = None
    if atlas is not None and uv is not None:
        tex = np.asarray(atlas).astype(np.float64) / 255.0
    for t in f:
        xs, ys = sx[t], sy[t]
        x0, x1 = int(max(0, math.floor(xs.min()))), int(min(tam - 1, math.ceil(xs.max())))
        y0, y1 = int(max(0, math.floor(ys.min()))), int(min(tam - 1, math.ceil(ys.max())))
        if x1 < x0 or y1 < y0:
            continue
        # só a frente (Godot: horária na tela com y para baixo = anti-horária aqui)
        area = (xs[1] - xs[0]) * (ys[2] - ys[0]) - (xs[2] - xs[0]) * (ys[1] - ys[0])
        if area <= 0:
            continue
        px, py = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        w0 = ((xs[1] - px) * (ys[2] - py) - (xs[2] - px) * (ys[1] - py)) / area
        w1 = ((xs[2] - px) * (ys[0] - py) - (xs[0] - px) * (ys[2] - py)) / area
        w2 = 1 - w0 - w1
        dentro = (w0 >= 0) & (w1 >= 0) & (w2 >= 0)
        if not dentro.any():
            continue
        zz = w0 * z[t[0]] + w1 * z[t[1]] + w2 * z[t[2]]
        iy, ix = np.where(dentro)
        iy += y0
        ix += x0
        zv = zz[dentro]
        melhor = zv < zb[iy, ix]
        if not melhor.any():
            continue
        iy, ix, zv = iy[melhor], ix[melhor], zv[melhor]
        W = np.stack([w0[dentro][melhor], w1[dentro][melhor], w2[dentro][melhor]], 1)
        cor = W @ c[t]
        if tex is not None:
            u = W @ uv[t]
            tx = np.clip((u[:, 0] * tex.shape[1]).astype(int), 0, tex.shape[1] - 1)
            ty = np.clip((u[:, 1] * tex.shape[0]).astype(int), 0, tex.shape[0] - 1)
            cor = cor * tex[ty, tx]
        else:
            cor = np.clip(cor, 0, 1)
        lz = W @ luz[t]
        zb[iy, ix] = zv
        img[iy, ix] = np.clip(cor * lz[:, None], 0, 1)
    return img


def main():
    saida = sys.argv[1]
    arqs = [a for a in sys.argv[2:] if not a.startswith("--")]
    op = dict(a[2:].split("=", 1) for a in sys.argv[2:] if a.startswith("--"))
    tam = int(op.get("tam", 640))
    lado = int(op.get("lado", 3))
    atlas = Image.open(op["atlas"]).convert("RGB") if "atlas" in op else None
    ss = 2
    imgs = []
    for a in arqs:
        sup = ler_msh(a)[0]
        im = desenhar(sup, tam * ss, float(op.get("giro", 30)), float(op.get("alto", 15)), atlas)
        im = Image.fromarray((im * 255 + 0.5).astype(np.uint8)).resize((tam, tam), Image.LANCZOS)
        imgs.append(im)
    cols = min(lado, len(imgs))
    linhas = (len(imgs) + cols - 1) // cols
    folha = Image.new("RGB", (cols * tam, linhas * tam), (255, 255, 255))
    for i, im in enumerate(imgs):
        folha.paste(im, ((i % cols) * tam, (i // cols) * tam))
    folha.save(saida)


if __name__ == "__main__":
    main()
