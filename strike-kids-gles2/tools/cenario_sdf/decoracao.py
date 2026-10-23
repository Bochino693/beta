# -*- coding: utf-8 -*-
"""
DECORAÇÃO DO PARQUE E PEÇAS SOLTAS (pirulito, árvores, cogumelo, bengala,
presente, rosquinha, nuvem, balão, cupcake, arco-íris, torre, lâmpada) —
as mesmas formas do tools/modelos/modelos.py do Godot 4 (gerar_cenario),
uma função por peça, na finura das fontes (paleta.FINO).
"""
import math

import numpy as np

from paleta import FINO, Paleta
from sdf import (Capsula, CaixaRedonda, CilindroRedondo, ConeRedondo, Elipsoide, Esfera,  # noqa: F401
                 Intersecao, Pintura, SemiEspaco, Toro, gerar_malha, hex_cor, rot_x, rot_y, rot_z, unir)


def gm(forma, lo, hi, passo, cores, pint=()):
    """gerar_malha na finura das fontes."""
    return gerar_malha(forma, lo, hi, passo * FINO, cores, pint)

def _peca_0():
    """pirulito gigante (espiral azul/amarela)"""
    pac = {}
    # --- pirulito gigante (espiral azul/amarela)
    pal = Paleta(cabo=hex_cor("#FFF6E8"), doce=hex_cor("#1E88F0"), listra=hex_cor("#FFD43B"))
    disco = CilindroRedondo((0, 2.0, 0), 0.62, 0.11, 0.1, pal.doce, rot=rot_x(math.pi / 2))
    cabo = Capsula((0, 0, 0), (0, 1.5, 0), 0.06, pal.cabo)

    def espiral(P):
        x, y = P[:, 0], P[:, 1] - 2.0
        r = np.sqrt(x * x + y * y)
        a = np.arctan2(y, x)
        return (np.abs(P[:, 2]) < 0.2) & (r > 0.03) & (np.sin(a * 1.0 + r * 15.0) > 0.25)
    m = gm(disco | cabo, (-0.7, -0.1, -0.2), (0.7, 2.7, 0.2), 0.034, pal.cores, [Pintura(espiral, pal.listra)])
    pac["pirulito"] = m
    return pac

def _peca_1():
    """árvores fofas: verde, laranja (outono) e verde-escura"""
    pac = {}
    # --- árvores fofas: verde, laranja (outono) e verde-escura
    for nome, cor_copa, cor_tronco in (("arvore_verde", "#5ED16A", "#A86B3C"), ("arvore_laranja", "#FFA23A", "#A86B3C"),
                                       ("arvore_escura", "#2FA35A", "#8E5A32")):
        pal = Paleta(tronco=hex_cor(cor_tronco), copa=hex_cor(cor_copa))
        tronco = ConeRedondo((0, 0, 0), (0, 1.3, 0), 0.16, 0.09, pal.tronco)
        rng = np.random.default_rng(len(nome))
        bolas = [Esfera((0, 1.75, 0), 0.62, pal.copa)]
        for _ in range(6):
            a = rng.uniform(0, 2 * math.pi)
            bolas.append(Esfera((0.42 * math.cos(a), 1.65 + rng.uniform(-0.1, 0.35), 0.42 * math.sin(a)), rng.uniform(0.33, 0.45), pal.copa))
        copa = unir(*bolas, k=0.1)
        m = gm(tronco.solda(copa, 0.05), (-1.15, -0.05, -1.15), (1.15, 2.75, 1.15), 0.055, pal.cores)
        pac[nome] = m
    return pac

def _peca_2():
    """cogumelo"""
    pac = {}
    # --- cogumelo
    pal = Paleta(caule=hex_cor("#FFF3DC"), chapeu=hex_cor("#FF4B5C"), pinta=hex_cor("#FFFFFF"))
    caule = ConeRedondo((0, 0, 0), (0, 0.55, 0), 0.2, 0.15, pal.caule)
    chapeu = Intersecao(Elipsoide((0, 0.6, 0), (0.55, 0.42, 0.55), pal.chapeu), SemiEspaco((0, 0.62, 0), (0, -1, 0)), 0.04)

    def pintas(P):
        d = P - np.array([0, 0.6, 0])
        d = d / np.linalg.norm(d, axis=1, keepdims=True)
        out = np.zeros(len(P), dtype=bool)
        for c in ((0, 1, 0), (0.7, 0.5, 0.3), (-0.6, 0.55, 0.5), (0.2, 0.5, -0.8), (-0.5, 0.5, -0.6), (0.6, 0.45, -0.55), (-0.1, 0.55, 0.85), (0.85, 0.45, 0.4)):
            c = np.array(c) / np.linalg.norm(c)
            out |= (d @ c) > 0.965
        return out & (P[:, 1] > 0.66)
    m = gm(caule.solda(chapeu, 0.04), (-0.62, -0.05, -0.62), (0.62, 1.1, 0.62), 0.034, pal.cores, [Pintura(pintas, pal.pinta)])
    pac["cogumelo"] = m
    return pac

def _peca_3():
    """bengala doce (listrada)"""
    pac = {}
    # --- bengala doce (listrada)
    pal = Paleta(branco=hex_cor("#FFFFFF"), vermelho=hex_cor("#FF3B4E"))
    haste = Capsula((0, 0, 0), (0, 1.6, 0), 0.085, pal.branco)
    curva = Intersecao(Toro((0.28, 1.6, 0), 0.28, 0.085, pal.branco, rot=rot_x(math.pi / 2)), SemiEspaco((0, 1.6, 0), (0, -1, 0)))

    def listras(P):
        a = np.arctan2(P[:, 2], P[:, 0])
        return np.sin(P[:, 1] * 22.0 + a * 1.0 + P[:, 0] * 22.0) > 0.2
    m = gm(haste | curva, (-0.15, -0.1, -0.15), (0.7, 2.0, 0.15), 0.024, pal.cores, [Pintura(listras, pal.vermelho)])
    pac["bengala"] = m
    return pac

def _peca_4():
    """caixa de presente"""
    pac = {}
    # --- caixa de presente
    pal = Paleta(caixa=hex_cor("#4FC3F7"), fita=hex_cor("#FFD43B"))
    caixa = CaixaRedonda((0, 0.35, 0), (0.36, 0.35, 0.36), 0.05, pal.caixa)
    tampa = CaixaRedonda((0, 0.72, 0), (0.39, 0.06, 0.39), 0.04, pal.caixa)
    laco1 = Toro((-0.12, 0.83, 0), 0.1, 0.035, pal.fita, rot=rot_z(math.pi / 2 - 0.5) @ rot_y(0.0))
    laco2 = Toro((0.12, 0.83, 0), 0.1, 0.035, pal.fita, rot=rot_z(-math.pi / 2 + 0.5))
    fita_pint = Pintura(lambda P: (np.abs(P[:, 0]) < 0.07) | (np.abs(P[:, 2]) < 0.07), pal.fita)
    m = gm(caixa | tampa | laco1 | laco2, (-0.45, -0.05, -0.45), (0.45, 1.0, 0.45), 0.032, pal.cores, [fita_pint])
    pac["presente"] = m
    return pac

def _peca_5():
    """rosquinha gigante (donut)"""
    pac = {}
    # --- rosquinha gigante (donut)
    pal = Paleta(massa=hex_cor("#E9A55B"), cobertura=hex_cor("#7B4A2E"), conf1=hex_cor("#FFFFFF"), conf2=hex_cor("#FFD43B"), conf3=hex_cor("#4FC3F7"))
    donut = Toro((0, 0.3, 0), 0.5, 0.28, pal.massa, rot=rot_x(math.pi / 2) @ rot_x(-math.pi / 2))
    rng = np.random.default_rng(7)
    conf = rng.normal(size=(140, 3))
    conf /= np.linalg.norm(conf, axis=1, keepdims=True)

    def cobertura(P):
        return P[:, 1] > 0.33 + 0.04 * np.sin(np.arctan2(P[:, 2], P[:, 0]) * 7)

    def confeitos(cor_alvo):
        def f(P):
            q = P - np.array([0, 0.3, 0])
            ang = np.arctan2(q[:, 2], q[:, 0])
            u = np.floor(ang / (2 * math.pi) * 40)
            v = np.floor(np.sqrt(q[:, 0] ** 2 + q[:, 2] ** 2) * 18)
            h = np.sin(u * 12.9898 + v * 78.233) * 43758.5453
            h = h - np.floor(h)
            return cobertura(P) & (P[:, 1] > 0.45) & (h > 0.86) & (np.floor(h * 100) % 3 == cor_alvo)
        return f
    m = gm(donut, (-0.85, -0.05, -0.85), (0.85, 0.65, 0.85), 0.036, pal.cores,
                    [Pintura(cobertura, pal.cobertura), Pintura(confeitos(0), pal.conf1), Pintura(confeitos(1), pal.conf2), Pintura(confeitos(2), pal.conf3)])
    pac["donut"] = m
    return pac

def _peca_6():
    """nuvem de desenho animado (6.4): bolotas redondas bem marcadas (a
    emenda entre elas aparece), a do meio mais alta, e a base reta"""
    pac = {}
    pal = Paleta(nuvem=hex_cor("#FFFFFF"))
    bolas = [Esfera(c, r, pal.nuvem) for c, r in (
        ((0.0, 0.86, 0.0), 0.78), ((-0.92, 0.6, 0.04), 0.55), ((0.97, 0.62, -0.03), 0.58),
        ((-1.58, 0.42, 0.0), 0.38), ((1.66, 0.42, 0.0), 0.4), ((0.38, 0.56, -0.46), 0.5),
        ((-0.42, 0.55, 0.43), 0.5), ((0.52, 0.5, 0.44), 0.45), ((-0.52, 0.5, -0.42), 0.45))]
    nuvem = Intersecao(unir(*bolas, k=0.06), SemiEspaco((0, 0.26, 0), (0, -1, 0)), 0.1)
    m = gm(nuvem, (-2.1, 0.0, -1.1), (2.1, 1.75, 1.1), 0.06, pal.cores)
    pac["nuvem"] = m
    return pac

def _peca_7():
    """balão (branco: o Godot pinta com a cor de cada cópia)"""
    pac = {}
    # --- balão (branco: o Godot pinta com a cor de cada cópia)
    pal = Paleta(balao=hex_cor("#FFFFFF"))
    balao = Elipsoide((0, 0.42, 0), (0.3, 0.36, 0.3), pal.balao).solda(ConeRedondo((0, 0.1, 0), (0, 0.0, 0), 0.06, 0.035, pal.balao), 0.05)
    m = gm(balao, (-0.35, -0.05, -0.35), (0.35, 0.82, 0.35), 0.034, pal.cores)
    pac["balao"] = m
    return pac

def _peca_8():
    """cupcake"""
    pac = {}
    # --- cupcake
    pal = Paleta(forma=hex_cor("#4FC3F7"), bolo=hex_cor("#C98A5A"), creme=hex_cor("#FFF7E6"), cereja=hex_cor("#FF3B4E"))
    forminha = ConeRedondo((0, 0, 0), (0, 0.42, 0), 0.32, 0.42, pal.forma)
    creme = unir(Esfera((0, 0.55, 0), 0.38, pal.creme), Esfera((0, 0.82, 0), 0.25, pal.creme), Esfera((0, 1.0, 0), 0.13, pal.creme), k=0.12)
    cereja = Esfera((0, 1.17, 0), 0.09, pal.cereja)

    def pregas(P):
        a = np.arctan2(P[:, 2], P[:, 0])
        return (P[:, 1] < 0.42) & (np.sin(a * 16) > 0.0)
    pal.cores[pal.forma]  # noqa
    m = gm(forminha.solda(creme, 0.04) | cereja, (-0.5, -0.05, -0.5), (0.5, 1.32, 0.5), 0.034, pal.cores,
                    [Pintura(pregas, pal.bolo)])
    pac["cupcake"] = m
    return pac

def _peca_9():
    """arco-íris (portal no fim da pista): faixas pintadas pelo raio"""
    pac = {}
    # --- arco-íris (portal no fim da pista): faixas pintadas pelo raio
    cores_ai = ["#FF4B5C", "#FF9F2E", "#FFD43B", "#5ED16A", "#4FC3F7", "#2E5BE6"]
    pal = Paleta(**{"c%d" % i: hex_cor(h) for i, h in enumerate(cores_ai)})
    R, r = 3.0, 0.42
    arco = Intersecao(Toro((0, 0, 0), R, r, 0, rot=rot_x(math.pi / 2)), SemiEspaco((0, -0.05, 0), (0, -1, 0)))
    arco = CaixaRedonda((0, 0, 0), (R + r, 0.01, 0.01), 0.005, 0).solda(arco, 0.0) if False else arco

    def faixa(i):
        def f(P):
            rr = np.sqrt(P[:, 0] ** 2 + P[:, 1] ** 2)
            lim0 = R + r - (i + 1) * (2 * r / 6)
            lim1 = R + r - i * (2 * r / 6)
            return (rr >= lim0) & (rr < lim1 + 0.01)
        return f
    m = gm(arco, (-R - r - 0.05, -0.1, -r - 0.05), (R + r + 0.05, R + r + 0.05, r + 0.05), 0.06, pal.cores,
                    [Pintura(faixa(i), i) for i in range(6)])
    pac["arco_iris"] = m
    return pac

def _peca_10():
    """torre de circo (lateral do fim da pista): branca e vermelha, telhado azul"""
    pac = {}
    # --- torre de circo (lateral do fim da pista): branca e vermelha, telhado azul
    pal = Paleta(parede=hex_cor("#FFFFFF"), listra=hex_cor("#E8384F"), telhado=hex_cor("#1E6FE0"), bandeira=hex_cor("#FFD43B"), janela=hex_cor("#0E2A5C"))
    corpo = CilindroRedondo((0, 1.25, 0), 0.55, 1.25, 0.08, pal.parede)
    ameia = CilindroRedondo((0, 2.6, 0), 0.66, 0.14, 0.06, pal.parede)
    telhado = ConeRedondo((0, 2.7, 0), (0, 3.9, 0), 0.62, 0.04, pal.telhado)
    pau = Capsula((0, 3.85, 0), (0, 4.35, 0), 0.02, pal.bandeira)
    bandeira = CaixaRedonda((0.14, 4.22, 0), (0.14, 0.09, 0.012), 0.01, pal.bandeira)

    def listras_torre(P):
        a = np.arctan2(P[:, 2], P[:, 0])
        return (P[:, 1] < 2.45) & (np.sin(a * 6 + P[:, 1] * 4.0) > 0.35)

    def janela(P):
        return (P[:, 2] > 0.3) & (np.abs(P[:, 0]) < 0.14) & (P[:, 1] > 1.55) & (P[:, 1] < 2.0) | \
               (P[:, 2] > 0.3) & (((P[:, 0]) ** 2 + (P[:, 1] - 2.0) ** 2) < 0.14 ** 2)
    m = gm(corpo | ameia | telhado | pau | bandeira, (-0.75, -0.05, -0.75), (0.75, 4.45, 0.75), 0.05, pal.cores,
                    [Pintura(listras_torre, pal.listra), Pintura(janela, pal.janela)])
    pac["torre"] = m
    return pac

def _peca_11():
    """lâmpadas do letreiro (contas pequenas; o alfa guarda a fase do pisca)"""
    pac = {}
    # --- lâmpadas do letreiro (contas pequenas; o alfa guarda a fase do pisca)
    pal = Paleta(lamp=hex_cor("#FFFFFF"))
    m = gm(Esfera((0, 0, 0), 0.07, pal.lamp), (-0.09, -0.09, -0.09), (0.09, 0.09, 0.09), 0.022, pal.cores)
    pac["lampada"] = m
    return pac


PECAS = {}
# nome do objeto -> função que o faz (as árvores saem as três juntas)
PECAS["pirulito"] = _peca_0
PECAS["arvore_verde"] = _peca_1
PECAS["arvore_laranja"] = _peca_1
PECAS["arvore_escura"] = _peca_1
PECAS["cogumelo"] = _peca_2
PECAS["bengala"] = _peca_3
PECAS["presente"] = _peca_4
PECAS["donut"] = _peca_5
PECAS["nuvem"] = _peca_6
PECAS["balao"] = _peca_7
PECAS["cupcake"] = _peca_8
PECAS["arco_iris"] = _peca_9
PECAS["torre"] = _peca_10
PECAS["lampada"] = _peca_11
