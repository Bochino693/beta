# -*- coding: utf-8 -*-
"""
ADESIVOS DO STRIKE KIDS (prontos para a grafica)
================================================

Monta os modelos de adesivos com as artes do proprio jogo: o Bob e a Mia
renderizados pelo jogo (pasta ../artes), os letreiros e o logo no mesmo
desenho do jogo (tools/arte/gerar_arte.py da versao Godot 4) e a marca
Lazer & Sport (ui/marca).

    python3 gerar_adesivos.py                 # tudo
    python3 gerar_adesivos.py cartela         # so uma parte:
                                              #   cartela | redondos | maquina | individuais

Sai em ../adesivos:
    cartelas/     A4 com os adesivos recortados (meio-corte) e A4 com 12
                  redondos de 6 cm
    individuais/  cada adesivo sozinho (PNG transparente + PDF com o corte)
    maquina/      letreiro, lateral, COMO JOGAR, faixa, START e FICHA
    previas/      JPG para ver no celular (o *_corte.jpg mostra o corte)

Cada PDF tem o tamanho final + sangria, a imagem em 300 DPI (150 DPI nas
pecas grandes da maquina) e, quando ha recorte, a linha de corte vetorial
na cor especial "CutContour" (magenta 100 %, 0,25 pt, sobreimpressao): a
plotter de recorte corta por ela e ela nao e impressa. Pecas retangulares
levam marcas de corte.
"""
import io
import math
import os
import random
import sys

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from reportlab.lib.colors import CMYKColor, CMYKColorSep
from reportlab.lib.utils import ImageReader
from reportlab.pdfgen import canvas as rl_canvas
from scipy import ndimage

Image.MAX_IMAGE_PIXELS = None

AQUI = os.path.dirname(os.path.abspath(__file__))
DIV = os.path.dirname(AQUI)                       # divulgacao/
RAIZ = os.environ.get("STRIKE_KIDS_RAIZ") or os.path.dirname(DIV)   # strike-kids-gles2/
FONTES = os.path.join(RAIZ, "fontes")
MARCA = os.path.join(RAIZ, "ui", "marca")
ARTES = os.path.join(DIV, "artes")
SAIDA = os.path.join(DIV, "adesivos")

MM = 25.4
PT = 72.0 / MM
MARINHO = "#0B1F45"

# degradês dos letreiros do jogo (gerar_arte.ui)
P_STRIKE = ["#FFF6A8", "#FFD43B", "#FF6A1E"]
P_SPARE = ["#C9F7FF", "#4FD8FF", "#2E6BFF"]
P_UAU = ["#E6FFFB", "#5EE6E0", "#13A3BC"]
P_SUPER = ["#FFF6A8", "#FF9F2E", "#FF3B4E"]
P_BOA = ["#E6FFD6", "#8DFF6A", "#2DBE4E"]
P_BRANCO = ["#FFFFFF", "#D6E6FF", "#7F9CFF"]
P_ESPACO = ["#F0F4FF", "#8FD3FF", "#2E6BFF"]
P_MAR = ["#E6FFFB", "#5EE6E0", "#1B8FD6"]
P_DINOS = ["#F4FFD6", "#A6EC52", "#2FA84F"]
P_PARQUE = ["#FFF6A8", "#FFB627", "#FF6A1E"]
P_LOGO = ["#FFF6A8", "#FFD43B", "#FF8A1E"]


# =====================================================================
# BASICO
# =====================================================================

def px(mm, dpi):
    return int(round(mm * dpi / MM))


def pxf(mm, dpi):
    return mm * dpi / MM


def cor(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def fonte(nome, tam):
    return ImageFont.truetype(os.path.join(FONTES, nome), max(1, int(round(tam))))


def dist_fora(b):
    """Distância (px) de cada ponto de fora até a forma b (0 dentro)."""
    return cv2.distanceTransform((~b).astype(np.uint8), cv2.DIST_L2, cv2.DIST_MASK_PRECISE)


def dist_dentro(b):
    """Distância (px) de cada ponto de dentro até a borda da forma b."""
    return cv2.distanceTransform(b.astype(np.uint8), cv2.DIST_L2, cv2.DIST_MASK_PRECISE)


def camada(tam, rgb, alfa):
    """Imagem RGBA de uma cor só com a transparência 'alfa' (0..1)."""
    a = (np.clip(alfa, 0, 1) * 255 + 0.5).astype(np.uint8)
    im = Image.new("RGBA", tam, tuple(rgb[:3]) + (255,))
    im.putalpha(Image.fromarray(a, "L"))
    return im


def colar(base, im, cx, cy):
    """Cola 'im' com o centro em (cx, cy) (aceita sair da borda)."""
    x, y = int(round(cx - im.width / 2)), int(round(cy - im.height / 2))
    base.alpha_composite(_recorte_para(base, im, x, y), (max(0, x), max(0, y)))


def colar_em(base, im, x, y):
    x, y = int(round(x)), int(round(y))
    base.alpha_composite(_recorte_para(base, im, x, y), (max(0, x), max(0, y)))


def _recorte_para(base, im, x, y):
    x0, y0 = max(0, -x), max(0, -y)
    x1, y1 = min(im.width, base.width - x), min(im.height, base.height - y)
    if x1 <= x0 or y1 <= y0:
        return Image.new("RGBA", (1, 1), (0, 0, 0, 0))
    return im.crop((x0, y0, x1, y1))


def redimensionar(im, largura=None, altura=None):
    if largura is None:
        largura = im.width * altura / im.height
    if altura is None:
        altura = im.height * largura / im.width
    return im.resize((max(1, int(round(largura))), max(1, int(round(altura)))), Image.LANCZOS)


def degrade(tam, paradas, vertical=True):
    """paradas: [(0..1, '#hex'), ...]."""
    w, h = tam
    n = h if vertical else w
    t = np.linspace(0, 1, n)
    ps = [p for p, _ in paradas]
    col = np.stack([np.interp(t, ps, [cor(c)[k] for _, c in paradas]) for k in range(3)], -1)
    col = col.astype(np.uint8)
    arr = np.repeat(col[:, None, :], w, axis=1) if vertical else np.repeat(col[None, :, :], h, axis=0)
    return Image.fromarray(arr, "RGB").convert("RGBA")


def degrade_radial(tam, cx, cy, raio, paradas):
    w, h = tam
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    t = np.clip(np.hypot(xx - cx, yy - cy) / raio, 0, 1)
    ps = [p for p, _ in paradas]
    canais = [np.interp(t, ps, [cor(c)[k] for _, c in paradas]).astype(np.uint8) for k in range(3)]
    return Image.fromarray(np.stack(canais, -1), "RGB").convert("RGBA")


def raios(base, cx, cy, n=18, alfa=0.16, giro=0.0, rgb=(255, 255, 255), raio_fade=None):
    """Raios de sol (fatias alternadas) a partir de (cx, cy)."""
    w, h = base.size
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    R = math.hypot(max(cx, w - cx), max(cy, h - cy)) * 1.05
    passo = 2 * math.pi / n
    for i in range(0, n, 2):
        a0 = giro + i * passo
        a1 = a0 + passo
        pts = [(cx, cy)] + [(cx + R * math.cos(a0 + (a1 - a0) * j / 8), cy + R * math.sin(a0 + (a1 - a0) * j / 8)) for j in range(9)]
        d.polygon(pts, fill=255)
    a = np.asarray(m, np.float32) / 255.0 * alfa
    a = cv2.GaussianBlur(a, (0, 0), max(0.8, w / 2500.0))
    if raio_fade:
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        a *= np.clip(1.15 - np.hypot(xx - cx, yy - cy) / raio_fade, 0, 1)
    base.alpha_composite(camada((w, h), rgb, a))


def brilho(base, cx, cy, raio, rgb=(255, 255, 255), alfa=0.5):
    w, h = base.size
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    t = np.clip(1 - np.hypot(xx - cx, yy - cy) / raio, 0, 1)
    base.alpha_composite(camada((w, h), rgb, (t ** 1.6) * alfa))


def estrela(d, cx, cy, r_ext, r_int, fill, pontas=5, giro=0.0):
    pts = []
    for i in range(pontas * 2):
        r = r_ext if i % 2 == 0 else r_int
        a = -math.pi / 2 + giro + i * math.pi / pontas
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    d.polygon(pts, fill=fill)


def estrela_contorno(d, cx, cy, r, cor_miolo, giro=0.0):
    """Estrela do jogo: contorno azul-marinho e miolo colorido."""
    estrela(d, cx, cy, r, r * 0.42, cor(MARINHO), giro=giro)
    estrela(d, cx, cy, r * 0.78, r * 0.32, cor(cor_miolo), giro=giro)


def nova_camada(base):
    """Camada transparente do tamanho de 'base' para desenhar o que é
    translúcido (no Pillow, desenhar translúcido direto numa imagem RGBA
    troca o pixel em vez de misturar); depois: base.alpha_composite(camada)."""
    c = Image.new("RGBA", base.size, (0, 0, 0, 0))
    return c, ImageDraw.Draw(c)


def estrelinhas(base, n, caixa, r_min, r_max, semente, alfa=110, evitar=None):
    """Estrelinhas brancas translúcidas no fundo (como o fundo do ícone)."""
    lay, d = nova_camada(base)
    rnd = random.Random(semente)
    x0, y0, x1, y1 = caixa
    for _ in range(n):
        x, y = rnd.uniform(x0, x1), rnd.uniform(y0, y1)
        if evitar and evitar(x, y):
            continue
        r = rnd.uniform(r_min, r_max)
        estrela(d, x, y, r, r * 0.42, (255, 255, 255, alfa), giro=rnd.uniform(-0.4, 0.4))
    base.alpha_composite(lay)


# =====================================================================
# LETREIROS E LOGO (o mesmo desenho do jogo)
# =====================================================================

def letreiro(linhas, cores, F, contorno=MARINHO, inclinar=-4, brilho_faixa=True, estrelas=True, semente="",
             fonte_nome="titan_one.ttf", saida=0.5):
    """Texto de desenho animado do jogo (gerar_arte.letreiro): degradê,
    contorno grosso azul-marinho, anel branco, sombra, faixa de brilho e
    estrelas. F = fonte desenhada (px); sai reduzido por 'saida' (0,5 = 2x
    de super-amostragem: fonte final = F/2)."""
    f = fonte(fonte_nome, F)
    tam_fonte = F / 2.0
    k = F / 600.0
    tmp = ImageDraw.Draw(Image.new("L", (10, 10)))
    caixas = [tmp.textbbox((0, 0), t, font=f) for t in linhas]
    larg = max(b[2] - b[0] for b in caixas)
    alt_linha = max(b[3] - b[1] for b in caixas)
    esp = int(alt_linha * 0.12)
    alt = alt_linha * len(linhas) + esp * (len(linhas) - 1)
    m = int(tam_fonte * 0.55)
    W, H = larg + m * 2, alt + m * 2
    mascara = Image.new("L", (W, H), 0)
    dm = ImageDraw.Draw(mascara)
    y = m
    for t, b in zip(linhas, caixas):
        x = m + (larg - (b[2] - b[0])) // 2 - b[0]
        dm.text((x, y - b[1]), t, font=f, fill=255)
        y += alt_linha + esp
    mk = np.asarray(mascara, np.float32) / 255.0
    forma = mk > 0.5
    fora = dist_fora(forma)
    borda = tam_fonte * 0.16
    cont = cv2.GaussianBlur(np.clip(borda - fora + 0.5, 0, 1), (0, 0), max(0.6, 1.5 * k))
    final = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    final.alpha_composite(camada((W, H), (0, 12, 36), cont * 0.55), (0, int(tam_fonte * 0.09)))
    final.alpha_composite(camada((W, H), cor(contorno), cont))
    anel = np.maximum(np.clip(borda / 3.0 - fora + 0.5, 0, 1), mk)
    final.alpha_composite(camada((W, H), (255, 255, 255), anel))
    g = degrade((W, H), [(0.0, cores[0]), (0.55, cores[1]), (1.0, cores[2])])
    g.putalpha(mascara)
    final.alpha_composite(g)
    if brilho_faixa:
        br = np.zeros((H, W), np.float32)
        y = m
        for _ in linhas:
            br[int(y + alt_linha * 0.06):int(y + alt_linha * 0.36), :] = 110 / 255.0
            y += alt_linha + esp
        dentro = np.clip(dist_dentro(forma) - borda / 4.0 + 0.5, 0, 1)
        br = cv2.GaussianBlur(br * dentro, (0, 0), max(0.8, 2 * k))
        final.alpha_composite(camada((W, H), (255, 255, 255), br))
    if estrelas:
        d = ImageDraw.Draw(final, "RGBA")
        rnd = random.Random(semente or "".join(linhas))
        for _ in range(5):
            cx = rnd.choice([rnd.uniform(0.02, 0.18), rnd.uniform(0.82, 0.98)]) * W
            cy = rnd.uniform(0.08, 0.92) * H
            r = rnd.uniform(0.05, 0.09) * H
            estrela(d, cx, cy, r, r * 0.42, cor(MARINHO), giro=rnd.uniform(-0.3, 0.3))
            estrela(d, cx, cy, r * 0.78, r * 0.32, cor(rnd.choice(["#FFE14D", "#FFFFFF", "#7FE7FF", "#FF9F2E"])),
                    giro=rnd.uniform(-0.3, 0.3))
    if inclinar:
        final = final.rotate(inclinar, resample=Image.BICUBIC, expand=True)
    final = final.crop(final.getbbox())
    if saida != 1:
        final = redimensionar(final, final.width * saida, final.height * saida)
    return final


def letreiro_altura(linhas, cores, altura_px, **kw):
    """Letreiro com a altura final pedida (px)."""
    teste = letreiro(linhas, cores, 200, **kw)
    F = 200 * altura_px / teste.height * 2
    im = letreiro(linhas, cores, F, **kw)
    return redimensionar(im, altura=altura_px)


def letreiro_largura(linhas, cores, largura_px, altura_max=None, **kw):
    teste = letreiro(linhas, cores, 200, **kw)
    F = 200 * largura_px / teste.width * 2
    if altura_max:
        F = min(F, 200 * altura_max / teste.height * 2)
    im = letreiro(linhas, cores, F, **kw)
    alvo = largura_px if not altura_max else min(largura_px, im.width * altura_max / im.height)
    return redimensionar(im, largura=alvo)


def _pino(k, esc):
    """Pino de boliche com carinha (o do logo do jogo)."""
    camada_p = Image.new("RGBA", (int(220 * esc * k), int(480 * esc * k)), (0, 0, 0, 0))
    dc = ImageDraw.Draw(camada_p, "RGBA")
    w, h = camada_p.size

    def elipse(cx, cy, rx, ry, **kw):
        dc.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], **kw)
    for (contorno, cc) in ((True, MARINHO), (False, "#FFFFFF")):
        e = 10 * k * esc if contorno else 0
        elipse(w / 2, h * 0.62, w * 0.42 + e, h * 0.3 + e, fill=cor(cc))
        elipse(w / 2, h * 0.17, w * 0.24 + e, h * 0.13 + e, fill=cor(cc))
        dc.rectangle([w / 2 - w * 0.15 - e, h * 0.2, w / 2 + w * 0.15 + e, h * 0.45], fill=cor(cc))
    dc.rectangle([w / 2 - w * 0.17, h * 0.3, w / 2 + w * 0.17, h * 0.34], fill=cor("#FF3B4E"))
    dc.rectangle([w / 2 - w * 0.18, h * 0.37, w / 2 + w * 0.18, h * 0.41], fill=cor("#FF3B4E"))
    for s in (-1, 1):
        elipse(w / 2 + s * w * 0.13, h * 0.58, w * 0.06, h * 0.045, fill=cor("#22101C"))
        elipse(w / 2 + s * w * 0.13 - w * 0.02, h * 0.57, w * 0.022, h * 0.016, fill=cor("#FFFFFF"))
    dc.arc([w / 2 - w * 0.1, h * 0.6, w / 2 + w * 0.1, h * 0.7], 20, 160, fill=cor("#22101C"), width=max(1, int(5 * k * esc)))
    return camada_p


def _bola(d, bx, by, br, k):
    def elipse(cx, cy, rx, ry, **kw):
        d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], **kw)
    elipse(bx, by, br + 10 * k, br + 10 * k, fill=cor(MARINHO))
    elipse(bx, by, br, br, fill=cor("#2E7BFF"))
    elipse(bx - br * 0.15, by - br * 0.1, br * 0.82, br * 0.8, fill=cor("#4FA8FF"))
    for (u, v, r) in ((-0.25, -0.35, 0.13), (0.1, -0.45, 0.11), (0.0, -0.15, 0.11)):
        elipse(bx + u * br, by + v * br, r * br, r * br, fill=cor(MARINHO))
    estrela(d, bx + br * 0.35, by + br * 0.3, br * 0.32, br * 0.14, cor("#FFE14D"))
    elipse(bx - br * 0.45, by - br * 0.55, br * 0.18, br * 0.12, fill=cor("#FFFFFF"))


def pino_img(altura_px, giro=0.0):
    k = altura_px * 2 / 480.0
    im = _pino(k, 1.0)
    if giro:
        im = im.rotate(giro, resample=Image.BICUBIC, expand=True)
    im = im.crop(im.getbbox())
    return redimensionar(im, im.width / 2, im.height / 2)


def bola_img(diametro_px):
    k = diametro_px * 2 / 210.0
    br = 95 * k
    lado = int(2 * (br + 12 * k)) + 4
    im = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    _bola(ImageDraw.Draw(im, "RGBA"), lado / 2, lado / 2, br, k)
    im = im.crop(im.getbbox())
    return redimensionar(im, im.width / 2, im.height / 2)


def logo(largura_px):
    """O logo STRIKE KIDS do jogo (gerar_arte.logo) na largura pedida."""
    escala = largura_px / 1364.0
    k = 2.0 * escala
    txt2 = letreiro(["STRIKE", "KIDS"], P_LOGO, 300 * k, inclinar=0, estrelas=False, saida=1.0)
    W, H = txt2.width / k + 360, txt2.height / k + 140
    img = Image.new("RGBA", (int(W * k), int(H * k)), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    px0, py0 = 150 * k, (H * k) * 0.52

    def pino(cx, cy, esc, giro):
        c = _pino(k, esc).rotate(giro, resample=Image.BICUBIC, expand=True)
        img.alpha_composite(c, (int(cx - c.width / 2), int(cy - c.height / 2)))
    pino(px0 + 30 * k, py0, 0.9, 14)
    pino(W * k - 140 * k, py0 + 30 * k, 0.75, -18)
    img.alpha_composite(txt2, (int((W * k - txt2.width) / 2), int(70 * k)))
    _bola(d, W * k - 210 * k, H * k - 150 * k, 95 * k, k)
    img = img.crop(img.getbbox())
    return redimensionar(img, largura=largura_px)


def texto(t, tam_px, rgb="#FFFFFF", contorno=MARINHO, larg_contorno=0.12, fonte_nome="fredoka_700.ttf", sombra=True,
          entrelinha=1.18):
    """Texto simples com contorno (Fredoka, a letra redonda do jogo); 'tam_px' = tamanho da fonte."""
    s = 2
    f = fonte(fonte_nome, tam_px * s)
    sw = int(round(tam_px * s * larg_contorno)) if contorno else 0
    linhas = t.split("\n")
    tmp = ImageDraw.Draw(Image.new("L", (10, 10)))
    caixas = [tmp.textbbox((0, 0), l, font=f, stroke_width=sw) for l in linhas]
    alt_l = tam_px * s * entrelinha
    W = int(max(b[2] - b[0] for b in caixas) + 4 * sw + 20)
    H = int(alt_l * len(linhas) + 4 * sw + tam_px * s * 0.6 + 20)
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im, "RGBA")
    for i, (l, b) in enumerate(zip(linhas, caixas)):
        x = (W - (b[2] - b[0])) / 2 - b[0]
        y = 10 + 2 * sw + i * alt_l
        if sombra and contorno:
            d.text((x, y + tam_px * s * 0.08), l, font=f, fill=(0, 12, 36, 110), stroke_width=sw, stroke_fill=(0, 12, 36, 110))
        d.text((x, y), l, font=f, fill=cor(rgb), stroke_width=sw, stroke_fill=cor(contorno) if contorno else None)
    im = im.crop(im.getbbox())
    return redimensionar(im, im.width / s, im.height / s)


def no_arco(im, tam, cx, cy, raio, cima=True):
    """Curva uma imagem de texto (reta) num arco de circunferência de raio
    'raio' (o meio da altura do texto), no alto (cima) ou embaixo."""
    w, h = im.size
    W, H = tam
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    dx, dy = xx - cx, yy - cy
    r = np.hypot(dx, dy)
    th = np.arctan2(dy, dx)
    if cima:
        u = w / 2.0 + (th + math.pi / 2) * raio
        v = (raio + h / 2.0) - r
    else:
        u = w / 2.0 - (th - math.pi / 2) * raio
        v = r - (raio - h / 2.0)
    arr = np.asarray(im.convert("RGBA"), np.float32)
    pre = arr.copy()
    pre[..., :3] *= pre[..., 3:4] / 255.0          # pré-multiplicado: sem franja escura
    saida = cv2.remap(pre, u.astype(np.float32), v.astype(np.float32), cv2.INTER_CUBIC,
                      borderMode=cv2.BORDER_CONSTANT, borderValue=(0, 0, 0, 0))
    a = np.clip(saida[..., 3:4], 0, 255)
    rgb = np.where(a > 0.5, saida[..., :3] * 255.0 / np.maximum(a, 1e-3), 0)
    out = np.concatenate([np.clip(rgb, 0, 255), a], -1).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def faixa(t, largura_px, altura_px, cor_fita="#FF3B4E", cor_texto="#FFFFFF", fonte_nome="titan_one.ttf"):
    """Fita (banner) de desenho animado com o texto no meio; as pontas
    (mais escuras, com o corte em V) ficam atrás e um pouco abaixo."""
    s = 2
    W, H = largura_px * s, altura_px * s
    cauda, desce = H * 0.8, H * 0.24
    lw = max(2, int(H * 0.075))
    tot_w, tot_h = W + 2 * cauda, H + desce
    im = Image.new("RGBA", (int(tot_w) + 2 * lw + 4, int(tot_h) + 2 * lw + 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(im, "RGBA")
    ox, oy = lw + 2, lw + 2
    escura = tuple(int(c * 0.7) for c in cor(cor_fita)[:3]) + (255,)
    ty0, ty1 = oy + desce, oy + desce + H
    for lado in (-1, 1):
        if lado < 0:
            xe, xi, ponta = ox, ox + cauda + H * 0.4, ox + H * 0.32
        else:
            xe, xi, ponta = ox + tot_w, ox + cauda + W - H * 0.4, ox + tot_w - H * 0.32
        pts = [(xi, ty0), (xe, ty0), (ponta, (ty0 + ty1) / 2), (xe, ty1), (xi, ty1)]
        d.polygon(pts, fill=escura, outline=cor(MARINHO), width=lw)
        # dobra (triângulo escuro entre a ponta e o corpo)
        xc = ox + cauda if lado < 0 else ox + cauda + W
        d.polygon([(xc, oy + H), (xc + (H * 0.45 if lado < 0 else -H * 0.45), oy + H), (xc, ty1)],
                  fill=tuple(int(c * 0.5) for c in cor(cor_fita)[:3]) + (255,), outline=cor(MARINHO), width=lw)
    d.rounded_rectangle([ox + cauda, oy, ox + cauda + W, oy + H], radius=int(H * 0.16), fill=cor(cor_fita),
                        outline=cor(MARINHO), width=lw)
    lay, dl = nova_camada(im)
    dl.rounded_rectangle([ox + cauda + lw * 2, oy + lw * 1.7, ox + cauda + W - lw * 2, oy + H * 0.42],
                         radius=int(H * 0.1), fill=(255, 255, 255, 52))
    im.alpha_composite(lay)
    tx = texto(t, H * 0.52, cor_texto, MARINHO, 0.13, fonte_nome=fonte_nome)
    esc = min(H * 0.6 / tx.height, W * 0.9 / tx.width)
    tx = redimensionar(tx, tx.width * esc, tx.height * esc)
    colar(im, tx, ox + cauda + W / 2, oy + H / 2)
    im = im.crop(im.getbbox())
    return redimensionar(im, im.width / s, im.height / s)


# =====================================================================
# ARTES DO JOGO
# =====================================================================

_artes = {}


def arte(nome):
    """Bob e Mia renderizados pelo jogo (fundo transparente), recortados."""
    if nome not in _artes:
        im = Image.open(os.path.join(ARTES, nome + ".png")).convert("RGBA")
        a = np.asarray(im)[..., 3]
        ys, xs = np.nonzero(a > 8)
        _artes[nome] = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    return _artes[nome]


def arte_altura(nome, altura_px):
    return redimensionar(arte(nome), altura=altura_px)


def placa_lazer(largura_px):
    im = Image.open(os.path.join(MARCA, "placa.png")).convert("RGBA")
    return redimensionar(im.crop(im.getbbox()), largura=largura_px)


# =====================================================================
# RECORTE (ADESIVO COM BORDA BRANCA E LINHA DE CORTE)
# =====================================================================

class Peca:
    """Um adesivo recortado: imagem (arte + borda branca + sangria branca),
    a forma do adesivo e a linha de corte (polígono em px desta imagem)."""

    def __init__(self, img, corte, dpi, nome=""):
        self.img = img
        self.corte = corte
        self.dpi = dpi
        self.nome = nome

    @property
    def caixa_corte(self):
        xs = [p[0] for p in self.corte]
        ys = [p[1] for p in self.corte]
        return min(xs), min(ys), max(xs), max(ys)

    def tamanho_mm(self):
        x0, y0, x1, y1 = self.caixa_corte
        return (x1 - x0) * MM / self.dpi, (y1 - y0) * MM / self.dpi


def recortar(im, dpi, borda_mm=2.6, contorno_mm=0.0, juntar_mm=2.2, suave_mm=0.45, sangria_mm=1.0, nome=""):
    """Adesivo recortado em volta da arte (já no tamanho final a 'dpi'):
    contorno azul-marinho opcional colado na arte, borda branca de
    'borda_mm', vãos estreitos fechados (sem cortar entre braço e corpo),
    um pedaço só (pontinhos soltos longe do corpo saem) e a linha de corte
    lisa. O branco passa 'sangria_mm' para fora do corte."""
    rb, rc, rj = pxf(borda_mm, dpi), pxf(contorno_mm, dpi), pxf(juntar_mm, dpi)
    rs = pxf(sangria_mm, dpi)
    pad = int(rb + rc + rj + rs) + 8
    W, H = im.width + 2 * pad, im.height + 2 * pad
    base = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    base.alpha_composite(im, (pad, pad))
    a = np.asarray(base)[..., 3].astype(np.float32) / 255.0
    arte_b = ndimage.binary_fill_holes(a > 0.5)
    alcance = dist_fora(arte_b) <= rb + rc + rj
    forma = dist_dentro(alcance) > rj
    rot, n = ndimage.label(forma)
    if n > 1:
        tamanhos = ndimage.sum(forma, rot, range(1, n + 1))
        forma = rot == (int(np.argmax(tamanhos)) + 1)
    forma = ndimage.binary_fill_holes(forma)
    sig = pxf(suave_mm, dpi)
    campo = cv2.GaussianBlur(forma.astype(np.float32), (0, 0), sig)
    corte_b = campo > 0.5
    # o que ficou fora do adesivo (pontinho solto) sai; nada encosta no corte
    dentro = np.clip(dist_dentro(corte_b) - rb * 0.6, 0, 1)
    a2 = a * dentro
    arte_rgba = np.asarray(base).copy()
    arte_rgba[..., 3] = (a2 * 255 + 0.5).astype(np.uint8)
    arte_im = Image.fromarray(arte_rgba, "RGBA")
    # branco: o adesivo + sangria
    rampa = sig * 2.5066 / 1.2
    branco = np.clip((campo - 0.5) * rampa + 0.5, 0, 1)
    if rs > 0:
        branco = np.maximum(branco, np.clip(rs - dist_fora(corte_b) + 0.5, 0, 1))
    out = camada((W, H), (255, 255, 255), branco)
    if rc > 0:
        arte_b2 = ndimage.binary_fill_holes(a2 > 0.5)
        ct = np.clip(rc - dist_fora(arte_b2) + 0.5, 0, 1)
        out.alpha_composite(camada((W, H), cor(MARINHO), cv2.GaussianBlur(ct, (0, 0), 0.6)))
    out.alpha_composite(arte_im)
    return Peca(out, contorno_de(corte_b), dpi, nome)


def contorno_de(b):
    """Linha de corte (polígono fechado, px) da forma b."""
    cs, _ = cv2.findContours(b.astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    c = max(cs, key=cv2.contourArea)[:, 0, :].astype(np.float64) + 0.5
    n = len(c)
    if n > 30:
        janela = 7
        ext = np.concatenate([c[-janela:], c, c[:janela]])
        ker = np.ones(2 * janela + 1) / (2 * janela + 1)
        c = np.stack([np.convolve(ext[:, i], ker, mode="same")[janela:janela + n] for i in range(2)], -1)
    ap = cv2.approxPolyDP(c.astype(np.float32).reshape(-1, 1, 2), 0.35, True)[:, 0, :]
    return [(float(x), float(y)) for x, y in ap]


def redondo_peca(img, dpi, diametro_mm, sangria_mm):
    """Peça redonda: a linha de corte é o círculo do tamanho final."""
    lado = img.width
    r = pxf(diametro_mm, dpi) / 2
    c = lado / 2.0
    n = 360
    corte = [(c + r * math.cos(2 * math.pi * i / n), c + r * math.sin(2 * math.pi * i / n)) for i in range(n)]
    p = Peca(img, corte, dpi)
    p.circulo = (c, c, r)
    return p


# =====================================================================
# PDF, PNG E PRÉVIAS
# =====================================================================

def salvar_pdf(caminho, img, dpi, final_mm, sangria_mm, cortes=(), circulos=(), marcas=True, titulo=""):
    """PDF para a gráfica. 'img' cobre o tamanho final + sangria. 'cortes':
    polígonos em mm a partir do canto de cima à esquerda do tamanho FINAL;
    'circulos': (cx, cy, raio) em mm. A linha de corte vai na cor especial
    CutContour (não imprime; a plotter corta por ela)."""
    fw, fh = final_mm
    mg = 10.0 if marcas else 3.0
    pw, ph = fw + 2 * (sangria_mm + mg), fh + 2 * (sangria_mm + mg)
    c = rl_canvas.Canvas(caminho, pagesize=(pw * PT, ph * PT), pageCompression=1)
    c.setTitle(titulo or os.path.basename(caminho))
    c.setAuthor("Lazer & Sport")
    c.setCreator("Strike Kids - gerar_adesivos.py")
    c.setSubject("Final %.0f x %.0f mm + sangria %.0f mm; corte: CutContour" % (fw, fh, sangria_mm))
    if img.mode == "RGBA":
        branco = Image.new("RGBA", img.size, (255, 255, 255, 255))
        branco.alpha_composite(img)
        img = branco
    buf = io.BytesIO()
    img.convert("RGB").save(buf, "JPEG", quality=95, subsampling=0, dpi=(dpi, dpi))
    buf.seek(0)
    c.drawImage(ImageReader(buf), mg * PT, mg * PT, width=(fw + 2 * sangria_mm) * PT, height=(fh + 2 * sangria_mm) * PT)
    x0, y0 = (mg + sangria_mm) * PT, (mg + sangria_mm) * PT
    c.setTrimBox((x0, y0, x0 + fw * PT, y0 + fh * PT))
    c.setBleedBox((mg * PT, mg * PT, (mg + fw + 2 * sangria_mm) * PT, (mg + fh + 2 * sangria_mm) * PT))

    def ponto(x, y):
        return (mg + sangria_mm + x) * PT, ph * PT - (mg + sangria_mm + y) * PT

    if cortes or circulos:
        c.saveState()
        c.setStrokeColor(CMYKColorSep(0, 1, 0, 0, spotName="CutContour", density=1))
        c.setStrokeOverprint(1)
        c.setLineWidth(0.25)
        for poli in cortes:
            p = c.beginPath()
            p.moveTo(*ponto(*poli[0]))
            for q in poli[1:]:
                p.lineTo(*ponto(*q))
            p.close()
            c.drawPath(p, stroke=1, fill=0)
        for (cx, cy, r) in circulos:
            c.circle(*ponto(cx, cy), r * PT, stroke=1, fill=0)
        c.restoreState()
    if marcas:
        c.saveState()
        c.setStrokeColor(CMYKColor(1, 1, 1, 1))
        c.setLineWidth(0.25)
        afasta, comp = sangria_mm + 2.0, 6.0
        for (x, y) in ((0, 0), (fw, 0), (0, fh), (fw, fh)):
            sx = -1 if x == 0 else 1
            sy = -1 if y == 0 else 1
            c.line(*ponto(x + sx * afasta, y), *ponto(x + sx * (afasta + comp), y))
            c.line(*ponto(x, y + sy * afasta), *ponto(x, y + sy * (afasta + comp)))
        c.setFont("Helvetica", 6)
        c.setFillColor(CMYKColor(0, 0, 0, 1))
        c.drawString((mg + sangria_mm) * PT, (mg * 0.35) * PT,
                     "%s  -  final %.0f x %.0f mm  +  sangria %.0f mm  -  %d DPI" % (titulo, fw, fh, sangria_mm, dpi))
        c.restoreState()
    c.showPage()
    c.save()


def previa(img, caminho, largura=1400, cortes_px=(), circulos_px=(), fundo="#FFFFFF"):
    """JPG pequeno para ver no celular; com 'cortes_px', a linha de corte em magenta."""
    esc = largura / img.width
    p = redimensionar(img, largura=largura)
    if fundo is not None:
        f = Image.new("RGBA", p.size, cor(fundo))
        f.alpha_composite(p)
        p = f
    if cortes_px or circulos_px:
        d = ImageDraw.Draw(p, "RGBA")
        for poli in cortes_px:
            pts = [(x * esc, y * esc) for x, y in poli]
            d.line(pts + [pts[0]], fill=(236, 0, 140, 255), width=2)
        for (cx, cy, r) in circulos_px:
            d.ellipse([(cx - r) * esc, (cy - r) * esc, (cx + r) * esc, (cy + r) * esc], outline=(236, 0, 140, 255), width=2)
    p.convert("RGB").save(caminho, "JPEG", quality=88)


def pasta(*partes):
    p = os.path.join(SAIDA, *partes)
    os.makedirs(p, exist_ok=True)
    return p


def mm_de(px_, dpi):
    return px_ * MM / dpi


# =====================================================================
# ADESIVOS (PEÇAS)
# =====================================================================

DPI = 300

# personagens (arquivo, altura em mm na cartela)
PERSONAGENS = {
    "bob_acenando": "Bob acenando", "mia_festa": "Mia na festa", "bob_astronauta": "Bob astronauta",
    "mia_pirata": "Mia pirata", "bob_dino": "Bob dinossaurinho", "mia_parque": "Mia no parque",
    "dupla_festa": "Bob e Mia na festa", "bob_jato": "Bob no strike", "mia_vitoria": "Mia campea",
    "bob_vibra": "Bob vibrando", "mia_escolhida": "Mia escolhida", "dupla_acenando": "Bob e Mia acenando",
}


def peca_personagem(nome, altura_mm, dpi=DPI):
    im = arte_altura(nome, px(altura_mm, dpi))
    return recortar(im, dpi, borda_mm=2.6, contorno_mm=0.0, nome=nome)


def peca_letreiro(linhas, cores, largura_mm, dpi=DPI, semente="", inclinar=-4, estrelas=True):
    im = letreiro_largura(linhas, cores, px(largura_mm, dpi), semente=semente, inclinar=inclinar, estrelas=estrelas)
    return recortar(im, dpi, borda_mm=2.2, juntar_mm=1.6, nome="_".join(linhas).lower())


def peca_logo(largura_mm, dpi=DPI):
    return recortar(logo(px(largura_mm, dpi)), dpi, borda_mm=2.4, juntar_mm=2.0, nome="logo")


def peca_pino(altura_mm, dpi=DPI, giro=12):
    return recortar(pino_img(px(altura_mm, dpi), giro), dpi, borda_mm=2.2, nome="pino")


def peca_bola(diametro_mm, dpi=DPI):
    return recortar(bola_img(px(diametro_mm, dpi)), dpi, borda_mm=2.2, nome="bola")


# --------------------------------------------------------- redondos

# fundo (degradê radial: centro -> borda), título no arco, personagem e
# o que vai embaixo ("STRIKE!" grande ou fita)
REDONDOS = [
    {"nome": "eu_fiz_strike_bob", "titulo": ["EU FIZ"], "p_titulo": P_UAU, "fundo": ["#7FE7FF", "#2A9BE0", "#123A7A"],
     "arte": "bob_jato", "alt": 0.70, "base": ("strike", None), "enfeite": "estrelas"},
    {"nome": "eu_fiz_strike_mia", "titulo": ["EU FIZ"], "p_titulo": P_UAU, "fundo": ["#8FF2C8", "#2FB98A", "#0E5E66"],
     "arte": "mia_vitoria", "alt": 0.70, "base": ("strike", None), "enfeite": "estrelas"},
    {"nome": "campeao_do_dia_bob", "titulo": ["CAMPEÃO"], "p_titulo": P_SPARE, "fundo": ["#FFF3A0", "#FFC93B", "#E07B00"],
     "arte": "bob_vibra", "alt": 0.72, "base": ("faixa", "DO DIA"), "enfeite": "estrelas"},
    {"nome": "campea_do_dia_mia", "titulo": ["CAMPEÃ"], "p_titulo": P_SPARE, "fundo": ["#FFF3A0", "#FFC93B", "#E07B00"],
     "arte": "mia_festa", "alt": 0.72, "base": ("faixa", "DO DIA"), "enfeite": "estrelas"},
    {"nome": "viagem_ao_espaco", "titulo": ["VIAGEM AO ESPAÇO!"], "p_titulo": P_ESPACO,
     "fundo": ["#3B5FC4", "#1A2F78", "#0A1538"], "arte": "bob_astronauta", "alt": 0.70,
     "base": ("faixa", "STRIKE KIDS"), "enfeite": "espaco"},
    {"nome": "fundo_do_mar", "titulo": ["FUNDO DO MAR!"], "p_titulo": P_MAR, "fundo": ["#8DF0F7", "#1FA6D8", "#0B4F8F"],
     "arte": "mia_pirata", "alt": 0.70, "base": ("faixa", "STRIKE KIDS"), "enfeite": "bolhas"},
    {"nome": "selva_dos_dinos", "titulo": ["SELVA DOS DINOS!"], "p_titulo": P_DINOS, "fundo": ["#E2FF9A", "#6CC93A", "#1F6E35"],
     "arte": "bob_dino", "alt": 0.70, "base": ("faixa", "STRIKE KIDS"), "enfeite": "folhas"},
    {"nome": "parque_de_diversoes", "titulo": ["PARQUE DE DIVERSÕES!"], "p_titulo": P_PARQUE,
     "fundo": ["#CFF6FF", "#5CC8F2", "#1A6FC0"], "arte": "mia_parque", "alt": 0.70,
     "base": ("faixa", "STRIKE KIDS"), "enfeite": "confete"},
]


def _enfeites(base, tipo, cx, cy, R, semente):
    lay, d = nova_camada(base)
    rnd = random.Random(semente)
    if tipo == "estrelas":
        estrelinhas(base, 26, (cx - R, cy - R, cx + R, cy + R), R * 0.025, R * 0.06, semente, alfa=150)
    elif tipo == "espaco":
        for _ in range(60):
            x, y = rnd.uniform(cx - R, cx + R), rnd.uniform(cy - R, cy + R)
            r = rnd.uniform(R * 0.006, R * 0.02)
            d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255, rnd.randint(120, 230)))
        estrelinhas(base, 10, (cx - R, cy - R, cx + R, cy + R), R * 0.03, R * 0.06, semente, alfa=200)
        # planeta com anel
        pxp, pyp, pr = cx + R * 0.55, cy - R * 0.05, R * 0.16
        d.ellipse([pxp - pr * 1.9, pyp - pr * 0.55, pxp + pr * 1.9, pyp + pr * 0.55], outline=(255, 214, 120, 255), width=max(2, int(pr * 0.16)))
        d.ellipse([pxp - pr, pyp - pr, pxp + pr, pyp + pr], fill=cor("#FF9F2E"))
        d.ellipse([pxp - pr * 0.75, pyp - pr * 0.85, pxp + pr * 0.35, pyp - pr * 0.05], fill=(255, 190, 96, 255))
        d.arc([pxp - pr * 1.9, pyp - pr * 0.55, pxp + pr * 1.9, pyp + pr * 0.55], 0, 180, fill=(255, 214, 120, 255), width=max(2, int(pr * 0.16)))
        pxl, pyl, pl = cx - R * 0.62, cy + R * 0.05, R * 0.09
        d.ellipse([pxl - pl, pyl - pl, pxl + pl, pyl + pl], fill=cor("#C9D6FF"))
        d.ellipse([pxl - pl * 0.4, pyl - pl * 0.5, pxl - pl * 0.05, pyl - pl * 0.15], fill=cor("#9FB0E8"))
    elif tipo == "bolhas":
        for _ in range(16):
            x, y = rnd.uniform(cx - R, cx + R), rnd.uniform(cy - R * 0.9, cy + R * 0.6)
            r = rnd.uniform(R * 0.025, R * 0.075)
            lw = max(1, int(r * 0.16))
            d.ellipse([x - r, y - r, x + r, y + r], outline=(255, 255, 255, 190), width=lw)
            d.ellipse([x - r * 0.55, y - r * 0.6, x - r * 0.1, y - r * 0.2], fill=(255, 255, 255, 170))
    elif tipo == "folhas":
        for _ in range(14):
            ang = rnd.uniform(0, 2 * math.pi)
            dist = rnd.uniform(R * 0.62, R * 0.98)
            x, y = cx + math.cos(ang) * dist, cy + math.sin(ang) * dist
            folha = Image.new("RGBA", (int(R * 0.5), int(R * 0.22)), (0, 0, 0, 0))
            df = ImageDraw.Draw(folha, "RGBA")
            df.ellipse([0, 0, folha.width - 1, folha.height - 1], fill=cor(rnd.choice(["#2E9E45", "#43B649", "#1F7A3A", "#7BD34F"]), 210))
            df.line([folha.width * 0.08, folha.height / 2, folha.width * 0.92, folha.height / 2], fill=(255, 255, 255, 90), width=max(1, int(R * 0.008)))
            folha = folha.rotate(math.degrees(-ang) + rnd.uniform(-40, 40), resample=Image.BICUBIC, expand=True)
            colar(base, folha, x, y)
    elif tipo == "confete":
        cores = ["#FF3B4E", "#FFD43B", "#2E6BFF", "#2DBE4E", "#FF9F2E", "#B65CFF", "#FFFFFF"]
        for _ in range(48):
            x, y = rnd.uniform(cx - R, cx + R), rnd.uniform(cy - R, cy + R * 0.4)
            w, h = rnd.uniform(R * 0.03, R * 0.06), rnd.uniform(R * 0.012, R * 0.024)
            q = Image.new("RGBA", (int(w) + 2, int(h) + 2), cor(rnd.choice(cores)))
            colar(base, q.rotate(rnd.uniform(0, 180), expand=True, resample=Image.BICUBIC), x, y)
    base.alpha_composite(lay)


def redondo(cfg, diametro_mm=60.0, dpi=DPI, sangria_mm=2.0, ss=2):
    """Adesivo redondo: fundo do tema com raios, personagem, título no arco
    e o "STRIKE!" ou a fita embaixo; anel branco e azul-marinho na borda."""
    d_px = pxf(diametro_mm, dpi * ss)
    s_px = pxf(sangria_mm, dpi * ss)
    lado = int(round(d_px + 2 * s_px))
    c = lado / 2.0
    R = d_px / 2.0
    u = R / 30.0                                  # 1 "mm" do adesivo de 60 mm
    img = degrade_radial((lado, lado), c, c - R * 0.15, R * 1.15, [(0, cfg["fundo"][0]), (0.55, cfg["fundo"][1]), (1, cfg["fundo"][2])])
    raios(img, c, c - R * 0.12, n=20, alfa=0.13, giro=0.08)
    brilho(img, c, c - R * 0.1, R * 0.75, alfa=0.35)
    _enfeites(img, cfg["enfeite"], c, c, R, cfg["nome"])
    r_int = R - 3.0 * u                           # dentro dos anéis
    # personagem (cortado pelo círculo de dentro)
    p = arte_altura(cfg["arte"], R * 2 * cfg["alt"])
    perso = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    base_y = c + R * 0.98
    colar_em(perso, p, c - p.width / 2, base_y - p.height)
    yy, xx = np.mgrid[0:lado, 0:lado].astype(np.float32)
    disco = np.clip(r_int - np.hypot(xx - c, yy - c) + 0.5, 0, 1)
    pa = np.asarray(perso).copy()
    pa[..., 3] = (pa[..., 3] * disco).astype(np.uint8)
    img.alpha_composite(Image.fromarray(pa, "RGBA"))
    # embaixo
    tipo, txt = cfg["base"]
    if tipo == "strike":
        st = letreiro_largura(["STRIKE!"], P_STRIKE, R * 1.5, semente="strike")
        colar(img, st, c, c + R * 0.5)
    else:
        f = faixa(txt, R * (1.2 if len(txt) > 7 else 0.82), R * 0.24,
                  cor_fita="#FF3B4E" if txt == "DO DIA" else "#123A7A",
                  cor_texto="#FFFFFF" if txt == "DO DIA" else "#FFD43B")
        colar(img, f, c, c + R * 0.66)
    # título no arco de cima
    n_letras = sum(len(t) for t in cfg["titulo"])
    alt_t = R * (0.30 if n_letras <= 7 else 0.24 if n_letras <= 14 else 0.21)
    t = letreiro_altura(cfg["titulo"], cfg["p_titulo"], alt_t, inclinar=0, estrelas=False)
    arco_max = R * 0.70 * math.pi * (200.0 / 180.0)
    if t.width > arco_max:
        t = redimensionar(t, largura=arco_max)
    raio_t = r_int - t.height * 0.55
    img.alpha_composite(no_arco(t, (lado, lado), c, c, raio_t, cima=True))
    # anéis: branco e azul-marinho (que passa para a sangria)
    r = np.hypot(xx - c, yy - c)
    anel_b = np.clip(r - r_int + 0.5, 0, 1) * np.clip((R - 1.8 * u) - r + 0.5, 0, 1)
    img.alpha_composite(camada((lado, lado), (255, 255, 255), anel_b))
    anel_m = np.clip(r - (R - 1.8 * u) + 0.5, 0, 1)
    img.alpha_composite(camada((lado, lado), cor(MARINHO), anel_m))
    # fora do círculo + sangria: transparente
    a = np.asarray(img).copy()
    a[..., 3] = (a[..., 3] * np.clip((R + s_px) - r + 0.5, 0, 1)).astype(np.uint8)
    img = Image.fromarray(a, "RGBA")
    img = redimensionar(img, img.width / ss, img.height / ss)
    return redondo_peca(img, dpi, diametro_mm, sangria_mm)


# =====================================================================
# CARTELAS
# =====================================================================

A4 = (210.0, 297.0)


def _fundo_cartela(W, H, dpi, semente):
    img = degrade((W, H), [(0, "#123A7A"), (0.45, "#1C7BCB"), (1, "#5CCBF2")])
    raios(img, W / 2, px(40, dpi), n=28, alfa=0.08, raio_fade=H * 0.9)
    brilho(img, W / 2, px(40, dpi), px(150, dpi), alfa=0.22)
    estrelinhas(img, 90, (0, 0, W, H), pxf(1.2, dpi), pxf(3.2, dpi), semente, alfa=70)
    return img


def cartela_recortados():
    """A4 com adesivos recortados (meio-corte): personagens, letreiros, logo, pino e bola."""
    dpi = DPI
    sg = 3.0
    W, H = px(A4[0] + 2 * sg, dpi), px(A4[1] + 2 * sg, dpi)
    off = pxf(sg, dpi)
    img = _fundo_cartela(W, H, dpi, "cartela")
    # cabeçalho (impresso, não é adesivo)
    lg = logo(px(92, dpi))
    colar(img, lg, W / 2, off + px(25, dpi))
    sub = texto("ADESIVOS DO BOB E DA MIA", pxf(4.4, dpi), "#FFFFFF", MARINHO, 0.16)
    colar(img, sub, W / 2, off + px(48, dpi))
    fileiras = [
        ([("p", "bob_acenando"), ("p", "mia_festa"), ("p", "bob_astronauta"), ("p", "mia_pirata")], 56),
        ([("p", "bob_dino"), ("p", "dupla_festa"), ("p", "mia_parque")], 54),
        ([("l", (["STRIKE!"], P_STRIKE, "strike")), ("l", (["SPARE!"], P_SPARE, "spare")), ("l", (["SUPER!"], P_SUPER, "super"))], 26),
        ([("logo", None), ("p", "bob_jato"), ("pino", None), ("bola", None), ("p", "mia_vitoria")], 44),
    ]
    margem, vao = 9.0, 4.0
    util = A4[0] - 2 * margem
    pecas_fileiras = []
    for itens, alt in fileiras:
        escala = 1.0
        for _ in range(4):
            pecas = []
            for tipo, arg in itens:
                if tipo == "p":
                    pecas.append(peca_personagem(arg, alt * escala * (0.8 if arg in ("bob_jato",) else 1.0)))
                elif tipo == "l":
                    linhas, cores, sem = arg
                    pecas.append(peca_letreiro(linhas, cores, alt * escala * 2.3, semente=sem))
                elif tipo == "logo":
                    pecas.append(peca_logo(alt * escala * 1.55))
                elif tipo == "pino":
                    pecas.append(peca_pino(alt * escala * 0.62))
                elif tipo == "bola":
                    pecas.append(peca_bola(alt * escala * 0.42))
            larg = sum(p.tamanho_mm()[0] for p in pecas) + vao * (len(pecas) - 1)
            if larg <= util:
                break
            escala *= util / larg * 0.99
        pecas_fileiras.append(pecas)
    # distribui as fileiras na altura que sobra
    topo, fim = 56.0, A4[1] - 14.0
    alturas = [max(p.tamanho_mm()[1] for p in ps) for ps in pecas_fileiras]
    folga = (fim - topo - sum(alturas)) / (len(alturas) + 1)
    y = topo + folga
    cortes_mm, cortes_px = [], []
    for ps, alt_f in zip(pecas_fileiras, alturas):
        larg = sum(p.tamanho_mm()[0] for p in ps)
        espaco = (A4[0] - 2 * margem - larg) / (len(ps) - 1) if len(ps) > 1 else 0
        espaco = min(espaco, 12.0)
        x = (A4[0] - (larg + espaco * (len(ps) - 1))) / 2
        for p in ps:
            pw, ph = p.tamanho_mm()
            x0c, y0c, _, _ = p.caixa_corte
            # alinha pelo meio da fileira
            ox_mm = x - mm_de(x0c, dpi)
            oy_mm = y + (alt_f - ph) / 2 - mm_de(y0c, dpi)
            colar_em(img, p.img, pxf(ox_mm + sg, dpi), pxf(oy_mm + sg, dpi))
            poli = [(ox_mm + mm_de(a, dpi), oy_mm + mm_de(b, dpi)) for a, b in p.corte]
            cortes_mm.append(poli)
            cortes_px.append([(pxf(a + sg, dpi), pxf(b + sg, dpi)) for a, b in poli])
            x += pw + espaco
        y += alt_f + folga
    pl = placa_lazer(px(34, dpi))
    colar(img, pl, W / 2, H - off - px(6.5, dpi))
    _conferir_vaos(cortes_mm)
    nome = "cartela_adesivos_A4"
    salvar_pdf(os.path.join(pasta("cartelas"), nome + ".pdf"), img, dpi, A4, sg, cortes=cortes_mm,
               titulo="Strike Kids - cartela de adesivos A4 (meio-corte)")
    img.convert("RGB").save(os.path.join(pasta("cartelas"), nome + ".jpg"), "JPEG", quality=93, dpi=(dpi, dpi))
    previa(img, os.path.join(pasta("previas"), nome + ".jpg"), 1240)
    previa(img, os.path.join(pasta("previas"), nome + "_corte.jpg"), 1240, cortes_px=cortes_px)
    print("  cartela de adesivos recortados: %d adesivos" % len(cortes_mm))


def _conferir_vaos(cortes_mm, minimo=2.5):
    """Nenhuma linha de corte encosta na outra (vão mínimo em mm)."""
    from scipy.spatial import cKDTree
    arvores = [cKDTree(np.array(p)) for p in cortes_mm]
    pior = 1e9
    for i in range(len(cortes_mm)):
        for j in range(i + 1, len(cortes_mm)):
            dd, _ = arvores[j].query(np.array(cortes_mm[i]))
            pior = min(pior, float(dd.min()))
    if pior < minimo:
        raise SystemExit("ERRO: duas linhas de corte a %.1f mm (mínimo %.1f)" % (pior, minimo))
    print("    menor vão entre cortes: %.1f mm" % pior)


def cartela_redondos():
    """A4 com 12 adesivos redondos de 6 cm (os 8 modelos + 4 repetidos)."""
    dpi = DPI
    sg = 3.0
    W, H = px(A4[0] + 2 * sg, dpi), px(A4[1] + 2 * sg, dpi)
    img = Image.new("RGBA", (W, H), (255, 255, 255, 255))
    d_mm = 60.0
    ordem = [0, 1, 2, 3, 4, 5, 6, 7, 0, 1, 2, 3]
    pecas = {}
    for i in set(ordem):
        pecas[i] = redondo(REDONDOS[i], d_mm, dpi)
    cols, lins = 3, 4
    vao_x = (A4[0] - 2 * 9.0 - cols * d_mm) / (cols - 1)
    vao_y = (A4[1] - 2 * 12.0 - lins * d_mm) / (lins - 1)
    circulos_mm, circulos_px = [], []
    for k, i in enumerate(ordem):
        col, lin = k % cols, k // cols
        cx = 9.0 + d_mm / 2 + col * (d_mm + vao_x)
        cy = 12.0 + d_mm / 2 + lin * (d_mm + vao_y)
        p = pecas[i]
        colar(img, p.img, pxf(cx + sg, dpi), pxf(cy + sg, dpi))
        circulos_mm.append((cx, cy, d_mm / 2))
        circulos_px.append((pxf(cx + sg, dpi), pxf(cy + sg, dpi), pxf(d_mm / 2, dpi)))
    nome = "cartela_redondos_6cm_A4"
    salvar_pdf(os.path.join(pasta("cartelas"), nome + ".pdf"), img, dpi, A4, sg, circulos=circulos_mm,
               titulo="Strike Kids - 12 adesivos redondos de 6 cm (A4)")
    img.convert("RGB").save(os.path.join(pasta("cartelas"), nome + ".jpg"), "JPEG", quality=93, dpi=(dpi, dpi))
    previa(img, os.path.join(pasta("previas"), nome + ".jpg"), 1240)
    previa(img, os.path.join(pasta("previas"), nome + "_corte.jpg"), 1240, circulos_px=circulos_px)
    print("  cartela de redondos: 12 de 6 cm (vãos %.1f x %.1f mm)" % (vao_x, vao_y))


def individuais():
    """Cada adesivo sozinho: PNG transparente (300 DPI) e PDF com o corte."""
    dpi = DPI
    destino = pasta("individuais")
    lista = []
    for nome in ["bob_acenando", "mia_festa", "bob_astronauta", "mia_pirata", "bob_dino", "mia_parque",
                 "dupla_festa", "bob_jato", "mia_vitoria", "dupla_acenando"]:
        alt = 70.0 if not nome.startswith("dupla") else 60.0
        lista.append(("personagem_" + nome, peca_personagem(nome, alt)))
    lista.append(("letreiro_strike", peca_letreiro(["STRIKE!"], P_STRIKE, 80, semente="strike")))
    lista.append(("letreiro_spare", peca_letreiro(["SPARE!"], P_SPARE, 70, semente="spare")))
    lista.append(("letreiro_super", peca_letreiro(["SUPER!"], P_SUPER, 70, semente="super")))
    lista.append(("letreiro_pegando_fogo", peca_letreiro(["PEGANDO", "FOGO!"], ["#FFF6A8", "#FF9F2E", "#FF3B1E"], 70,
                                                         semente="pegando_fogo")))
    lista.append(("logo_strike_kids", peca_logo(90)))
    for i, cfg in enumerate(REDONDOS):
        lista.append(("redondo_6cm_" + cfg["nome"], redondo(cfg, 60.0, dpi)))
    for nome, p in lista:
        circ = getattr(p, "circulo", None)
        sg = 2.0 if circ else 1.0
        if circ:
            cx, cy, r = circ
            img = p.img
            fw = fh = mm_de(2 * r, dpi)
            final_mm = (fw, fh)
            img_pdf = img
            circulos = [(fw / 2, fh / 2, fw / 2)]
            cortes = []
        else:
            x0, y0, x1, y1 = p.caixa_corte
            m = pxf(sg, dpi)
            caixa = (int(math.floor(x0 - m)), int(math.floor(y0 - m)), int(math.ceil(x1 + m)), int(math.ceil(y1 + m)))
            img_pdf = p.img.crop(caixa)
            fw, fh = mm_de(caixa[2] - caixa[0], dpi) - 2 * sg, mm_de(caixa[3] - caixa[1], dpi) - 2 * sg
            final_mm = (fw, fh)
            cortes = [[(mm_de(a - caixa[0], dpi) - sg, mm_de(b - caixa[1], dpi) - sg) for a, b in p.corte]]
            circulos = []
        branco = Image.new("RGBA", img_pdf.size, (255, 255, 255, 255))
        branco.alpha_composite(img_pdf)
        salvar_pdf(os.path.join(destino, nome + ".pdf"), branco, dpi, final_mm, sg, cortes=cortes, circulos=circulos,
                   marcas=False, titulo="Strike Kids - %s (%.0f x %.0f mm)" % (nome, final_mm[0], final_mm[1]))
        img_pdf.save(os.path.join(destino, nome + ".png"), dpi=(dpi, dpi), optimize=True)
    print("  individuais: %d adesivos (PNG + PDF)" % len(lista))


# =====================================================================
# MÁQUINA
# =====================================================================

DPI_GRANDE = 150


def _salvar_maquina(img, nome, final_mm, sg, dpi, titulo, circulos=(), cortes=(), marcas=True):
    destino = pasta("maquina")
    salvar_pdf(os.path.join(destino, nome + ".pdf"), img, dpi, final_mm, sg, cortes=cortes, circulos=circulos,
               marcas=marcas, titulo=titulo)
    previa(img, os.path.join(pasta("previas"), nome + ".jpg"), 1600 if img.width >= img.height else 1000)
    print("  %s: %.0f x %.0f cm" % (nome, final_mm[0] / 10, final_mm[1] / 10))


def letreiro_maquina(largura_mm=1000.0, altura_mm=300.0):
    """Letreiro do alto da máquina: logo, Bob e Mia, 'BOLICHE INFANTIL 3D'."""
    dpi, sg = DPI_GRANDE, 5.0
    W, H = px(largura_mm + 2 * sg, dpi), px(altura_mm + 2 * sg, dpi)
    o = pxf(sg, dpi)
    u = pxf(1, dpi)
    img = degrade((W, H), [(0, "#0E2C66"), (0.6, "#1866B8"), (1, "#2A9BE0")])
    cx, cy = W / 2, o + 130 * u
    raios(img, cx, cy, n=36, alfa=0.10, raio_fade=W * 0.6)
    brilho(img, cx, cy, 380 * u, alfa=0.35)
    estrelinhas(img, 70, (0, 0, W, H), 3 * u, 9 * u, "letreiro", alfa=90,
                evitar=lambda x, y: abs(x - cx) < 300 * u and y < o + 240 * u)
    lg = logo(px(min(560, largura_mm * 0.55), dpi))
    if lg.height > 210 * u:
        lg = redimensionar(lg, altura=210 * u)
    colar(img, lg, cx, o + 18 * u + lg.height / 2)
    f = faixa("BOLICHE INFANTIL 3D", min(430, largura_mm * 0.43) * u, 44 * u, cor_fita="#FF3B4E")
    colar(img, f, cx, o + altura_mm * u - 34 * u)
    alt_p = altura_mm * 0.95 * u
    bob = arte_altura("bob_acenando", alt_p)
    mia = arte_altura("mia_festa", alt_p)
    colar_em(img, bob, o + largura_mm * 0.115 * u - bob.width / 2, o + altura_mm * u + 4 * u - bob.height)
    colar_em(img, mia, o + largura_mm * 0.885 * u - mia.width / 2, o + altura_mm * u + 4 * u - mia.height)
    pin1 = pino_img(95 * u, 10)
    pin2 = pino_img(80 * u, -14)
    colar(img, pin1, o + largura_mm * 0.225 * u, o + altura_mm * u - 58 * u)
    colar(img, pin2, o + largura_mm * 0.775 * u, o + altura_mm * u - 52 * u)
    nome = "letreiro_%dx%dcm" % (largura_mm / 10, altura_mm / 10)
    _salvar_maquina(img, nome, (largura_mm, altura_mm), sg, dpi, "Strike Kids - letreiro da maquina")


def _medalhao(cfg, diametro_mm, dpi):
    p = redondo(cfg, diametro_mm, dpi, sangria_mm=0.0)
    return p.img


def lateral_maquina(largura_mm=600.0, altura_mm=1200.0):
    """Lateral da máquina (em pé): logo, Bob e Mia, '1 OU 2 JOGADORES!', os 4 cenários e a Lazer & Sport."""
    dpi, sg = DPI_GRANDE, 5.0
    W, H = px(largura_mm + 2 * sg, dpi), px(altura_mm + 2 * sg, dpi)
    o = pxf(sg, dpi)
    u = pxf(1, dpi)
    img = degrade((W, H), [(0, "#0E2C66"), (0.35, "#1866B8"), (0.7, "#3DB7EC"), (1, "#FFD43B")])
    cy_raios = o + 560 * u
    raios(img, W / 2, cy_raios, n=30, alfa=0.10, raio_fade=H * 0.55)
    brilho(img, W / 2, cy_raios, 360 * u, alfa=0.35)
    estrelinhas(img, 70, (0, 0, W, o + 700 * u), 3 * u, 9 * u, "lateral", alfa=90)
    lg = logo(px(largura_mm * 0.88, dpi))
    colar(img, lg, W / 2, o + 40 * u + lg.height / 2)
    sub = texto("BOLICHE INFANTIL 3D", 30 * u, "#FFFFFF", MARINHO, 0.16)
    colar(img, sub, W / 2, o + 300 * u)
    dupla = arte_altura("dupla_festa", 470 * u)
    if dupla.width > largura_mm * 0.98 * u:
        dupla = redimensionar(dupla, largura=largura_mm * 0.98 * u)
    colar_em(img, dupla, W / 2 - dupla.width / 2, o + 820 * u - dupla.height)
    f = faixa("1 OU 2 JOGADORES!", largura_mm * 0.74 * u, 62 * u, cor_fita="#FF3B4E")
    colar(img, f, W / 2, o + 845 * u)
    d_mm = (largura_mm - 2 * 26 - 3 * 14) / 4.0
    for i, idx in enumerate([4, 5, 6, 7]):
        med = _medalhao(REDONDOS[idx], d_mm, dpi)
        colar(img, med, o + (26 + d_mm / 2 + i * (d_mm + 14)) * u, o + 990 * u)
    tx = texto("UM CENÁRIO NOVO A CADA RODADA!", 24 * u, "#FFFFFF", MARINHO, 0.16)
    colar(img, tx, W / 2, o + 1078 * u)
    pl = placa_lazer(px(250, dpi))
    colar(img, pl, W / 2, o + 1146 * u)
    nome = "lateral_%dx%dcm" % (largura_mm / 10, altura_mm / 10)
    _salvar_maquina(img, nome, (largura_mm, altura_mm), sg, dpi, "Strike Kids - lateral da maquina")


def _botao_start(diam_px):
    s = 2
    D = int(diam_px * s)
    im = Image.new("RGBA", (D, D), (0, 0, 0, 0))
    d = ImageDraw.Draw(im, "RGBA")
    c = D / 2
    d.ellipse([0, 0, D - 1, D - 1], fill=cor(MARINHO))
    d.ellipse([D * 0.06, D * 0.06, D * 0.94, D * 0.94], fill=cor("#B3122A"))
    d.ellipse([D * 0.10, D * 0.08, D * 0.90, D * 0.86], fill=cor("#FF3B4E"))
    lay, dl = nova_camada(im)
    dl.ellipse([D * 0.2, D * 0.13, D * 0.8, D * 0.42], fill=(255, 255, 255, 80))
    im.alpha_composite(lay)
    tx = texto("START", D * 0.2 / s, "#FFFFFF", MARINHO, 0.14, fonte_nome="titan_one.ttf")
    tx = redimensionar(tx, largura=D * 0.7)
    colar(im, tx, c, c + D * 0.02)
    return redimensionar(im, diam_px, diam_px)


def _camera_icone(larg_px):
    s = 2
    W = int(larg_px * s)
    H = int(W * 0.78)
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im, "RGBA")
    lw = W * 0.04
    d.rounded_rectangle([W * 0.3 - lw, H * 0.04 - lw, W * 0.62 + lw, H * 0.3], radius=int(W * 0.05), fill=cor(MARINHO))
    d.rounded_rectangle([W * 0.3, H * 0.04, W * 0.62, H * 0.3], radius=int(W * 0.04), fill=cor("#5C6B8A"))
    d.rounded_rectangle([0, H * 0.18, W - 1, H - 1], radius=int(W * 0.12), fill=cor(MARINHO))
    d.rounded_rectangle([lw, H * 0.18 + lw, W - 1 - lw, H - 1 - lw], radius=int(W * 0.1), fill=cor("#2E6BFF"))
    lay, dl = nova_camada(im)
    dl.rounded_rectangle([lw * 2, H * 0.18 + lw * 2, W - 1 - lw * 2, H * 0.45], radius=int(W * 0.08), fill=(255, 255, 255, 50))
    im.alpha_composite(lay)
    cx, cy, r = W * 0.5, H * 0.6, H * 0.3
    d.ellipse([cx - r - lw, cy - r - lw, cx + r + lw, cy + r + lw], fill=cor(MARINHO))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=cor("#DDEBFF"))
    d.ellipse([cx - r * 0.7, cy - r * 0.7, cx + r * 0.7, cy + r * 0.7], fill=cor("#14234A"))
    lay, dl = nova_camada(im)
    dl.ellipse([cx - r * 0.45, cy - r * 0.5, cx - r * 0.05, cy - r * 0.15], fill=(255, 255, 255, 200))
    im.alpha_composite(lay)
    d = ImageDraw.Draw(im, "RGBA")
    d.ellipse([W * 0.78, H * 0.28, W * 0.9, H * 0.38], fill=cor("#FFD43B"))
    return redimensionar(im, larg_px, larg_px * 0.78)


PASSOS = [
    ("APERTE\nSTART", "Aperte de novo para\njogar em 2!", "start"),
    ("ESCOLHA\nSEU AMIGO", "Role a bola para o\nBob ou para a Mia", "amigos"),
    ("SORRIA!", "A câmera tira a sua\nfoto para o placar", "foto"),
    ("ROLE A\nBOLA!", "Derrube os pinos e\nfaça STRIKE!", "bola"),
]


def como_jogar(largura_mm=400.0, altura_mm=300.0, com_foto=True):
    dpi, sg = DPI_GRANDE, 5.0
    W, H = px(largura_mm + 2 * sg, dpi), px(altura_mm + 2 * sg, dpi)
    o = pxf(sg, dpi)
    u = pxf(1, dpi)
    img = degrade((W, H), [(0, "#0E2C66"), (0.55, "#1866B8"), (1, "#2A9BE0")])
    raios(img, W / 2, o + 30 * u, n=30, alfa=0.08, raio_fade=W * 0.8)
    estrelinhas(img, 40, (0, 0, W, H), 2 * u, 5 * u, "como_jogar", alfa=70)
    tit = letreiro_altura(["COMO JOGAR"], P_STRIKE, 50 * u, semente="como_jogar")
    colar(img, tit, W / 2, o + 32 * u)
    passos = PASSOS if com_foto else [PASSOS[0], PASSOS[1], PASSOS[3]]
    n = len(passos)
    mx, vao = 14.0, 13.0
    larg_c = (largura_mm - 2 * mx - (n - 1) * vao) / n
    topo, base_c = 66.0, altura_mm - 14.0
    alt_c = base_c - topo
    for i, (titulo, sub, icone) in enumerate(passos):
        x0 = mx + i * (larg_c + vao)
        cart = Image.new("RGBA", (int(larg_c * u), int(alt_c * u)), (0, 0, 0, 0))
        dc = ImageDraw.Draw(cart, "RGBA")
        lw = 2.2 * u
        dc.rounded_rectangle([0, 0, cart.width - 1, cart.height - 1], radius=int(12 * u), fill=cor(MARINHO))
        dc.rounded_rectangle([lw, lw, cart.width - 1 - lw, cart.height - 1 - lw], radius=int(10 * u), fill=cor("#F4FBFF"))
        dc.rounded_rectangle([lw, lw, cart.width - 1 - lw, cart.height * 0.5], radius=int(10 * u), fill=cor("#D9F2FF"))
        cx = cart.width / 2
        ilu_cy = cart.height * 0.28
        if icone == "start":
            colar(cart, _botao_start(min(larg_c * 0.62, 64) * u), cx, ilu_cy)
        elif icone == "amigos":
            b = arte("bob_busto")
            m = arte("mia_busto")
            alvo_l = cart.width * 0.9
            esc = min(alvo_l / (b.width * 0.86 + m.width * 0.86), cart.height * 0.4 / max(b.height, m.height))
            b = redimensionar(b, b.width * esc, b.height * esc)
            m = redimensionar(m, m.width * esc, m.height * esc)
            dupla = Image.new("RGBA", cart.size, (0, 0, 0, 0))
            base_y = cart.height * 0.5
            colar_em(dupla, b, cx - b.width * 0.86, base_y - b.height)
            colar_em(dupla, m, cx - m.width * 0.0, base_y - m.height)
            # recorta no miolo do cartão (sem passar da borda)
            masc = Image.new("L", cart.size, 0)
            ImageDraw.Draw(masc).rounded_rectangle([lw, lw, cart.width - 1 - lw, cart.height - 1 - lw], radius=int(10 * u), fill=255)
            dupla.putalpha(Image.fromarray((np.asarray(dupla)[..., 3].astype(np.float32) * np.asarray(masc) / 255).astype(np.uint8)))
            cart.alpha_composite(dupla)
        elif icone == "foto":
            colar(cart, _camera_icone(min(larg_c * 0.6, 62) * u), cx, ilu_cy)
            dd = ImageDraw.Draw(cart, "RGBA")
            for (ex, ey, er) in ((0.18, 0.12, 5), (0.84, 0.1, 6.5), (0.82, 0.42, 4)):
                estrela_contorno(dd, cart.width * ex, cart.height * ey, er * u, "#FFE14D")
        elif icone == "bola":
            for (px_, py_, h_, g_) in ((0.62, 0.30, 46, -8), (0.78, 0.31, 42, 12), (0.70, 0.22, 40, 0)):
                colar(cart, pino_img(h_ * u, g_), cart.width * px_, cart.height * py_)
            colar(cart, bola_img(34 * u), cart.width * 0.3, cart.height * 0.36)
        dc = ImageDraw.Draw(cart, "RGBA")
        # número
        nr = 13 * u
        dc.ellipse([4 * u, 4 * u, 4 * u + 2 * nr, 4 * u + 2 * nr], fill=cor(MARINHO))
        dc.ellipse([4 * u + lw, 4 * u + lw, 4 * u + 2 * nr - lw, 4 * u + 2 * nr - lw], fill=cor("#FFD43B"))
        num = texto(str(i + 1), 17 * u, MARINHO, None, 0, fonte_nome="titan_one.ttf", sombra=False)
        colar(cart, num, 4 * u + nr, 4 * u + nr + 0.5 * u)
        t = texto(titulo, 19 * u, MARINHO, None, 0, fonte_nome="titan_one.ttf", sombra=False)
        if t.width > cart.width * 0.9:
            t = redimensionar(t, largura=cart.width * 0.9)
        bloco = t.height + 9 * u      # título + vão + subtítulo, no meio da metade de baixo
        s = texto(sub, 12.5 * u, "#24406E", None, 0, fonte_nome="fredoka_600.ttf", sombra=False)
        if s.width > cart.width * 0.9:
            s = redimensionar(s, largura=cart.width * 0.9)
        bloco += s.height
        y0 = cart.height * 0.5 + (cart.height * 0.5 - bloco) * 0.42
        colar(cart, t, cx, y0 + t.height / 2)
        colar(cart, s, cx, y0 + t.height + 9 * u + s.height / 2)
        colar_em(img, cart, o + x0 * u, o + topo * u)
        if i < n - 1:
            dd = ImageDraw.Draw(img, "RGBA")
            ax = o + (x0 + larg_c + vao / 2) * u
            ay = o + (topo + alt_c * 0.28) * u
            r = vao * 0.42 * u
            dd.polygon([(ax - r * 0.6, ay - r), (ax + r * 0.8, ay), (ax - r * 0.6, ay + r)], fill=cor("#FFD43B"))
    nome = "como_jogar_%dx%dcm%s" % (largura_mm / 10, altura_mm / 10, "" if com_foto else "_sem_foto")
    _salvar_maquina(img, nome, (largura_mm, altura_mm), sg, dpi,
                    "Strike Kids - como jogar" + ("" if com_foto else " (sem camera)"))


def _seta(d, cx, cy, r, esp, cor_miolo, contorno):
    """Seta em V de cabeça para baixo (aponta para cima)."""
    pts = [(cx - r, cy + r * 0.55), (cx, cy - r * 0.45), (cx + r, cy + r * 0.55),
           (cx + r, cy + r * 0.55 + esp), (cx, cy - r * 0.45 + esp), (cx - r, cy + r * 0.55 + esp)]
    d.polygon(pts, fill=cor(cor_miolo), outline=cor(MARINHO), width=max(1, int(contorno)))


def faixa_role(largura_mm=600.0, altura_mm=150.0):
    """Faixa para a rampa/pista: ROLE A BOLA AQUI! com setas para a frente."""
    dpi, sg = DPI_GRANDE, 5.0
    W, H = px(largura_mm + 2 * sg, dpi), px(altura_mm + 2 * sg, dpi)
    u = pxf(1, dpi)
    img = degrade((W, H), [(0, "#123A7A"), (1, "#1C7BCB")])
    raios(img, W / 2, H / 2, n=40, alfa=0.07)
    d = ImageDraw.Draw(img)
    r, esp = 26 * u, 13 * u
    for lado in (-1, 1):
        cx = W / 2 + lado * (largura_mm / 2 - 52) * u
        for j, dy in enumerate((-0.2, 0.16)):
            _seta(d, cx, H / 2 + dy * altura_mm * u - esp / 2, r, esp, "#FFD43B" if j == 0 else "#FFB627", 1.6 * u)
    t = letreiro_altura(["ROLE A BOLA AQUI!"], P_STRIKE, altura_mm * 0.7 * u, inclinar=0, estrelas=False)
    if t.width > (largura_mm - 2 * 95) * u:
        t = redimensionar(t, largura=(largura_mm - 2 * 95) * u)
    colar(img, t, W / 2, H / 2)
    nome = "faixa_role_a_bola_%dx%dcm" % (largura_mm / 10, altura_mm / 10)
    _salvar_maquina(img, nome, (largura_mm, altura_mm), sg, dpi, "Strike Kids - faixa ROLE A BOLA AQUI")


def adesivo_start(diametro_mm=100.0):
    dpi, sg = 300, 2.0
    ss = 1
    D = pxf(diametro_mm, dpi)
    lado = int(round(D + 2 * pxf(sg, dpi)))
    c = lado / 2
    R = D / 2
    img = degrade_radial((lado, lado), c, c - R * 0.2, R * 1.1, [(0, "#FF8A9A"), (0.5, "#FF3B4E"), (1, "#A50E24")])
    raios(img, c, c, n=24, alfa=0.10)
    brilho(img, c, c - R * 0.35, R * 0.6, alfa=0.35)
    st = letreiro_largura(["START"], P_STRIKE, R * 1.45, inclinar=0, estrelas=False)
    colar(img, st, c, c + R * 0.08)
    ap = letreiro_altura(["APERTE"], ["#FFFFFF", "#FFFFFF", "#D6E6FF"], R * 0.26, inclinar=0, estrelas=False)
    img.alpha_composite(no_arco(ap, (lado, lado), c, c, R * 0.72, cima=True))
    d = ImageDraw.Draw(img, "RGBA")
    for (ang, rr) in ((120, 0.06), (90, 0.075), (60, 0.06)):
        a = math.radians(ang)
        estrela_contorno(d, c + math.cos(a) * R * 0.72, c + math.sin(a) * R * 0.72, rr * R, "#FFE14D")
    yy, xx = np.mgrid[0:lado, 0:lado].astype(np.float32)
    r = np.hypot(xx - c, yy - c)
    u = R / 50.0
    img.alpha_composite(camada((lado, lado), (255, 255, 255), np.clip(r - (R - 4.2 * u) + 0.5, 0, 1) * np.clip((R - 2.4 * u) - r + 0.5, 0, 1)))
    img.alpha_composite(camada((lado, lado), cor(MARINHO), np.clip(r - (R - 2.4 * u) + 0.5, 0, 1)))
    a = np.asarray(img).copy()
    a[..., 3] = (a[..., 3] * np.clip((R + pxf(sg, dpi)) - r + 0.5, 0, 1)).astype(np.uint8)
    img = Image.fromarray(a, "RGBA")
    del ss
    nome = "aperte_start_%dcm" % (diametro_mm / 10)
    final = (diametro_mm, diametro_mm)
    _salvar_maquina(img, nome, final, sg, dpi, "Strike Kids - APERTE START (redondo)",
                    circulos=[(diametro_mm / 2, diametro_mm / 2, diametro_mm / 2)], marcas=False)


def adesivo_ficha(largura_mm=100.0, altura_mm=50.0):
    dpi, sg = 300, 2.0
    W, H = px(largura_mm + 2 * sg, dpi), px(altura_mm + 2 * sg, dpi)
    o = pxf(sg, dpi)
    u = pxf(1, dpi)
    img = degrade((W, H), [(0, "#FFE680"), (1, "#FFB627")])
    raios(img, W * 0.2, H / 2, n=20, alfa=0.12)
    d = ImageDraw.Draw(img, "RGBA")
    # ficha (moeda) com seta
    cx, cy, r = o + 20 * u, H / 2, 13 * u
    d.ellipse([cx - r - 1.2 * u, cy - r - 1.2 * u, cx + r + 1.2 * u, cy + r + 1.2 * u], fill=cor(MARINHO))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=cor("#FFD43B"))
    d.ellipse([cx - r * 0.72, cy - r * 0.72, cx + r * 0.72, cy + r * 0.72], outline=cor("#E08A00"), width=int(1.2 * u))
    estrela(d, cx, cy, r * 0.5, r * 0.22, cor("#E08A00"))
    t = texto("INSIRA\nA FICHA", 11 * u, MARINHO, None, 0, fonte_nome="titan_one.ttf", sombra=False)
    if t.width > 58 * u:
        t = redimensionar(t, largura=58 * u)
    colar(img, t, o + 66 * u, H / 2)
    # corte: retângulo de cantos redondos (polígono)
    rr = 6.0
    corte = []
    for (qx, qy, a0) in ((largura_mm - rr, rr, -90), (largura_mm - rr, altura_mm - rr, 0), (rr, altura_mm - rr, 90), (rr, rr, 180)):
        for k in range(10):
            a = math.radians(a0 + 9 * k)
            corte.append((qx + rr * math.cos(a), qy + rr * math.sin(a)))
    nome = "insira_a_ficha_%dx%dcm" % (largura_mm / 10, altura_mm / 10)
    _salvar_maquina(img, nome, (largura_mm, altura_mm), sg, dpi, "Strike Kids - INSIRA A FICHA", cortes=[corte], marcas=False)


def maquina():
    letreiro_maquina()
    lateral_maquina()
    como_jogar()
    como_jogar(com_foto=False)
    faixa_role()
    adesivo_start()
    adesivo_ficha()


def main():
    partes = sys.argv[1:] or ["cartela", "redondos", "individuais", "maquina"]
    for p in partes:
        print("== " + p)
        {"cartela": cartela_recortados, "redondos": cartela_redondos, "individuais": individuais, "maquina": maquina}[p]()


if __name__ == "__main__":
    main()
