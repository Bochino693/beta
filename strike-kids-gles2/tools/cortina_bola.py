# -*- coding: utf-8 -*-
"""
CORTINA DA CAÇAPA DAS BOLAS (a boca no fundo do fosso, por onde a bola
entra): um desenho de cada cenário, cortado nas 7 tiras de borracha
(scripts/mundo.gd, shaders/cortina.shader).

    python3 -I tools/cortina_bola.py

Grava texturas/cortina_bola.png (1024 x 1024): 4 faixas de 1024 x 256, uma
por cenário, na ordem de Mundo.LINHA_CORTINA (parque, espaco, mar, dinos).
A faixa cobre a boca inteira (1,5 m x 0,39 m); cada tira mostra 1/7 dela.
Desenhado 2x maior e reduzido (bordas lisas).
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

AQUI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SAIDA = os.path.join(AQUI, "texturas", "cortina_bola.png")
K = 2                  # desenha 2x e reduz
W, H = 1024 * K, 256 * K
TIRAS = 7
TIRA = W / TIRAS


def degrade(cima, baixo):
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    for y in range(H):
        t = y / (H - 1)
        d.line([(0, y), (W, y)], fill=tuple(int(cima[i] * (1 - t) + baixo[i] * t) for i in range(3)))
    return img


def estrela(d, cx, cy, r, cor, pontas=5, vale=0.45, giro=-math.pi / 2, contorno=None, larg=0):
    pts = []
    for i in range(pontas * 2):
        a = giro + math.pi * i / pontas
        rr = r if i % 2 == 0 else r * vale
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    if contorno:
        d.polygon(pts, fill=contorno)
        pts2 = []
        for i in range(pontas * 2):
            a = giro + math.pi * i / pontas
            rr = (r - larg) if i % 2 == 0 else (r - larg) * vale
            pts2.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
        d.polygon(pts2, fill=cor)
    else:
        d.polygon(pts, fill=cor)


def brilho(d, cx, cy, r, cor):
    """Estrelinha de 4 pontas (brilho)."""
    estrela(d, cx, cy, r, cor, pontas=4, vale=0.28, giro=0)


def circulo(d, cx, cy, r, cor, contorno=None, larg=0):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=cor, outline=contorno, width=larg)


def parque():
    # lona de circo: as tiras alternam vermelho e creme, babado amarelo em
    # cima, uma estrela grande no meio e confetes
    img = Image.new("RGB", (W, H), (255, 243, 226))
    d = ImageDraw.Draw(img)
    for i in range(TIRAS):
        if i % 2 == 0:
            d.rectangle([i * TIRA, 0, (i + 1) * TIRA, H], fill=(255, 75, 110))
    # babado (meias-luas amarelas com contorno laranja)
    n = 14
    for i in range(n + 1):
        cx = i * W / n
        circulo(d, cx, 34 * K, 40 * K, (255, 159, 46))
        circulo(d, cx, 30 * K, 36 * K, (255, 210, 63))
    d.rectangle([0, 0, W, 30 * K], fill=(255, 210, 63))
    random.seed(7)
    cores = [(94, 209, 106), (79, 195, 247), (180, 110, 255), (255, 159, 46), (46, 123, 255)]
    for _ in range(70):
        x = random.uniform(0, W)
        y = random.uniform(80 * K, H - 10 * K)
        if abs(x - W / 2) < 150 * K and abs(y - 150 * K) < 110 * K:
            continue
        r = random.uniform(5, 10) * K
        circulo(d, x, y, r, random.choice(cores))
    estrela(d, W / 2, 158 * K, 92 * K, (255, 210, 63), contorno=(255, 255, 255), larg=12 * K)
    circulo(d, W / 2 - 26 * K, 150 * K, 9 * K, (60, 40, 60))
    circulo(d, W / 2 + 26 * K, 150 * K, 9 * K, (60, 40, 60))
    d.arc([W / 2 - 28 * K, 150 * K, W / 2 + 28 * K, 190 * K], 20, 160, fill=(60, 40, 60), width=6 * K)
    for s in (-1, 1):
        estrela(d, W / 2 + s * 270 * K, 150 * K, 42 * K, (255, 255, 255), contorno=(255, 159, 46), larg=7 * K)
    return img


def espaco():
    img = degrade((40, 22, 110), (12, 16, 58))
    d = ImageDraw.Draw(img)
    random.seed(3)
    for _ in range(160):
        x, y = random.uniform(0, W), random.uniform(0, H)
        circulo(d, x, y, random.uniform(1.2, 3.2) * K, (255, 255, 255))
    for _ in range(14):
        brilho(d, random.uniform(0, W), random.uniform(0, H), random.uniform(10, 18) * K, (255, 245, 180))
    # planeta com anel (esquerda) e lua (direita)
    px, py, pr = 210 * K, 140 * K, 78 * K
    d.ellipse([px - pr * 1.9, py - pr * 0.42, px + pr * 1.9, py + pr * 0.42], outline=(255, 214, 120), width=10 * K)
    circulo(d, px, py, pr, (255, 140, 60))
    d.pieslice([px - pr, py - pr, px + pr, py + pr], 200, 340, fill=(255, 170, 90))
    for (dx, dy, r) in ((-25, 20, 14), (30, -10, 10), (10, 40, 8)):
        circulo(d, px + dx * K, py + dy * K, r * K, (225, 110, 50))
    d.arc([px - pr * 1.9, py - pr * 0.42, px + pr * 1.9, py + pr * 0.42], 0, 180, fill=(255, 214, 120), width=10 * K)
    circulo(d, 840 * K, 90 * K, 46 * K, (235, 235, 255))
    circulo(d, 826 * K, 80 * K, 9 * K, (200, 200, 230))
    circulo(d, 856 * K, 104 * K, 7 * K, (200, 200, 230))
    # foguetinho no meio, indo para a direita, com fogo
    cx, cy = W / 2, 150 * K
    d.polygon([(cx - 40 * K, cy - 18 * K), (cx - 92 * K, cy), (cx - 40 * K, cy + 18 * K)], fill=(255, 159, 46))
    d.polygon([(cx - 40 * K, cy - 10 * K), (cx - 70 * K, cy), (cx - 40 * K, cy + 10 * K)], fill=(255, 230, 120))
    d.rounded_rectangle([cx - 48 * K, cy - 34 * K, cx + 70 * K, cy + 34 * K], radius=30 * K, fill=(245, 245, 255))
    d.polygon([(cx + 66 * K, cy - 30 * K), (cx + 120 * K, cy), (cx + 66 * K, cy + 30 * K)], fill=(232, 56, 79))
    d.polygon([(cx - 30 * K, cy - 30 * K), (cx - 60 * K, cy - 62 * K), (cx + 4 * K, cy - 30 * K)], fill=(232, 56, 79))
    d.polygon([(cx - 30 * K, cy + 30 * K), (cx - 60 * K, cy + 62 * K), (cx + 4 * K, cy + 30 * K)], fill=(232, 56, 79))
    circulo(d, cx + 22 * K, cy, 19 * K, (79, 195, 247), contorno=(46, 80, 160), larg=5 * K)
    return img


def mar():
    img = degrade((70, 200, 230), (8, 90, 140))
    d = ImageDraw.Draw(img)
    # superfície em ondas
    pts = [(0, 0)]
    for x in range(0, W + 1, 8):
        pts.append((x, 34 * K + math.sin(x / (60.0 * K)) * 10 * K))
    pts.append((W, 0))
    d.polygon(pts, fill=(170, 240, 250))
    # algas nas pontas e areia embaixo
    d.ellipse([-80 * K, H - 40 * K, W + 80 * K, H + 60 * K], fill=(245, 214, 140))
    random.seed(5)
    for base in (40, 120, 900, 975):
        x0 = base * K
        for k in range(3):
            pts = []
            for j in range(12):
                y = H - 20 * K - j * 14 * K
                pts.append((x0 + k * 18 * K + math.sin(j * 0.8 + k) * 10 * K, y))
            d.line(pts, fill=(60, 180, 90), width=11 * K, joint="curve")
    # bolhas
    for _ in range(40):
        x, y, r = random.uniform(0, W), random.uniform(60 * K, H - 50 * K), random.uniform(5, 13) * K
        circulo(d, x, y, r, None, contorno=(220, 250, 255), larg=max(2, int(2.5 * K)))
        circulo(d, x - r * 0.35, y - r * 0.35, r * 0.25, (240, 255, 255))

    def peixe(cx, cy, s, cor, listra, vira=1):
        d.polygon([(cx - vira * 58 * s, cy), (cx - vira * 92 * s, cy - 32 * s), (cx - vira * 92 * s, cy + 32 * s)], fill=cor)
        d.ellipse([cx - 66 * s, cy - 40 * s, cx + 66 * s, cy + 40 * s], fill=cor)
        for dx in (-20, 18):
            d.rectangle([cx + vira * dx * s - 7 * s, cy - 38 * s, cx + vira * dx * s + 7 * s, cy + 38 * s], fill=listra)
        d.ellipse([cx - 66 * s, cy - 40 * s, cx + 66 * s, cy + 40 * s], outline=(60, 30, 20), width=int(4 * s))
        circulo(d, cx + vira * 40 * s, cy - 8 * s, 10 * s, (255, 255, 255))
        circulo(d, cx + vira * 43 * s, cy - 8 * s, 5 * s, (30, 20, 30))

    peixe(W / 2, 140 * K, 1.25 * K, (255, 128, 30), (255, 255, 255))
    peixe(300 * K, 170 * K, 0.7 * K, (255, 210, 63), (79, 195, 247), vira=-1)
    peixe(760 * K, 110 * K, 0.6 * K, (255, 100, 160), (255, 255, 255), vira=-1)
    return img


def dinos():
    img = degrade((70, 160, 60), (30, 95, 40))
    d = ImageDraw.Draw(img)
    random.seed(11)
    # folhagem: folhas grandes nas pontas e em cima
    def folha(cx, cy, comp, larg, ang, cor):
        pts = []
        for i in range(24):
            t = i / 23.0
            x = (t - 0.5) * comp
            y = math.sin(t * math.pi) * larg * 0.5
            pts.append((x, y))
        for i in range(23, -1, -1):
            t = i / 23.0
            pts.append(((t - 0.5) * comp, -math.sin(t * math.pi) * larg * 0.5))
        ca, sa = math.cos(ang), math.sin(ang)
        d.polygon([(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in pts], fill=cor)
        d.line([(cx - comp * 0.5 * ca, cy - comp * 0.5 * sa), (cx + comp * 0.5 * ca, cy + comp * 0.5 * sa)],
               fill=(40, 110, 40), width=4 * K)
    for _ in range(26):
        x = random.choice([random.uniform(0, 260), random.uniform(764, 1024), random.uniform(0, 1024)]) * K
        y = random.uniform(0, 70) * K if 260 * K < x < 764 * K else random.uniform(0, 256) * K
        folha(x, y, random.uniform(90, 150) * K, random.uniform(34, 52) * K, random.uniform(0, math.pi),
              random.choice([(110, 200, 70), (140, 220, 90), (90, 180, 60)]))
    # pegada de dinossauro no meio: a sola e 3 dedos compridos com unha
    cx, cy = W / 2, 178 * K
    areia, unha = (242, 210, 122), (205, 160, 80)

    def oval(x0, y0, comp, larg, ang, cor):
        ca, sa = math.cos(ang), math.sin(ang)
        pts = []
        for i in range(32):
            a = 2 * math.pi * i / 32
            x, y = math.cos(a) * comp * 0.5, math.sin(a) * larg * 0.5
            pts.append((x0 + x * ca - y * sa, y0 + x * sa + y * ca))
        d.polygon(pts, fill=cor)

    oval(cx, cy, 104 * K, 84 * K, 0.0, areia)
    for ang in (-2.05, -1.5708, -1.09):
        dx, dy = math.cos(ang), math.sin(ang)
        mx, my = cx + dx * 70 * K, cy + dy * 70 * K
        oval(mx, my, 92 * K, 36 * K, ang, areia)
        px, py = cx + dx * 128 * K, cy + dy * 128 * K
        nx, ny = -dy, dx
        d.polygon([(px - dx * 14 * K + nx * 10 * K, py - dy * 14 * K + ny * 10 * K),
                   (px + dx * 16 * K, py + dy * 16 * K),
                   (px - dx * 14 * K - nx * 10 * K, py - dy * 14 * K - ny * 10 * K)], fill=unha)
    for _ in range(30):
        x, y = random.uniform(260, 764) * K, random.uniform(90, 250) * K
        if math.hypot(x - cx, y - cy + 50 * K) < 150 * K:
            continue
        circulo(d, x, y, random.uniform(4, 9) * K, (200, 240, 120))
    return img


def main():
    linhas = [parque(), espaco(), mar(), dinos()]
    final = Image.new("RGB", (1024, 1024))
    for i, im in enumerate(linhas):
        final.paste(im.resize((1024, 256), Image.LANCZOS), (0, 256 * i))
    final.save(SAIDA, optimize=True)
    print("gravado", SAIDA)


if __name__ == "__main__":
    main()
