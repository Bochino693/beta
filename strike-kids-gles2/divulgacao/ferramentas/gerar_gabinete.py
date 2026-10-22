# -*- coding: utf-8 -*-
"""
GABINETE DO STRIKE KIDS (BOLICHE KIDS) - TEMAS DE ADESIVAGEM
============================================================

O mesmo gabinete com varios temas de adesivos, alternando as cores e as
artes do jogo, para mostrar aos clientes e mandar para a grafica:

    branco, vermelho, azul, espaco, mar, dinos, parque

    python3 gerar_gabinete.py                  # todos os temas (impressao + maquete)
    python3 gerar_gabinete.py branco vermelho  # so estes temas
    python3 gerar_gabinete.py --maquete        # so as texturas da maquete 3D (rapido)

Medidas: GABINETE (mm), logo abaixo - mude ali se o seu gabinete for
diferente e rode de novo. Cada adesivo sai no tamanho da face: PDF com
sangria de 10 mm e marcas de corte; os furos (tela, camera, som, START,
ficha, retorno das bolas, entrada da bola na torre) vao com a linha de
corte vetorial CutContour. O desenho continua por baixo dos furos (se o
furo do gabinete ficar um pouco fora do lugar, nao aparece branco).
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
import gerar_adesivos as ga  # noqa: E402  (logo, letreiros, artes e PDF)

SAIDA = os.path.join(ga.DIV, "adesivos", "gabinete")

# --------------------------------------------------------------- medidas
GABINETE = {
    "largura": 800,          # largura da pista e da torre
    "pista_comprimento": 2600,
    "pista_altura": 520,     # do chao ao topo das laterais da pista
    "piso_altura": 450,      # do chao ao piso da pista (onde a bola rola)
    "piso_largura": 700,     # piso entre as laterais
    "torre_profundidade": 600,
    "torre_altura": 2000,    # do chao ao topo da torre (sem o letreiro)
    "letreiro_altura": 380,
    "letreiro_profundidade": 300,
    "tela": (535, 950),      # janela do monitor: TV 43" em pe (area visivel ~529 x 941)
    "tela_base": 760,        # do chao a borda de baixo da janela
    "camera": (400, 1830, 40),           # (x do centro, altura do centro, diametro)
    "som": (280, 1830, 80),              # (distancia do meio, altura, diametro) - 2 furos
    "entrada_bola": (700, 650),          # (largura, altura do chao ate o topo da abertura)
    "start": (130, 330, 60),             # botao START na frente da pista (x, altura, diametro)
    "ficha": (670, 330, 60, 110),        # moedeiro (x, altura do centro, largura, altura)
    "bolas": (400, 40, 300, 160),        # retorno das bolas (x do meio, altura da base, largura, altura)
}
SANGRIA = 10.0

# ----------------------------------------------------------------- temas
# fundo: degrade de cima para baixo; raios: (cor, forca); enfeite: estrelas,
# confete, espaco, bolhas ou folhas; faixa: (cor da fita, cor do texto);
# neon: moldura da tela; rodape: faixa escura de baixo; titulo: o letreiro
# do cenario (temas de cenario); bob/mia/dupla: artes do Bob e da Mia.
TEMAS = {
    "branco": {"nome": "Branco", "fundo": [(0, "#FFFFFF"), (0.6, "#F2F7FE"), (1, "#D7E8FA")],
               "raios": ("#7CC4FF", 0.12), "enfeite": "confete", "faixa": ("#FF3B4E", "#FFFFFF"),
               "neon": "#2E6BFF", "moldura": "#0B1F45", "rodape": "#0B1F45", "titulo": None,
               "bob": "bob_acenando", "mia": "mia_festa", "dupla": "dupla_acenando"},
    "vermelho": {"nome": "Vermelho", "fundo": [(0, "#FF6066"), (0.55, "#E31B2D"), (1, "#8E0A1A")],
                 "raios": ("#FFFFFF", 0.13), "enfeite": "estrelas", "faixa": ("#FFD43B", "#0B1F45"),
                 "neon": "#FFD43B", "moldura": "#4A0610", "rodape": "#4A0610", "titulo": None,
                 "bob": "bob_jato", "mia": "mia_vitoria", "dupla": "dupla_festa"},
    "azul": {"nome": "Azul", "fundo": [(0, "#36A9EE"), (0.5, "#1866B8"), (1, "#0D2A63")],
             "raios": ("#FFFFFF", 0.11), "enfeite": "estrelas", "faixa": ("#FF3B4E", "#FFFFFF"),
             "neon": "#4FD8FF", "moldura": "#081A40", "rodape": "#081A40", "titulo": None,
             "bob": "bob_acenando", "mia": "mia_festa", "dupla": "dupla_festa"},
    "espaco": {"nome": "Espaço", "fundo": [(0, "#33228A"), (0.5, "#16205C"), (1, "#060A22")],
               "raios": ("#8FD3FF", 0.07), "enfeite": "espaco", "faixa": ("#2E6BFF", "#FFD43B"),
               "neon": "#8FD3FF", "moldura": "#05071A", "rodape": "#05071A",
               "titulo": (["VIAGEM AO", "ESPAÇO!"], ga.P_ESPACO),
               "bob": "bob_astronauta", "mia": "mia_astronauta", "dupla": "dupla_astronauta"},
    "mar": {"nome": "Fundo do Mar", "fundo": [(0, "#8EF0F7"), (0.5, "#1FA6D8"), (1, "#0A4A88")],
            "raios": ("#FFFFFF", 0.12), "enfeite": "bolhas", "faixa": ("#FF9F2E", "#FFFFFF"),
            "neon": "#5EE6E0", "moldura": "#05335E", "rodape": "#05335E",
            "titulo": (["FUNDO", "DO MAR!"], ga.P_MAR),
            "bob": "bob_pirata", "mia": "mia_pirata", "dupla": "dupla_pirata"},
    "dinos": {"nome": "Selva dos Dinos", "fundo": [(0, "#E4FF9E"), (0.5, "#6CC93A"), (1, "#1C6631")],
              "raios": ("#FFFFFF", 0.11), "enfeite": "folhas", "faixa": ("#E8742A", "#FFFFFF"),
              "neon": "#A6EC52", "moldura": "#0F3D1C", "rodape": "#0F3D1C",
              "titulo": (["SELVA DOS", "DINOS!"], ga.P_DINOS),
              "bob": "bob_dino", "mia": "mia_dino", "dupla": "dupla_dino"},
    "parque": {"nome": "Parque de Diversões", "fundo": [(0, "#FFF3A8"), (0.5, "#FFB627"), (1, "#EC5F14")],
               "raios": ("#FFFFFF", 0.17), "enfeite": "confete", "faixa": ("#FF3B4E", "#FFFFFF"),
               "neon": "#FF3B4E", "moldura": "#6E2400", "rodape": "#6E2400",
               "titulo": (["PARQUE DE", "DIVERSÕES!"], ga.P_PARQUE),
               "bob": "bob_parque", "mia": "mia_parque", "dupla": "dupla_parque"},
}
ORDEM = ["branco", "vermelho", "azul", "espaco", "mar", "dinos", "parque"]
DESCRICAO = {
    "branco": "Limpo e colorido: fundo branco com confetes nas cores do jogo. Combina com qualquer ambiente.",
    "vermelho": "Vermelho STRIKE: cheio de energia, com estrelas e o amarelo do jogo. Chama a atenção de longe.",
    "azul": "O azul do Strike Kids: céu de estrelas e raios de luz, com o Bob e a Mia.",
    "espaco": "Viagem ao Espaço: estrelas e planetas, o Bob e a Mia de astronauta.",
    "mar": "Fundo do Mar: azul-turquesa com bolhas, o Bob e a Mia de pirata.",
    "dinos": "Selva dos Dinos: o verde da selva com folhas, o Bob e a Mia de dinossaurinho.",
    "parque": "Parque de Diversões: amarelo e laranja de circo com confetes, o Bob e a Mia no parque.",
}
CORES_CONFETE = ["#FF3B4E", "#FFD43B", "#2E6BFF", "#2DBE4E", "#FF9F2E", "#B65CFF", "#4FD8FF"]


# ------------------------------------------------------------ o "papel"

class Painel:
    """Uma face do gabinete: tamanho final em mm + sangria; posições sempre
    em mm a partir do canto de cima à esquerda do tamanho FINAL."""

    def __init__(self, w_mm, h_mm, dpi, sangria=SANGRIA):
        self.w, self.h, self.dpi, self.s = float(w_mm), float(h_mm), dpi, sangria
        self.u = dpi / ga.MM
        self.W = int(round((w_mm + 2 * sangria) * self.u))
        self.H = int(round((h_mm + 2 * sangria) * self.u))
        self.cortes, self.circulos = [], []

    def x(self, mm):
        return (mm + self.s) * self.u

    def y(self, mm):
        return (mm + self.s) * self.u

    def mm(self, v):
        return v * self.u

    def furo_ret(self, x0, y0, w, h, r=0.0):
        pts = []
        if r <= 0:
            pts = [(x0, y0), (x0 + w, y0), (x0 + w, y0 + h), (x0, y0 + h)]
        else:
            for (cx, cy, a0) in ((x0 + w - r, y0 + r, -90), (x0 + w - r, y0 + h - r, 0), (x0 + r, y0 + h - r, 90),
                                 (x0 + r, y0 + r, 180)):
                for k in range(10):
                    a = math.radians(a0 + 10 * k)
                    pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
        self.cortes.append(pts)

    def furo_circ(self, cx, cy, d):
        self.circulos.append((cx, cy, d / 2.0))

    def mascara_furos(self):
        """Alfa 0 dentro dos furos (para a maquete)."""
        m = Image.new("L", (self.W, self.H), 255)
        d = ImageDraw.Draw(m)
        for poli in self.cortes:
            d.polygon([(self.x(a), self.y(b)) for a, b in poli], fill=0)
        for (cx, cy, r) in self.circulos:
            d.ellipse([self.x(cx - r), self.y(cy - r), self.x(cx + r), self.y(cy + r)], fill=0)
        return m


def decorar(img, p, tipo, caixa_mm, semente, dens=1.0):
    """Enfeites do tema espalhados numa área (mm): estrelas, confete,
    espaço (pontinhos e planetas), bolhas ou folhas."""
    x0, y0, x1, y1 = caixa_mm
    area = max(0.01, (x1 - x0) * (y1 - y0) / 1e6)  # m²
    rnd = random.Random(semente)
    lay, d = ga.nova_camada(img)
    u = p.u
    if tipo == "estrelas":
        for _ in range(int(55 * area * dens)):
            x, y, r = rnd.uniform(x0, x1), rnd.uniform(y0, y1), rnd.uniform(5, 16)
            ga.estrela(d, p.x(x), p.y(y), r * u, r * 0.42 * u, (255, 255, 255, rnd.randint(70, 140)), giro=rnd.uniform(-0.4, 0.4))
        img.alpha_composite(lay)
        d2 = ImageDraw.Draw(img)
        for _ in range(int(9 * area * dens)):
            x, y, r = rnd.uniform(x0, x1), rnd.uniform(y0, y1), rnd.uniform(12, 24)
            ga.estrela_contorno(d2, p.x(x), p.y(y), r * u, rnd.choice(["#FFE14D", "#FFFFFF", "#7FE7FF", "#FF9F2E"]),
                                giro=rnd.uniform(-0.3, 0.3))
        return
    if tipo == "confete":
        for _ in range(int(240 * area * dens)):
            x, y = rnd.uniform(x0, x1), rnd.uniform(y0, y1)
            c = ga.cor(rnd.choice(CORES_CONFETE), rnd.randint(150, 235))
            if rnd.random() < 0.3:
                r = rnd.uniform(3, 6) * u
                d.ellipse([p.x(x) - r, p.y(y) - r, p.x(x) + r, p.y(y) + r], fill=c)
            else:
                w, h, a = rnd.uniform(9, 17) * u, rnd.uniform(4, 7) * u, rnd.uniform(0, math.pi)
                cx, cy = p.x(x), p.y(y)
                pts = [(cx + dx * math.cos(a) - dy * math.sin(a), cy + dx * math.sin(a) + dy * math.cos(a))
                       for dx, dy in ((-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2))]
                d.polygon(pts, fill=c)
        img.alpha_composite(lay)
        return
    if tipo == "espaco":
        for _ in range(int(380 * area * dens)):
            x, y, r = rnd.uniform(x0, x1), rnd.uniform(y0, y1), rnd.uniform(0.8, 2.6) * u
            d.ellipse([p.x(x) - r, p.y(y) - r, p.x(x) + r, p.y(y) + r], fill=(255, 255, 255, rnd.randint(110, 235)))
        for _ in range(int(30 * area * dens)):
            x, y, r = rnd.uniform(x0, x1), rnd.uniform(y0, y1), rnd.uniform(6, 14)
            ga.estrela(d, p.x(x), p.y(y), r * u, r * 0.4 * u, (255, 255, 255, 200), giro=rnd.uniform(-0.4, 0.4))
        for _ in range(max(1, int(1.6 * area * dens))):
            x, y, r = rnd.uniform(x0, x1), rnd.uniform(y0, y1), rnd.uniform(35, 80)
            c1 = rnd.choice(["#FF9F2E", "#C9D6FF", "#FF6A8A", "#8FD3FF"])
            cx, cy, R = p.x(x), p.y(y), r * u
            if rnd.random() < 0.5:
                d.ellipse([cx - R * 1.9, cy - R * 0.5, cx + R * 1.9, cy + R * 0.5], outline=(255, 214, 120, 230), width=max(2, int(R * 0.14)))
            d.ellipse([cx - R, cy - R, cx + R, cy + R], fill=ga.cor(c1))
            d.ellipse([cx - R * 0.7, cy - R * 0.8, cx + R * 0.2, cy - R * 0.1], fill=(255, 255, 255, 90))
        img.alpha_composite(lay)
        return
    if tipo == "bolhas":
        for _ in range(int(60 * area * dens)):
            x, y, r = rnd.uniform(x0, x1), rnd.uniform(y0, y1), rnd.uniform(6, 30) * u
            cx, cy = p.x(x), p.y(y)
            d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(255, 255, 255, 185), width=max(1, int(r * 0.14)))
            d.ellipse([cx - r * 0.55, cy - r * 0.6, cx - r * 0.1, cy - r * 0.2], fill=(255, 255, 255, 170))
        img.alpha_composite(lay)
        return
    if tipo == "folhas":
        img.alpha_composite(lay)
        for _ in range(int(26 * area * dens)):
            x, y = rnd.uniform(x0, x1), rnd.uniform(y0, y1)
            fw, fh = rnd.uniform(90, 170) * u, rnd.uniform(34, 60) * u
            folha = Image.new("RGBA", (int(fw) + 2, int(fh) + 2), (0, 0, 0, 0))
            df = ImageDraw.Draw(folha)
            df.ellipse([0, 0, folha.width - 1, folha.height - 1], fill=ga.cor(rnd.choice(["#2E9E45", "#43B649", "#1F7A3A", "#7BD34F"]), 205))
            folha2 = Image.new("RGBA", folha.size, (0, 0, 0, 0))
            ImageDraw.Draw(folha2).line([folha.width * 0.08, folha.height / 2, folha.width * 0.92, folha.height / 2],
                                        fill=(255, 255, 255, 110), width=max(1, int(3 * u)))
            folha.alpha_composite(folha2)
            ga.colar(img, folha.rotate(rnd.uniform(0, 180), expand=True, resample=Image.BICUBIC), p.x(x), p.y(y))
        return
    img.alpha_composite(lay)


def fundo(p, tema, centro_mm=None, dens=1.0, semente=""):
    img = ga.degrade((p.W, p.H), tema["fundo"])
    cx, cy = centro_mm or (p.w / 2, p.h * 0.4)
    cor_r, forca = tema["raios"]
    if forca > 0:
        ga.raios(img, p.x(cx), p.y(cy), n=30, alfa=forca, rgb=ga.cor(cor_r)[:3], raio_fade=max(p.W, p.H) * 0.9)
    ga.brilho(img, p.x(cx), p.y(cy), min(p.W, p.H) * 0.55, alfa=0.28)
    decorar(img, p, tema["enfeite"], (-p.s, -p.s, p.w + p.s, p.h + p.s), semente or tema["nome"], dens)
    return img


def rodape(img, p, tema, altura_mm):
    d = ImageDraw.Draw(img)
    d.rectangle([0, p.y(p.h - altura_mm), p.W, p.H], fill=ga.cor(tema["rodape"]))
    d.rectangle([0, p.y(p.h - altura_mm), p.W, p.y(p.h - altura_mm) + max(2, 3 * p.u)], fill=ga.cor(tema["neon"]))


def titulo_tema(tema, largura_px, altura_px, semente):
    """O letreiro do cenário (temas de cenário) ou "BOLICHE INFANTIL 3D"."""
    if tema["titulo"]:
        linhas, cores = tema["titulo"]
        return ga.letreiro_largura(linhas, cores, largura_px, altura_max=altura_px, semente=semente)
    return ga.faixa("BOLICHE INFANTIL 3D", largura_px, altura_px * 0.45, cor_fita=tema["faixa"][0], cor_texto=tema["faixa"][1])


def medalhao(i, d_mm, p):
    return ga.redondo(ga.REDONDOS[i], d_mm, p.dpi, sangria_mm=0.0).img


# --------------------------------------------------------- as faces

def letreiro_frente(tema, dpi):
    G = GABINETE
    p = Painel(G["largura"], G["letreiro_altura"], dpi)
    img = fundo(p, tema, (p.w / 2, p.h * 0.5), semente="letreiro")
    lg = ga.logo(int(p.mm(p.w * 0.6)))
    if lg.height > p.mm(p.h * 0.8):
        lg = ga.redimensionar(lg, altura=p.mm(p.h * 0.8))
    ga.colar(img, lg, p.x(p.w / 2), p.y(p.h * 0.48))
    for nome, xc in ((tema["bob"], 0.115), (tema["mia"], 0.885)):
        a = ga.arte_altura(nome, int(p.mm(p.h * 0.86)))
        if a.width > p.mm(p.w * 0.25):
            a = ga.redimensionar(a, largura=p.mm(p.w * 0.25))
        ga.colar_em(img, a, p.x(p.w * xc) - a.width / 2, p.y(p.h + 6) - a.height)
    return p, img


def letreiro_lateral(tema, dpi, lado):
    G = GABINETE
    p = Painel(G["letreiro_profundidade"], G["letreiro_altura"], dpi)
    img = fundo(p, tema, (p.w / 2, p.h * 0.45), semente="letreiro_lado" + lado)
    pin = ga.pino_img(int(p.mm(p.h * 0.5)), 12 if lado == "esquerda" else -12)
    pin2 = ga.pino_img(int(p.mm(p.h * 0.42)), -16 if lado == "esquerda" else 16)
    bola = ga.bola_img(int(p.mm(p.h * 0.34)))
    ga.colar(img, pin2, p.x(p.w * 0.3), p.y(p.h * 0.42))
    ga.colar(img, pin, p.x(p.w * 0.6), p.y(p.h * 0.38))
    ga.colar(img, bola, p.x(p.w * 0.5), p.y(p.h * 0.72))
    return p, img


def letreiro_traseira(tema, dpi):
    """Atrás do letreiro (a máquina longe da parede também é vista de trás)."""
    G = GABINETE
    p = Painel(G["largura"], G["letreiro_altura"], dpi)
    img = fundo(p, tema, (p.w / 2, p.h * 0.5), semente="letreiro_tras")
    lg = ga.logo(int(p.mm(p.w * 0.56)))
    if lg.height > p.mm(p.h * 0.78):
        lg = ga.redimensionar(lg, altura=p.mm(p.h * 0.78))
    ga.colar(img, lg, p.x(p.w / 2), p.y(p.h * 0.48))
    for xc, ang in ((0.12, 12), (0.88, -12)):
        ga.colar(img, ga.pino_img(int(p.mm(p.h * 0.56)), ang), p.x(p.w * xc), p.y(p.h * 0.42))
        ga.colar(img, ga.bola_img(int(p.mm(p.h * 0.3))), p.x(p.w * (xc + (0.06 if xc < 0.5 else -0.06))), p.y(p.h * 0.74))
    return p, img


def torre_frente(tema, dpi):
    G = GABINETE
    topo = G["torre_altura"]
    p = Painel(G["largura"], topo - G["pista_altura"], dpi)
    tw, th = G["tela"]
    tx0, ty0 = (p.w - tw) / 2, topo - (G["tela_base"] + th)
    img = fundo(p, tema, (p.w / 2, ty0 + th / 2), dens=0.8, semente="torre_frente")
    # moldura da tela: painel escuro + neon
    m = 46.0
    lay, d = ga.nova_camada(img)
    d.rounded_rectangle([p.x(tx0 - m), p.y(ty0 - m), p.x(tx0 + tw + m), p.y(ty0 + th + m)], radius=int(p.mm(40)),
                        fill=ga.cor(tema["moldura"]))
    img.alpha_composite(lay)
    neon = Image.new("RGBA", (p.W, p.H), (0, 0, 0, 0))
    dn = ImageDraw.Draw(neon)
    dn.rounded_rectangle([p.x(tx0 - 20), p.y(ty0 - 20), p.x(tx0 + tw + 20), p.y(ty0 + th + 20)], radius=int(p.mm(26)),
                         outline=ga.cor(tema["neon"]), width=max(3, int(p.mm(9))))
    glow = np.asarray(neon)[..., 3].astype(np.float32) / 255.0
    import cv2
    glow = cv2.GaussianBlur(glow, (0, 0), max(1.0, p.mm(9)))
    img.alpha_composite(ga.camada((p.W, p.H), ga.cor(tema["neon"]), np.clip(glow * 1.6, 0, 1) * 0.8))
    img.alpha_composite(neon)
    dn2 = ImageDraw.Draw(img)
    dn2.rounded_rectangle([p.x(tx0 - 20) + p.mm(3.5), p.y(ty0 - 20) + p.mm(3.5), p.x(tx0 + tw + 20) - p.mm(3.5),
                           p.y(ty0 + th + 20) - p.mm(3.5)], radius=int(p.mm(23)), outline=(255, 255, 255, 230),
                          width=max(1, int(p.mm(2.5))))
    p.furo_ret(tx0, ty0, tw, th, r=8)
    # câmera (com o SORRIA!) e som
    cxm, czm, cd = G["camera"]
    cy = topo - czm
    dc = ImageDraw.Draw(img)
    rr = p.mm(cd / 2 + 14)
    dc.ellipse([p.x(cxm) - rr, p.y(cy) - rr, p.x(cxm) + rr, p.y(cy) + rr], fill=ga.cor(tema["moldura"]),
               outline=ga.cor(tema["neon"]), width=max(2, int(p.mm(5))))
    p.furo_circ(cxm, cy, cd)
    sdx, szm, sd = G["som"]
    for sx in (p.w / 2 - sdx, p.w / 2 + sdx):
        r1 = p.mm(sd / 2 + 16)
        dc.ellipse([p.x(sx) - r1, p.y(topo - szm) - r1, p.x(sx) + r1, p.y(topo - szm) + r1], fill=ga.cor(tema["moldura"]),
                   outline=ga.cor(tema["neon"]), width=max(2, int(p.mm(5))))
        p.furo_circ(sx, topo - szm, sd)
    sorria = ga.texto("SORRIA!", p.mm(26), "#FFFFFF", ga.MARINHO, 0.16, fonte_nome="titan_one.ttf")
    seta = Image.new("RGBA", (int(p.mm(40)), int(p.mm(30))), (0, 0, 0, 0))
    ImageDraw.Draw(seta).polygon([(0, seta.height * 0.5), (seta.width, 0), (seta.width * 0.75, seta.height * 0.5),
                                  (seta.width, seta.height)], fill=ga.cor("#FFD43B"), outline=ga.cor(ga.MARINHO))
    yc = cy
    ga.colar(img, seta, p.x(cxm + cd / 2 + 14 + 26), p.y(yc))
    ga.colar(img, sorria, p.x(cxm + cd / 2 + 14 + 52) + sorria.width / 2, p.y(yc))
    # pinos sobre a entrada da bola
    lb, zb = G["entrada_bola"]
    yb0 = topo - zb
    faixa_h = ty0 + th + m - 4
    n = 10
    alt_pino = min(70.0, (yb0 - faixa_h) * 0.85)
    if alt_pino > 25:
        for k in range(n):
            xk = (p.w - lb) / 2 + 30 + k * (lb - 60) / (n - 1)
            ga.colar(img, ga.pino_img(int(p.mm(alt_pino)), (k % 3 - 1) * 6), p.x(xk), p.y((faixa_h + yb0) / 2))
    p.furo_ret((p.w - lb) / 2, yb0, lb, p.h - yb0 + SANGRIA)
    return p, img


def torre_lateral(tema, dpi, lado):
    G = GABINETE
    p = Painel(G["torre_profundidade"], G["torre_altura"], dpi)
    W = p.w
    img = fundo(p, tema, (W / 2, 900), semente="torre_" + lado)
    lg = ga.logo(int(p.mm(W * 0.88)))
    ga.colar(img, lg, p.x(W / 2), p.y(40) + lg.height / 2)
    y = 40 + lg.height / p.u + 30
    t = titulo_tema(tema, int(p.mm(W * 0.86)), int(p.mm(170)), "torre" + lado)
    ga.colar(img, t, p.x(W / 2), p.y(y) + t.height / 2)
    y += t.height / p.u + 10
    nome = tema["bob"] if lado == "esquerda" else tema["mia"]
    alt = 1450 - y
    a = ga.arte_altura(nome, int(p.mm(alt)))
    if a.width > p.mm(W * 0.98):
        a = ga.redimensionar(a, largura=p.mm(W * 0.98))
    ga.colar_em(img, a, p.x(W / 2) - a.width / 2, p.y(1450) - a.height)
    f = ga.faixa("1 OU 2 JOGADORES!", p.mm(W * 0.8), p.mm(70), cor_fita=tema["faixa"][0], cor_texto=tema["faixa"][1])
    ga.colar(img, f, p.x(W / 2), p.y(1480))
    meds = (4, 5) if lado == "esquerda" else (6, 7)
    dm = min(240.0, W * 0.4)
    for k, i in enumerate(meds):
        ga.colar(img, medalhao(i, dm, p), p.x(W * (0.27 if k == 0 else 0.73)), p.y(1690))
    pl = ga.placa_lazer(int(p.mm(W * 0.5)))
    ga.colar(img, pl, p.x(W / 2), p.y(1895))
    rodape(img, p, tema, 45)
    return p, img


def torre_traseira(tema, dpi):
    G = GABINETE
    p = Painel(G["largura"], G["torre_altura"], dpi)
    W = p.w
    img = fundo(p, tema, (W / 2, 950), semente="traseira")
    lg = ga.logo(int(p.mm(W * 0.86)))
    ga.colar(img, lg, p.x(W / 2), p.y(60) + lg.height / 2)
    y = 60 + lg.height / p.u + 40
    t = titulo_tema(tema, int(p.mm(W * 0.8)), int(p.mm(190)), "traseira")
    ga.colar(img, t, p.x(W / 2), p.y(y) + t.height / 2)
    a = ga.arte_altura(tema["dupla"], int(p.mm(900)))
    if a.width > p.mm(W * 0.96):
        a = ga.redimensionar(a, largura=p.mm(W * 0.96))
    ga.colar_em(img, a, p.x(W / 2) - a.width / 2, p.y(1640) - a.height)
    tx = ga.texto("UM CENÁRIO NOVO A CADA RODADA!", p.mm(30), "#FFFFFF", ga.MARINHO, 0.16)
    if tx.width > p.mm(W * 0.92):
        tx = ga.redimensionar(tx, largura=p.mm(W * 0.92))
    ga.colar(img, tx, p.x(W / 2), p.y(1700))
    pl = ga.placa_lazer(int(p.mm(W * 0.5)))
    ga.colar(img, pl, p.x(W / 2), p.y(1860))
    rodape(img, p, tema, 45)
    return p, img


def pista_lateral(tema, dpi, lado):
    """Lateral da pista. Esquerda: a torre fica à esquerda do desenho e o
    jogador à direita; na direita, o contrário (o logo sempre do lado do jogador)."""
    G = GABINETE
    p = Painel(G["pista_comprimento"], G["pista_altura"], dpi)
    L, H = p.w, p.h

    def X(x):  # posição a partir da ponta da torre
        return x if lado == "esquerda" else L - x
    img = fundo(p, tema, (X(L - 420), H * 0.4), semente="pista_" + lado)
    a = ga.arte_altura(tema["dupla"], int(p.mm(H * 0.9)))
    ga.colar_em(img, a, p.x(X(430)) - a.width / 2, p.y(H - 22) - a.height)
    n_med = 4
    dm = min(270.0, H * 0.52)
    x_ini, x_fim = 900.0, L - 840.0
    for k in range(n_med):
        xk = x_ini + k * (x_fim - x_ini) / (n_med - 1)
        ga.colar(img, medalhao(4 + (k if lado == "esquerda" else n_med - 1 - k), dm, p), p.x(X(xk)), p.y(H * 0.44))
    tx = ga.texto("UM CENÁRIO NOVO A CADA RODADA!", p.mm(34), "#FFFFFF", ga.MARINHO, 0.16)
    ga.colar(img, tx, p.x(X((x_ini + x_fim) / 2)), p.y(H * 0.86))
    lg = ga.logo(int(p.mm(560)))
    if lg.height > p.mm(H * 0.58):
        lg = ga.redimensionar(lg, altura=p.mm(H * 0.58))
    ga.colar(img, lg, p.x(X(L - 400)), p.y(H * 0.36))
    f = ga.faixa("1 OU 2 JOGADORES!", p.mm(470), p.mm(66), cor_fita=tema["faixa"][0], cor_texto=tema["faixa"][1])
    ga.colar(img, f, p.x(X(L - 400)), p.y(H * 0.78))
    rodape(img, p, tema, 28)
    return p, img


def pista_frente(tema, dpi):
    G = GABINETE
    H = G["pista_altura"]
    p = Painel(G["largura"], H, dpi)
    img = fundo(p, tema, (p.w / 2, 60), semente="pista_frente")
    d = ImageDraw.Draw(img)
    # ROLE A BOLA!
    t = ga.letreiro_largura(["ROLE A BOLA!"], ga.P_STRIKE, int(p.mm(330)), altura_max=int(p.mm(110)), semente="role")
    ga.colar(img, t, p.x(p.w / 2), p.y(85))
    # START
    sx, sz, sd = G["start"]
    sy = H - sz
    for (r, c) in ((sd / 2 + 48, ga.MARINHO), (sd / 2 + 42, "#B3122A"), (sd / 2 + 36, "#FF3B4E")):
        d.ellipse([p.x(sx - r), p.y(sy - r), p.x(sx + r), p.y(sy + r)], fill=ga.cor(c))
    d.ellipse([p.x(sx - sd / 2 - 8), p.y(sy - sd / 2 - 8), p.x(sx + sd / 2 + 8), p.y(sy + sd / 2 + 8)], fill=ga.cor(ga.MARINHO))
    p.furo_circ(sx, sy, sd)
    lb = ga.texto("APERTE\nSTART", p.mm(24), "#FFFFFF", ga.MARINHO, 0.16, fonte_nome="titan_one.ttf")
    ga.colar(img, lb, p.x(sx), p.y(sy + sd / 2 + 48 + 8) + lb.height / 2)
    # ficha
    fx, fz, fw, fh = G["ficha"]
    fy = H - fz
    d.rounded_rectangle([p.x(fx - fw / 2 - 26), p.y(fy - fh / 2 - 26), p.x(fx + fw / 2 + 26), p.y(fy + fh / 2 + 26)],
                        radius=int(p.mm(16)), fill=ga.cor(ga.MARINHO))
    d.rounded_rectangle([p.x(fx - fw / 2 - 20), p.y(fy - fh / 2 - 20), p.x(fx + fw / 2 + 20), p.y(fy + fh / 2 + 20)],
                        radius=int(p.mm(12)), fill=ga.cor("#FFD43B"))
    p.furo_ret(fx - fw / 2, fy - fh / 2, fw, fh, r=6)
    lf = ga.texto("FICHA", p.mm(24), "#FFFFFF", ga.MARINHO, 0.16, fonte_nome="titan_one.ttf")
    ga.colar(img, lf, p.x(fx), p.y(fy + fh / 2 + 26 + 8) + lf.height / 2)
    # retorno das bolas
    bx, bz, bw, bh = G["bolas"]
    by0 = H - bz - bh
    d.rounded_rectangle([p.x(bx - bw / 2 - 18), p.y(by0 - 18), p.x(bx + bw / 2 + 18), p.y(by0 + bh + 18)],
                        radius=int(p.mm(40)), fill=ga.cor(ga.MARINHO))
    d.rounded_rectangle([p.x(bx - bw / 2 - 11), p.y(by0 - 11), p.x(bx + bw / 2 + 11), p.y(by0 + bh + 11)],
                        radius=int(p.mm(34)), fill=ga.cor(tema["neon"]))
    p.furo_ret(bx - bw / 2, by0, bw, bh, r=28)
    lbl = ga.texto("AS BOLAS VOLTAM AQUI", p.mm(22), "#FFFFFF", ga.MARINHO, 0.16)
    ga.colar(img, lbl, p.x(bx), p.y(by0 - 18 - 6) - lbl.height / 2)
    rodape(img, p, tema, 18)
    return p, img


def pista_piso(tema, dpi):
    """Piso da pista (onde a bola rola): madeira, faixa de falta, setas
    arco-íris e a trilha de estrelas até os pinos, como no jogo. Em cima do
    desenho fica a torre; embaixo, o lado do jogador."""
    G = GABINETE
    p = Painel(G["piso_largura"], G["pista_comprimento"], dpi, sangria=SANGRIA)
    W, H = p.W, p.H
    rnd = random.Random("piso")
    arr = np.zeros((H, W, 3), np.float32)
    tabua = 39.0  # mm (a largura das tábuas da pista de verdade)
    xs = (np.arange(W) / p.u - p.s)
    idx = np.floor(xs / tabua).astype(int)
    tons = {}
    for i in np.unique(idx):
        tons[i] = rnd.uniform(-14, 14)
    base = np.array(ga.cor("#E9C48A")[:3], np.float32)
    col = np.array([tons[i] for i in idx], np.float32)
    ys = np.arange(H, dtype=np.float32)
    veio = (np.sin(ys[:, None] / p.mm(23) + idx[None, :] * 1.7) * 5 + np.sin(ys[:, None] / p.mm(7.3) + idx[None, :]) * 2)
    arr[:] = base[None, None, :]
    arr += (col[None, :, None] + veio[..., None])
    junta = (np.abs((xs / tabua) - np.round(xs / tabua)) * tabua < 0.6)
    arr[:, junta, :] *= 0.82
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    d = ImageDraw.Draw(img)
    # bordas neon do tema
    for xb in (6, p.w - 6):
        d.rectangle([p.x(xb - 5), 0, p.x(xb + 5), H], fill=ga.cor(tema["neon"]))
    # faixa de falta (lado do jogador)
    yf = p.h - 330
    d.rectangle([p.x(-p.s), p.y(yf - 4), p.x(p.w + p.s), p.y(yf + 4)], fill=ga.cor("#E0262E"))
    for k in range(7):
        xk = p.w * (k + 1) / 8
        r = p.mm(7)
        d.ellipse([p.x(xk) - r, p.y(yf + 110) - r, p.x(xk) + r, p.y(yf + 110) + r], fill=ga.cor("#3A2A1A"))
    # ROLE A BOLA AQUI! (lido de quem está no começo da pista)
    t = ga.letreiro_largura(["ROLE A BOLA AQUI!"], ga.P_STRIKE, int(p.mm(p.w * 0.9)), altura_max=int(p.mm(140)), inclinar=0,
                            estrelas=False)
    ga.colar(img, t, p.x(p.w / 2), p.y(p.h - 170))
    # setas arco-íris
    cores = ["#FF3B4E", "#FF9F2E", "#FFD43B", "#2DBE4E", "#4FD8FF", "#2E6BFF", "#B65CFF"]
    ya = p.h - 1000
    for k, c in enumerate(cores):
        xk = p.w * (k + 1) / 8
        yk = ya - abs(k - 3) * 55
        s = 34
        d.polygon([(p.x(xk), p.y(yk - s * 1.6)), (p.x(xk + s), p.y(yk + s)), (p.x(xk - s), p.y(yk + s))],
                  fill=ga.cor(c), outline=ga.cor(ga.MARINHO), width=max(1, int(p.mm(3))))
    # trilha de estrelas até os pinos
    for k in range(9):
        yk = p.h - 1350 - k * 130
        r = 22 + k * 1.2
        ga.estrela_contorno(d, p.x(p.w / 2), p.y(yk), p.mm(r), tema["neon"] if k % 2 == 0 else "#FFE14D")
    return p, img


PECAS = [
    # (código, nome do arquivo, função, lados, dpi de impressão)
    ("01", "letreiro_frente", letreiro_frente, None, 150),
    ("02", "letreiro_lateral", letreiro_lateral, ("esquerda", "direita"), 150),
    ("02", "letreiro_traseira", letreiro_traseira, None, 150),
    ("03", "torre_frente", torre_frente, None, 120),
    ("04", "torre_lateral", torre_lateral, ("esquerda", "direita"), 100),
    ("05", "torre_traseira", torre_traseira, None, 100),
    ("06", "pista_lateral", pista_lateral, ("esquerda", "direita"), 100),
    ("07", "pista_frente", pista_frente, None, 150),
    ("08", "pista_piso", pista_piso, None, 100),
]
DPI_MAQUETE = 40  # 1,6 px por mm: só para a maquete 3D


def gerar_tema(chave, maquete_so=False):
    tema = TEMAS[chave]
    destino = os.path.join(SAIDA, chave)
    texturas = os.path.join(SAIDA, "_maquete", chave)
    os.makedirs(destino, exist_ok=True)
    os.makedirs(texturas, exist_ok=True)
    resumo = []
    for cod, nome, func, lados, dpi in PECAS:
        for lado in (lados or (None,)):
            arq = "%s_%s%s" % (cod, nome, "_" + lado if lado else "")
            d = DPI_MAQUETE if maquete_so else dpi
            p, img = func(tema, d, lado) if lado else func(tema, d)
            # textura da maquete (furos transparentes, sem sangria)
            corte = (int(round(p.s * p.u)), int(round(p.s * p.u)), int(round((p.s + p.w) * p.u)), int(round((p.s + p.h) * p.u)))
            tex = img.copy()
            tex.putalpha(Image.fromarray(np.minimum(np.asarray(tex)[..., 3], np.asarray(p.mascara_furos()))))
            tex = tex.crop(corte)
            if d != DPI_MAQUETE:
                tex = ga.redimensionar(tex, tex.width * DPI_MAQUETE / d, tex.height * DPI_MAQUETE / d)
            tex.save(os.path.join(texturas, arq + ".png"))
            if not maquete_so:
                tam = "%dx%dcm" % (round(p.w / 10), round(p.h / 10))
                pdf = os.path.join(destino, "%s_%s.pdf" % (arq, tam))
                ga.salvar_pdf(pdf, img, d, (p.w, p.h), p.s, cortes=p.cortes, circulos=p.circulos, marcas=True,
                              titulo="Strike Kids - gabinete tema %s - %s" % (tema["nome"], arq), qualidade=90)
                ga.previa(img, os.path.join(destino, "%s_previa.jpg" % arq), 1200 if p.W >= p.H else 700,
                          cortes_px=[[(p.x(a), p.y(b)) for a, b in poli] for poli in p.cortes],
                          circulos_px=[(p.x(cx), p.y(cy), r * p.u) for cx, cy, r in p.circulos])
                resumo.append((arq, p.w, p.h, d, os.path.getsize(pdf)))
            print("   %s %s %.0f x %.0f mm" % (chave, arq, p.w, p.h), flush=True)
    folha(chave)
    return resumo


def folha(chave):
    """Os 12 adesivos do tema numa imagem só (na mesma escala, com o nome e o
    tamanho): <tema>/folha_dos_adesivos.jpg. Usa as texturas da maquete."""
    tema = TEMAS[chave]
    tex = os.path.join(SAIDA, "_maquete", chave)
    k = 0.5 / (DPI_MAQUETE / ga.MM)       # 0,5 px por mm na folha
    f_tit = ga.fonte("titan_one.ttf", 56)
    f_rot = ga.fonte("fredoka_700.ttf", 22)
    linhas = [["01_letreiro_frente", "02_letreiro_lateral_esquerda", "02_letreiro_lateral_direita",
               "02_letreiro_traseira", "07_pista_frente"],
              ["03_torre_frente", "04_torre_lateral_esquerda", "04_torre_lateral_direita", "05_torre_traseira"],
              ["06_pista_lateral_esquerda"], ["06_pista_lateral_direita"], ["08_pista_piso"]]
    ims = {}
    for ln in linhas:
        for n in ln:
            im = Image.open(os.path.join(tex, n + ".png")).convert("RGBA")
            mm = (im.width / (DPI_MAQUETE / ga.MM), im.height / (DPI_MAQUETE / ga.MM))
            im = ga.redimensionar(im, im.width * k, im.height * k)
            if n == "08_pista_piso":
                im = im.rotate(90, expand=True)
            # nome quebrado na largura da peça (no mínimo 170 px) + o tamanho
            larg, ls = max(im.width, 170), []
            for p in n.replace("_", " ").split(" "):
                if ls and f_rot.getlength(ls[-1] + " " + p) <= larg:
                    ls[-1] += " " + p
                else:
                    ls.append(p)
            ls.append("%d x %d cm%s" % (round(mm[0] / 10), round(mm[1] / 10), " (deitado)" if n == "08_pista_piso" else ""))
            ims[n] = (im, ls, larg)
    M, gx, gy, topo, lh = 40, 34, 40, 150, 27
    W = max(sum(max(ims[n][0].width, ims[n][2]) for n in ln) + gx * (len(ln) - 1) for ln in linhas) + 2 * M
    H = topo + M
    for ln in linhas:
        H += max(len(ims[n][1]) for n in ln) * lh + 8 + max(ims[n][0].height for n in ln) + gy
    img = Image.new("RGBA", (int(W), int(H)), (38, 43, 56, 255))
    d = ImageDraw.Draw(img)
    tit = "TEMA %s - OS 12 ADESIVOS DO GABINETE" % tema["nome"].upper()
    if f_tit.getlength(tit) > W - 2 * M:
        f_tit = ga.fonte("titan_one.ttf", int(56 * (W - 2 * M) / f_tit.getlength(tit)))
    d.text((M, 62), tit, font=f_tit, fill=(255, 255, 255), anchor="lm")
    d.text((M, 118), "na mesma escala; furos em escuro. Medidas: tamanho final, sem a sangria de 10 mm.",
           font=f_rot, fill=(190, 200, 220), anchor="lm")
    y = topo + 20
    for ln in linhas:
        x = M
        rot_h = max(len(ims[n][1]) for n in ln) * lh + 8
        for n in ln:
            im, ls, larg = ims[n]
            for i, t in enumerate(ls):
                d.text((x, y + rot_h - 8 - (len(ls) - i - 1) * lh), t, font=f_rot,
                       fill=(255, 214, 80) if i < len(ls) - 1 else (255, 255, 255), anchor="ls")
            img.alpha_composite(im, (int(x), int(y + rot_h)))
            x += max(im.width, larg) + gx
        y += rot_h + max(ims[n][0].height for n in ln) + gy
    img.convert("RGB").save(os.path.join(SAIDA, chave, "folha_dos_adesivos.jpg"), quality=86)


def planta(destino):
    """Planta do gabinete (PDF vetorial, 2 folhas A3): 1) vista lateral e de
    cima (1:20) com a tabela dos adesivos; 2) vista de frente (1:10) com a
    posição de cada furo. Os números são os arquivos de cada tema."""
    from reportlab.lib.colors import Color
    from reportlab.lib.pagesizes import A3, landscape, portrait
    from reportlab.pdfgen import canvas as rl_canvas
    G = GABINETE
    L, PC, PH, PISO = G["largura"], G["pista_comprimento"], G["pista_altura"], G["piso_altura"]
    TP, TH, LH, LP = G["torre_profundidade"], G["torre_altura"], G["letreiro_altura"], G["letreiro_profundidade"]
    tw, th = G["tela"]
    PT = ga.PT
    azul = Color(0.07, 0.16, 0.36)
    cinza = Color(0.42, 0.47, 0.56)
    branco = Color(1, 1, 1)
    cores = {"letreiro": Color(1, 0.86, 0.35), "torre": Color(0.62, 0.8, 1), "pista": Color(0.66, 0.9, 1),
             "piso": Color(0.95, 0.85, 0.65), "furo": Color(0.12, 0.14, 0.2)}
    c = rl_canvas.Canvas(destino, pagesize=landscape(A3))
    c.setTitle("Strike Kids - planta do gabinete")
    c.setAuthor("Lazer & Sport")
    est = {"esc": 1 / 20.0, "x0": 0.0, "y0": 0.0}

    def vista(x0, y0, esc):
        est.update(x0=x0, y0=y0, esc=esc)

    def P(x, y):
        return (est["x0"] + x * est["esc"]) * PT, (est["y0"] + y * est["esc"]) * PT

    def texto_centro(a, b, linhas, tam, cor=azul, negrito=True):
        c.setFillColor(cor)
        c.setFont("Helvetica-Bold" if negrito else "Helvetica", tam)
        ls = linhas.split("\n")
        for k, linha in enumerate(ls):
            c.drawCentredString(a, b + ((len(ls) - 1) / 2.0 - k) * tam * 1.2 - tam * 0.35, linha)

    def ret(x, y, w, h, cor_f=None, rotulo=None, tam=7, cor_txt=azul):
        c.setStrokeColor(azul)
        c.setLineWidth(0.8)
        a, b = P(x, y)
        if cor_f is not None:
            c.setFillColor(cor_f)
        c.rect(a, b, w * est["esc"] * PT, h * est["esc"] * PT, stroke=1, fill=1 if cor_f is not None else 0)
        if rotulo:
            texto_centro(a + w * est["esc"] * PT / 2, b + h * est["esc"] * PT / 2, rotulo, tam, cor_txt)

    def circ(x, y, d):
        c.setFillColor(cores["furo"])
        a, b = P(x, y)
        c.circle(a, b, d / 2 * est["esc"] * PT, stroke=0, fill=1)

    def cota(xa, ya, xb, yb, texto, desloc=8.0, vertical=False):
        c.setStrokeColor(cinza)
        c.setFillColor(cinza)
        c.setLineWidth(0.45)
        a1, b1 = P(xa, ya)
        a2, b2 = P(xb, yb)
        d = desloc * PT
        c.setFont("Helvetica", 7)
        if vertical:
            c.line(a1 + d, b1, a2 + d, b2)
            for (a, b) in ((a1, b1), (a2, b2)):
                c.line(a + d - 2, b, a + d + 2, b)
                c.line(a + 1, b, a + d + 3, b)
            c.saveState()
            c.translate(a1 + d - 2.8, (b1 + b2) / 2)
            c.rotate(90)
            c.drawCentredString(0, 0, texto)
            c.restoreState()
        else:
            c.line(a1, b1 - d, a2, b2 - d)
            for (a, b) in ((a1, b1), (a2, b2)):
                c.line(a, b - d - 2, a, b - d + 2)
                c.line(a, b - 1, a, b - d - 3)
            c.drawCentredString((a1 + a2) / 2, b1 - d - 8, texto)

    def titulo(pw, ph, subtitulo):
        c.setFillColor(azul)
        c.setFont("Helvetica-Bold", 15)
        c.drawString(15 * PT, ph - 14 * PT, "STRIKE KIDS (BOLICHE KIDS) - GABINETE PROPOSTO")
        c.setFont("Helvetica", 8.5)
        c.drawString(15 * PT, ph - 20 * PT, subtitulo)

    # ================= folha 1: lateral + de cima + tabela
    pw, ph = landscape(A3)
    titulo(pw, ph, "Medidas em mm. Os números são os arquivos de cada tema (adesivos/gabinete/<tema>). Outra medida: "
           "mude GABINETE em ferramentas/gerar_gabinete.py e gere de novo.")
    vista(28.0, 140.0, 1 / 20.0)
    a, b = P(0, TH + LH)
    c.setFillColor(azul)
    c.setFont("Helvetica-Bold", 10)
    c.drawString(28 * PT, b + 6 * PT, "VISTA LATERAL (lado esquerdo) - 1:20")
    ret(0, 0, PC, PH, cores["pista"], "06 pista_lateral_esquerda (e 06 direita, do outro lado)\n%d x %d" % (PC, PH))
    ret(PC, 0, TP, TH, cores["torre"], "04\ntorre_lateral\nesq. e dir.\n%d x %d" % (TP, TH))
    ret(PC, TH, LP, LH, cores["letreiro"], "02\n%dx%d" % (LP, LH), tam=6)
    c.setStrokeColor(cinza)
    c.setDash(2, 2)
    a, b = P(0, PISO)
    a2, b2 = P(PC, PISO)
    c.line(a, b, a2, b2)
    c.setDash()
    c.setFont("Helvetica", 6.5)
    c.setFillColor(cinza)
    c.drawString(a + 3, b + 2.5, "piso da pista (a %d do chão)" % PISO)
    a, b = P(0, PH * 0.5)
    texto_centro(a - 9 * PT, b, "FRENTE\n(jogador)", 6.5, cinza)
    cota(0, 0, PC, 0, "%d (pista)" % PC)
    cota(PC, 0, PC + TP, 0, "%d" % TP)
    cota(0, 0, PC + TP, 0, "%d (total)" % (PC + TP), desloc=18)
    cota(PC + TP, 0, PC + TP, PH, "%d" % PH, desloc=6, vertical=True)
    cota(PC + TP, 0, PC + TP, TH, "%d" % TH, desloc=14, vertical=True)
    cota(PC + TP, 0, PC + TP, TH + LH, "%d (total)" % (TH + LH), desloc=22, vertical=True)
    vista(28.0, 55.0, 1 / 20.0)
    a, b = P(0, L)
    c.setFillColor(azul)
    c.setFont("Helvetica-Bold", 10)
    c.drawString(28 * PT, b + 5 * PT, "VISTA DE CIMA - 1:20")
    ret(0, 0, PC, L, cores["pista"])
    ret(0, (L - G["piso_largura"]) / 2, PC, G["piso_largura"], cores["piso"], "08 pista_piso  %d x %d" % (G["piso_largura"], PC))
    ret(PC, 0, TP, L, cores["torre"])
    ret(PC, 0, LP, L, None)
    a, b = P(PC + LP + (TP - LP) / 2, L / 2)
    texto_centro(a, b, "torre", 7)
    a, b = P(PC + LP / 2, L - 60)
    texto_centro(a, b, "letreiro", 6, cinza, False)
    cota(0, 0, PC + TP, 0, "%d" % (PC + TP))
    cota(PC + TP, 0, PC + TP, L, "%d" % L, desloc=6, vertical=True)
    # tabela
    linhas = [("01", "letreiro_frente", "%d x %d" % (L, LH), "1", "lona/vinil translúcido (luminoso)"),
              ("02", "letreiro_lateral esq. e dir.", "%d x %d" % (LP, LH), "2", "vinil branco + laminação"),
              ("02", "letreiro_traseira", "%d x %d" % (L, LH), "1", "vinil branco (opcional)"),
              ("03", "torre_frente (furos: tela, câmera, som, bola)", "%d x %d" % (L, TH - PH), "1", "vinil branco + laminação"),
              ("04", "torre_lateral esq. e dir.", "%d x %d" % (TP, TH), "2", "vinil branco + laminação"),
              ("05", "torre_traseira", "%d x %d" % (L, TH), "1", "vinil branco (opcional)"),
              ("06", "pista_lateral esq. e dir.", "%d x %d" % (PC, PH), "2", "vinil branco + laminação"),
              ("07", "pista_frente (furos: START, ficha, bolas)", "%d x %d" % (L, PH), "1", "vinil branco + laminação"),
              ("08", "pista_piso (opcional)", "%d x %d" % (G["piso_largura"], PC), "1", "vinil de piso + laminação")]
    tx0, ty0 = 250.0, 250.0
    c.setFont("Helvetica-Bold", 10)
    c.setFillColor(azul)
    c.drawString(tx0 * PT, (ty0 + 7) * PT, "ADESIVOS DE CADA TEMA (sangria de 10 mm)")
    cols = (0, 9, 78, 103, 112)
    c.setFont("Helvetica-Bold", 7.5)
    for k, cab in enumerate(("nº", "peça", "mm", "qtd", "material sugerido")):
        c.drawString((tx0 + cols[k]) * PT, ty0 * PT, cab)
    c.setFont("Helvetica", 7.5)
    for i, lin in enumerate(linhas):
        yy = (ty0 - 6 * (i + 1)) * PT
        for k, v in enumerate(lin):
            c.drawString((tx0 + cols[k]) * PT, yy, v)
    notas = ["TEMAS (o mesmo gabinete e as mesmas medidas): Branco, Vermelho, Azul, Espaço, Fundo do Mar, Selva dos Dinos e",
             "Parque de Diversões. Cada tema tem os 12 arquivos (01 a 08, com esquerda e direita) e as fotos da máquina montada.",
             "",
             "FUROS: o PDF traz a linha de corte vetorial (CutContour). Se o furo já estiver feito no gabinete, aplique o",
             "vinil por cima e recorte com estilete pela borda do furo. O desenho continua por baixo dos furos.",
             "",
             "TELA: TV 43\" em pé (o jogo gira a imagem). Câmera da foto acima da tela, 2 alto-falantes, 5 sensores na",
             "entrada da bola, retorno das bolas na frente da pista, START e moedeiro (modo ficha) na frente da pista.",
             "",
             "Medidas de referência para fabricar a estrutura: a planta 2 (vista de frente, 1:10) dá a posição de cada furo."]
    c.setFont("Helvetica", 7.5)
    c.setFillColor(azul)
    for i, n in enumerate(notas):
        c.drawString(tx0 * PT, (ty0 - 64 - 4.6 * i) * PT, n)
    c.showPage()
    # ================= folha 2: vista de frente com os furos
    pw, ph = portrait(A3)
    c.setPageSize((pw, ph))
    titulo(pw, ph, "Vista de frente (de quem joga) - 1:10 - posição dos furos, medidas em mm a partir do chão e da borda esquerda.")
    vista(80.0, 112.0, 1 / 10.0)
    ret(0, PH, L, TH - PH, cores["torre"])
    ret(0, TH, L, LH, cores["letreiro"], "01 letreiro_frente  %d x %d (luminoso)" % (L, LH), tam=8)
    ret((L - tw) / 2, G["tela_base"], tw, th, cores["furo"], "TELA (TV 43\" em pé)\njanela %d x %d" % (tw, th), tam=8, cor_txt=branco)
    cx_, cz_, cd_ = G["camera"]
    circ(cx_, cz_, cd_)
    sdx, sz, sd = G["som"]
    for sx in (L / 2 - sdx, L / 2 + sdx):
        circ(sx, sz, sd)
    lb, zb = G["entrada_bola"]
    ret((L - lb) / 2, PH, lb, zb - PH, cores["furo"], "entrada da bola %d x %d" % (lb, zb - PH), tam=7, cor_txt=branco)
    a, b = P(L / 2, (G["tela_base"] + th + TH) / 2 + 60)
    texto_centro(a, b, "03 torre_frente  %d x %d" % (L, TH - PH), 8)
    ret(0, 0, L, PH, cores["pista"])
    sx_, sz_, sd_ = G["start"]
    circ(sx_, sz_, sd_)
    fx_, fz_, fw_, fh_ = G["ficha"]
    ret(fx_ - fw_ / 2, fz_ - fh_ / 2, fw_, fh_, cores["furo"])
    bx_, bz_, bw_, bh_ = G["bolas"]
    ret(bx_ - bw_ / 2, bz_, bw_, bh_, cores["furo"], "retorno das bolas\n%d x %d" % (bw_, bh_), tam=7, cor_txt=branco)
    a, b = P(L / 2, PH - 60)
    texto_centro(a, b, "07 pista_frente  %d x %d" % (L, PH), 8)
    for (x, y, t) in ((sx_, sz_ - 60, "START Ø%d" % sd_), (fx_, fz_ - 82, "moedeiro %d x %d" % (fw_, fh_)),
                      (cx_, cz_ - 42, "câmera Ø%d" % cd_), (L / 2 - sdx, sz - 62, "som Ø%d" % sd),
                      (L / 2 + sdx, sz - 62, "som Ø%d" % sd)):
        a, b = P(x, y)
        texto_centro(a, b, t, 6.5, azul, False)
    # cotas (horizontais embaixo, verticais à direita)
    cota(0, 0, L, 0, "%d" % L, desloc=10)
    cota(0, 0, sx_, 0, "%d" % sx_, desloc=20)
    cota(0, 0, fx_, 0, "%d" % fx_, desloc=30)
    cota(0, 0, (L - tw) / 2, 0, "%d" % ((L - tw) / 2), desloc=40)
    cota(0, 0, L / 2 - sdx, 0, "%d" % (L / 2 - sdx), desloc=50)
    cota(L, 0, L, G["tela_base"], "%d (base da tela)" % G["tela_base"], desloc=8, vertical=True)
    cota(L, 0, L, G["tela_base"] + th, "%d (topo da tela)" % (G["tela_base"] + th), desloc=18, vertical=True)
    cota(L, 0, L, cz_, "%d (câmera e som)" % cz_, desloc=28, vertical=True)
    cota(L, 0, L, TH, "%d" % TH, desloc=38, vertical=True)
    cota(L, 0, L, TH + LH, "%d" % (TH + LH), desloc=48, vertical=True)
    cota(L, 0, L, sz_, "%d (START e moedeiro)" % sz_, desloc=58, vertical=True)
    cota(L, 0, L, PH, "%d" % PH, desloc=68, vertical=True)
    c.showPage()
    c.save()


def vinheta(im, forca=0.2):
    """Escurece de leve os cantos da foto (o estúdio fica com profundidade)."""
    a = np.asarray(im.convert("RGB")).astype(np.float32)
    h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = ((xx - w / 2) / (w / 2)) ** 2 + ((yy - h * 0.45) / (h / 2)) ** 2
    f = 1.0 - forca * np.clip(d / 2.0, 0, 1) ** 1.2
    return Image.fromarray(np.clip(a * f[..., None], 0, 255).astype(np.uint8))


def enquadrar(im, margem=0.05, limiar=60):
    """Corta a foto em volta das máquinas (o que difere da cor do fundo do
    estúdio, no canto de cima à esquerda), com uma margem."""
    a = np.asarray(im.convert("RGB")).astype(np.int16)
    m = np.abs(a - a[4, 4]).max(axis=2) > limiar
    ys, xs = np.nonzero(m)
    if len(xs) == 0:
        return im
    mx, my = margem * im.width, margem * im.height
    return im.crop((int(max(0, xs.min() - mx)), int(max(0, ys.min() - my)),
                    int(min(im.width, xs.max() + mx)), int(min(im.height, ys.max() + my))))


def catalogo(pasta_fotos, destino):
    """Catálogo para os clientes (A4 deitado): 1) capa com as 7 máquinas lado
    a lado; 2) a fila em perspectiva; 3 a 9) uma página por tema (3D, de
    frente, de lado e de trás). pasta_fotos/<tema>/*.png e pasta_fotos/fila/
    vêm da maquete (ferramentas/godot4/gabinete_render.tscn). Grava
    destino/catalogo_temas.pdf, cada página em JPG (destino/catalogo/, para
    mandar pelo WhatsApp) e as fotos 3D em JPG (destino/fotos/)."""
    import io
    import json
    from PIL import ImageFilter
    from reportlab.lib.utils import ImageReader
    from reportlab.pdfgen import canvas as rl_canvas
    W, H = 2480, 1754                     # A4 deitado a 300 DPI
    PT = ga.PT
    MAR = ga.cor(ga.MARINHO)
    f_tit = ga.fonte("titan_one.ttf", 92)
    f_sub = ga.fonte("fredoka_700.ttf", 44)
    f_txt = ga.fonte("fredoka_600.ttf", 36)
    f_nome = ga.fonte("fredoka_700.ttf", 38)
    f_rot = ga.fonte("fredoka_700.ttf", 30)
    pasta_pag = os.path.join(destino, "catalogo")
    pasta_jpg = os.path.join(destino, "fotos")
    os.makedirs(pasta_pag, exist_ok=True)
    os.makedirs(pasta_jpg, exist_ok=True)
    fotos = {}

    def foto(*partes):
        c = os.path.join(pasta_fotos, *partes)
        if c not in fotos:
            fotos[c] = vinheta(Image.open(c)) if os.path.exists(c) else None
            if fotos[c] is not None:
                im = fotos[c]
                if max(im.size) > 1800:
                    im = im.resize((round(im.width * 1800 / max(im.size)), round(im.height * 1800 / max(im.size))),
                                   Image.LANCZOS)
                im.save(os.path.join(pasta_jpg, "_".join(partes).replace(".png", ".jpg").replace("fila_fila", "fila")),
                        quality=88)
        return fotos[c]

    def cartao(im, w, rotulo=None):
        im = ga.redimensionar(im.convert("RGBA"), largura=w)
        raio = int(min(im.size) * 0.035)
        m = Image.new("L", im.size, 0)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, im.width - 1, im.height - 1], radius=raio, fill=255)
        im.putalpha(m)
        if rotulo:
            d = ImageDraw.Draw(im)
            d.text((raio + 6, raio), rotulo, font=f_rot, fill=(255, 255, 255), anchor="lt", stroke_width=4,
                   stroke_fill=MAR)
        sombra = Image.new("RGBA", (im.width + 40, im.height + 40), (0, 0, 0, 0))
        ImageDraw.Draw(sombra).rounded_rectangle([20, 26, im.width + 20, im.height + 26], radius=raio,
                                                 fill=(0, 10, 30, 110))
        sombra = sombra.filter(ImageFilter.GaussianBlur(12))
        sombra.alpha_composite(im, (20, 20))
        return sombra

    def pos(ct, x, y):
        """Canto de cima à esquerda da FOTO (a sombra sobra 20 px em volta)."""
        return x - 20, y - 20

    def escrever(d, xy, t, f, ancora="mm", larg=5):
        d.text(xy, t, font=f, fill=(255, 255, 255), anchor=ancora, stroke_width=larg, stroke_fill=MAR,
               align="center")

    def fundo_azul():
        img = ga.degrade((W, H), [(0, "#0E2C66"), (0.6, "#1866B8"), (1, "#2A9BE0")])
        ga.raios(img, W / 2, H * 0.3, n=30, alfa=0.06)
        ga.estrelinhas(img, 60, (0, 0, W, H), 6, 14, "catalogo", alfa=70)
        return img

    paginas = []
    posicoes = {}
    c = os.path.join(pasta_fotos, "fila", "fila.json")
    if os.path.exists(c):
        with open(c, encoding="utf-8") as arq:
            posicoes = json.load(arq)
    # ---- 1) capa: as 7 máquinas lado a lado, com o nome de cada tema embaixo
    img = fundo_azul()
    ga.colar(img, ga.logo(760), W / 2, 205)
    ga.colar(img, ga.placa_lazer(380), W - 250, 110)
    d = ImageDraw.Draw(img)
    escrever(d, (W / 2, 430), "ESCOLHA O TEMA DA SUA MÁQUINA", f_tit, larg=8)
    escrever(d, (W / 2, 520), "O mesmo gabinete de boliche infantil em 7 temas, com as cores e as artes do jogo",
             f_sub, larg=4)
    f = foto("fila", "fila.png")
    if f is not None and posicoes.get("fila"):
        # só a faixa das máquinas (o chão de cima e de baixo sobra)
        y_a = max(0, min(p["topo"][1] for p in posicoes["fila"]) - 0.07 * f.height)
        y_b = min(f.height, max(p["pe"][1] for p in posicoes["fila"]) + 0.07 * f.height)
        f = f.crop((0, int(y_a), f.width, int(y_b)))
    if f is not None:
        cw = 2360
        ct = cartao(f, cw)
        x0, y0 = 60, 580
        ga.colar_em(img, ct, *pos(ct, x0, y0))
        esc = cw / f.width
        d = ImageDraw.Draw(img)
        for k, t in enumerate(ORDEM):
            if k >= len(posicoes.get("fila", [])):
                break
            px = x0 + posicoes["fila"][k]["pe"][0] * esc
            nome = TEMAS[t]["nome"].upper()
            if " " in nome and len(nome) > 9:
                a = nome.rfind(" ", 0, len(nome) // 2 + 4)
                nome = nome[:a] + "\n" + nome[a + 1:]
            escrever(d, (px, y0 + f.height * esc + 34), "%d\n%s" % (k + 1, nome), f_nome, ancora="ma", larg=5)
    paginas.append(("capa", img))
    # ---- 2) a fila em perspectiva
    f = foto("fila", "fila_lado.png")
    if f is not None:
        img = fundo_azul()
        d = ImageDraw.Draw(img)
        escrever(d, (W / 2, 115), "O MESMO GABINETE, 7 TEMAS", f_tit, larg=8)
        escrever(d, (W / 2, 205), "O tema da máquina muda só com os adesivos: escolha um ou monte a fila com todos!",
                 f_sub, larg=4)
        f = enquadrar(f)
        cw = min(2280, 1290 * f.width / f.height)
        ct = cartao(f, cw)
        ga.colar_em(img, ct, *pos(ct, (W - cw) / 2, 275))
        G = GABINETE
        escrever(d, (W / 2, 275 + f.height * cw / f.width + 80),
                 "Gabinete: %s m de comprimento, %s m de largura e %s m de altura  -  TV 43\" em pé, câmera para a "
                 "foto, START e moedeiro" % (("%.2f" % ((G["pista_comprimento"] + G["torre_profundidade"]) / 1000)).replace(".", ","),
                                            ("%.2f" % (G["largura"] / 1000)).replace(".", ","),
                                            ("%.2f" % ((G["torre_altura"] + G["letreiro_altura"]) / 1000)).replace(".", ",")),
                 f_txt, larg=4)
        paginas.append(("fila", img))
    # ---- 3 a 9) uma página por tema
    for i, t in enumerate(ORDEM):
        tema = TEMAS[t]
        img = ga.degrade((W, H), tema["fundo"])
        ga.raios(img, W * 0.35, H * 0.45, n=30, alfa=tema["raios"][1] * 0.8, rgb=ga.cor(tema["raios"][0])[:3])
        lg = ga.logo(400)
        ga.colar(img, lg, W - 270, 30 + lg.height / 2)
        x0, y0 = 60, 270
        f1 = foto(t, "frente_esquerda.png")
        if f1 is not None:
            ct = cartao(f1, 1410)
            ga.colar_em(img, ct, *pos(ct, x0, y0))
            yb = y0 + f1.height * 1410 / f1.width + 30
            for k, (v, rot) in enumerate((("lateral.png", "DE LADO"), ("tras_direita.png", "DE TRÁS"))):
                fv = foto(t, v)
                if fv is not None:
                    ct = cartao(fv, 675, rot)
                    ga.colar_em(img, ct, *pos(ct, x0 + k * 735, yb))
        ff = foto(t, "frente.png")
        if ff is not None:
            ct = cartao(ff, 820, "DE FRENTE")
            ga.colar_em(img, ct, *pos(ct, 1570, y0))
        d = ImageDraw.Draw(img)
        escrever(d, (75, 105), "TEMA %d: %s" % (i + 1, tema["nome"].upper()), f_tit, ancora="lm", larg=8)
        escrever(d, (78, 200), DESCRICAO[t], f_txt, ancora="lm", larg=4)
        escrever(d, (1980, 1630), "12 adesivos prontos para a gráfica:\nletreiro, torre, laterais e frente\nda pista e o piso",
                 f_txt, ancora="mm", larg=4)
        paginas.append((t, img))
    c = rl_canvas.Canvas(os.path.join(destino, "catalogo_temas.pdf"), pagesize=(297 * PT, 210 * PT))
    c.setTitle("Strike Kids - temas do gabinete")
    c.setAuthor("Lazer & Sport")
    for k, (nome, pg) in enumerate(paginas):
        pg = pg.convert("RGB")
        pg.resize((1754, 1240), Image.LANCZOS).save(os.path.join(pasta_pag, "%02d_%s.jpg" % (k + 1, nome)), quality=88)
        buf = io.BytesIO()
        pg.save(buf, "JPEG", quality=88)
        buf.seek(0)
        c.drawImage(ImageReader(buf), 0, 0, width=297 * PT, height=210 * PT)
        c.showPage()
    c.save()


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    maquete_so = "--maquete" in sys.argv
    temas = args or ORDEM
    if "--catalogo" in sys.argv:
        catalogo(args[0], SAIDA)
        print("catalogo ok")
        return
    if "--planta" in sys.argv:
        os.makedirs(SAIDA, exist_ok=True)
        planta(os.path.join(SAIDA, "planta_do_gabinete_A3.pdf"))
        print("planta ok")
        return
    for t in temas:
        print("== tema", t, flush=True)
        gerar_tema(t, maquete_so)


if __name__ == "__main__":
    main()
