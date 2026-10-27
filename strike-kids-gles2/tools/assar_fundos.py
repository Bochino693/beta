# -*- coding: utf-8 -*-
"""
FUNDOS PINTADOS (6.9): a paisagem distante de cada fase numa FAIXA
panorâmica que o céu desenha atrás de tudo (shaders/ceu.shader e
ceu_leve.shader). 7.0: SÓ A PAISAGEM — montanhas, colinas, a mata lá longe,
nebulosas e estrelas, raios de luz e o recife na névoa. Nada de objeto
pintado (o castelo, o Saturno, o vulcão, os planetas, as tendas, os
peixes...): os objetos do jogo são todos 3D, do mesmo jeito (o castelo e o
Saturno viraram modelos, tools/cenario_sdf/temas.py).

Na Mali-450 o que pesa são os vértices: cada objeto 3D lá longe custa
triângulos em todo quadro e aparece minúsculo. Pintado no céu, o fundo
custa UMA leitura de textura por pixel do céu (os mesmos 48 x 24 vértices
da esfera) — e pode ter todo o detalhe que se quiser.

    python3 -I tools/assar_fundos.py [tema ...]      ->  texturas/fundo_<tema>.png

A faixa vai de -ARCO a +ARCO graus em volta da frente da pista (-Z) e de
EL_TOPO a EL_BAIXO graus de altura; a cor sai pronta, já como na tela. A
parte de cima de cada faixa é o próprio degradê do céu (as mesmas contas do
shader: o degradê e a tela_g4), e o shader mistura a faixa com o céu no
alto e nos lados — sem emenda.
"""
import math
import os
import sys

import numpy as np
from PIL import Image

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
W, H = (1024, 256) if os.environ.get("PREVIA") else (4096, 1024)
ARCO = 75.0          # graus para cada lado da frente
EL_TOPO = 40.0       # graus (linha 0)
EL_BAIXO = -6.0      # graus (última linha)

# os céus de scripts/temas.gd (CONFIG[tema]["ceu"]: topo, meio, horizonte, chão)
CEUS = {
    "parque": ["#2F7FFF", "#6CBBFF", "#E4F4FF", "#8CD18C"],
    "espaco": ["#040A26", "#0E2560", "#2C6AB8", "#14244E"],
    "mar": ["#0A4F86", "#1A94C0", "#86E6DE", "#E8D29A"],
    "dinos": ["#3FA7E8", "#9BD8F0", "#FFE4AE", "#6BBF59"],
}

AZ1 = np.linspace(-ARCO, ARCO, W, dtype=np.float32)
EL1 = np.linspace(EL_TOPO, EL_BAIXO, H, dtype=np.float32)
AZ, EL = np.meshgrid(AZ1, EL1)
PX = (EL_TOPO - EL_BAIXO) / H          # graus por pixel (na altura)
AA = PX * 1.1                          # largura do antisserrilhado


# ------------------------------------------------------------------ cor
def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)


def viva(c):
    lum = (c * np.array([0.299, 0.587, 0.114], np.float32)).sum(-1, keepdims=True)
    sat = c.max(-1, keepdims=True) - c.min(-1, keepdims=True)
    c = lum + (c - lum) * (1.14 + 0.34 * (1.0 - sat))
    return np.clip(c * 1.08 - 0.045, 0.0, 1.0)


def tela_g4(x):
    x = np.clip(x, 0.0, 1.25)
    return viva(x * (1.2094 - x * (0.015 + 0.25 * x)))


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def ceu(tema):
    """O degradê do céu como o shader faz (y = seno da altura) + tela_g4."""
    topo, meio, hor, chao = [hexc(c) for c in CEUS[tema]]
    y = np.sin(np.radians(EL))[..., None]
    c = hor + (meio - hor) * smooth(0.0, 0.18, y)
    c = c + (topo - c) * smooth(0.18, 0.75, y)
    baixo = hor + (chao - hor) * smooth(0.0, -0.08, y)
    c = np.where(y > 0.0, c, baixo)
    return tela_g4(c).astype(np.float32)


def mistura(a, b, t):
    return a + (b - a) * t


# ------------------------------------------------------------------ formas
def cob(sd):
    """Cobertura (0..1) de uma forma pela distância com sinal (graus)."""
    return np.clip(0.5 - sd / AA, 0.0, 1.0).astype(np.float32)


def pintar(img, cor, c):
    c = c[..., None]
    img *= (1.0 - c)
    img += np.asarray(cor, np.float32) * c


def ruido1(x, semente, freqs):
    rng = np.random.RandomState(semente)
    s = np.zeros_like(x)
    tot = 0.0
    for f, a in freqs:
        s += a * np.sin(x * f + rng.uniform(0, 2 * math.pi))
        tot += a
    return s / tot


def ruido2(semente, base=(16, 6), oitavas=4, ganho=0.5):
    """Ruído suave (0..1) do tamanho da faixa: grades aleatórias ampliadas."""
    rng = np.random.RandomState(semente)
    s = np.zeros((H, W), np.float32)
    a = 1.0
    tot = 0.0
    gx, gy = base
    for _ in range(oitavas):
        g = rng.uniform(0, 1, (gy, gx)).astype(np.float32)
        im = Image.fromarray((g * 255).astype(np.uint8), "L").resize((W, H), Image.BICUBIC)
        s += a * np.asarray(im, np.float32) / 255.0
        tot += a
        a *= ganho
        gx, gy = gx * 2, gy * 2
    return s / tot


def elipse_sd(a0, e0, ra, re):
    q = np.sqrt(((AZ - a0) / ra) ** 2 + ((EL - e0) / re) ** 2)
    return (q - 1.0) * min(ra, re)


def cordilheira(img, altura, cor_topo, cor_base, borda=None, aro=None, aro_larg=0.35, contorno=None):
    """Silhueta de morro/montanha: tudo abaixo de `altura(az)` (graus), com
    degradê vertical, um aro claro no alto (luz) e contorno opcional."""
    h = altura[None, :] if altura.ndim == 1 else altura
    sd = EL - h
    c = cob(sd)
    t = np.clip((h - EL) / 8.0, 0.0, 1.0)[..., None]
    cor = mistura(np.asarray(cor_topo, np.float32), np.asarray(cor_base, np.float32), t)
    if contorno is not None:
        pintar(img, contorno, cob(sd - 0.14))
    pintar_cor(img, cor, c)
    if aro is not None:
        k = np.clip(1.0 - (h - EL) / aro_larg, 0.0, 1.0) * c
        pintar(img, aro, k * 0.55)


def pintar_cor(img, cor, c):
    c = c[..., None]
    img *= (1.0 - c)
    img += cor * c


def brilho(img, cor, k):
    img += np.asarray(cor, np.float32) * k[..., None]
    np.clip(img, 0.0, 1.0, out=img)


def nuvem(img, a0, e0, larg, alt, cor, sombra, semente):
    """Nuvem fofa de desenho: bolotas de tamanhos diferentes, base reta."""
    rng = np.random.RandomState(semente)
    sd = np.full((H, W), 1e9, np.float32)
    n = 6
    for i in range(n):
        x = a0 + (i / (n - 1) - 0.5) * larg * 0.8
        r = alt * (0.45 + 0.55 * math.sin(math.pi * (i + 0.5) / n)) * rng.uniform(0.75, 1.05)
        sd = np.minimum(sd, np.sqrt((AZ - x) ** 2 + (EL - (e0 + r * 0.55)) ** 2) - r)
    sd = np.maximum(sd, e0 - EL)          # base reta
    c = cob(sd)
    t = np.clip((EL - e0) / (alt * 1.2), 0.0, 1.0)[..., None]
    cor_v = mistura(np.asarray(sombra, np.float32), np.asarray(cor, np.float32), t)
    pintar_cor(img, cor_v, c * 0.96)


# ------------------------------------------------------------------ selva
def dinos():
    img = ceu("dinos")
    hor = hexc("#FFE4AE")
    # nuvens fofas
    for i, (a, e, l, h) in enumerate([(-58, 13, 16, 3.2), (-30, 22, 12, 2.4), (35, 17, 18, 3.4), (62, 25, 11, 2.2),
                                      (8, 30, 14, 2.6)]):
        nuvem(img, a, e, l, h, hexc("#FFFFFF"), hexc("#D9DDF2"), 70 + i)
    # cordilheira lá longe (azulada, quase sumindo na névoa)
    a = AZ1
    h1 = 7.0 + 2.6 * ruido1(a, 1, [(0.07, 1.0), (0.19, 0.5), (0.5, 0.18)])
    cordilheira(img, h1, mistura(hexc("#8DA6E0"), hor, 0.35), mistura(hexc("#A8C2EC"), hor, 0.55),
                aro=hexc("#FFFFFF"))
    # montanhas do meio (verdes, com aro de luz)
    h2 = 3.6 + 2.2 * ruido1(a, 2, [(0.11, 1.0), (0.31, 0.45), (0.9, 0.12)])
    cordilheira(img, h2, mistura(hexc("#4DB07A"), hor, 0.2), mistura(hexc("#2E8A5A"), hor, 0.3),
                aro=hexc("#E9FFB0"), contorno=mistura(hexc("#1E5E3C"), hor, 0.3))
    # mata (copas redondas) e palmeiras na frente
    copa = 1.4 + 0.9 * ruido1(a, 3, [(0.6, 1.0), (1.3, 0.6), (2.7, 0.3)])
    rng = np.random.RandomState(9)
    bolas = np.full((H, W), 1e9, np.float32)
    for x in np.arange(-ARCO, ARCO, 1.6):
        x = x + rng.uniform(-0.5, 0.5)
        r = rng.uniform(0.9, 1.7)
        y = 1.0 + rng.uniform(-0.3, 0.6)
        bolas = np.minimum(bolas, np.sqrt((AZ - x) ** 2 + (EL - y) ** 2) - r)
    bolas = np.minimum(bolas, EL - copa[None, :] * 0.6)
    pintar(img, hexc("#1F6B35"), cob(bolas - 0.12))
    pintar(img, hexc("#2F8F44"), cob(bolas))
    pintar(img, hexc("#58BE4F"), cob(bolas + 0.0) * np.clip((EL - 0.8) / 2.2, 0.0, 1.0) * 0.6)
    return img


def parque():
    img = ceu("parque")
    hor = hexc("#E4F4FF")
    a = AZ1
    for i, (x, e, l, h) in enumerate([(-64, 15, 15, 3.0), (-36, 26, 12, 2.3), (-6, 33, 13, 2.4), (30, 22, 17, 3.2),
                                      (60, 14, 14, 2.8), (48, 31, 10, 2.0)]):
        nuvem(img, x, e, l, h, hexc("#FFFFFF"), hexc("#D4E2FA"), 80 + i)
    # colinas longe (azuladas)
    h1 = 4.2 + 1.6 * ruido1(a, 21, [(0.05, 1.0), (0.13, 0.5), (0.4, 0.15)])
    cordilheira(img, h1, mistura(hexc("#7CC4A8"), hor, 0.45), mistura(hexc("#9AD6BE"), hor, 0.55), aro=hexc("#FFFFFF"))
    # colinas da frente (verde vivo) com arvorezinhas redondas
    h2 = 2.0 + 1.0 * ruido1(a, 22, [(0.13, 1.0), (0.35, 0.4)])
    cordilheira(img, h2, hexc("#6BCF5C"), hexc("#4FB04A"), aro=hexc("#E9FFC0"), contorno=hexc("#2F7F3A"))
    # a mata lá longe: copas redondas na cor das colinas, sem desenho
    # (silhueta macia, um pouco na névoa)
    rng = np.random.RandomState(23)
    bolas = np.full((H, W), 1e9, np.float32)
    for x in np.arange(-ARCO, ARCO, 1.9):
        x = x + rng.uniform(-0.6, 0.6)
        hb = float(np.interp(x, a, h2))
        r = rng.uniform(0.8, 1.4)
        bolas = np.minimum(bolas, np.sqrt((AZ - x) ** 2 + (EL - (hb + r * 0.5)) ** 2) - r)
    bolas = np.minimum(bolas, EL - h2[None, :])
    pintar(img, mistura(hexc("#3E9C4C"), hor, 0.25), cob(bolas - 0.1))
    pintar(img, mistura(hexc("#5CBF56"), hor, 0.2), cob(bolas))
    cordilheira(img, h2 - 0.6, hexc("#6BCF5C"), hexc("#4FB04A"), aro=hexc("#E9FFC0"), contorno=hexc("#2F7F3A"))
    return img


def espaco():
    img = ceu("espaco")
    # nebulosas (cores somadas, nuvens macias)
    n1 = ruido2(31, (10, 4), 5, 0.55)
    n2 = ruido2(32, (14, 5), 5, 0.55)
    alto = smooth(-2.0, 10.0, EL)
    brilho(img, hexc("#B03CFF"), smooth(0.52, 0.85, n1) * alto * 0.38)
    brilho(img, hexc("#FF4FA8"), smooth(0.6, 0.9, n1 * 0.6 + n2 * 0.4) * alto * 0.25)
    brilho(img, hexc("#2FD8FF"), smooth(0.55, 0.88, n2) * alto * 0.3)
    # estrelas
    rng = np.random.RandomState(33)
    est = np.zeros((H, W), np.float32)
    n = 2600
    xs = rng.randint(0, W, n)
    ys = rng.randint(0, H, n)
    br = rng.uniform(0.3, 1.0, n) ** 2
    est[ys, xs] = br
    im = Image.fromarray((est * 255).astype(np.uint8), "L")
    from PIL import ImageFilter
    glow = np.asarray(im.filter(ImageFilter.GaussianBlur(1.2)), np.float32) / 255.0
    est = np.maximum(est, glow * 3.0) * smooth(-1.0, 3.0, EL)
    brilho(img, hexc("#FFFFFF"), np.clip(est, 0, 1) * 0.95)
    # estrelas grandes de 4 pontas
    for k in range(14):
        x, y = rng.uniform(-72, 72), rng.uniform(6, 38)
        s = rng.uniform(0.5, 1.1)
        cruz = np.minimum(np.abs(AZ - x) * 8 + np.abs(EL - y), np.abs(EL - y) * 8 + np.abs(AZ - x))
        brilho(img, hexc("#FFF6D0"), np.exp(-cruz / (0.35 * s)) * 0.9)
        brilho(img, hexc("#9FE8FF"), np.exp(-np.sqrt((AZ - x) ** 2 + (EL - y) ** 2) / (0.6 * s)) * 0.35)
    # GALÁXIA espiral à direita
    gx, gy = 18.0, 29.0
    dx, dy = (AZ - gx) / 1.0, (EL - gy) / 0.55
    r = np.sqrt(dx * dx + dy * dy) + 1e-3
    th = np.arctan2(dy, dx)
    braco = np.cos(2.0 * (th - np.log(r) * 1.6))
    gal = np.exp(-r / 3.2) * (0.35 + 0.65 * smooth(0.2, 1.0, braco))
    brilho(img, hexc("#FFD6F5"), gal * 0.8)
    brilho(img, hexc("#FFFFFF"), np.exp(-r / 0.7) * 0.8)
    # estrela cadente
    t = np.clip((AZ + 4.0) / 10.0, 0.0, 1.0)
    linha = np.abs((EL - 33.0) - (AZ + 4.0) * -0.35)
    cauda = np.exp(-linha / 0.12) * t * (AZ < 6.0) * (AZ > -4.0)
    brilho(img, hexc("#FFFFFF"), cauda * 0.9)
    brilho(img, hexc("#FFFFFF"), np.exp(-np.sqrt((AZ - 6.0) ** 2 + (EL - 29.5) ** 2) / 0.25))
    # horizonte: chão da lua (lilás) com crateras e o brilho da atmosfera
    a = AZ1
    h1 = 2.6 + 1.0 * ruido1(a, 34, [(0.09, 1.0), (0.3, 0.4)])
    brilho(img, hexc("#4FE3FF"), np.exp(-np.abs(EL - h1[None, :]) / 0.6) * 0.45)
    cordilheira(img, h1, hexc("#8E86D8"), hexc("#5A54A8"), aro=hexc("#CFF6FF"), contorno=hexc("#2A2A6E"))
    rng = np.random.RandomState(35)
    for k in range(26):
        x = rng.uniform(-74, 74)
        hb = float(np.interp(x, a, h1))
        y = rng.uniform(-1.5, hb - 0.8)
        rx = rng.uniform(0.8, 2.2)
        sd = elipse_sd(x, y, rx, rx * 0.28)
        pintar(img, hexc("#3E3A86"), cob(sd) * (EL < hb - 0.2))
        pintar(img, hexc("#A8A2EE"), cob(elipse_sd(x, y - rx * 0.06, rx * 0.85, rx * 0.2)) * (EL < hb - 0.2) * 0.6)
    return img


def mar():
    img = ceu("mar")
    hor = hexc("#86E6DE")
    a = AZ1
    # raios de luz vindos de cima (fachos inclinados)
    rng = np.random.RandomState(41)
    for k in range(10):
        x0 = rng.uniform(-80, 80)
        larg = rng.uniform(1.2, 3.5)
        inc = rng.uniform(0.25, 0.45)
        d = np.abs((AZ - x0) - (EL_TOPO - EL) * inc) - larg * (0.6 + 0.4 * (EL_TOPO - EL) / 40.0)
        k_ = np.clip(-d / 1.5, 0, 1) * smooth(-2.0, 30.0, EL) * rng.uniform(0.12, 0.22)
        brilho(img, hexc("#E8FFF8"), k_)
    # recife lá longe (silhueta azulada)
    h1 = 5.0 + 2.0 * ruido1(a, 42, [(0.08, 1.0), (0.23, 0.5), (0.7, 0.2)])
    cordilheira(img, h1, mistura(hexc("#3D8FB8"), hor, 0.45), mistura(hexc("#5AAFC8"), hor, 0.6))
    # FLORESTA DE ALGAS (kelp) altas, balançando
    for grupo, (xa, xb, n_) in enumerate([(-70, -28, 14), (24, 70, 14), (-12, 10, 5)]):
        for j in range(n_):
            x = rng.uniform(xa, xb)
            alt = rng.uniform(9, 22) * (0.6 if grupo == 2 else 1.0)
            fase = rng.uniform(0, 6.28)
            longe = rng.uniform(0.5, 0.72)
            cor = mistura(hexc("#2E9A6A"), hor, longe)
            cor2 = mistura(hexc("#6BD08A"), hor, longe)
            t = np.clip((EL - 0.0) / alt, 0, 1)
            xc = x + 1.2 * np.sin(EL * 0.35 + fase) * t
            sd = np.abs(AZ - xc) - 0.22 * (1.0 - 0.5 * t)
            sd = np.maximum(sd, np.maximum(-EL, EL - alt))
            pintar(img, cor, cob(sd))
            # folhas
            for f in range(int(alt / 1.6)):
                yf = 1.2 + f * 1.6
                lado = 1 if f % 2 else -1
                xf = x + 1.2 * math.sin(yf * 0.35 + fase) * min(yf / alt, 1.0)
                fol = elipse_sd(xf + lado * 0.7, yf + 0.3, 0.75, 0.28)
                pintar(img, cor2 if f % 3 else cor, cob(fol))
    # bolhas subindo
    for k in range(70):
        x, y = rng.uniform(-74, 74), rng.uniform(1, 38)
        r = rng.uniform(0.12, 0.35)
        aro = np.abs(np.sqrt((AZ - x) ** 2 + (EL - y) ** 2) - r) - 0.04
        pintar(img, hexc("#E8FFFF"), cob(aro) * 0.7)
        pintar(img, hexc("#FFFFFF"), cob(np.sqrt((AZ - x + r * 0.35) ** 2 + (EL - y - r * 0.35) ** 2) - r * 0.25) * 0.8)
    # RECIFE DE CORAIS colorido na frente (cores vivas, um pouco na névoa)
    h2 = 1.8 + 0.8 * ruido1(a, 43, [(0.15, 1.0), (0.45, 0.4)])
    cordilheira(img, h2, mistura(hexc("#E9C98A"), hor, 0.3), mistura(hexc("#D9B070"), hor, 0.3), aro=hexc("#FFF6DA"))
    # pedras e corais lá longe: silhuetas macias na cor da névoa
    rng = np.random.RandomState(44)
    bolas = np.full((H, W), 1e9, np.float32)
    for x in np.arange(-ARCO, ARCO, 2.2):
        x = x + rng.uniform(-0.8, 0.8)
        hb = float(np.interp(x, a, h2))
        r = rng.uniform(0.7, 1.5)
        bolas = np.minimum(bolas, np.sqrt((AZ - x) ** 2 + ((EL - hb) * 1.3) ** 2) - r)
    pintar(img, mistura(hexc("#5C9FB4"), hor, 0.5), cob(bolas - 0.1))
    pintar(img, mistura(hexc("#78B9C4"), hor, 0.5), cob(bolas))
    cordilheira(img, h2 - 0.5, mistura(hexc("#E9C98A"), hor, 0.3), mistura(hexc("#D9B070"), hor, 0.3), aro=hexc("#FFF6DA"))
    return img


PINTORES = {"dinos": dinos, "parque": parque, "espaco": espaco, "mar": mar}


def main():
    temas = sys.argv[1:] or list(PINTORES)
    for t in temas:
        img = PINTORES[t]()
        caminho = os.path.join(RAIZ, "texturas", "fundo_%s.png" % t)
        Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB").save(caminho, optimize=True)
        print("fundo", t, caminho)


if __name__ == "__main__":
    main()
