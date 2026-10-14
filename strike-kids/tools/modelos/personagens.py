# -*- coding: utf-8 -*-
"""
PERSONAGENS DO STRIKE KIDS: TURBO E ROSI
========================================

Dois robozinhos originais (estilo "herói robô" dos desenhos clássicos):
  * TURBO — menino-robô: corpo branco, short azul-marinho, botas-jato
    vermelhas, topete azul-noite, antena com luz amarela, núcleo azul no peito.
  * ROSI  — menina-robô toda rosinha: cabelo rosa com dois coques, saia rosa,
    botas magenta, antena de coração, núcleo de coração no peito.

Juntas articuladas (robô!): ombro, cotovelo, quadril, joelho, pescoço —
é o que deixa eles jogarem boliche de verdade (passada, balanço do braço,
deslize, pose final).

Cor do vértice: RGB = cor (sRGB); ALFA = 1 rosto (pele onde o rosto é
desenhado), 0.5 = luz (brilha), 0 = normal.
"""
import math
import os

import numpy as np

from sdf import (Capsula, CilindroRedondo, ConeRedondo, Deslocada, Elipsoide, Esfera,
                 Intersecao, Pacote, Pintura, SemiEspaco, Toro, coracao_2d, estrela_2d,
                 gerar_malha, hex_cor, rot_x, rot_y, rot_z, unir)

# ------------------------------------------------------------- juntas
QUADRIL_Y = 0.40
PESCOCO_Y = 0.72
OMBRO = np.array([0.205, 0.645, 0.0])
COTOVELO = np.array([0.248, 0.515, 0.004])
MAO = np.array([0.282, 0.383, 0.016])
QUADRIL = np.array([0.09, 0.40, 0.0])
JOELHO = np.array([0.09, 0.232, 0.0])

ROSTO = 1.0
LUZ = 0.5
PASSO = 0.0108


class Paleta:
    def __init__(self, **cores):
        self.nomes = list(cores.keys())
        self.cores = [cores[n] for n in self.nomes]

    def __getattr__(self, nome):
        nomes = self.__dict__.get("nomes", [])
        if nome in nomes:
            return nomes.index(nome)
        raise AttributeError(nome)


def alfa_por_cor(pal):
    alfas = np.array([c[3] for c in pal.cores], dtype=np.float32)

    def f(P, cids):
        return alfas[cids]
    return f


def espelho(v, s):
    return np.array([v[0] * s, v[1], v[2]])


# ------------------------------------------------------------- cabeça

def cabeca_base(pele):
    cranio = Elipsoide((0, 0.985, 0), (0.305, 0.285, 0.285), pele)
    bochechas = Elipsoide((0, 0.915, 0.03), (0.268, 0.212, 0.245), pele)
    nariz = Elipsoide((0, 0.927, 0.272), (0.036, 0.028, 0.026), pele)
    return cranio.solda(bochechas, 0.07).solda(nariz, 0.016)


def plano_cabelo(frente_y, tras_y, cor):
    dy, dz = tras_y - frente_y, -0.6
    n = np.array([0.0, -dz, dy])
    n = n / np.linalg.norm(n)
    if n[1] > 0:
        n = -n
    return SemiEspaco((0, frente_y, 0.3), n, cor)


def orelhas_robo(pal, metal, anel):
    """Discos de 'alto-falante' no lugar das orelhas, com anel que brilha."""
    formas = []
    for s in (1, -1):
        disco = CilindroRedondo((s * 0.288, 0.94, -0.012), 0.072, 0.032, 0.016, metal, rot=rot_z(math.pi / 2))
        formas.append(disco)
    pint = Pintura(lambda P: (np.abs(P[:, 0]) > 0.312) & ((P[:, 1] - 0.94) ** 2 + (P[:, 2] + 0.012) ** 2 > 0.032 ** 2)
                   & ((P[:, 1] - 0.94) ** 2 + (P[:, 2] + 0.012) ** 2 < 0.054 ** 2), anel)
    return formas, pint


# ------------------------------------------------------------- membros

def braco(s, cores):
    """Retorna (superior, inferior). s = +1 esquerda do personagem (+x)."""
    om, co, mao = espelho(OMBRO, s), espelho(COTOVELO, s), espelho(MAO, s)
    ombreira = Esfera(om + np.array([s * 0.012, -0.012, 0]), 0.074, cores["ombro"])
    sup = Capsula(om, co, 0.047, cores["membro"])
    junta = Esfera(co, 0.052, cores["junta"])
    superior = ombreira.solda(sup, 0.03) | junta
    pulso = mao + np.array([s * -0.004, 0.05, -0.004])
    inf = Capsula(co, pulso, 0.045, cores["membro"])
    punho = Toro(pulso + np.array([0, 0.005, 0]), 0.046, 0.017, cores["punho"],
                 rot=rot_z(-s * 0.25))
    luva = Esfera(mao, 0.064, cores["luva"])
    polegar = Elipsoide(mao + np.array([s * -0.028, 0.022, 0.05]), (0.026, 0.032, 0.026), cores["luva"])
    inferior = inf.solda(luva, 0.03).solda(polegar, 0.012) | punho
    return superior, inferior


def perna(s, cores, menina):
    q, j = espelho(QUADRIL, s), espelho(JOELHO, s)
    r = 0.05 if menina else 0.054
    coxa = Capsula(q, j, r, cores["membro"])
    junta = Esfera(j, 0.058, cores["junta"])
    superior = coxa | junta
    tornozelo = np.array([q[0], 0.11, 0.0])
    canela = Capsula(j, tornozelo, r, cores["membro"])
    cano = CilindroRedondo(np.array([q[0], 0.135, 0.0]), r + 0.024, 0.05, 0.018, cores["bota"])
    pe = Elipsoide((q[0], 0.06, 0.035), (0.08, 0.066, 0.122) if not menina else (0.074, 0.062, 0.112), cores["bota"])
    bota = cano.solda(pe, 0.04)
    inferior = canela.solda(bota, 0.02)
    pint = [
        Pintura(lambda P: P[:, 1] < 0.024, cores["sola"]),
        Pintura(lambda P: (P[:, 1] > 0.168) & (P[:, 1] < 0.186), cores["faixa"]),
        # bocal do jato (sola)
        Pintura(lambda P, x=q[0]: (P[:, 1] < 0.03) & ((P[:, 0] - x) ** 2 + (P[:, 2] - 0.02) ** 2 < 0.04 ** 2), cores["jato"]),
    ]
    return superior, inferior, pint


# ------------------------------------------------------------- TURBO

def turbo():
    pal = Paleta(
        pele=hex_cor("#F9C9A6", ROSTO),
        cabelo=hex_cor("#1C2255"),
        reflexo=hex_cor("#4D63D6"),
        metal=hex_cor("#C9D3E8"),
        anel=hex_cor("#3CE7FF", LUZ),
        antena=hex_cor("#9AA7C7"),
        luz_antena=hex_cor("#FFE14D", LUZ),
        corpo=hex_cor("#F6F8FF"),
        nucleo=hex_cor("#38E1FF", LUZ),
        aro=hex_cor("#8E9BBE"),
        short=hex_cor("#243184"),
        cinto=hex_cor("#FFD43B"),
        junta=hex_cor("#A9B5D1"),
        punho=hex_cor("#FF4B3E"),
        bota=hex_cor("#FF3D3D"),
        faixa=hex_cor("#FFD43B"),
        sola=hex_cor("#3A3F5C"),
        jato=hex_cor("#6E7698"),
    )
    cab = cabeca_base(pal.pele)
    orelhas, pint_orelha = orelhas_robo(pal, pal.metal, pal.anel)
    # cabelo azul-noite espetado (estilo herói de desenho): casco + mechas
    # pontudas para cima/trás e uma franjinha pontuda na testa
    casco = Intersecao(Elipsoide((0, 1.0, -0.02), (0.322, 0.305, 0.305), pal.cabelo),
                       plano_cabelo(1.12, 0.80, pal.cabelo), 0.02)
    pontas = []
    for (b0, b1, ra) in (
            ((0.0, 1.2, 0.02), (0.02, 1.43, -0.06), 0.085),     # topete central para cima
            ((0.13, 1.2, -0.02), (0.27, 1.38, -0.16), 0.075),   # laterais para cima/trás
            ((-0.13, 1.2, -0.02), (-0.27, 1.38, -0.16), 0.075),
            ((0.0, 1.14, -0.2), (0.0, 1.3, -0.4), 0.08),        # nuca para trás
            ((0.22, 1.06, -0.15), (0.38, 1.12, -0.3), 0.065),
            ((-0.22, 1.06, -0.15), (-0.38, 1.12, -0.3), 0.065),
            ((0.07, 1.13, 0.22), (0.12, 1.03, 0.33), 0.05),     # franja pontuda
            ((-0.07, 1.13, 0.22), (-0.13, 1.04, 0.32), 0.05),
            ((0.0, 1.15, 0.22), (-0.01, 1.05, 0.34), 0.05)):
        pontas.append(ConeRedondo(b0, b1, ra, 0.012, pal.cabelo))
    cabelo = unir(casco, *pontas, k=0.045)
    reflexo = Pintura(lambda P: (P[:, 1] > 1.2) & (np.abs(P[:, 0] + 0.05) < 0.018 + (P[:, 1] - 1.2) * 0.05) & (P[:, 2] > -0.02) & (P[:, 2] < 0.2), pal.reflexo)
    antena = Capsula((0.1, 1.25, -0.14), (0.16, 1.42, -0.2), 0.012, pal.antena)
    bolinha = Esfera((0.165, 1.44, -0.205), 0.036, pal.luz_antena)
    cabeca = unir(cab, cabelo, k=0.012)
    for o in orelhas:
        cabeca = cabeca.solda(o, 0.01)
    cabeca = cabeca | antena | bolinha
    pint_cab = [pint_orelha, reflexo]

    cores = dict(membro=pal.corpo, ombro=pal.corpo, junta=pal.junta, punho=pal.punho, luva=pal.corpo,
                 bota=pal.bota, faixa=pal.faixa, sola=pal.sola, jato=pal.jato)
    peito = Elipsoide((0, 0.57, 0), (0.182, 0.172, 0.142), pal.corpo)
    ombros = Capsula((-0.145, 0.648, 0), (0.145, 0.648, 0), 0.066, pal.corpo)
    short = Elipsoide((0, 0.425, 0), (0.172, 0.1, 0.134), pal.short)
    cinto = Toro((0, 0.478, 0), 0.165, 0.021, pal.cinto)
    pescoco = Capsula((0, 0.66, 0), (0, 0.78, 0), 0.055, pal.metal)
    tronco = peito.solda(ombros, 0.06).solda(short, 0.02).solda(pescoco, 0.015) | cinto
    pint_tronco = [
        Pintura(lambda P: (P[:, 2] > 0.06) & (P[:, 0] ** 2 + (P[:, 1] - 0.585) ** 2 < 0.07 ** 2), pal.aro),
        Pintura(lambda P: (P[:, 2] > 0.06) & (P[:, 0] ** 2 + (P[:, 1] - 0.585) ** 2 < 0.05 ** 2), pal.nucleo),
        Pintura(lambda P: (P[:, 2] > 0.04) & (np.abs(P[:, 0]) < 0.022) & (P[:, 1] > 0.488) & (P[:, 1] < 0.53), pal.aro),
    ]
    return pal, (cabeca, pint_cab), (tronco, pint_tronco), cores, False


# ------------------------------------------------------------- ROSI

def rosi():
    pal = Paleta(
        pele=hex_cor("#FCCDBF", ROSTO),
        cabelo=hex_cor("#F7509F"),
        reflexo=hex_cor("#FF8DC4"),
        metal=hex_cor("#F3D7EA"),
        anel=hex_cor("#FF5FC8", LUZ),
        antena=hex_cor("#E7B6D6"),
        luz_antena=hex_cor("#FF3D8F", LUZ),
        corpo=hex_cor("#FFF6FB"),
        vestido=hex_cor("#FF6FB5"),
        saia=hex_cor("#FF86C3"),
        barra=hex_cor("#FFFFFF"),
        nucleo=hex_cor("#FF2E8A", LUZ),
        gola=hex_cor("#FFFFFF"),
        prendedor=hex_cor("#FFD43B"),
        estrela=hex_cor("#FFD43B"),
        junta=hex_cor("#E9C0DA"),
        punho=hex_cor("#C24BFF"),
        bota=hex_cor("#C24BFF"),
        faixa=hex_cor("#FFFFFF"),
        sola=hex_cor("#5A3A73"),
        jato=hex_cor("#8E74A8"),
    )
    cab = cabeca_base(pal.pele)
    orelhas, pint_orelha = orelhas_robo(pal, pal.metal, pal.anel)
    # cabelo rosa com franjinha e maria-chiquinha (duas caudas com laço)
    casco = Intersecao(Elipsoide((0, 0.99, -0.025), (0.318, 0.302, 0.302), pal.cabelo),
                       plano_cabelo(1.095, 0.76, pal.cabelo), 0.025)
    caudas, prendedores = [], []
    for s in (1, -1):
        raiz = Esfera((s * 0.255, 1.13, -0.1), 0.085, pal.cabelo)
        cauda = Elipsoide((s * 0.37, 0.985, -0.12), (0.095, 0.185, 0.105), pal.cabelo, rot=rot_z(s * 0.42))
        ponta = Elipsoide((s * 0.425, 0.84, -0.1), (0.07, 0.075, 0.075), pal.cabelo)
        caudas.append(unir(raiz, cauda, ponta, k=0.06))
        # laço: duas abas + nó
        no = np.array([s * 0.29, 1.15, -0.06])
        prendedores.append(Esfera(no, 0.032, pal.prendedor))
        prendedores.append(Elipsoide(no + np.array([s * 0.0, 0.055, 0.02]), (0.03, 0.055, 0.022), pal.prendedor, rot=rot_x(0.3) @ rot_z(s * 0.5)))
        prendedores.append(Elipsoide(no + np.array([s * 0.035, -0.04, 0.02]), (0.03, 0.05, 0.022), pal.prendedor, rot=rot_z(-s * 0.9)))
    cabelo = unir(casco, *caudas, k=0.05)
    reflexo = Pintura(lambda P: (P[:, 1] > 1.12) & (P[:, 1] < 1.2) & (P[:, 2] > 0.05) & (np.abs(P[:, 0] + 0.08) < 0.05), pal.reflexo)
    estrela_presilha = Elipsoide((-0.2, 1.1, 0.2), (0.045, 0.045, 0.018), pal.estrela, rot=rot_y(-0.6))
    pint_estrela = Pintura(lambda P: (P[:, 0] < -0.16) & (P[:, 1] > 1.05) & (P[:, 1] < 1.15) & (P[:, 2] > 0.17)
                           & ~estrela_2d(P[:, 0], P[:, 1], -0.2, 1.1, 0.048, 0.022), pal.cabelo)
    antena = Capsula((0.0, 1.28, -0.1), (0.0, 1.42, -0.12), 0.011, pal.antena)
    cor1 = Esfera((-0.022, 1.455, -0.12), 0.026, pal.luz_antena)
    cor2 = Esfera((0.022, 1.455, -0.12), 0.026, pal.luz_antena)
    cor3 = ConeRedondo((0, 1.448, -0.12), (0, 1.41, -0.12), 0.034, 0.006, pal.luz_antena)
    coracao = unir(cor1, cor2, cor3, k=0.012)
    cabeca = unir(cab, cabelo, k=0.012)
    for o in orelhas:
        cabeca = cabeca.solda(o, 0.01)
    for p in prendedores:
        cabeca = cabeca | p
    cabeca = cabeca | estrela_presilha | antena | coracao
    pint_cab = [pint_orelha, pint_estrela]

    cores = dict(membro=pal.corpo, ombro=pal.vestido, junta=pal.junta, punho=pal.punho, luva=pal.corpo,
                 bota=pal.bota, faixa=pal.faixa, sola=pal.sola, jato=pal.jato)
    blusa = Elipsoide((0, 0.578, 0), (0.168, 0.16, 0.132), pal.vestido)
    ombros = Capsula((-0.14, 0.648, 0), (0.14, 0.648, 0), 0.062, pal.vestido)
    saia = ConeRedondo((0, 0.53, 0), (0, 0.3, 0), 0.15, 0.25, pal.saia)
    gola = Toro((0, 0.705, 0.0), 0.075, 0.02, pal.gola)
    pescoco = Capsula((0, 0.66, 0), (0, 0.78, 0), 0.05, pal.metal)
    tronco = blusa.solda(ombros, 0.06).solda(saia, 0.05).solda(pescoco, 0.015) | gola
    pint_tronco = [
        Pintura(lambda P: (P[:, 1] < 0.335), pal.barra),
        Pintura(lambda P: (P[:, 2] > 0.06) & coracao_2d(P[:, 0], P[:, 1], 0.0, 0.592, 0.075), pal.nucleo),
        Pintura(lambda P: (P[:, 1] > 0.49) & (P[:, 1] < 0.515), pal.barra),
    ]
    return pal, (cabeca, pint_cab), (tronco, pint_tronco), cores, True


# ------------------------------------------------------------- montagem

def gerar_personagem(nome, fabrica, pasta):
    pal, (cabeca, pint_cab), (tronco, pint_tronco), cores, menina = fabrica()
    alfa = alfa_por_cor(pal)
    pac = Pacote()

    def malha(forma, pint, bmin, bmax):
        return gerar_malha(forma, bmin, bmax, PASSO, pal.cores, pint, mascara_rosto=alfa)

    q = np.array([0, QUADRIL_Y, 0])
    pac.adicionar("corpo", malha(tronco, pint_tronco, (-0.34, 0.25, -0.3), (0.34, 0.83, 0.3)), "", q, q)
    pc = np.array([0, PESCOCO_Y, 0])
    pac.adicionar("cabeca", malha(cabeca, pint_cab, (-0.44, 0.66, -0.48), (0.44, 1.52, 0.42)), "corpo", pc - q, pc)
    for lado, s in (("e", 1), ("d", -1)):
        sup, inf = braco(s, cores)
        om, co = espelho(OMBRO, s), espelho(COTOVELO, s)
        xs = sorted([s * 0.11, s * 0.34])
        pac.adicionar("braco_" + lado, malha(sup, [], (xs[0], 0.44, -0.11), (xs[1], 0.74, 0.11)), "corpo", om - q, om)
        xs = sorted([s * 0.16, s * 0.38])
        pac.adicionar("antebraco_" + lado, malha(inf, [], (xs[0], 0.29, -0.1), (xs[1], 0.59, 0.13)), "braco_" + lado, co - om, co)
    for lado, s in (("e", 1), ("d", -1)):
        sup, inf, pint = perna(s, cores, menina)
        qq, jj = espelho(QUADRIL, s), espelho(JOELHO, s)
        x = qq[0]
        pac.adicionar("coxa_" + lado, malha(sup, [], (x - 0.09, 0.16, -0.09), (x + 0.09, 0.47, 0.09)), "corpo", qq - q, qq)
        pac.adicionar("canela_" + lado, malha(inf, pint, (x - 0.11, -0.02, -0.11), (x + 0.11, 0.3, 0.19)), "coxa_" + lado, jj - qq, jj)
    pac.gravar(os.path.join(pasta, nome), meta={
        "rosto": {"centro": [0.0, 0.955 - PESCOCO_Y], "tamanho": [0.46, 0.40]},
        "mao_d": [float(v) for v in (espelho(MAO, -1) - espelho(COTOVELO, -1))],
        "mao_e": [float(v) for v in (MAO - COTOVELO)],
        "jato_e": [float(v) for v in (np.array([0.09, 0.0, 0.02]) - JOELHO)],
        "jato_d": [float(v) for v in (np.array([-0.09, 0.0, 0.02]) - espelho(JOELHO, -1))],
        "antena": [0.0, 1.45 - PESCOCO_Y, -0.15],
    })
