# -*- coding: utf-8 -*-
"""
IMAGEM DE ABERTURA (a que aparece ao ligar o jogo e fica enquanto ele
carrega): TELA CHEIA com o fundo azul da marca, o símbolo da Lazer & Sport
(alvo com o dardo em cima da placa) e o selo GAMES embaixo.

    python3 -I tools/imagem_abertura.py

Grava (a partir de ui/marca/*.png):
  ui/splash.png         1080x1920  em pé (a capa do jogo, girada pela tela)
  ui/splash_giro_0.png  1920x1080  TV deitada
  ui/splash_giro_1.png  1920x1080  monitor em pé, topo na ESQUERDA do HDMI
  ui/splash_giro_m1.png 1920x1080  monitor em pé, topo na DIREITA do HDMI
O APK usa a splash_giro_<giro>.png do projeto como imagem do Android e do
Godot (tools/android/montar_apk.sh, GERAR_APK.ps1); a capa do jogo
(scripts/aquecer.gd) mostra a mesma, por cima, até o jogo estar pronto.
"""
import os

import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UI = os.path.join(AQUI, "ui")

# o fundo da marca (ui/marca/fundo.png): azul claro no meio, escuro nas bordas
CENTRO = np.array([44, 128, 222], float)
MEIO = np.array([16, 56, 120], float)
BORDA = np.array([5, 18, 44], float)


def fundo(w, h, cy):
    """Degradê radial da marca, com o claro em (w/2, cy)."""
    y, x = np.mgrid[0:h, 0:w].astype(float)
    r = np.hypot((x - w / 2) / (0.62 * min(w, h)), (y - cy) / (0.62 * min(w, h)))
    t1 = np.clip(r, 0, 1)[..., None]
    t2 = np.clip((r - 1) / 0.9, 0, 1)[..., None]
    c = CENTRO * (1 - t1) + MEIO * t1
    c = c * (1 - t2) + BORDA * t2
    return Image.fromarray(np.clip(c + 0.5, 0, 255).astype(np.uint8), "RGB")


def compor(w, h, largura_logo, altura_max):
    """A marca no meio da tela: o símbolo e o GAMES embaixo, juntos cabendo
    em largura_logo x altura_max."""
    logo = Image.open(os.path.join(UI, "marca", "lazer_sport.png")).convert("RGBA")
    games = Image.open(os.path.join(UI, "marca", "games.png")).convert("RGBA")
    lw = largura_logo
    lh = lw * logo.height / logo.width
    gw = lw * 0.5
    gh = gw * games.height / games.width
    espaco = lh * 0.05
    total = lh + espaco + gh
    if total > altura_max:
        k = altura_max / total
        lw, lh, gw, gh, espaco, total = lw * k, lh * k, gw * k, gh * k, espaco * k, altura_max
    topo = (h - total) / 2
    img = fundo(w, h, topo + lh * 0.55).convert("RGBA")
    l = logo.resize((int(round(lw)), int(round(lh))), Image.LANCZOS)
    g = games.resize((int(round(gw)), int(round(gh))), Image.LANCZOS)
    img.alpha_composite(l, (int(round((w - lw) / 2)), int(round(topo))))
    img.alpha_composite(g, (int(round((w - gw) / 2)), int(round(topo + lh + espaco))))
    return img.convert("RGB")


def main():
    em_pe = compor(1080, 1920, 1080 * 0.88, 1920 * 0.62)
    deitada = compor(1920, 1080, 1920 * 0.56, 1080 * 0.80)
    em_pe.save(os.path.join(UI, "splash.png"), optimize=True)
    deitada.save(os.path.join(UI, "splash_giro_0.png"), optimize=True)
    # monitor em pé ligado deitado: a imagem em pé girada como a tela do jogo
    em_pe.rotate(90, expand=True).save(os.path.join(UI, "splash_giro_1.png"), optimize=True)
    em_pe.rotate(-90, expand=True).save(os.path.join(UI, "splash_giro_m1.png"), optimize=True)
    print("imagens de abertura gravadas em", UI)


if __name__ == "__main__":
    main()
