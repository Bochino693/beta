# -*- coding: utf-8 -*-
"""
COMERCIAL NARRADO DO STRIKE KIDS
================================

Monta o comercial com a partida gravada pelo proprio jogo (o diretor
godot4/video.gd grava cada quadro em JPG e os sons com o numero do quadro
em sons.json), a narracao (narracao.py: uma frase por arquivo), a musica e
os efeitos do jogo nos quadros certos, legendas e o cartao final (logo,
Bob e Mia, marca Lazer & Sport).

    python3 montar_comercial.py v|h VOZ saida.mp4 --promo PASTA --narracao PASTA
            [--dupla PASTA] [--contato "texto"] [--sem-legenda] [--capa capa.jpg]

    v = vertical 1080x1920 (Reels, TikTok, Shorts, status do WhatsApp)
    h = horizontal 1920x1080 (YouTube, TV, apresentacao)
    VOZ = pf_dora (feminina) ou pm_alex (masculina)

O roteiro (TOMADAS e FALAS) marca cada trecho por um som do jogo (a
"ancora": o 1o strike, o replay, a troca de cenario...), entao o mesmo
roteiro serve para a gravacao vertical e para a horizontal.
"""
import json
import math
import os
import subprocess
import sys
import wave

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
import gerar_adesivos as ga  # noqa: E402  (logo, artes e letreiros do jogo)

RAIZ = ga.RAIZ
SONS = os.path.join(RAIZ, "sons")
FONTES = ga.FONTES
TAXA = 44100
FPS = 30

# --------------------------------------------------------------- roteiro
# (nome, vertical, horizontal, transicao, musica)
#   vertical/horizontal: (gravacao, ancora (som, ocorrencia), de, ate), "="
#   (o mesmo do vertical) ou None (sem esta tomada). 'de' e 'ate' em quadros
#   a partir do quadro da ancora. "promo" = a partida de 1 jogador gravada no
#   formato do video; "dupla" = a de 2 jogadores (gravada em pe: no video
#   deitado ela entra no meio, com o fundo desfocado).
TOMADAS = [
    ("abertura", ("promo", ("whoosh", 0), 9, 54), "=", "corte", "menu"),            # bola rolando para os pinos
    ("logo", ("promo", ("brilho", 1), 6, 111), "=", "flash", "menu"),              # logo + Bob e Mia (parque, espaco)
    ("escolha", ("promo", ("escolha", 0), -28, 34), "=", "flash", "menu"),         # ESCOLHA SEU AMIGO!
    ("sorria", ("dupla", ("tique", 0), -43, 113), ("promo", ("tique", 0), -47, 93), "corte", "menu"),  # SORRIA! 3, 2, 1
    ("jogar", ("promo", ("strike", 1), -132, 28), "=", "flash", "jogo"),           # vez do Bob, bola, STRIKE!
    ("replay", ("promo", ("rolando:on", 2), 1, 108), "=", "corte", "jogo"),        # REPLAY em camera lenta
    ("espaco", ("promo", ("musica:musica_jogo", 0), 8, 70), "=", "flash", "jogo"),  # VIAGEM AO ESPACO!
    ("mar", ("promo", ("brilho", 4), 14, 46), "=", "corte", "jogo"),               # FUNDO DO MAR!
    ("dinos", ("promo", ("brilho", 6), 11, 43), "=", "corte", "jogo"),             # SELVA DOS DINOS!
    ("parque", ("dupla", ("musica:musica_jogo", 0), 8, 48), "=", "corte", "jogo"),  # PARQUE DE DIVERSOES!
    ("modal", ("dupla", ("start", 1), -13, 32), ("promo", ("start", 0), 20, 80), "flash", "jogo"),  # 1 OU 2 JOGADORES
    ("dupla", ("dupla", ("vez", 2), 45, 80), "=", "corte", "jogo"),                # a vez da Mia (2 jogadores)
    ("festa", ("dupla", ("strike", 0), 49, 82), "=", "corte", "jogo"),             # a Mia comemora o strike
    ("fogo1", ("promo", ("strike", 2), 3, 49), "=", "flash", "jogo"),              # STRIKE! PEGANDO FOGO!
    ("fogo2", ("promo", ("rolando:on", 4), 4, 44), "=", "corte", "jogo"),          # a bola com o rastro de fogo
    ("fogo3", ("promo", ("strike", 3), 0, 52), "=", "corte", "jogo"),              # 3 STRIKES SEGUIDOS!
    ("fim", ("promo", ("fim", 0), 18, 106), "=", "flash", "fim"),                  # FIM DE JOGO + classificacao
]
# sem a gravacao de 2 jogadores: estas no lugar (None = sem a tomada)
TROCAS_SEM_DUPLA = {
    "sorria": ("promo", ("tique", 0), -47, 93),
    "parque": ("promo", ("brilho", 1), -36, 2),
    "modal": ("promo", ("start", 0), 20, 80),
    "dupla": None,
    "festa": None,
}
# (frase, tomada, quando): segundos depois do comeco da tomada, ou
# ("termina_em", som, ocorrencia, folga) = a frase acaba 'folga' s depois do som
FALAS = [
    ("abre", "abertura", 0.35),
    ("amigo", "escolha", 0.1),
    ("foto", "sorria", 1.3),
    ("jogar", "jogar", ("termina_em", "strike", 1, 0.45)),
    ("replay", "replay", 0.3),
    ("cenarios", "espaco", 0.05),
    ("amigos", "modal", 0.3),
    ("fogo", "fogo1", 0.15),
    ("ranking", "fim", 0.25),
    ("final", "cartao", 0.45),
    ("marca", "cartao", None),          # logo depois da anterior
]
CARTAO_MIN = 5.6
# altura da legenda (fração da tela) onde o jogo tem botão/quadro no lugar de sempre
LEGENDA_Y = {"v": 0.73, "h": 0.86}
LEGENDA_Y_TOMADA = {"v": {"logo": 0.875, "modal": 0.875},
                    "h": {"sorria": 0.94, "modal": 0.115, "fim": 0.79}}


# ------------------------------------------------------------------ util

def ler_audio(caminho):
    """Lê wav/ogg (ffmpeg) como float32 estéreo 44,1 kHz."""
    bruto = subprocess.run(["ffmpeg", "-v", "quiet", "-i", caminho, "-f", "f32le", "-ac", "2", "-ar", str(TAXA), "-"],
                           capture_output=True, check=True).stdout
    return np.frombuffer(bruto, dtype=np.float32).reshape(-1, 2).copy()


_sons = {}


def som(nome):
    if nome not in _sons:
        _sons[nome] = None
        for ext in (".wav", ".ogg"):
            c = os.path.join(SONS, nome + ext)
            if os.path.exists(c):
                _sons[nome] = ler_audio(c)
                break
    return _sons[nome]


def mudar_tom(a, tom):
    if abs(tom - 1.0) < 0.01:
        return a
    n = int(len(a) / tom)
    x = np.linspace(0, len(a) - 1, n)
    return np.stack([np.interp(x, np.arange(len(a)), a[:, k]) for k in range(2)], -1).astype(np.float32)


def limitar(a, lim):
    """Limitador suave: igual até 80 % do limite, depois curva até o limite."""
    j = lim * 0.8
    m = np.abs(a)
    return np.where(m > j, np.sign(a) * (j + (lim - j) * np.tanh((m - j) / (lim - j))), a).astype(np.float32)


def suave(x):
    x = min(1.0, max(0.0, x))
    return x * x * (3 - 2 * x)


def volta(x):
    """Entrada com um pulinho (passa de 1 e volta)."""
    x = min(1.0, max(0.0, x))
    c1, c3 = 1.70158, 2.70158
    return 1 + c3 * (x - 1) ** 3 + c1 * (x - 1) ** 2


class Gravacao:
    """Quadros (q00000.jpg...) e sons (sons.json) gravados pelo diretor do jogo."""

    def __init__(self, pasta):
        self.pasta = pasta
        d = json.load(open(os.path.join(pasta, "sons.json"), encoding="utf-8"))
        base = next(int(r[0]) for r in d["registro"] if r[1] == "inicio")
        self.eventos = [(int(r[0]) - base, str(r[1]), float(r[2]), float(r[3])) for r in d["registro"] if r[1] != "inicio"]
        self.quadros = int(d["quadros"])
        self.tam = Image.open(self.quadro(0)).size

    def quadro(self, i):
        return os.path.join(self.pasta, "q%05d.jpg" % max(0, min(self.quadros - 1, i)))

    def ancora(self, nome, n):
        lista = [q for q, ev, _, _ in self.eventos if ev == nome]
        if n >= len(lista):
            raise SystemExit("roteiro: o som '%s' nº %d não está em %s (há %d)" % (nome, n, self.pasta, len(lista)))
        return lista[n]

    def rolando(self):
        """Intervalos (quadros) com a bola rolando."""
        out, liga = [], None
        for q, ev, _, _ in self.eventos:
            if ev == "rolando:on":
                liga = q
            elif ev == "rolando:off" and liga is not None:
                out.append((liga, q))
                liga = None
        return out


# --------------------------------------------------------------- imagem

def encaixar(im, W, H):
    """Quadro de outro formato (vertical num vídeo deitado): fundo com o
    próprio quadro ampliado e desfocado, o quadro inteiro no meio."""
    if im.size == (W, H):
        return im
    esc_fundo = max(W / im.width, H / im.height)
    fundo = im.resize((int(im.width * esc_fundo) + 1, int(im.height * esc_fundo) + 1), Image.BILINEAR)
    fundo = fundo.crop(((fundo.width - W) // 2, (fundo.height - H) // 2, (fundo.width - W) // 2 + W, (fundo.height - H) // 2 + H))
    fundo = fundo.resize((W // 8, H // 8), Image.BILINEAR).filter(ImageFilter.GaussianBlur(6)).resize((W, H), Image.BILINEAR)
    fundo = Image.blend(fundo, Image.new("RGB", (W, H), (11, 31, 69)), 0.35)
    esc = min(W / im.width, H / im.height)
    frente = im.resize((int(im.width * esc), int(im.height * esc)), Image.LANCZOS)
    fundo.paste(frente, ((W - frente.width) // 2, (H - frente.height) // 2))
    return fundo


def legenda(texto, W, tam):
    """Legenda: caixa azul-marinho translúcida, letra redonda branca e as
    palavras EM MAIÚSCULAS (STRIKE, REPLAY...) em amarelo."""
    f = ImageFont.truetype(os.path.join(FONTES, "fredoka_700.ttf"), tam)
    sw = max(2, tam // 10)
    tmp = ImageDraw.Draw(Image.new("L", (10, 10)))

    def larg(t):
        return tmp.textlength(t, font=f)
    palavras = texto.split()
    linhas, atual = [], []
    for p in palavras:
        if atual and larg(" ".join(atual + [p])) > W * 0.84:
            linhas.append(atual)
            atual = [p]
        else:
            atual.append(p)
    linhas.append(atual)
    alt = int(tam * 1.22)
    pad_x, pad_y = int(tam * 0.7), int(tam * 0.38)
    lw = max(larg(" ".join(l)) for l in linhas)
    Wc, Hc = int(lw + 2 * pad_x + 2 * sw), int(alt * len(linhas) + 2 * pad_y)
    im = Image.new("RGBA", (Wc, Hc), (0, 0, 0, 0))
    caixa = Image.new("RGBA", (Wc, Hc), (0, 0, 0, 0))
    ImageDraw.Draw(caixa).rounded_rectangle([0, 0, Wc - 1, Hc - 1], radius=int(tam * 0.55), fill=(11, 31, 69, 200))
    im.alpha_composite(caixa)
    d = ImageDraw.Draw(im)
    espaco = larg(" ")
    for i, l in enumerate(linhas):
        x = (Wc - larg(" ".join(l))) / 2
        y = pad_y + i * alt + (alt - tam * 1.0) / 2 - tam * 0.12
        for p in l:
            letras = [c for c in p if c.isalpha()]
            destaque = len(letras) >= 2 and all(c.isupper() for c in letras)
            d.text((x, y), p, font=f, fill=(255, 212, 59, 255) if destaque else (255, 255, 255, 255),
                   stroke_width=sw, stroke_fill=(11, 31, 69, 255))
            x += larg(p) + espaco
    return im


class Cartao:
    """Cartão final animado: raios girando, o logo entra com um pulinho, o
    Bob e a Mia sobem, a frase e a marca Lazer & Sport aparecem com a voz."""

    def __init__(self, W, H, t_frase, t_marca, contato=""):
        self.W, self.H, self.t_frase, self.t_marca = W, H, t_frase, t_marca
        vertical = H > W
        self.v = vertical
        self.fundo = ga.degrade((W, H), [(0, "#0E2C66"), (0.55, "#1866B8"), (1, "#2A9BE0")]).convert("RGBA")
        ga.estrelinhas(self.fundo, 40, (0, 0, W, H), W * 0.006, W * 0.014, "cartao", alfa=90)
        self.c_raios = (W * 0.5, H * 0.33) if vertical else (W * 0.29, H * 0.4)
        cx, cy = self.c_raios
        lado = int(2 * max(math.hypot(x - cx, y - cy) for x in (0, W) for y in (0, H)) * 1.03)
        self.raios = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
        ga.raios(self.raios, lado / 2, lado / 2, n=24, alfa=0.12)
        brilho = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ga.brilho(brilho, self.c_raios[0], self.c_raios[1], min(W, H) * 0.5, alfa=0.45)
        self.brilho = brilho
        self.logo = ga.logo(int(W * (0.84 if vertical else 0.40)))
        self.dupla = ga.arte_altura("dupla_acenando", int(H * (0.36 if vertical else 0.84)))
        if self.dupla.width > W * (0.94 if vertical else 0.5):
            self.dupla = ga.redimensionar(self.dupla, largura=W * (0.94 if vertical else 0.5))
        tam = int(W * (0.056 if vertical else 0.026))
        self.frase = ga.texto("Leve para o seu parque,\nshopping ou buffet infantil!", tam, "#FFFFFF", ga.MARINHO, 0.14)
        self.contato = ga.texto(contato, int(tam * 0.85), "#FFD43B", ga.MARINHO, 0.14) if contato else None
        self.placa = ga.placa_lazer(int(W * (0.5 if vertical else 0.24)))

    def quadro(self, t):
        W, H = self.W, self.H
        im = self.fundo.copy()
        r = self.raios.rotate(-t * 9.0, resample=Image.BILINEAR)
        ga.colar(im, r, *self.c_raios)
        im.alpha_composite(self.brilho)
        # logo: entra com pulinho e respira
        k = volta(t / 0.55) * (1 + 0.012 * math.sin(t * 2 * math.pi / 1.7))
        if k > 0.02:
            lg = self.logo.resize((max(1, int(self.logo.width * k)), max(1, int(self.logo.height * k))), Image.BILINEAR)
            if self.v:
                ga.colar(im, lg, W / 2, H * 0.17)
            else:
                ga.colar(im, lg, W * 0.29, H * 0.3)
        # Bob e Mia sobem
        s = suave((t - 0.2) / 0.6)
        if s > 0:
            dp = self.dupla
            if self.v:
                ga.colar_em(im, dp, W / 2 - dp.width / 2, H * 0.71 - dp.height + (1 - s) * H * 0.35)
            else:
                ga.colar_em(im, dp, W * 0.73 - dp.width / 2 + (1 - s) * W * 0.4, H * 1.0 - dp.height + H * 0.02)
        # frase (com a voz) e contato
        a = suave((t - self.t_frase + 0.1) / 0.35)
        if a > 0:
            fr = self.frase.copy()
            fr.putalpha(Image.fromarray((np.asarray(fr)[..., 3] * a).astype(np.uint8)))
            cx, cy = (W / 2, H * 0.775) if self.v else (W * 0.29, H * 0.62)
            ga.colar(im, fr, cx, cy)
            if self.contato is not None:
                ct = self.contato.copy()
                ct.putalpha(Image.fromarray((np.asarray(ct)[..., 3] * a).astype(np.uint8)))
                ga.colar(im, ct, cx, cy + fr.height * 0.5 + ct.height * 0.8)
        # marca Lazer & Sport
        k2 = volta((t - self.t_marca + 0.15) / 0.45)
        if k2 > 0.02:
            pl = self.placa.resize((max(1, int(self.placa.width * k2)), max(1, int(self.placa.height * k2))), Image.BILINEAR)
            ga.colar(im, pl, *((W / 2, H * 0.915) if self.v else (W * 0.29, H * 0.86)))
        return im.convert("RGB")


# --------------------------------------------------------------- montagem

def main():
    args = sys.argv[1:]
    if len(args) < 3:
        print(__doc__)
        sys.exit(1)
    formato, voz, saida = args[:3]
    opc = {}
    i = 3
    while i < len(args):
        if args[i] in ("--sem-legenda",):
            opc[args[i]] = True
            i += 1
        else:
            opc[args[i]] = args[i + 1]
            i += 2
    W, H = (1080, 1920) if formato == "v" else (1920, 1080)
    grav = {"promo": Gravacao(opc["--promo"])}
    if opc.get("--dupla"):
        grav["dupla"] = Gravacao(opc["--dupla"])
    linhas = {x["chave"]: x for x in json.load(open(os.path.join(opc["--narracao"], "linhas.json"), encoding="utf-8"))[voz]}
    for x in linhas.values():
        x["arquivo"] = os.path.join(opc["--narracao"], os.path.basename(x["arquivo"]))
    tomadas = []
    for nome, fv, fh, trans, mus in TOMADAS:
        fonte = fv if (formato == "v" or fh == "=") else fh
        if fonte is not None and fonte[0] not in grav:
            fonte = TROCAS_SEM_DUPLA.get(nome)
        if fonte is None:
            continue
        g, anc, de, ate = fonte
        tomadas.append((nome, g, anc, de, ate, trans, mus))
    # linha do tempo
    tl, t = [], 0.0
    for nome, g, (ev, n), de, ate, trans, mus in tomadas:
        G = grav[g]
        a = G.ancora(ev, n)
        f0, f1 = a + de, a + ate
        tl.append({"nome": nome, "g": G, "f0": f0, "f1": f1, "t0": t, "n": f1 - f0, "trans": trans, "musica": mus})
        t += (f1 - f0) / FPS
    t_cartao = t
    por_nome = {s["nome"]: s for s in tl}
    # falas
    falas, fim_ant = [], 0.0
    for chave, tomada, quando in FALAS:
        L = linhas[chave]
        if tomada == "cartao":
            t0 = t_cartao + (quando if quando is not None else 0)
        else:
            s = por_nome.get(tomada)
            if s is None:
                continue
            if isinstance(quando, tuple):
                q = s["g"].ancora(quando[1], quando[2])
                t0 = s["t0"] + (q - s["f0"]) / FPS - (L["dur"] - quando[3])
            else:
                t0 = s["t0"] + quando
        if quando is None:
            t0 = fim_ant + 0.3
        t0 = max(t0, fim_ant + 0.18)
        falas.append({"chave": chave, "t": t0, "dur": L["dur"], "L": L, "cartao": tomada == "cartao"})
        fim_ant = t0 + L["dur"]
    dur_cartao = max(CARTAO_MIN, fim_ant - t_cartao + 1.2)
    total = t_cartao + dur_cartao
    n_total = int(round(total * FPS))
    print("roteiro: %d tomadas, %.1f s de jogo + %.1f s de cartão = %.1f s" % (len(tl), t_cartao, dur_cartao, total))
    roteiro = ["ROTEIRO DO COMERCIAL (%s, %dx%d, voz %s) - %.1f s" % ("vertical" if formato == "v" else "horizontal", W, H, voz, total), ""]
    roteiro.append("IMAGENS (tempo no video: o que aparece)")
    descr = {"abertura": "a bola rolando para os pinos (abertura do jogo)", "logo": "logo STRIKE KIDS com o Bob e a Mia",
             "abertura2": "o Bob e a Mia no parque", "escolha": "ESCOLHA SEU AMIGO!", "sorria": "SORRIA! (3, 2, 1, foto)",
             "jogar": "vez do Bob: bola, pinos, STRIKE!", "replay": "REPLAY em camera lenta", "espaco": "VIAGEM AO ESPACO!",
             "mar": "FUNDO DO MAR!", "dinos": "SELVA DOS DINOS!", "parque": "PARQUE DE DIVERSOES!",
             "modal": "QUANTOS VAO JOGAR? (1 ou 2)", "dupla": "2 jogadores: a vez da Mia", "festa": "a Mia comemora",
             "fogo1": "STRIKE! PEGANDO FOGO!",
             "fogo2": "a bola com rastro de fogo", "fogo3": "3 STRIKES SEGUIDOS!", "fim": "FIM DE JOGO + classificacao de hoje"}
    for x in tl:
        roteiro.append("  %5.1f - %5.1f s  %s" % (x["t0"], x["t0"] + x["n"] / FPS, descr.get(x["nome"], x["nome"])))
    roteiro.append("  %5.1f - %5.1f s  cartao final: logo, Bob e Mia, frase e a marca Lazer & Sport" % (t_cartao, total))
    roteiro += ["", "NARRACAO (tempo: frase)"]
    for f in falas:
        print("  %5.2f-%5.2f  %s" % (f["t"], f["t"] + f["dur"], f["L"]["legenda"]))
        roteiro.append("  %5.1f - %5.1f s  %s" % (f["t"], f["t"] + f["dur"], f["L"]["legenda"]))
    with open(os.path.splitext(saida)[0] + "_roteiro.txt", "w", encoding="utf-8") as arq_r:
        arq_r.write("\n".join(roteiro) + "\n")

    # ------------------------------------------------------------ áudio
    trilha_voz = np.zeros((int(total * TAXA) + TAXA, 2), np.float32)
    voz_ativa = np.zeros(len(trilha_voz), np.float32)
    for f in falas:
        a = ler_audio(f["L"]["arquivo"])
        rms = float(np.sqrt(np.mean(a[np.abs(a[:, 0]) > 0.01] ** 2))) if np.any(np.abs(a[:, 0]) > 0.01) else 0.1
        a = limitar(a * (0.16 / max(rms, 1e-4)), 0.95)
        i0 = int(f["t"] * TAXA)
        n = min(len(a), len(trilha_voz) - i0)
        trilha_voz[i0:i0 + n] += a[:n]
        voz_ativa[max(0, i0 - int(0.15 * TAXA)):i0 + n + int(0.25 * TAXA)] = 1.0
    # envelope suave (abaixa a música/efeitos quando a voz fala)
    k = int(0.12 * TAXA)
    env = np.convolve(voz_ativa, np.ones(k) / k, mode="same").astype(np.float32)

    musica = np.zeros_like(trilha_voz)
    blocos = []
    for s in tl:
        if blocos and blocos[-1][0] == s["musica"]:
            blocos[-1][2] = s["t0"] + s["n"] / FPS
        else:
            blocos.append([s["musica"], s["t0"], s["t0"] + s["n"] / FPS])
    blocos[-1][2] = total
    if blocos[-1][0] != "fim":
        blocos.append(["fim", t_cartao, total])
    arquivos = {"menu": "musica_menu", "jogo": "musica_jogo", "fim": "musica_fim"}
    cruz = 0.5
    for j, (m, a0, a1) in enumerate(blocos):
        trilha = som(arquivos[m])
        if trilha is None:
            continue
        ini = a0 - cruz / 2 if j > 0 else 0.0
        fim = a1 + cruz / 2 if j < len(blocos) - 1 else total
        n = int((fim - ini) * TAXA)
        rep = np.tile(trilha, (n // len(trilha) + 1, 1))[:n].copy()
        fi = int(cruz * TAXA)
        if j > 0:
            rep[:fi] *= np.linspace(0, 1, fi)[:, None]
        else:
            rep[:int(0.25 * TAXA)] *= np.linspace(0, 1, int(0.25 * TAXA))[:, None]
        if j < len(blocos) - 1:
            rep[-fi:] *= np.linspace(1, 0, fi)[:, None]
        i0 = int(ini * TAXA)
        n = min(len(rep), len(musica) - i0)
        musica[i0:i0 + n] += rep[:n]
    # fim: a música termina com o vídeo
    fo = int(1.2 * TAXA)
    fim_i = int(total * TAXA)
    musica[fim_i - fo:fim_i] *= np.linspace(1, 0, fo)[:, None]
    musica[fim_i:] = 0

    efeitos = np.zeros_like(trilha_voz)

    def colocar(a, t0, vol):
        i0 = int(t0 * TAXA)
        if a is None or i0 >= len(efeitos):
            return
        if i0 < 0:
            a = a[-i0:]
            i0 = 0
        n = min(len(a), len(efeitos) - i0)
        efeitos[i0:i0 + n] += a[:n] * vol

    rol = som("bola_rolando")
    for s in tl:
        G, f0, f1 = s["g"], s["f0"], s["f1"]
        for q, ev, vol, tom in G.eventos:
            if not (f0 <= q < f1) or ev.startswith("musica:") or ev.startswith("rolando"):
                continue
            colocar(mudar_tom(som(ev), tom) if som(ev) is not None else None, s["t0"] + (q - f0) / FPS, vol * 0.8)
        for (a, b) in G.rolando():
            a2, b2 = max(a, f0), min(b, f1)
            if b2 > a2 and rol is not None:
                n = int((b2 - a2) / FPS * TAXA)
                rep = np.tile(rol, (n // len(rol) + 1, 1))[:n].copy()
                fd = min(len(rep), int(0.08 * TAXA))
                rep[-fd:] *= np.linspace(1, 0, fd)[:, None]
                colocar(rep, s["t0"] + (a2 - f0) / FPS, 0.55)
    # cartão final: brilho + torcida
    colocar(som("brilho"), t_cartao + 0.05, 0.8)
    colocar(som("torcida"), t_cartao + 0.25, 0.35)

    env2 = env[:, None]
    mix = trilha_voz + musica * (0.55 - 0.43 * env2) + efeitos * (0.85 - 0.55 * env2)
    mix = mix[:int(total * TAXA)]
    # volume final: -14 LUFS (medido pelo ffmpeg) e pico abaixo de -1 dB
    tmp_wav = saida + ".trilha.wav"

    def gravar_wav(arr, caminho):
        with wave.open(caminho, "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(TAXA)
            w.writeframes((np.clip(arr, -1, 1) * 32767).astype(np.int16).tobytes())
    pico = float(np.max(np.abs(mix))) or 1.0
    mix = mix / pico * 0.7
    gravar_wav(mix, tmp_wav)
    med = subprocess.run(["ffmpeg", "-hide_banner", "-i", tmp_wav, "-af", "loudnorm=print_format=json", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    try:
        j = json.loads(med[med.rindex("{"):med.rindex("}") + 1])
        ganho = 10 ** ((-14.0 - float(j["input_i"])) / 20)
    except Exception:
        ganho = 1.0
    mix = mix * ganho
    mix = limitar(mix, 0.84)
    gravar_wav(mix, tmp_wav)

    # ------------------------------------------------------------ vídeo
    tam_leg = 54 if formato == "v" else 50
    legs = {}
    if not opc.get("--sem-legenda"):
        for f in falas:
            if not f["cartao"]:
                legs[f["chave"]] = legenda(f["L"]["legenda"], W, tam_leg)
    def y_legenda(tq):
        s = next((x for x in reversed(tl) if x["t0"] <= tq + 1e-6), tl[0])
        return H * LEGENDA_Y_TOMADA[formato].get(s["nome"], LEGENDA_Y[formato])
    t_frase = next((f["t"] for f in falas if f["chave"] == "final"), t_cartao + 0.5) - t_cartao
    t_marca = next((f["t"] for f in falas if f["chave"] == "marca"), t_cartao + 4.5) - t_cartao
    cartao = Cartao(W, H, t_frase, t_marca, opc.get("--contato", ""))
    ff = subprocess.Popen(["ffmpeg", "-y", "-v", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % (W, H), "-r", str(FPS),
                           "-i", "-", "-i", tmp_wav, "-c:v", "libx264", "-preset", "slow", "-crf", "20",
                           "-maxrate", "4500k" if formato == "v" else "6000k", "-bufsize", "9000k", "-pix_fmt", "yuv420p",
                           "-movflags", "+faststart", "-c:a", "aac", "-b:a", "192k", "-shortest", saida], stdin=subprocess.PIPE)
    capa = None
    branco = Image.new("RGB", (W, H), (255, 255, 255))
    for qi in range(n_total):
        tq = qi / FPS
        if tq < t_cartao:
            s = next(x for x in reversed(tl) if x["t0"] <= tq + 1e-6)
            k = int(round((tq - s["t0"]) * FPS))
            im = Image.open(s["g"].quadro(s["f0"] + min(k, s["n"] - 1))).convert("RGB")
            im = encaixar(im, W, H)
            if s["trans"] == "flash" and k < 5:
                im = Image.blend(im, branco, [0.8, 0.55, 0.35, 0.18, 0.07][k])
        else:
            tc = tq - t_cartao
            im = cartao.quadro(tc)
            if tc < 0.2:
                im = Image.blend(im, branco, 0.8 * (1 - tc / 0.2))
            if capa is None and tc >= max(2.0, t_marca + 0.7):
                capa = im.copy()
        # legenda da frase que está tocando
        for f in falas:
            lg = legs.get(f["chave"])
            if lg is None:
                continue
            a0, a1 = f["t"] - 0.1, f["t"] + f["dur"] + 0.35
            prox = [g["t"] for g in falas if g["t"] > f["t"]]
            if prox:
                a1 = min(a1, prox[0] - 0.12)
            if a0 <= tq < a1:
                al = min(1.0, (tq - a0) / 0.12, (a1 - tq) / 0.12)
                lgi = lg if al >= 0.999 else Image.fromarray(
                    np.concatenate([np.asarray(lg)[..., :3], (np.asarray(lg)[..., 3:] * al).astype(np.uint8)], -1), "RGBA")
                base = im.convert("RGBA")
                ga.colar(base, lgi, W / 2, y_legenda(f["t"]))
                im = base.convert("RGB")
        ff.stdin.write(im.tobytes())
    ff.stdin.close()
    ff.wait()
    os.remove(tmp_wav)
    if capa is None:
        capa = cartao.quadro(dur_cartao - 0.1)
    if opc.get("--capa"):
        capa.save(opc["--capa"], quality=92)
    print("comercial: %s (%.1f s, %dx%d, voz %s)" % (saida, total, W, H, voz))


if __name__ == "__main__":
    main()
