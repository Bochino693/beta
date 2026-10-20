"""Assa a decoração FIXA da pista (madeira envernizada, linha de falta,
pontos, trilha de estrelas, setas arco-íris e área dos pinos) numa textura,
com as mesmas contas do pista.gdshader do Godot 4. O shader da edição
OpenGL ES 2.0 só soma o que mexe (neon, luzes correndo, reflexos, brilho da
bola e o piscar das estrelas).

    python3 -I tools/assar_pista.py texturas/madeira.png texturas/pista_pronta.png

Saída RGBA 512x4096: RGB = sqrt(cor_linear / ESCALA), A = máscara das
estrelas (1 dentro, cai em volta: o halo) — o shader acende cada estrela.
"""
import sys
import numpy as np
from PIL import Image

MEIA = 0.675
Z0 = 0.1           # começo da pista (d = -0.1)
Z_FIM = -11.95     # fim do deck
REPETE = 3.6
DP = 10.5          # distância dos pinos (-z_pino1)
LARG, ALT = 512, 4096
SS = 2             # supersampling
ESCALA = 1.6

ARCO = np.array([(1.0, 0.23, 0.33), (1.0, 0.56, 0.13), (1.0, 0.85, 0.15),
                 (0.35, 0.86, 0.33), (0.2, 0.8, 1.0), (0.27, 0.47, 1.0), (0.72, 0.38, 1.0)], np.float32)


def srgb_lin(c):
    c = np.asarray(c, np.float32)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def bilinear(img, u, v):
    """amostra com repetição (u, v em 0..1, qualquer valor)."""
    h, w, _ = img.shape
    x = (u * w - 0.5) % w
    y = (v * h - 0.5) % h
    x0 = np.floor(x).astype(np.int64)
    y0 = np.floor(y).astype(np.int64)
    fx = (x - x0)[..., None]
    fy = (y - y0)[..., None]
    x1 = (x0 + 1) % w
    y1 = (y0 + 1) % h
    x0 %= w
    y0 %= h
    a = img[y0, x0] * (1 - fx) + img[y0, x1] * fx
    b = img[y1, x0] * (1 - fx) + img[y1, x1] * fx
    return a * (1 - fy) + b * fy


def cobre(dist, w):
    return np.clip(0.5 - dist / w, 0.0, 1.0)


def sd_tri(px, py, qx, qy):
    px = np.abs(px)
    t = np.clip((px * qx + py * qy) / (qx * qx + qy * qy), 0.0, 1.0)
    ax, ay = px - qx * t, py - qy * t
    t2 = np.clip(px / qx, 0.0, 1.0)
    bx, by = px - qx * t2, py - qy
    s = -np.sign(qy)
    d1 = np.minimum(ax * ax + ay * ay, bx * bx + by * by)
    d2a = s * (px * qy - py * qx)
    d2b = s * (py - qy)
    # min componente a componente de vec2(dot(a,a), d2a) e vec2(dot(b,b), d2b)
    dy = np.minimum(d2a, d2b)
    return -np.sqrt(d1) * np.sign(dy)


def sd_estrela(px, py, r, vale):
    k1 = (0.809016994375, -0.587785252292)
    k2 = (-0.809016994375, -0.587785252292)
    px = np.abs(px)
    t = 2.0 * np.maximum(k1[0] * px + k1[1] * py, 0.0)
    px, py = px - t * k1[0], py - t * k1[1]
    t = 2.0 * np.maximum(k2[0] * px + k2[1] * py, 0.0)
    px, py = px - t * k2[0], py - t * k2[1]
    px = np.abs(px)
    py = py - r
    bax, bay = vale * -k1[1], vale * k1[0] - 1.0
    h = np.clip((px * bax + py * bay) / (bax * bax + bay * bay), 0.0, r)
    lx, ly = px - bax * h, py - bay * h
    return np.sqrt(lx * lx + ly * ly) * np.sign(py * bax - px * bay)


class Camada:
    """c(madeira) = madeira * m + b, por texel (todas as contas são afins)."""

    def __init__(self, base):
        self.c = base

    def mix(self, cor, t):
        t = t[..., None]
        self.c = self.c * (1 - t) + np.asarray(cor, np.float32) * t

    def soma(self, cor, t):
        self.c = self.c + np.asarray(cor, np.float32) * t[..., None]

    def adesivo(self, dist, w, cor, contorno, acesa):
        halo = np.exp(-np.maximum(dist, 0.0) * 22.0) * 0.35 * acesa
        self.c = self.c + cor * halo[..., None]
        self.mix((1.0, 1.0, 1.0), cobre(dist - contorno, w))
        self.c = self.c * (1 - cobre(dist, w)[..., None]) + (cor * (0.75 + 0.6 * acesa)) * cobre(dist, w)[..., None]


def main():
    madeira = np.asarray(Image.open(sys.argv[1]).convert("RGB"), np.float32) / 255.0
    madeira = srgb_lin(madeira)
    tom = srgb_lin([1.0, 0.84, 0.6])
    W, H = LARG * SS, ALT * SS
    # centro de cada amostra no mundo
    x = ((np.arange(W, dtype=np.float32) + 0.5) / W - 0.5) * (2 * MEIA)
    z = Z0 + (np.arange(H, dtype=np.float32) + 0.5) / H * (Z_FIM - Z0)
    X, Zm = np.meshgrid(x, z)
    d = -Zm
    ax = np.abs(X)
    w = max(2 * MEIA / W, (Z0 - Z_FIM) / H) * 1.2

    u = X / (MEIA * 2.0) + 0.5
    v = -Zm / REPETE
    c = bilinear(madeira, u, v) * tom
    l = (c * np.array([0.299, 0.587, 0.114], np.float32)).sum(-1, keepdims=True)
    c = np.clip((l + (c - l) * 1.25) * 1.04 - 0.02, 0.0, 1.0)
    cam = Camada(c)
    mascara = np.zeros(d.shape, np.float32)

    # linha de falta (o pulso fica na média)
    falta = np.abs(d - 0.02) - 0.022
    cam.mix((1.0, 0.18, 0.35), cobre(falta, w))
    cam.soma((1.0, 0.2, 0.4), np.exp(-np.maximum(falta, 0.0) * 40.0) * 0.35 * (d < 0.4))

    # pontos de mira a 1,6 m
    ip = np.clip(np.round(X / 0.17), -3, 3)
    dd = np.sqrt((X - ip * 0.17) ** 2 + (d - 1.6) ** 2) - 0.042
    zona = np.abs(d - 1.6) < 0.14
    cor = ARCO[(ip + 3).astype(np.int64)]
    antes = cam.c.copy()
    cam.adesivo(dd, w, cor, 0.013, 0.6)
    cam.c = np.where(zona[..., None], cam.c, antes)

    # trilha de estrelas (apagadas: acesa = 0.35; o shader acende)
    k = np.clip(np.round((d - 2.3) / 1.35), 0, 5)
    qy = d - (2.3 + k * 1.35)
    r = 0.17 + k * 0.022
    de = sd_estrela(X, qy, r, 0.48) - 0.014
    zona = (ax < 0.36) & (d > 1.9) & (d < DP - 1.05)
    cor = ARCO[np.mod(k * 2, 7).astype(np.int64)]
    antes = cam.c.copy()
    cam.adesivo(de, w, cor, 0.02, 0.35)
    cam.c = np.where(zona[..., None], cam.c, antes)
    mascara = np.where(zona, np.exp(-np.maximum(de, 0.0) * 22.0), 0.0)

    # setas arco-íris (o pulso fica na média)
    is_ = np.clip(np.round(X / 0.17), -3, 3)
    ponta = 3.78 + (3.0 - np.abs(is_)) * 0.3
    ds = sd_tri(X - is_ * 0.17, ponta - d, 0.066, 0.44)
    zona = (d > 3.2) & (d < 4.85)
    cor = ARCO[(is_ + 3).astype(np.int64)]
    antes = cam.c.copy()
    cam.adesivo(ds, w, cor, 0.016, 0.875)
    cam.c = np.where(zona[..., None], cam.c, antes)
    # a seta por cima da estrela não pisca
    mascara = np.where(zona & (ds < 0.03), mascara * np.clip(ds / 0.03, 0.0, 1.0), mascara)

    # área dos pinos: marcas, tom mais claro e o holofote
    zona = d > DP - 1.4
    r2x, r2y = X, d - DP
    lin = np.clip(np.round(r2y / 0.329), 0, 3)
    kk = np.clip(np.round(r2x / 0.38 + lin * 0.5), 0, lin)
    mpx, mpy = (kk - lin * 0.5) * 0.38, lin * 0.329
    marca = cobre(np.sqrt((r2x - mpx) ** 2 + (r2y - mpy) ** 2) - 0.08, w)
    cc = cam.c
    cc2 = cc * (1 + 0.2 * marca[..., None]) + 0.05 * marca[..., None]
    t = np.clip((d - (DP - 0.7)) / 0.3, 0.0, 1.0)
    cc2 = cc2 * (1.0 + 0.1 * (t * t * (3 - 2 * t)))[..., None]
    spot = np.exp(-((r2x) ** 2 + (r2y - 0.45) ** 2) * 1.6)
    cc2 = cc2 + np.array([1.0, 0.92, 0.75], np.float32) * (spot * 0.28)[..., None]
    cam.c = np.where(zona[..., None], cc2, cc)

    # reduz o supersampling (média de cada bloco SSxSS)
    cor = cam.c.reshape(ALT, SS, LARG, SS, 3).mean(axis=(1, 3))
    msk = mascara.reshape(ALT, SS, LARG, SS).mean(axis=(1, 3))
    print("cor máx", cor.max(), "> escala:", (cor > ESCALA).mean())
    rgb = np.sqrt(np.clip(cor / ESCALA, 0.0, 1.0))
    out = np.concatenate([rgb, np.clip(msk, 0, 1)[..., None]], -1)
    Image.fromarray(np.round(out * 255).astype(np.uint8), "RGBA").save(sys.argv[2], optimize=True)
    print("ok", sys.argv[2])


if __name__ == "__main__":
    main()
