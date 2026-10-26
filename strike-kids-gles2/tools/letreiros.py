# -*- coding: utf-8 -*-
"""
LETREIROS NOVOS no mesmo desenho dos letreiros do jogo (STRIKE!, EMPATE!,
FUNDO DO MAR!...): o mesmo código do tools/arte/gerar_arte.py da versão
original (degradê, contorno azul-marinho grosso, anel branco, brilho e
estrelinhas), para os avisos novos ficarem iguaizinhos aos de sempre.

    python3 -I tools/letreiros.py            # todos os daqui
    python3 -I tools/letreiros.py desempate  # só um

As imagens vão para ui/ (o Godot importa como os outros letreiros: o
.import do empate.png serve de modelo).
"""
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
UI = os.path.join(RAIZ, "ui")
FONTES = os.path.join(RAIZ, "fontes")
ESCALA_UI = 1.6   # como os outros letreiros (o HUD divide por isso)
ROXO = "#0B1F45"  # contorno azul-marinho (cor da marca)


def cor(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def fonte(nome, tam):
    return ImageFont.truetype(os.path.join(FONTES, nome), tam)


def estrela(d, cx, cy, r_ext, r_int, fill, pontas=5, giro=0.0):
    pts = []
    for i in range(pontas * 2):
        r = r_ext if i % 2 == 0 else r_int
        a = -math.pi / 2 + giro + i * math.pi / pontas
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    d.polygon(pts, fill=fill)


def gradiente_vertical(tam, cores):
    """cores: lista de (posição 0..1, '#hex')."""
    import numpy as np
    w, h = tam
    t = np.linspace(0, 1, h)
    ps = [p for p, _ in cores]
    canais = []
    for k in range(4):
        canais.append(np.interp(t, ps, [cor(c)[k] for _, c in cores]))
    col = np.stack(canais, -1).astype(np.uint8)  # (h, 4)
    arr = np.repeat(col[:, None, :], w, axis=1)
    return Image.fromarray(arr, "RGBA")


def letreiro(texto, nome, cores, contorno="#0B1F45", tam_fonte=260, fonte_nome="titan_one.ttf", inclinar=-4,
             brilho=True, estrelas=True, linhas=None, escala=None):
    """Texto de desenho animado: degradê, contorno grosso, sombra, brilho."""
    f = fonte(fonte_nome, tam_fonte * 2)
    textos = linhas or [texto]
    # mede
    tmp = Image.new("L", (10, 10))
    dt = ImageDraw.Draw(tmp)
    caixas = [dt.textbbox((0, 0), t, font=f) for t in textos]
    larg = max(b[2] - b[0] for b in caixas)
    alt_linha = max(b[3] - b[1] for b in caixas)
    esp = int(alt_linha * 0.12)
    alt = alt_linha * len(textos) + esp * (len(textos) - 1)
    m = int(tam_fonte * 0.55)
    W, H = larg + m * 2, alt + m * 2
    mascara = Image.new("L", (W, H), 0)
    dm = ImageDraw.Draw(mascara)
    y = m
    for t, b in zip(textos, caixas):
        x = m + (larg - (b[2] - b[0])) // 2 - b[0]
        dm.text((x, y - b[1]), t, font=f, fill=255)
        y += alt_linha + esp
    borda = int(tam_fonte * 0.16)
    contorno_m = mascara.filter(ImageFilter.MaxFilter(borda * 2 + 1)) if borda < 40 else mascara
    if borda >= 40:
        contorno_m = mascara
        for _ in range(borda // 12):
            contorno_m = contorno_m.filter(ImageFilter.MaxFilter(25))
    contorno_m = contorno_m.filter(ImageFilter.GaussianBlur(1.5))
    final = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    # sombra
    sombra = Image.new("RGBA", (W, H), (0, 12, 36, 0))
    sombra.putalpha(contorno_m.point(lambda v: int(v * 0.55)))
    final.alpha_composite(sombra, (0, int(tam_fonte * 0.09)))
    # contorno escuro
    c_img = Image.new("RGBA", (W, H), cor(contorno))
    c_img.putalpha(contorno_m)
    final.alpha_composite(c_img)
    # anel branco fino entre contorno e preenchimento
    anel = mascara.filter(ImageFilter.MaxFilter(max(3, (borda // 3) * 2 + 1)))
    a_img = Image.new("RGBA", (W, H), (255, 255, 255, 255))
    a_img.putalpha(anel)
    final.alpha_composite(a_img)
    # preenchimento em degradê
    g = gradiente_vertical((W, H), [(0.0, cores[0]), (0.55, cores[1]), (1.0, cores[2])])
    g.putalpha(mascara)
    final.alpha_composite(g)
    if brilho:
        # faixa de brilho na metade de cima das letras
        br = Image.new("L", (W, H), 0)
        db = ImageDraw.Draw(br)
        y = m
        for _ in textos:
            db.rectangle([0, y + alt_linha * 0.06, W, y + alt_linha * 0.36], fill=110)
            y += alt_linha + esp
        br = ImageChops.multiply(br, mascara.filter(ImageFilter.MinFilter(max(3, (borda // 4) * 2 + 1))))
        b_img = Image.new("RGBA", (W, H), (255, 255, 255, 255))
        b_img.putalpha(br.filter(ImageFilter.GaussianBlur(2)))
        final.alpha_composite(b_img)
    if estrelas:
        d = ImageDraw.Draw(final)
        rnd = random.Random(nome)
        for i in range(5):
            cx = rnd.choice([rnd.uniform(0.02, 0.18), rnd.uniform(0.82, 0.98)]) * W
            cy = rnd.uniform(0.08, 0.92) * H
            r = rnd.uniform(0.05, 0.09) * H
            estrela(d, cx, cy, r, r * 0.42, cor("#0B1F45"), giro=rnd.uniform(-0.3, 0.3))
            estrela(d, cx, cy, r * 0.78, r * 0.32, cor(rnd.choice(["#FFE14D", "#FFFFFF", "#7FE7FF", "#FF9F2E"])), giro=rnd.uniform(-0.3, 0.3))
    if inclinar:
        final = final.rotate(inclinar, resample=Image.BICUBIC, expand=True)
    bbox = final.getbbox()
    final = final.crop(bbox)
    e = (ESCALA_UI if escala is None else escala) / 2.0
    final = final.resize((int(final.width * e), int(final.height * e)), Image.LANCZOS)
    final.save(os.path.join(UI, nome + ".png"))
    print("  letreiro", nome, final.size)


# (nome, texto ou linhas, cores do degradê, tamanho da letra)
LETREIROS = [
    # DESEMPATE: 2 jogadores empatados jogam a rodada extra (6.8)
    ("desempate", "DESEMPATE!", None, ["#FFF6A8", "#FF9F2E", "#FF3B4E"], 230),
]


def principal(quais):
    for nome, texto, linhas, cores, tam in LETREIROS:
        if quais and nome not in quais:
            continue
        letreiro(texto or "", nome, cores, ROXO, tam, linhas=linhas)


if __name__ == "__main__":
    principal(sys.argv[1:])
