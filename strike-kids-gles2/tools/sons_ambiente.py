# -*- coding: utf-8 -*-
"""
SONS DE AMBIENTE DAS FASES (6.9) — sintetizados do zero (só numpy), fofos e
curtos, como os outros sons do jogo (sons/*.wav, 44100 Hz, mono, 16 bits):

    amb_baleia    canto da baleia fofinha ("uuu-ôô"), com eco de água
    amb_ptero     "kii-kii!" do pterodáctilo
    amb_dino      "rawr~" de dinossaurinho (fofo, nada de medo)
    amb_vulcao    ronco do vulcão com bolhas de lava
    amb_passaros  passarinhos da selva
    amb_carrossel caixinha de música do carrossel
    amb_ovni      "uuu-uuu" do disco voador
    amb_estrela   brilhinho das estrelas
    amb_bolhas    bolhas subindo
    amb_peixe     "blub blub" dos peixinhos

    python3 -I tools/sons_ambiente.py [nome ...]

O jogo toca cada um quando o bicho/objeto age na tela (Temas: o dino
levanta a cabeça e ruge, o vulcão treme e solta fumaça...), saindo do lado
em que ele está (AudioStreamPlayer3D) — ver Temas._sons_ambiente.
"""
import os
import sys
import wave

import numpy as np

SR = 44100
RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
TAU = 2.0 * np.pi



def n_of(s):
    return int(round(s * SR))


def tt(n):
    return np.arange(n) / SR


def env(n, pts):
    """Envelope por pontos (tempo s, valor)."""
    return np.interp(tt(n), [p[0] for p in pts], [p[1] for p in pts])


def fase(f):
    """Fase de uma frequência que varia (Hz por amostra)."""
    return TAU * np.cumsum(f) / SR


def bp(f, fc, oit):
    return np.exp(-0.5 * (np.log2(np.maximum(f, 1.0) / fc) / oit) ** 2)


def lp(f, fc, ordem=2):
    return 1.0 / np.sqrt(1.0 + (f / fc) ** (2 * ordem))


def hp(f, fc, ordem=2):
    return 1.0 / np.sqrt(1.0 + (fc / np.maximum(f, 1e-3)) ** (2 * ordem))


def filtro(x, ganho, folga=0.3):
    n = len(x)
    m = n + n_of(folga)
    X = np.fft.rfft(x, m)
    g = ganho(np.fft.rfftfreq(m, 1.0 / SR))
    return np.fft.irfft(X * g, m)[:n]


def harm(f, partes):
    """Soma de harmônicos de uma frequência que varia: partes = [(k, amp)]."""
    ph = fase(f)
    y = np.zeros(len(f))
    for k, a in partes:
        ok = (f * k < 0.45 * SR).astype(float)
        y += a * np.sin(ph * k) * ok
    return y


def suaviza(pts, n):
    """Curva suave (cosseno) passando pelos pontos (tempo, valor)."""
    t = tt(n)
    ts = np.array([p[0] for p in pts])
    vs = np.array([p[1] for p in pts])
    i = np.clip(np.searchsorted(ts, t) - 1, 0, len(ts) - 2)
    u = np.clip((t - ts[i]) / np.maximum(ts[i + 1] - ts[i], 1e-6), 0, 1)
    u = 0.5 - 0.5 * np.cos(np.pi * u)
    return vs[i] + (vs[i + 1] - vs[i]) * u


def eco(x, atrasos, ganhos, cauda=0.0):
    y = np.concatenate([x, np.zeros(n_of(cauda))])
    out = y.copy()
    for a, g in zip(atrasos, ganhos):
        d = n_of(a)
        out[d:] += g * y[:len(y) - d]
    return out


def reverb(x, tamanho=0.6, mistura=0.35, cauda=1.0, brilho=3500.0):
    """Reverb simples: vários ecos espalhados, que vão sumindo."""
    r = np.random.default_rng(7)
    y = np.concatenate([x, np.zeros(n_of(cauda))])
    w = np.zeros_like(y)
    for _ in range(18):
        a = r.uniform(0.02, tamanho)
        d = n_of(a)
        g = 0.55 * np.exp(-a / (tamanho * 0.45)) * r.choice([-1, 1])
        w[d:] += g * y[:len(y) - d]
    w = filtro(w, lambda f: lp(f, brilho, 1))
    return y * (1 - mistura) + w * mistura


def fade(x, a=0.005, b=0.08):
    x = x.copy()
    na, nb = max(1, n_of(a)), max(1, n_of(b))
    x[:na] *= np.linspace(0, 1, na)
    x[-nb:] *= np.linspace(1, 0, nb) ** 2
    return x


def normaliza(x, pico=0.7):
    return x / (np.max(np.abs(x)) + 1e-9) * pico


# ------------------------------------------------------------------ os sons
def baleia():
    """Duas notas cantadas e escorregadas ("uuu-ôôô"), com vibrato, vogal
    redondinha e eco de água."""
    partes = []
    for ini, dur, pts in [(0.0, 1.35, [(0, 230), (0.35, 330), (0.8, 410), (1.35, 340)]),
                          (1.55, 1.1, [(0, 390), (0.5, 300), (1.1, 255)])]:
        n = n_of(dur)
        f = suaviza(pts, n) * (1.0 + 0.018 * np.sin(TAU * 5.2 * tt(n)) * np.clip(tt(n) / 0.4, 0, 1))
        y = harm(f, [(1, 1.0), (2, 0.55), (3, 0.28), (4, 0.12), (5, 0.06)])
        # vogal "u-o": formantes que passeiam
        y = filtro(y, lambda fr: 0.25 + bp(fr, 420, 0.7) + 0.6 * bp(fr, 950, 0.5))
        y *= env(n, [(0, 0), (0.18, 1), (dur - 0.35, 0.85), (dur, 0)])
        partes.append((ini, y))
    total = np.zeros(n_of(2.8))
    for ini, y in partes:
        i = n_of(ini)
        total[i:i + len(y)] += y[:len(total) - i]
    total = filtro(total, lambda f: lp(f, 2600, 2) * hp(f, 120, 1))
    return reverb(total, tamanho=0.5, mistura=0.42, cauda=1.2, brilho=2200)


def ptero():
    """ "Kii-kii!": dois piados curtos que sobem, com um pouco de rouquidão."""
    total = np.zeros(n_of(0.95))
    r = np.random.default_rng(3)
    for k, (ini, base) in enumerate([(0.0, 1250.0), (0.26, 1380.0)]):
        dur = 0.2
        n = n_of(dur)
        f = suaviza([(0, base), (0.07, base * 1.55), (0.2, base * 1.2)], n)
        y = harm(f, [(1, 1.0), (2, 0.45), (3, 0.2)])
        ruido = filtro(r.standard_normal(n), lambda fr: bp(fr, base * 1.8, 0.6)) * 0.25
        y = (y + ruido) * env(n, [(0, 0), (0.015, 1), (0.12, 0.7), (dur, 0)])
        i = n_of(ini)
        total[i:i + n] += y
    total = filtro(total, lambda fr: bp(fr, 2200, 1.4) + 0.3)
    return eco(total, [0.11, 0.23], [0.25, 0.1], cauda=0.3)


def dino():
    """ "Rawr~" de filhote: voz cheia (dente-de-serra suave) que sobe e cai,
    vogal "a-u", um ronquinho de leve e um "hm!" fofo no fim."""
    dur = 1.0
    n = n_of(dur)
    f = suaviza([(0, 150), (0.18, 215), (0.6, 190), (1.0, 120)], n)
    f = f * (1.0 + 0.03 * np.sin(TAU * 21.0 * tt(n)))       # ronquinho
    y = harm(f, [(k, 1.0 / k) for k in range(1, 14)])
    a = np.clip(tt(n) / dur, 0, 1)
    y = filtro(y, lambda fr: 0.2 + bp(fr, 750, 0.55) + 0.7 * bp(fr, 1250, 0.45) + 0.3 * bp(fr, 2600, 0.4))
    y *= env(n, [(0, 0), (0.08, 1), (0.7, 0.8), (dur, 0)])
    r = np.random.default_rng(5)
    sopro = filtro(r.standard_normal(n), lambda fr: bp(fr, 900, 0.9)) * 0.12 * env(n, [(0, 0), (0.1, 1), (dur, 0)])
    rawr = y + sopro
    m = n_of(0.26)
    fh = suaviza([(0, 230), (0.12, 330), (0.26, 300)], m)
    hm = harm(fh, [(1, 1.0), (2, 0.4), (3, 0.15)]) * env(m, [(0, 0), (0.03, 1), (0.26, 0)])
    total = np.zeros(n_of(1.45))
    total[:n] += rawr
    i = n_of(1.1)
    total[i:i + m] += hm * 0.7
    return reverb(total, tamanho=0.25, mistura=0.18, cauda=0.4)


def vulcao():
    """Ronco grave que cresce e some, com bolhas de lava estourando."""
    dur = 2.3
    n = n_of(dur)
    r = np.random.default_rng(11)
    ronco = filtro(np.cumsum(r.standard_normal(n)), lambda f: lp(f, 110, 3) * hp(f, 25, 2))
    ronco = ronco / (np.max(np.abs(ronco)) + 1e-9)
    ronco *= env(n, [(0, 0), (0.45, 1), (1.5, 0.8), (dur, 0)])
    ronco *= 1.0 + 0.25 * np.sin(TAU * 7.0 * tt(n))
    total = ronco
    for k in range(7):
        ini = r.uniform(0.3, 1.9)
        m = n_of(0.09)
        fb = suaviza([(0, 320 + 60 * k % 3), (0.09, 110)], m)
        b = np.sin(fase(fb)) * env(m, [(0, 0), (0.005, 1), (0.09, 0)])
        i = n_of(ini)
        total[i:i + m] += b * 0.5
    return total


def passaros():
    """Passarinhos da selva: "piu-piu" e um canto de duas notas lá longe."""
    total = np.zeros(n_of(1.7))
    for ini, f0, f1, dur, g in [(0.0, 2600, 3600, 0.09, 1.0), (0.14, 2700, 3700, 0.09, 0.9),
                                (0.55, 3400, 2500, 0.16, 0.8), (0.95, 1500, 1500, 0.18, 0.5),
                                (1.2, 1200, 1200, 0.22, 0.5)]:
        n = n_of(dur)
        f = suaviza([(0, f0), (dur, f1)], n)
        y = harm(f, [(1, 1.0), (2, 0.15)]) * env(n, [(0, 0), (0.01, 1), (dur * 0.6, 0.6), (dur, 0)])
        i = n_of(ini)
        total[i:i + n] += y * g
    return reverb(total, tamanho=0.3, mistura=0.25, cauda=0.4)


def sino(f, dur, tau=0.6):
    n = n_of(dur)
    t = tt(n)
    y = np.zeros(n)
    for k, a, d in [(1.0, 1.0, 1.0), (2.76, 0.35, 0.45), (5.4, 0.15, 0.25), (8.93, 0.06, 0.15)]:
        y += a * np.sin(TAU * f * k * t) * np.exp(-t / (tau * d))
    return y * np.minimum(1.0, t / 0.002)


def carrossel():
    """Caixinha de música do carrossel (valsinha em dó maior)."""
    nota = {"C5": 523.25, "D5": 587.33, "E5": 659.25, "F5": 698.46, "G5": 783.99, "A5": 880.0,
            "B5": 987.77, "C6": 1046.5, "G4": 392.0, "E6": 1318.5, "D6": 1174.7}
    melodia = ["E5", "G5", "C6", "B5", "G5", "E5", "F5", "A5", "D6", "C6", "A5", "F5",
               "G5", "E5", "C5", "D5", "B5", "G5", "C6"]
    passo = 0.19
    total = np.zeros(n_of(passo * len(melodia) + 1.2))
    for k, nm in enumerate(melodia):
        y = sino(nota[nm], 1.0, 0.5) * (0.9 if k % 3 == 0 else 0.65)
        i = n_of(k * passo)
        total[i:i + len(y)] += y
        if k % 3 == 0:     # o baixinho da valsa
            b = sino(nota["C5"] / 2 if k % 6 == 0 else nota["G4"] / 2, 0.6, 0.3) * 0.35
            total[i:i + len(b)] += b
    return reverb(total, tamanho=0.3, mistura=0.2, cauda=0.3)


def ovni():
    """ "Uuu-uuu" de disco voador (teremim) e um brilhinho no fim."""
    dur = 1.6
    n = n_of(dur)
    f = suaviza([(0, 520), (0.5, 880), (0.9, 640), (1.3, 920), (1.6, 700)], n)
    f = f * (1.0 + 0.05 * np.sin(TAU * 7.5 * tt(n)))
    y = harm(f, [(1, 1.0), (2, 0.12)]) * env(n, [(0, 0), (0.12, 1), (1.3, 0.8), (dur, 0)])
    total = np.zeros(n_of(2.1))
    total[:n] += y
    for k, fr in enumerate([1568.0, 2093.0, 2637.0]):
        s = sino(fr, 0.5, 0.25) * 0.35
        i = n_of(1.25 + k * 0.07)
        total[i:i + len(s)] += s[:len(total) - i]
    return reverb(total, tamanho=0.4, mistura=0.3, cauda=0.6)


def estrela():
    """Brilhinho das estrelas: arpejo de sininhos agudos."""
    total = np.zeros(n_of(1.6))
    for k, fr in enumerate([1046.5, 1318.5, 1568.0, 2093.0, 2637.0]):
        s = sino(fr, 1.0, 0.35) * (0.8 - 0.1 * k)
        i = n_of(k * 0.075)
        total[i:i + len(s)] += s[:len(total) - i]
    return reverb(total, tamanho=0.5, mistura=0.35, cauda=0.6)


def bolhas():
    """Bolhas subindo: "plim-plop" que sobem de tom."""
    total = np.zeros(n_of(1.3))
    r = np.random.default_rng(13)
    t0 = 0.0
    for k in range(7):
        m = n_of(0.07)
        f0 = r.uniform(350, 700)
        f = f0 * np.exp(np.linspace(0, 1.1, m))
        b = np.sin(fase(f)) * env(m, [(0, 0), (0.004, 1), (0.07, 0)])
        i = n_of(t0)
        total[i:i + m] += b * r.uniform(0.5, 1.0)
        t0 += r.uniform(0.08, 0.2)
    return reverb(total, tamanho=0.3, mistura=0.3, cauda=0.4, brilho=2500)


def peixe():
    """ "Blub blub" dos peixinhos."""
    total = np.zeros(n_of(0.6))
    for ini, f0 in [(0.0, 260.0), (0.2, 300.0)]:
        m = n_of(0.13)
        f = suaviza([(0, f0), (0.06, f0 * 1.3), (0.13, f0 * 0.9)], m)
        b = harm(f, [(1, 1.0), (2, 0.3)]) * env(m, [(0, 0), (0.01, 1), (0.13, 0)])
        i = n_of(ini)
        total[i:i + m] += b
    return reverb(total, tamanho=0.25, mistura=0.3, cauda=0.3, brilho=1800)


SONS = {"amb_baleia": baleia, "amb_ptero": ptero, "amb_dino": dino, "amb_vulcao": vulcao,
        "amb_passaros": passaros, "amb_carrossel": carrossel, "amb_ovni": ovni, "amb_estrela": estrela,
        "amb_bolhas": bolhas, "amb_peixe": peixe}


def gravar(nome, x):
    x = normaliza(fade(x), 0.7)
    caminho = os.path.join(RAIZ, "sons", nome + ".wav")
    with wave.open(caminho, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())
    print("%-14s %.2f s  %s" % (nome, len(x) / SR, caminho))


def main():
    for nome in (sys.argv[1:] or list(SONS)):
        gravar(nome, SONS[nome]())


if __name__ == "__main__":
    main()
