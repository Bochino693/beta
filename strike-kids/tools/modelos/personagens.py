# -*- coding: utf-8 -*-
"""
PERSONAGENS DO STRIKE KIDS: BOB (cachorrinho) E MIA (gatinha)
=============================================================

Mascotes fofinhos, estilo desenho infantil: cabeça grande e redonda,
focinho, olhos grandes e brilhantes (desenhados no rosto), orelhinhas,
rabinho que abana, corpinho gordinho e patinhas.

  * BOB — cachorrinho caramelo de focinho clarinho, orelhas caídas,
    camiseta turquesa com estrela e lencinho vermelho no pescoço.
  * MIA — gatinha cinza-clara listradinha, orelhas pontudas com o
    dentro rosado, vestidinho lilás de bolinhas e laço amarelo na orelha.

Juntas articuladas (ombro, cotovelo, quadril, joelho, pescoço e rabo):
é o que deixa eles jogarem boliche de verdade.

Cor do vértice: RGB = cor (sRGB); ALFA = 1 rosto (onde o desenho do rosto
pode aparecer), 0.5 = luz (brilha), 0 = normal.
"""
import math
import os

import numpy as np

from sdf import (Capsula, ConeRedondo, Elipsoide, Esfera, Pacote, Pintura, Toro,
                 estrela_2d, gerar_malha, hex_cor, rot_x, rot_z, unir)

# ------------------------------------------------------------- juntas
QUADRIL_Y = 0.40
PESCOCO_Y = 0.72
OMBRO = np.array([0.20, 0.64, 0.0])
COTOVELO = np.array([0.245, 0.515, 0.004])
MAO = np.array([0.278, 0.39, 0.016])
QUADRIL = np.array([0.095, 0.40, 0.0])
JOELHO = np.array([0.095, 0.235, 0.0])
RABO = np.array([0.0, 0.44, -0.15])

ROSTO = 1.0
LUZ = 0.5
PASSO = 0.0105


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


# ------------------------------------------------------------- cabeça de bichinho

def cabeca_bicho(pelo, focinho, nariz):
    """Cabeça redondinha + bochechas fofas + focinho + narizinho."""
    cranio = Elipsoide((0, 0.985, -0.01), (0.292, 0.262, 0.262), pelo)
    cab = cranio
    for s in (1, -1):
        cab = cab.solda(Esfera((s * 0.135, 0.895, 0.105), 0.135, pelo), 0.08)
    foc = Elipsoide((0, 0.885, 0.19), (0.125, 0.085, 0.105), focinho)
    cab = cab.solda(foc, 0.045)
    nar = Elipsoide((0, 0.928, 0.29), (0.046, 0.032, 0.03), nariz)
    return cab.solda(nar, 0.01)


# ------------------------------------------------------------- membros (patinhas)

def braco(s, cores):
    """(superior, inferior). s = +1 lado esquerdo do personagem (+x)."""
    om, co, mao = espelho(OMBRO, s), espelho(COTOVELO, s), espelho(MAO, s)
    manga = Elipsoide(om + np.array([s * 0.01, -0.02, 0]), (0.078, 0.085, 0.078), cores["manga"])
    sup = Capsula(om, co, 0.05, cores["pelo"])
    superior = manga.solda(sup, 0.02).solda(Esfera(co, 0.05, cores["pelo"]), 0.02)
    pulso = mao + np.array([s * -0.004, 0.05, -0.004])
    inf = Capsula(co, pulso, 0.048, cores["pelo"])
    pata = Elipsoide(mao, (0.068, 0.07, 0.066), cores["pata"])
    inferior = inf.solda(pata, 0.035)
    return superior, inferior


def perna(s, cores):
    q, j = espelho(QUADRIL, s), espelho(JOELHO, s)
    coxa = Capsula(q, j, 0.062, cores["coxa"])
    superior = coxa.solda(Esfera(j, 0.058, cores["pelo"]), 0.02)
    tornozelo = np.array([q[0], 0.1, 0.01])
    canela = Capsula(j, tornozelo, 0.056, cores["pelo"])
    pe = Elipsoide((q[0], 0.055, 0.04), (0.078, 0.06, 0.112), cores["pata"])
    inferior = canela.solda(pe, 0.04)
    # dedinhos (dois risquinhos) na frente da patinha
    pint = [Pintura(lambda P, x=q[0]: (P[:, 2] > 0.12) & (P[:, 1] < 0.09)
                    & (np.abs(np.abs(P[:, 0] - x) - 0.024) < 0.006), cores["dedo"])]
    return superior, inferior, pint


# ------------------------------------------------------------- BOB (cachorrinho)

def bob():
    pal = Paleta(
        pelo=hex_cor("#F0B064", ROSTO),
        focinho=hex_cor("#FFF0DC", ROSTO),
        nariz=hex_cor("#3B2626"),
        orelha=hex_cor("#A8612E"),
        camisa=hex_cor("#23B5C8"),
        estampa=hex_cor("#FFD43B"),
        lenco=hex_cor("#FF5A4E"),
        pata=hex_cor("#FFF0DC"),
        dedo=hex_cor("#D8B48E"),
        pelo_corpo=hex_cor("#F0B064"),
    )
    cab = cabeca_bicho(pal.pelo, pal.focinho, pal.nariz)
    topete = unir(Esfera((0.0, 1.23, 0.05), 0.055, pal.pelo), Esfera((0.05, 1.215, 0.08), 0.045, pal.pelo),
                  Esfera((-0.045, 1.22, 0.07), 0.045, pal.pelo), k=0.03)
    cabeca = cab.solda(topete, 0.04)
    for s in (1, -1):   # orelhas caídas, macias
        cabeca = cabeca.solda(Elipsoide((s * 0.275, 0.94, -0.03), (0.075, 0.175, 0.115), pal.orelha,
                                        rot=rot_z(s * 0.32) @ rot_x(0.1)), 0.025)
    # mancha clarinha em volta de um olho (charme do Bob)
    pint_cab = [Pintura(lambda P: (P[:, 2] > 0.12) & ((P[:, 0] + 0.1) ** 2 + (P[:, 1] - 0.985) ** 2 * 1.3 < 0.075 ** 2), pal.focinho)]

    cores = dict(pelo=pal.pelo_corpo, manga=pal.camisa, pata=pal.pata, coxa=pal.pelo_corpo, dedo=pal.dedo)
    corpo = Elipsoide((0, 0.53, 0.0), (0.19, 0.2, 0.16), pal.camisa)
    barriga = Elipsoide((0, 0.43, 0.01), (0.175, 0.1, 0.145), pal.pelo_corpo)
    ombros = Capsula((-0.14, 0.64, 0), (0.14, 0.64, 0), 0.065, pal.camisa)
    pescoco = Capsula((0, 0.66, 0), (0, 0.78, 0), 0.07, pal.pelo_corpo)
    lenco = Toro((0, 0.705, 0.0), 0.085, 0.03, pal.lenco)
    ponta = ConeRedondo((0, 0.69, 0.1), (0, 0.6, 0.15), 0.05, 0.012, pal.lenco)
    tronco = corpo.solda(ombros, 0.06).solda(barriga, 0.03).solda(pescoco, 0.02) | lenco | ponta
    pint_tronco = [Pintura(lambda P: (P[:, 2] > 0.06) & estrela_2d(P[:, 0], P[:, 1], 0.0, 0.53, 0.075, 0.034), pal.estampa)]
    # rabinho para cima (abana!)
    rabo = unir(Capsula(RABO, RABO + np.array([0, 0.09, -0.08]), 0.042, pal.pelo_corpo),
                Esfera(RABO + np.array([0, 0.11, -0.1]), 0.05, pal.focinho), k=0.03)
    return pal, (cabeca, pint_cab), (tronco, pint_tronco), cores, rabo


# ------------------------------------------------------------- MIA (gatinha)

def mia():
    pal = Paleta(
        pelo=hex_cor("#D9DEE8", ROSTO),
        focinho=hex_cor("#FFFFFF", ROSTO),
        listra=hex_cor("#A3ADC2", ROSTO),
        nariz=hex_cor("#FF8FA8"),
        orelha=hex_cor("#D9DEE8"),
        orelha_dentro=hex_cor("#FFB3C4"),
        vestido=hex_cor("#9C7CFF"),
        gola=hex_cor("#FFFFFF"),
        laco=hex_cor("#FFD43B"),
        pata=hex_cor("#FFFFFF"),
        dedo=hex_cor("#FFC2D0"),
        pelo_corpo=hex_cor("#D9DEE8"),
        bolinha=hex_cor("#FFFFFF"),
    )
    cabeca = cabeca_bicho(pal.pelo, pal.focinho, pal.nariz)
    for s in (1, -1):   # orelhas pontudas
        cabeca = cabeca.solda(ConeRedondo((s * 0.165, 1.13, -0.03), (s * 0.235, 1.33, -0.05), 0.095, 0.022, pal.orelha), 0.04)
    no = np.array([0.2, 1.2, 0.04])   # laço amarelo na orelha
    laco = unir(Esfera(no, 0.03, pal.laco),
                Elipsoide(no + np.array([0.05, 0.02, 0.0]), (0.05, 0.035, 0.022), pal.laco, rot=rot_z(0.35)),
                Elipsoide(no + np.array([-0.05, -0.02, 0.0]), (0.05, 0.035, 0.022), pal.laco, rot=rot_z(0.35)), k=0.01)
    cabeca = cabeca | laco

    def dentro_orelha(P):
        r = np.zeros(len(P), dtype=bool)
        for s in (1, -1):
            d = P - np.array([s * 0.2, 1.23, 0.0])
            r |= (P[:, 2] > -0.02) & (np.abs(d[:, 0]) < 0.05 - np.clip(d[:, 1], 0, 0.1) * 0.35) & (d[:, 1] > -0.04) & (d[:, 1] < 0.09)
        return r

    def listras(P):
        a = (P[:, 1] > 1.1) & (P[:, 2] > 0.05)
        return a & ((np.abs(P[:, 0]) < 0.018) | (np.abs(np.abs(P[:, 0]) - 0.06) < 0.014)) & (P[:, 1] < 1.2 - np.abs(P[:, 0]) * 0.6)
    pint_cab = [Pintura(dentro_orelha, pal.orelha_dentro), Pintura(listras, pal.listra)]

    cores = dict(pelo=pal.pelo_corpo, manga=pal.vestido, pata=pal.pata, coxa=pal.pelo_corpo, dedo=pal.dedo)
    blusa = Elipsoide((0, 0.56, 0), (0.175, 0.17, 0.145), pal.vestido)
    ombros = Capsula((-0.135, 0.64, 0), (0.135, 0.64, 0), 0.062, pal.vestido)
    saia = ConeRedondo((0, 0.53, 0), (0, 0.31, 0), 0.155, 0.245, pal.vestido)
    gola = Toro((0, 0.7, 0.0), 0.08, 0.024, pal.gola)
    pescoco = Capsula((0, 0.66, 0), (0, 0.78, 0), 0.065, pal.pelo_corpo)
    tronco = blusa.solda(ombros, 0.06).solda(saia, 0.05).solda(pescoco, 0.02) | gola

    def bolinhas(P):
        ang = np.arctan2(P[:, 0], P[:, 2])
        u = ang / (2 * math.pi) * 12.0
        v = (P[:, 1] - 0.31) / 0.06
        linha = np.floor(v)
        u2 = u + 0.5 * (linha % 2)
        du = u2 - np.round(u2)
        dv = v - (linha + 0.5)
        return (P[:, 1] < 0.48) & (du * du * 0.6 + dv * dv < 0.07)
    pint_tronco = [Pintura(bolinhas, pal.bolinha)]
    # rabo comprido e curvado, pontinha listrada
    p0 = RABO
    p1 = RABO + np.array([0.0, 0.03, -0.14])
    p2 = RABO + np.array([0.02, 0.17, -0.2])
    p3 = RABO + np.array([0.06, 0.28, -0.14])
    rabo = unir(Capsula(p0, p1, 0.034, pal.pelo_corpo), Capsula(p1, p2, 0.034, pal.pelo_corpo),
                Capsula(p2, p3, 0.034, pal.listra), k=0.03)
    return pal, (cabeca, pint_cab), (tronco, pint_tronco), cores, rabo


# ------------------------------------------------------------- montagem

def gerar_personagem(nome, fabrica, pasta):
    pal, (cabeca, pint_cab), (tronco, pint_tronco), cores, rabo = fabrica()
    alfa = alfa_por_cor(pal)
    pac = Pacote()

    def malha(forma, pint, bmin, bmax):
        return gerar_malha(forma, bmin, bmax, PASSO, pal.cores, pint, mascara_rosto=alfa)

    def sem_rosto(forma, pint, bmin, bmax):
        return gerar_malha(forma, bmin, bmax, PASSO, pal.cores, pint, mascara_rosto=lambda P, c: np.zeros(len(P)))

    q = np.array([0, QUADRIL_Y, 0])
    pac.adicionar("corpo", sem_rosto(tronco, pint_tronco, (-0.34, 0.25, -0.3), (0.34, 0.84, 0.3)), "", q, q)
    pc = np.array([0, PESCOCO_Y, 0])
    pac.adicionar("cabeca", malha(cabeca, pint_cab, (-0.46, 0.6, -0.46), (0.46, 1.42, 0.42)), "corpo", pc - q, pc)
    pac.adicionar("rabo", sem_rosto(rabo, [], (-0.15, 0.35, -0.45), (0.15, 0.8, -0.05)), "corpo", RABO - q, RABO)
    for lado, s in (("e", 1), ("d", -1)):
        sup, inf = braco(s, cores)
        om, co = espelho(OMBRO, s), espelho(COTOVELO, s)
        xs = sorted([s * 0.1, s * 0.34])
        pac.adicionar("braco_" + lado, sem_rosto(sup, [], (xs[0], 0.44, -0.12), (xs[1], 0.74, 0.12)), "corpo", om - q, om)
        xs = sorted([s * 0.16, s * 0.38])
        pac.adicionar("antebraco_" + lado, sem_rosto(inf, [], (xs[0], 0.29, -0.11), (xs[1], 0.59, 0.13)), "braco_" + lado, co - om, co)
    for lado, s in (("e", 1), ("d", -1)):
        sup, inf, pint = perna(s, cores)
        qq, jj = espelho(QUADRIL, s), espelho(JOELHO, s)
        x = qq[0]
        pac.adicionar("coxa_" + lado, sem_rosto(sup, [], (x - 0.1, 0.16, -0.1), (x + 0.1, 0.48, 0.1)), "corpo", qq - q, qq)
        pac.adicionar("canela_" + lado, sem_rosto(inf, pint, (x - 0.11, -0.02, -0.1), (x + 0.11, 0.3, 0.18)), "coxa_" + lado, jj - qq, jj)
    pac.gravar(os.path.join(pasta, nome), meta={
        "rosto": {"centro": [0.0, 0.94 - PESCOCO_Y], "tamanho": [0.46, 0.40]},
    })
