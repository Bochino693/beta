# -*- coding: utf-8 -*-
"""
FUNDOS PINTADOS (6.9): a paisagem distante de cada fase numa FAIXA
panorâmica que o céu desenha atrás de tudo (shaders/ceu.shader e
ceu_leve.shader): montanhas e o vulcão grande na selva, colinas com castelo,
circo e montanha-russa no parque, nebulosas, galáxia e planetas no espaço,
floresta de algas, recifes e raios de luz no fundo do mar.

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
    # VULCÃO lá longe, à direita (o de verdade, 3D, fica à esquerda do
    # gabinete): cone liso, cratera, lava descendo e fumaça
    va, vp, vb = 31.0, 12.5, 11.0            # centro, pico, meia-base
    perfil = vp * (1.0 - (np.abs(a - va) / vb) ** 1.15)
    perfil = np.minimum(perfil, vp - 0.9 + 0.0 * a)          # topo cortado (cratera)
    perfil = np.where(np.abs(a - va) < vb, perfil, -10.0)
    hv = np.maximum(perfil, -10.0)
    corpo_t = mistura(hexc("#B6553C"), hor, 0.12)
    corpo_b = mistura(hexc("#8A3A2A"), hor, 0.25)
    cordilheira(img, hv, corpo_t, corpo_b, aro=hexc("#FFD0A0"), aro_larg=0.5, contorno=hexc("#5A2418"))
    dentro = cob(EL - hv[None, :])
    # lado da sombra (direita do vulcão) mais escuro
    lado = smooth(va - 1.0, va + 6.0, AZ) * dentro
    pintar(img, mistura(hexc("#6E2A20"), hor, 0.2), lado * 0.35)
    # lava: três rios lisos que descem da boca, afinando, com brilho em volta
    for k, (dx, comp) in enumerate([(-1.2, 7.5), (0.4, 9.5), (1.7, 6.0)]):
        t = np.clip((vp - 0.9 - EL) / comp, 0.0, 1.0)
        xr = va + dx * (1.0 + 1.6 * t) + 0.35 * np.sin(t * 5.0 + k)
        larg = 0.55 * (1.0 - 0.75 * t) + 0.08
        sd = np.abs(AZ - xr) - larg
        sd = np.maximum(sd, EL - (vp - 0.7))
        sd = np.maximum(sd, (vp - 0.9 - comp) - EL)
        brilho(img, hexc("#FF7A00"), np.exp(-np.maximum(sd, 0.0) / 0.5) * dentro * 0.3)
        pintar(img, hexc("#FF6A12"), cob(sd) * dentro)
        pintar(img, hexc("#FFC93B"), cob(sd + larg * 0.45) * dentro)
    # a boca acesa e o clarão em cima
    boca = elipse_sd(va, vp - 0.9, 2.3, 0.45)
    pintar(img, hexc("#FFB238"), cob(boca))
    brilho(img, hexc("#FF8A2A"), np.exp(-np.maximum(elipse_sd(va, vp, 4.0, 2.2), 0) / 2.0) * 0.35)
    # fumaça: bolotas subindo e indo para a direita
    for k in range(9):
        t = k / 8.0
        x = va + 0.6 + t * 9.0 + 1.2 * math.sin(k * 1.7)
        y = vp + 1.5 + t * 15.0
        r = 1.6 + t * 3.0
        sd = np.sqrt((AZ - x) ** 2 + (EL - y) ** 2) - r
        sombra = np.clip((y - EL) / r * 0.5 + 0.5, 0.0, 1.0)[..., None]
        cor = mistura(hexc("#FBF8FF"), hexc("#B7AECB"), sombra * (0.55 + 0.2 * t))
        pintar_cor(img, cor, cob(sd) * (0.97 - 0.3 * t))
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
    for x in (-66, -52, -41, -33, -19, -12, 11, 17, 24, 43, 55, 69):
        palmeira(img, x + rng.uniform(-1.5, 1.5), 1.4 + rng.uniform(0, 0.6), rng.uniform(4.0, 7.5),
                 rng.uniform(-0.3, 0.3), rng.randint(1000))
    # pterossauros lá longe
    for x, y, s in [(12, 27, 1.2), (19, 30, 0.9), (-46, 24, 1.0)]:
        passaro(img, x, y, s, hexc("#7A4A6E"))
    return img


def palmeira(img, x0, y0, alt, incl, semente):
    rng = np.random.RandomState(semente)
    topo = (x0 + incl * alt, y0 + alt)
    # tronco
    t = np.clip((EL - y0) / alt, 0.0, 1.0)
    xt = x0 + incl * alt * t
    sd = np.abs(AZ - xt) - 0.28 * (1.0 - 0.35 * t)
    sd = np.maximum(sd, np.maximum(y0 - EL, EL - topo[1]))
    pintar(img, hexc("#7A4A2A"), cob(sd - 0.08))
    pintar(img, hexc("#B87A46"), cob(sd))
    # folhas: arcos caindo
    for k in range(7):
        ang = -2.6 + k * 0.85 + rng.uniform(-0.15, 0.15)
        comp = rng.uniform(2.6, 3.6)
        u = np.clip(((AZ - topo[0]) * math.cos(ang) + (EL - topo[1]) * math.sin(ang)) / comp, 0.0, 1.0)
        px = topo[0] + math.cos(ang) * comp * u
        py = topo[1] + math.sin(ang) * comp * u - 1.4 * u * u
        larg = 0.42 * np.sin(np.pi * np.clip(u, 0.02, 0.98)) + 0.05
        sd = np.sqrt((AZ - px) ** 2 + (EL - py) ** 2) - larg
        pintar(img, hexc("#1F6B35"), cob(sd - 0.1))
        pintar(img, hexc("#3FA34D"), cob(sd))
        pintar(img, hexc("#7AD15A"), cob(sd + larg * 0.55))


def passaro(img, x, y, s, cor):
    for lado in (-1, 1):
        u = np.clip((AZ - x) * lado / (1.1 * s), 0.0, 1.0)
        py = y + 0.55 * s * np.sin(np.pi * u) * (1 - u) - 0.1 * s
        sd = np.abs(EL - py) - 0.14 * s * (1 - u)
        sd = np.maximum(sd, -(AZ - x) * lado)
        sd = np.maximum(sd, (AZ - x) * lado - 1.1 * s)
        pintar(img, cor, cob(sd) * 0.8)


# ------------------------------------------------------------------ parque
def parque():
    img = ceu("parque")
    hor = hexc("#E4F4FF")
    a = AZ1
    for i, (x, e, l, h) in enumerate([(-64, 15, 15, 3.0), (-36, 26, 12, 2.3), (-6, 33, 13, 2.4), (30, 22, 17, 3.2),
                                      (60, 14, 14, 2.8), (48, 31, 10, 2.0)]):
        nuvem(img, x, e, l, h, hexc("#FFFFFF"), hexc("#D4E2FA"), 80 + i)
    # balões lá no alto
    rng = np.random.RandomState(12)
    for k in range(9):
        x, y = rng.uniform(-70, 70), rng.uniform(16, 36)
        cor = hexc(["#FF4B5C", "#FFD43B", "#4FC3F7", "#5ED16A", "#B36BFF", "#FF9F2E"][k % 6])
        r = rng.uniform(0.7, 1.1)
        fio = np.abs(AZ - x - 0.15 * np.sin((y - EL) * 1.5)) - 0.04
        fio = np.maximum(fio, np.maximum(EL - (y - r), (y - r - 2.4) - EL))
        pintar(img, hexc("#FFFFFF"), cob(fio) * 0.8)
        pintar(img, cor * 0.7, cob(elipse_sd(x, y, r, r * 1.2) - 0.1))
        pintar(img, cor, cob(elipse_sd(x, y, r, r * 1.2)))
        pintar(img, hexc("#FFFFFF"), cob(elipse_sd(x - r * 0.35, y + r * 0.4, r * 0.25, r * 0.35)) * 0.7)
    # colinas longe (azuladas)
    h1 = 4.2 + 1.6 * ruido1(a, 21, [(0.05, 1.0), (0.13, 0.5), (0.4, 0.15)])
    cordilheira(img, h1, mistura(hexc("#7CC4A8"), hor, 0.45), mistura(hexc("#9AD6BE"), hor, 0.55), aro=hexc("#FFFFFF"))
    # CASTELO de conto de fadas à esquerda
    castelo(img, 15.0, 2.5)
    # tendas de circo
    tenda(img, -24.0, 2.2, 3.4, 4.6, hexc("#FF3B50"), hexc("#FFFFFF"), hexc("#FFD43B"))
    tenda(img, 33.0, 2.0, 2.8, 3.8, hexc("#3B7BFF"), hexc("#FFFFFF"), hexc("#FF9F2E"))
    tenda(img, -66.0, 2.0, 2.6, 3.4, hexc("#9B5BFF"), hexc("#FFE873"), hexc("#FF4B5C"))
    # MONTANHA-RUSSA à direita: trilho em ondas com loop e pilares
    montanha_russa(img, -60.0, -32.0)
    # colinas da frente (verde vivo) com arvorezinhas redondas
    h2 = 2.0 + 1.0 * ruido1(a, 22, [(0.13, 1.0), (0.35, 0.4)])
    cordilheira(img, h2, hexc("#6BCF5C"), hexc("#4FB04A"), aro=hexc("#E9FFC0"), contorno=hexc("#2F7F3A"))
    rng = np.random.RandomState(23)
    for x in np.arange(-ARCO + 2, ARCO, 4.3):
        x = x + rng.uniform(-1.2, 1.2)
        hb = float(np.interp(x, a, h2))
        r = rng.uniform(0.9, 1.4)
        cor = hexc(["#3FAE4A", "#FF9F2E", "#2E8A3E", "#FF6FAE"][rng.randint(4)])
        tronco = np.maximum(np.abs(AZ - x) - 0.13, np.maximum(hb - 0.3 - EL, EL - (hb + 1.2)))
        pintar(img, hexc("#8A5A34"), cob(tronco))
        bola = np.sqrt((AZ - x) ** 2 + (EL - (hb + 1.2 + r * 0.8)) ** 2) - r
        pintar(img, cor * 0.62, cob(bola - 0.12))
        pintar(img, cor, cob(bola))
        pintar(img, np.minimum(cor * 1.25 + 0.1, 1.0), cob(np.sqrt((AZ - x + r * 0.3) ** 2 + (EL - (hb + 1.2 + r * 1.1)) ** 2) - r * 0.4) * 0.8)
    # bandeirinhas
    for xa, xb in [(-60, -46), (30, 44)]:
        for k in range(12):
            t = k / 11.0
            x = xa + (xb - xa) * t
            y = 9.0 - 1.4 * math.sin(math.pi * t)
            cor = hexc(["#FF4B5C", "#FFD43B", "#4FC3F7", "#5ED16A"][k % 4])
            sd = np.maximum(np.abs(AZ - x) - 0.35 * np.clip((EL - (y - 0.8)) / 0.8, 0, 1), np.maximum(y - 0.8 - EL, EL - y))
            pintar(img, cor, cob(sd))
    return img


def castelo(img, x0, y0):
    parede = hexc("#F7B3D6")
    sombra = hexc("#E58DBE")
    telhado = hexc("#7A4FD6")
    telhado2 = hexc("#3F7FE8")
    linha = hexc("#6A2E7A")
    def torre(x, larg, alt, cor_t, ponta):
        sd = np.maximum(np.abs(AZ - x) - larg, np.maximum(y0 - EL, EL - (y0 + alt)))
        pintar(img, linha, cob(sd - 0.1))
        pintar_cor(img, mistura(parede, sombra, smooth(x - larg, x + larg, AZ)[..., None] * 0.6), cob(sd))
        # janela
        jan = np.maximum(np.abs(AZ - x) - larg * 0.3, np.abs(EL - (y0 + alt * 0.72)) - larg * 0.45)
        pintar(img, hexc("#3A2A6E"), cob(jan))
        # telhado cônico
        base = y0 + alt
        t = np.clip((EL - base) / ponta, 0.0, 1.0)
        sdt = np.maximum(np.abs(AZ - x) - (larg + 0.35) * (1.0 - t), np.maximum(base - EL, EL - (base + ponta)))
        pintar(img, linha, cob(sdt - 0.1))
        pintar_cor(img, mistura(cor_t * 1.15, cor_t * 0.8, smooth(x - larg, x + larg, AZ)[..., None]), cob(sdt))
        # bandeira
        mastro = np.maximum(np.abs(AZ - x) - 0.05, np.maximum(base + ponta - EL, EL - (base + ponta + 1.0)))
        pintar(img, linha, cob(mastro))
        band = np.maximum(np.maximum(AZ - (x + 0.9), x - AZ), np.abs(EL - (base + ponta + 0.8)) - 0.22 * (1 - (AZ - x) / 0.9))
        pintar(img, hexc("#FFD43B"), cob(band))
    # muralha
    sd = np.maximum(np.abs(AZ - x0) - 5.5, np.maximum(y0 - EL, EL - (y0 + 3.2)))
    ameias = np.maximum(sd, -(np.abs(np.mod(AZ - x0, 1.0) - 0.5) - 0.25))
    muro = np.minimum(np.maximum(np.abs(AZ - x0) - 5.5, np.maximum(y0 - EL, EL - (y0 + 2.8))),
                      np.maximum(np.abs(AZ - x0) - 5.5, np.maximum(ameias, EL - (y0 + 3.3))))
    pintar(img, linha, cob(muro - 0.1))
    pintar(img, parede, cob(muro))
    porta = np.maximum(np.abs(AZ - x0) - 0.9, np.maximum(y0 - EL, EL - (y0 + 1.8)))
    porta = np.minimum(porta, np.sqrt((AZ - x0) ** 2 + (EL - (y0 + 1.8)) ** 2) - 0.9)
    pintar(img, hexc("#7A3A2A"), cob(porta))
    torre(x0 - 5.6, 1.0, 6.0, telhado, 3.0)
    torre(x0 + 5.6, 1.0, 6.0, telhado, 3.0)
    torre(x0 - 2.4, 1.2, 8.5, telhado2, 3.6)
    torre(x0 + 2.4, 1.2, 8.5, telhado2, 3.6)
    torre(x0, 1.6, 11.0, telhado, 4.6)


def tenda(img, x0, y0, larg, alt, cor_a, cor_b, ponta):
    t = np.clip((EL - y0) / alt, 0.0, 1.0)
    curva = larg * (1.0 - t) ** 1.25
    sd = np.maximum(np.abs(AZ - x0) - curva, np.maximum(y0 - EL, EL - (y0 + alt)))
    pintar(img, hexc("#4A1A3A"), cob(sd - 0.1))
    listra = (np.floor((AZ - x0) / np.maximum(curva, 0.05) * 3.0 + 10) % 2)[..., None]
    cor = mistura(cor_a, cor_b, listra)
    cor = cor * (1.0 - 0.25 * smooth(x0 - larg, x0 + larg, AZ))[..., None]
    pintar_cor(img, cor, cob(sd))
    # barrado de baixo
    bar = np.maximum(np.abs(AZ - x0) - larg * 1.02, np.abs(EL - (y0 + 0.25)) - 0.3)
    bar = np.maximum(bar, -(np.sqrt((np.mod(AZ - x0, 0.9) - 0.45) ** 2 + (EL - y0) ** 2) - 0.45))
    pintar(img, ponta, cob(bar))
    mastro = np.maximum(np.abs(AZ - x0) - 0.06, np.maximum(y0 + alt - EL, EL - (y0 + alt + 0.9)))
    pintar(img, hexc("#4A1A3A"), cob(mastro))
    band = np.maximum(np.maximum(AZ - (x0 + 0.8), x0 - AZ), np.abs(EL - (y0 + alt + 0.7)) - 0.2 * (1 - (AZ - x0) / 0.8))
    pintar(img, ponta, cob(band))


def montanha_russa(img, xa, xb):
    xs = np.linspace(xa, xb, 400)
    t = (xs - xa) / (xb - xa)
    ys = 3.0 + 6.0 * np.abs(np.sin(t * math.pi * 2.2)) * (1.1 - 0.5 * t) + 1.0
    # pilares
    for k in range(0, 400, 22):
        sd = np.maximum(np.abs(AZ - xs[k]) - 0.07, np.maximum(1.8 - EL, EL - ys[k]))
        pintar(img, hexc("#F2F2F7"), cob(sd))
    # o trilho: por coluna, a altura da curva
    hcurva = np.interp(AZ1, xs, ys, left=-50, right=-50)
    dent = (AZ1 >= xa) & (AZ1 <= xb)
    d = np.abs(EL - hcurva[None, :])
    d = np.where(dent[None, :], d, 1e9)
    pintar(img, hexc("#8A1A2A"), cob(d - 0.36))
    pintar(img, hexc("#FF3B50"), cob(d - 0.26))
    pintar(img, hexc("#FFFFFF"), cob(np.abs(EL - hcurva[None, :] - 0.12) - 0.05) * dent[None, :])
    # loop
    cx, cy, r = xa + (xb - xa) * 0.55, 6.5, 2.6
    anel = np.abs(np.sqrt((AZ - cx) ** 2 + (EL - cy) ** 2) - r)
    pintar(img, hexc("#8A1A2A"), cob(anel - 0.36))
    pintar(img, hexc("#FF3B50"), cob(anel - 0.26))
    # carrinhos
    for tc in (0.18, 0.21, 0.24):
        x = xa + (xb - xa) * tc
        y = float(np.interp(x, xs, ys))
        sd = elipse_sd(x, y + 0.45, 0.55, 0.38)
        pintar(img, hexc("#FFD43B"), cob(sd))


# ------------------------------------------------------------------ espaço
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
    # PLANETA GRANDE com anel à esquerda
    planeta(img, -15.0, 21.0, 5.2, hexc("#FFB07A"), hexc("#E06A4A"), hexc("#FFE0B0"), anel=True)
    # planetinhas
    planeta(img, 25.0, 14.0, 2.2, hexc("#5FE0C8"), hexc("#2A9AAE"), hexc("#D8FFF4"))
    planeta(img, -30.0, 33.0, 1.5, hexc("#B48CFF"), hexc("#6A4AD0"), hexc("#EDE0FF"))
    planeta(img, 42.0, 25.0, 1.2, hexc("#FFE16A"), hexc("#E0A030"), hexc("#FFF8D0"))
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


def planeta(img, x, y, r, cor, escura, clara, anel=False):
    sd = np.sqrt((AZ - x) ** 2 + (EL - y) ** 2) - r
    dentro = cob(sd)
    # faixas e sombreado
    faixa = 0.5 + 0.5 * np.sin((EL - y) / r * 7.0 + np.sin((AZ - x) / r * 3.0) * 0.6)
    cor_p = mistura(cor, clara, (faixa * 0.35)[..., None])
    luz = np.clip(((AZ - x) * -0.6 + (EL - y) * 0.8) / r * 0.5 + 0.5, 0, 1)
    cor_p = mistura(escura, cor_p, (0.35 + 0.65 * luz)[..., None])
    if anel:
        ra, rb, inc = r * 1.9, r * 0.5, -0.3
        u = (AZ - x) * math.cos(inc) - (EL - y) * math.sin(inc)
        v = (AZ - x) * math.sin(inc) + (EL - y) * math.cos(inc)
        q = np.sqrt((u / ra) ** 2 + (v / rb) ** 2)
        anel_m = cob((np.abs(q - 1.0) - 0.16) * rb)
        atras = (v > 0)
        pintar(img, hexc("#FFE6B8"), anel_m * atras)
    brilho(img, clara, np.exp(-np.maximum(sd, 0) / (r * 0.25)) * 0.25)
    pintar(img, escura * 0.6, cob(sd - 0.12))
    pintar_cor(img, cor_p, dentro)
    pintar(img, hexc("#FFFFFF"), cob(np.sqrt((AZ - x + r * 0.42) ** 2 + (EL - y - r * 0.42) ** 2) - r * 0.22) * 0.5)
    if anel:
        frente = (v <= 0)
        pintar(img, hexc("#C98A5A"), anel_m * frente)
        pintar(img, hexc("#FFE6B8"), cob((np.abs(q - 1.0) - 0.08) * rb) * frente)


# ------------------------------------------------------------------ mar
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
    # cardumes ao longe (peixinhos escuros)
    for cx, cy, n_ in [(-30, 24, 16), (38, 18, 12), (8, 31, 9)]:
        for j in range(n_):
            x = cx + rng.uniform(-6, 6)
            y = cy + rng.uniform(-2.5, 2.5)
            s = rng.uniform(0.35, 0.55)
            corpo = elipse_sd(x, y, s, s * 0.45)
            rabo = np.maximum(np.abs(EL - y) - ((x - s) - AZ) * 0.8, np.maximum(AZ - (x - s), (x - s * 1.6) - AZ))
            pintar(img, mistura(hexc("#1A6E9A"), hor, 0.35), cob(np.minimum(corpo, rabo)))
    # recife lá longe (silhueta azulada)
    h1 = 5.0 + 2.0 * ruido1(a, 42, [(0.08, 1.0), (0.23, 0.5), (0.7, 0.2)])
    cordilheira(img, h1, mistura(hexc("#3D8FB8"), hor, 0.45), mistura(hexc("#5AAFC8"), hor, 0.6))
    # FLORESTA DE ALGAS (kelp) altas, balançando
    for grupo, (xa, xb, n_) in enumerate([(-70, -28, 14), (24, 70, 14), (-12, 10, 5)]):
        for j in range(n_):
            x = rng.uniform(xa, xb)
            alt = rng.uniform(9, 22) * (0.6 if grupo == 2 else 1.0)
            fase = rng.uniform(0, 6.28)
            longe = rng.uniform(0.25, 0.6)
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
    rng = np.random.RandomState(44)
    cores = ["#FF6FAE", "#B36BFF", "#FF9A5A", "#FFD43B", "#4FD8FF", "#FF4B6E"]
    for x in np.arange(-ARCO, ARCO, 2.6):
        x = x + rng.uniform(-0.9, 0.9)
        hb = float(np.interp(x, a, h2))
        cor = mistura(hexc(cores[rng.randint(len(cores))]), hor, 0.28)
        tipo = rng.randint(3)
        if tipo == 0:      # coral cérebro (meia bola)
            r = rng.uniform(0.9, 1.6)
            sd = np.maximum(np.sqrt((AZ - x) ** 2 + (EL - hb) ** 2) - r, hb - 0.2 - EL)
            pintar(img, cor * 0.7, cob(sd - 0.1))
            pintar(img, cor, cob(sd))
            pintar(img, np.minimum(cor * 1.2 + 0.08, 1), cob(np.sqrt((AZ - x + r * 0.3) ** 2 + (EL - hb - r * 0.55) ** 2) - r * 0.35) * 0.7)
        elif tipo == 1:    # leque
            r = rng.uniform(1.6, 2.6)
            th = np.arctan2(AZ - x, EL - hb)
            sd = np.maximum(np.sqrt((AZ - x) ** 2 + (EL - hb) ** 2) - r, np.abs(th) - 0.9)
            pintar(img, cor * 0.7, cob(sd - 0.1))
            pintar(img, cor, cob(sd))
            raios = np.abs(np.sin(th * 7.0)) < 0.25
            pintar(img, cor * 0.75, cob(sd) * raios * 0.6)
        else:              # galhos
            for g in range(4):
                ang = -0.8 + g * 0.53 + rng.uniform(-0.15, 0.15)
                comp = rng.uniform(1.4, 2.6)
                u = np.clip(((AZ - x) * math.sin(ang) + (EL - hb) * math.cos(ang)) / comp, 0, 1)
                px = x + math.sin(ang) * comp * u
                py = hb + math.cos(ang) * comp * u
                sd = np.sqrt((AZ - px) ** 2 + (EL - py) ** 2) - 0.28 * (1.0 - 0.4 * u)
                pintar(img, cor * 0.7, cob(sd - 0.08))
                pintar(img, cor, cob(sd))
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
