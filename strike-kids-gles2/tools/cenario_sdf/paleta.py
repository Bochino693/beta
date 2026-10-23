# -*- coding: utf-8 -*-
"""Paleta de cores dos modelos (nomes -> índice) e a FINURA das fontes.

FINO multiplica o passo da grade do SDF (e divide o lado dos tubos): 1 = a
resolução dos modelos do Godot 4; 0,5 = fontes 8x mais finas para o assador
(tools/modelos_texturizados.py) tirar o desenho e a forma lisos. Vem da
variável de ambiente CENARIO_FINO (padrão 0,5).
"""
import os

FINO = float(os.environ.get("CENARIO_FINO", "0.5"))


class Paleta:
    """Nomes de cor -> índice. O alfa de cada cor é a máscara do rosto."""

    def __init__(self, **cores):
        self.nomes = list(cores.keys())
        self.cores = [cores[n] for n in self.nomes]

    def __getattr__(self, nome):
        nomes = self.__dict__.get("nomes", [])
        if nome in nomes:
            return nomes.index(nome)
        raise AttributeError(nome)


def lados(n):
    """Lados de um tubo/bolinha na finura atual (mais lados nas fontes finas)."""
    return max(3, int(round(n / max(FINO, 0.25) ** 0.5)))
