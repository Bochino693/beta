"""Assa as ESTRELAS do céu do Espaço numa textura (equiretangular, no mesmo
mapeamento de UV da SphereMesh do Godot 3), com as contas do ceu_leve do
Godot 4 (uma camada de estrelas sorteadas numa grade 3D). Na Mali-400 o
sorteio por pixel não tem precisão (as estrelas piscariam e andariam).

    python3 -I tools/assar_estrelas.py texturas/estrelas_ceu.png
"""
import sys
import numpy as np
from PIL import Image

LARG, ALT = 2048, 1024
SS = 4
ESC, LIMIAR, TAM = 90.0, 0.955, 0.2


def h3(p):
    p = (p * np.float32(0.1031)) % np.float32(1.0)
    pzyx = p[..., ::-1]
    d = (p * (pzyx + np.float32(31.32))).sum(-1, keepdims=True)
    p = p + d
    return ((p[..., 0] + p[..., 1]) * p[..., 2]) % np.float32(1.0)


def main():
    saida = np.zeros((ALT, LARG), np.float32)
    pico = np.zeros((ALT, LARG), np.float32)
    passo = 64  # linhas por vez (memória)
    for y0 in range(0, ALT, passo):
        ys = (np.arange(y0 * SS, (y0 + passo) * SS, dtype=np.float32) + 0.5) / (ALT * SS)
        xs = (np.arange(LARG * SS, dtype=np.float32) + 0.5) / (LARG * SS)
        U, V = np.meshgrid(xs, ys)
        fi = U * np.float32(2 * np.pi)
        te = V * np.float32(np.pi)
        d = np.stack([np.sin(fi) * np.sin(te), np.cos(te), np.cos(fi) * np.sin(te)], -1).astype(np.float32)
        p = d * np.float32(ESC)
        cel = np.floor(p)
        f = p - cel - np.float32(0.5)
        r = h3(cel)
        dist = np.sqrt((f * f).sum(-1))
        t = np.clip((TAM - dist) / TAM, 0.0, 1.0)
        e = t * t * (3 - 2 * t)
        e = np.where((r > LIMIAR) & (d[..., 1] > -0.02), e, 0.0)
        bloco = e.reshape(passo, SS, LARG, SS)
        saida[y0:y0 + passo] = bloco.mean(axis=(1, 3))
        pico[y0:y0 + passo] = bloco.max(axis=(1, 3))
    img = np.clip(saida * 0.6 + pico * 0.4, 0.0, 1.0)
    Image.fromarray(np.round(img * 255).astype(np.uint8), "L").save(sys.argv[1], optimize=True)
    print("ok", sys.argv[1], "estrelas acesas em", (img > 0.3).mean() * 100, "% dos texels")


if __name__ == "__main__":
    main()
