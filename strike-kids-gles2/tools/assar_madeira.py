"""Assa a MADEIRA DO PISO dos jogadores (texturas/madeira.png): tábuas de
maple com veios, emendas e o brilho do verniz, num ladrilho que se repete
sem costura nos dois sentidos.

    python3 -I tools/assar_madeira.py texturas/madeira.png

Na vista da pista o piso ocupa a parte de baixo da tela inteira, pertinho
da câmera: a madeira antiga (1024 de largura, tábuas lisas) aparecia
esticada 2 vezes e borrada. Esta tem 2048 x 2048 e cada tábua (4 cm) dá
~52 pixels — na TV, quase 1 pixel da textura por pixel da tela. Vai como
ETC1 (2 MB na placa de vídeo) e o piso.shader lê UMA vez por pixel, como
antes: mais nítida sem custar quadro nenhum.

O ladrilho cobre 39 tábuas na largura e metade do comprimento da madeira
antiga (piso.shader: escala_uv = 4,2 x 3,2).
"""
import sys

import numpy as np
from PIL import Image

LADO = 2048
TABUAS = 39
SEMENTE = 2027

# cor média da madeira antiga (para o piso não mudar de tom)
MEDIA = np.array([234.5, 195.0, 139.6])
CLARA = np.array([250.0, 214.0, 158.0])
ESCURA = np.array([226.0, 180.0, 120.0])


def borrar_periodico(campo, sigma_y, sigma_x):
    """Desfoque gaussiano que dá a volta nas bordas (o ladrilho emenda)."""
    h, w = campo.shape
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    filtro = np.exp(-2.0 * (np.pi ** 2) * ((fy * sigma_y) ** 2 + (fx * sigma_x) ** 2))
    return np.real(np.fft.ifft2(np.fft.fft2(campo) * filtro))


def principal(saida):
    rnd = np.random.default_rng(SEMENTE)
    y, x = np.mgrid[0:LADO, 0:LADO].astype(np.float64)
    largura = LADO / TABUAS
    k = np.floor(x / largura).astype(int)
    lx = x - k * largura                      # 0..largura dentro da tábua

    # EMENDAS das pontas: cada tábua tem 1 ou 2, em alturas sorteadas; cada
    # pedaço entre emendas é uma tábua diferente (tom próprio)
    emendas = []
    for _ in range(TABUAS):
        n = 1 if rnd.uniform() < 0.75 else 2
        emendas.append(np.sort(rnd.uniform(0, LADO, n)))
    pedaco = np.zeros((LADO, LADO), dtype=int)
    dist_emenda = np.full((LADO, LADO), 1e9)
    lado_emenda = np.zeros((LADO, LADO))
    for t in range(TABUAS):
        col = k == t
        yy = y[col]
        p = np.zeros_like(yy, dtype=int)
        dmin = np.full_like(yy, 1e9)
        sinal = np.zeros_like(yy)
        for e in emendas[t]:
            p += (yy >= e).astype(int)
            for desloc in (-LADO, 0.0, LADO):
                d = yy - (e + desloc)
                perto = np.abs(d) < np.abs(dmin)
                dmin = np.where(perto, d, dmin)
        # o pedaço que dá a volta (depois da última emenda) é o mesmo do começo
        p = np.where(p == len(emendas[t]), 0, p)
        pedaco[col] = t * 4 + p
        dist_emenda[col] = np.abs(dmin)
        lado_emenda[col] = np.sign(dmin)
    tons = rnd.uniform(0.0, 1.0, TABUAS * 4)
    tons = tons[pedaco]
    base = ESCURA[None, None, :] + (CLARA - ESCURA)[None, None, :] * tons[..., None]
    # um pouco mais quente ou mais clara em cada tábua
    calor = rnd.uniform(-0.04, 0.04, TABUAS * 4)[pedaco]
    base[..., 0] *= 1.0 + calor * 0.3
    base[..., 2] *= 1.0 - calor

    # VEIOS: linhas ao longo da tábua, um pouco onduladas (a onda dá a volta
    # inteira no comprimento: emenda sem costura)
    veio = np.zeros((LADO, LADO))
    fase_t = rnd.uniform(0, 2 * np.pi, (TABUAS * 4, 3))
    freq_t = rnd.uniform(2.2, 5.5, (TABUAS * 4, 3))
    onda = np.zeros((LADO, LADO))
    for m in (1, 2, 3, 5):
        a = rnd.uniform(1.0, 3.5) / m
        ph = rnd.uniform(0, 2 * np.pi, TABUAS * 4)[pedaco]
        onda += a * np.sin(2 * np.pi * m * y / LADO + ph)
    u = (lx + onda) / largura
    for i in range(3):
        veio += np.sin(2 * np.pi * freq_t[pedaco, i] * u + fase_t[pedaco, i]) * (0.6 / (i + 1))
    linhas = np.clip((veio - 0.55) / 0.35, 0.0, 1.0)
    # fibras finas: ruído esticado ao longo da tábua
    fibra = borrar_periodico(rnd.normal(0, 1, (LADO, LADO)), 38.0, 0.9)
    fibra /= np.abs(fibra).max()
    luz = 1.0 - 0.1 * linhas + 0.04 * fibra

    # DIVISA entre as tábuas: risquinho escuro, sombrinha ao lado e um fio
    # claro do outro lado (o chanfro pegando luz)
    d_esq = lx
    d_dir = largura - lx
    risco = np.clip(1.6 - np.minimum(d_esq, d_dir), 0.0, 1.0)
    luz *= 1.0 - 0.30 * risco
    luz *= 1.0 - 0.06 * np.exp(-d_esq / 3.0)
    luz *= 1.0 + 0.05 * np.clip(1.0 - np.abs(d_dir - 2.2), 0.0, 1.0)
    # emendas das pontas: o mesmo risco, atravessado
    risco_p = np.clip(1.5 - dist_emenda, 0.0, 1.0)
    luz *= 1.0 - 0.26 * risco_p
    luz *= 1.0 + 0.04 * np.clip(1.0 - np.abs(dist_emenda - 2.0), 0.0, 1.0) * (lado_emenda > 0)

    # VERNIZ: faixas largas de brilho na diagonal (frequências inteiras: o
    # ladrilho emenda)
    brilho = 0.5 + 0.5 * np.sin(2 * np.pi * (2 * x / LADO + 1 * y / LADO))
    luz *= 1.0 + 0.06 * brilho * brilho

    cor = base * luz[..., None]
    cor *= (MEDIA / cor.reshape(-1, 3).mean(0))[None, None, :]
    img = np.clip(cor + 0.5, 0, 255).astype(np.uint8)
    Image.fromarray(img, "RGB").save(saida, optimize=True)
    print("madeira:", saida, img.shape, "média", img.reshape(-1, 3).mean(0).round(1))


if __name__ == "__main__":
    principal(sys.argv[1] if len(sys.argv) > 1 else "texturas/madeira.png")
