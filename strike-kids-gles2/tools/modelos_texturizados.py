# -*- coding: utf-8 -*-
"""
MODELOS DO CENÁRIO COM TEXTURA ASSADA (versão 6.2) — forma leve, desenho
dos originais.

    python3 tools/modelos_texturizados.py <antigos> <atuais> <texturas> [nome1,nome2 | atlas]

  <antigos>: os modelos ORIGINAIS (os de antes do tools/malhas_leves.py,
             tirados do git), exportados com
             tools/malhas_leves.gd -- --exportar <antigos> --origem=<pasta>
  <atuais>:  os modelos do projeto, exportados com
             tools/malhas_leves.gd -- --exportar <atuais>
  <texturas>: onde gravar o atlas (res://texturas/cenario)
Depois: tools/malhas_leves.gd -- --importar <atuais> (troca as malhas).

O QUE ERA RUIM: para caber na Mali-400/450 cada objeto do cenário foi
simplificado de ~2.400 para ~500 triângulos (malhas_leves.py). Só que o
desenho deles (olhos, bocas, pintas, listras, confeitos) era pintado nos
VÉRTICES: com menos vértices o desenho sumia ou ficava serrilhado, e a
forma ficava quebrada.

O JEITO DOS JOGOS PROFISSIONAIS: a forma com poucos triângulos e o desenho
numa TEXTURA. Aqui, para cada objeto:
  1. a forma do ORIGINAL simplificada olhando só a forma (sem gastar
     triângulos nas bordas de cor) — com os triângulos que o objeto tinha;
  2. as normais do original (suaves; só as quinas do desenho original
     continuam quinas — as que a simplificação criaria, não);
  3. a malha aberta num mapa UV (xatlas);
  4. a COR DO ORIGINAL assada na textura: cada pixel procura o ponto do
     original mais perto (do mesmo lado da superfície) e pega a cor dele,
     já como ela sai na tela (as mesmas contas do toon_leve.shader:
     sRGB -> linear, curva do Godot 4 e cor viva). O shader do jogo só
     multiplica pela luz de cada vértice — 1 conta por pixel;
  5. o alfa da cor do vértice (as partes que brilham) vem do original;
  6. a textura de cada objeto vira um pedaço de UM ATLAS só (todas juntas
     numa imagem, o mapa UV de cada um levado para o pedaço dele): com uma
     textura só, todos os objetos do cenário usam o MESMO material e o
     Lote (scripts/lote.gd) junta os parados num desenho por região — com
     uma textura por objeto, cada tipo era um desenho a mais. As peças de
     uma cor só entram também: o UV delas aponta para um quadradinho
     branco do atlas e a cor vem do vértice (o shader multiplica as duas).
Os pedaços (<atuais>/pedacos/<nome>.png, com a malha de UV própria em
<id>.local.msh) ficam guardados: refazer um objeto só remonta o atlas.
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image
from scipy.spatial import cKDTree
import xatlas
import meshoptimizer as mo

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from malhas_leves import ler_msh, gravar_msh, VERTEX, NORMAL, COLOR, TEX_UV, TRIANGULOS  # noqa: E402

# TRIÂNGULOS DE CADA OBJETO — a versão DE PERTO (7.0): com o simplificador
# de qualidade (decimar) e as fontes em alta, ~2,5 vezes os da 6.9: os
# objetos ficam lisos, sem "rugas" nem "amassados". Cada objeto tem mais
# duas versões, tiradas desta com o mesmo desenho (gerar_niveis): MEIO
# (~45%, os da 6.9) e LONGE (~18%); scripts/temas.gd escolhe pelo tamanho
# na tela (e o governador do quadro troca para as mais leves se a TV Box
# não segurar 60 quadros).
ALVO = {
    # selva dos dinos
    "dino": 3500, "ptero": 2600, "vulcao": 3600, "flor_gigante": 1300, "palmeira": 1300,
    "samambaia": 1600, "ovo_dino": 1100, "pedra": 750, "nuvem": 950,
    # espaço
    # (7.0b: o planeta com anel é o grande do céu, no lugar do Saturno)
    "planeta_anel": 6000, "foguete": 1900, "ovni": 2200, "planeta": 1400, "cristal": 700,
    "pedra_lua": 650, "estrela_3d": 750,
    # fundo do mar
    "navio": 5500, "tartaruga": 3200, "agua_viva": 2600, "peixe": 1300, "peixe_azul": 1300, "peixe_amarelo": 1300,
    "concha": 900, "coral": 1500, "coral_roxo": 1900, "alga": 750, "estrela_mar": 750,
    # o baú em duas peças (o corpo e a tampa, que abre)
    "bau": 1100, "bau_tampa": 700,
    # parque
    "carrossel": 5200, "roda": 3600, "roda_base": 750, "cabine": 700, "tenda": 1600,
    "torre": 1600, "arco_iris": 2000, "arvore_verde": 900, "arvore_laranja": 900,
    "arvore_escura": 900, "bengala": 900, "cogumelo": 1000, "cupcake": 1200, "donut": 1000,
    "pirulito": 850, "presente": 1000, "balao": 700, "lampada": 160, "castelo": 5200,
    # 7.0: mais decoração
    "arbusto": 1100, "flores": 1500, "tricera": 3200, "anemona": 1600, "satelite": 2200, "poste": 700,
}
# erro máximo da forma de cada peça (fração do tamanho DELA); o padrão é ERRO_FORMA
ERRO = {"roda": 0.008, "peixe": 0.008, "peixe_azul": 0.008, "peixe_amarelo": 0.008, "ovo_dino": 0.03,
        "cristal": 0.04, "palmeira": 0.03}
# textura de cada objeto (lado em pixels; o padrão é 512). 7.0: um ATLAS POR
# FASE (ATLAS_DO_TEMA), então cada fase tem a imagem inteira para os
# objetos dela — os principais com 2048, os outros com 1024 (eram 1024 e
# 512 dividindo uma imagem só com as quatro fases)
TEX_2048 = ("navio", "carrossel", "dino", "vulcao", "planeta_anel")
TEX_1024 = ("ptero", "tenda", "foguete", "roda", "ovni", "flor_gigante", "agua_viva", "palmeira",
            "pedra", "torre", "cupcake", "donut", "presente", "cristal", "pedra_lua", "planeta", "concha",
            "estrela_mar", "bau", "arbusto", "flores", "anemona",
            "satelite", "tartaruga", "castelo", "tricera")
# (cada fase cabe numa imagem de 4096 x 4096 — o maior lado que a Mali-450
# aceita: as maiores de 2048, a maioria de 1024 e as de desenho simples
# — listras, espiral — com 512, o padrão)
TEX_512 = ()
TEX_128 = ()
TEX_256 = ("lampada", "bau_tampa")
# SEM TEXTURA: as peças de uma cor só ou quase (plantas, nuvens, balões,
# lâmpadas) espalhadas às dezenas pelo cenário — a textura não acrescenta
# desenho e os cortes do mapa UV somariam vértices em cada cópia. Nelas: a
# forma limpa do original e a cor dele nos vértices (com o sombreado dos
# cantinhos).
SO_COR = ("arvore_escura", "arvore_laranja", "arvore_verde", "balao", "lampada", "nuvem",
          "alga", "coral", "coral_roxo", "estrela_3d", "cabine", "roda_base", "poste")
# EM QUE FASE CADA OBJETO APARECE (o atlas de cada uma só tem os dela; os
# que aparecem em duas ficam no MESMO lugar nas duas imagens)
TEMAS_DO_OBJETO = {
    "parque": ("arco_iris", "torre", "arvore_verde", "arvore_laranja", "arvore_escura", "pirulito", "cogumelo",
               "bengala", "presente", "donut", "cupcake", "roda_base", "roda", "cabine", "carrossel", "tenda",
               "nuvem", "balao", "lampada", "castelo", "arbusto", "flores", "poste"),
    "espaco": ("planeta_anel", "foguete", "ovni", "planeta", "estrela_3d", "cristal", "pedra_lua", "satelite"),
    "mar": ("navio", "bau", "bau_tampa", "coral", "coral_roxo", "alga", "estrela_mar", "concha", "pedra",
            "peixe", "peixe_azul", "peixe_amarelo", "agua_viva", "tartaruga", "anemona"),
    "dinos": ("vulcao", "palmeira", "dino", "ptero", "samambaia", "pedra", "flor_gigante", "ovo_dino", "nuvem",
              "arbusto", "tricera"),
}
ANGULO_QUINA = 75.0
PADDING = 4
# o atlas: largura fixa; a altura é a potência de 2 que couber (a Mali-450
# só faz mipmap em textura de lado potência de 2)
ATLAS_LARGURA = 4096
ATLAS = "atlas_%s.png"


# ------------------------------------------------------------ cor na tela
def s2l(c):
    return c * (c * (c * 0.305306011 + 0.682171111) + 0.012522878)


def viva(c):
    lum = c @ np.array([0.299, 0.587, 0.114])
    sat = c.max(axis=1) - c.min(axis=1)
    k = 1.14 + 0.34 * (1.0 - sat)
    c = lum[:, None] + (c - lum[:, None]) * k[:, None]
    return np.clip(c * 1.08 - 0.045, 0.0, 1.0)


def tela_g4(x):
    x = np.clip(x, 0.0, 1.25)
    return viva(x * (1.2094 - x * (0.015 + 0.25 * x)))


# ------------------------------------------------------------ malha
def soldar(v, f):
    """Junta os vértices na mesma posição (o original tem cópias nas bordas
    de cor e nas quinas): a forma vira uma peça só para simplificar."""
    tam = float(np.linalg.norm(v.max(0) - v.min(0))) or 1.0
    chave = np.round(v / (tam * 1e-5)).astype(np.int64)
    _, primeiro, inv = np.unique(chave, axis=0, return_index=True, return_inverse=True)
    inv = inv.reshape(-1)
    fw = inv[f]
    ok = (fw[:, 0] != fw[:, 1]) & (fw[:, 1] != fw[:, 2]) & (fw[:, 0] != fw[:, 2])
    return v[primeiro], fw[ok], inv


## erro máximo da forma (fração do tamanho do objeto): se o alvo de
## triângulos pedir mais que isso, o objeto fica com mais triângulos — a
## forma não quebra (raios da roda-gigante, o ovo, a borda da tenda)
ERRO_FORMA = 0.03
ERRO_LIMITE = 0.06


def simplificar_forma(v, f, alvo_tris, erro=None):
    ind = np.ascontiguousarray(f.reshape(-1).astype(np.uint32))
    pos = np.ascontiguousarray(v.astype(np.float32))
    if len(f) <= alvo_tris:
        return f
    destino = np.zeros_like(ind)
    qtd = mo.simplify(destino, ind, pos, target_index_count=alvo_tris * 3,
                      target_error=ERRO_FORMA if erro is None else erro)
    return destino[:qtd].reshape(-1, 3)


## O SIMPLIFICADOR DE QUALIDADE (7.0): o "quadric edge collapse" do
## MeshLab (pymeshlab) com a POSIÇÃO ÓTIMA — cada ponto que sobra vai para
## onde a forma da fonte pede (o meshoptimizer só escolhia entre os pontos
## que já existiam: as folhas e as curvas saíam amassadas, com "rugas"),
## triângulos bem formados (qualidade) e a normal de cada face sem virar.
## O pymeshlab precisa da libOpenGL (nem a usa): MESHLAB_GL = a pasta dela,
## se o sistema não tiver.
_meshlab = None


def _pymeshlab():
    global _meshlab
    if _meshlab is None:
        pasta = os.environ.get("MESHLAB_GL", "")
        if pasta:
            import ctypes
            ctypes.CDLL(os.path.join(pasta, "libOpenGL.so.0"), mode=ctypes.RTLD_GLOBAL)
        try:
            import pymeshlab
            ms = pymeshlab.MeshSet()
            if not hasattr(ms, "meshing_decimation_quadric_edge_collapse"):
                raise ImportError("sem o filtro de simplificar")
            _meshlab = pymeshlab
        except ImportError as e:
            print("  (sem pymeshlab: %s — fica o meshoptimizer)" % e)
            _meshlab = False
    return _meshlab


def decimar(v, f, alvo_tris):
    """A peça (v, f) com `alvo_tris` triângulos, os pontos no lugar ótimo.
    Devolve (pontos, triângulos) novos."""
    pml = _pymeshlab()
    if not pml or len(f) <= alvo_tris:
        if len(f) <= alvo_tris:
            return v, f
        sk = simplificar_forma(v, f, alvo_tris, ERRO_LIMITE)
        us = np.unique(sk)
        rm = np.full(len(v), -1)
        rm[us] = np.arange(len(us))
        return v[us], rm[sk]
    ms = pml.MeshSet()
    ms.add_mesh(pml.Mesh(vertex_matrix=np.ascontiguousarray(v, np.float64), face_matrix=np.ascontiguousarray(f, np.int32)))
    ms.meshing_decimation_quadric_edge_collapse(targetfacenum=int(alvo_tris), qualitythr=0.6, preserveboundary=True,
                                                boundaryweight=2.0, preservenormal=True, preservetopology=True,
                                                optimalplacement=True, planarquadric=True, planarweight=0.002,
                                                autoclean=True)
    m = ms.current_mesh()
    return m.vertex_matrix().astype(np.float64), m.face_matrix().astype(np.int64)


def normais_nos_pontos(pv, pf, vw, media, quina):
    """A normal (suave, a da fonte) e a quina de cada ponto NOVO da forma
    leve: a média das normais dos pontos da fonte em volta — só os do MESMO
    LADO (numa folha fina o outro lado está quase no mesmo lugar: a média
    se anularia) — e quina se a fonte tinha quina ali."""
    fn = np.cross(pv[pf[:, 1]] - pv[pf[:, 0]], pv[pf[:, 2]] - pv[pf[:, 0]])
    ng = np.zeros_like(pv)
    for k in range(3):
        np.add.at(ng, pf[:, k], fn)
    ng /= np.maximum(np.linalg.norm(ng, axis=1, keepdims=True), 1e-12)
    aresta = np.linalg.norm(pv[pf[:, 1]] - pv[pf[:, 0]], axis=1).mean() if len(pf) else 0.01
    d, j = cKDTree(vw).query(pv, k=min(12, len(vw)))
    lado = np.einsum("pkd,pd->pk", media[j], ng) > 0.2
    lado[:, 0] |= ~lado.any(1)
    w = lado / np.maximum(d, aresta * 0.05)
    n = np.einsum("pk,pkd->pd", w, media[j])
    n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)
    perto = lado & (d < aresta * 0.6)
    q = (quina[j] & perto).any(1)
    return n, q


def simplificar_pecas(v, f, alvo_tris, erro=None, pontos_novos=False):
    """A FORMA PEÇA POR PEÇA (6.4): o simplificador junto num objeto inteiro
    acha 'barato' acabar com as peças pequenas (o erro de amassar um pônei
    de 0,8 m é menor que o de achatar o telhado do carrossel): os pôneis,
    as cabines e as pétalas viravam cacos. Aqui cada peça solta é
    simplificada sozinha, com o erro medido no tamanho DELA, e os
    triângulos são repartidos pela raiz da área de cada uma (as pequenas
    ganham mais que a parte da área delas).
    pontos_novos (7.0): devolve (pontos, triângulos) com os pontos no lugar
    ótimo (decimar); senão, os triângulos com os pontos de `v`."""
    from scipy.sparse import coo_matrix
    from scipy.sparse.csgraph import connected_components
    if len(f) <= alvo_tris:
        return (v, f) if pontos_novos else f
    n = len(v)
    lig = coo_matrix((np.ones(f.size), (f.reshape(-1), np.roll(f, 1, 1).reshape(-1))), shape=(n, n))
    _, rotulo = connected_components(lig, directed=False)
    peca = rotulo[f[:, 0]]
    ids = np.unique(peca)
    area = np.linalg.norm(np.cross(v[f[:, 1]] - v[f[:, 0]], v[f[:, 2]] - v[f[:, 0]]), axis=1) / 2
    a_peca = np.array([area[peca == k].sum() for k in ids])
    t_peca = np.array([(peca == k).sum() for k in ids])
    peso = np.sqrt(np.maximum(a_peca, 1e-12))
    # reparte; as peças que já têm menos que a parte delas ficam inteiras e
    # o que sobra vai para as outras
    cota = np.zeros(len(ids))
    livre = np.ones(len(ids), bool)
    resto = float(alvo_tris)
    for _ in range(6):
        c = resto * peso / max(peso[livre].sum(), 1e-12)
        cheia = livre & (t_peca <= c)
        if not cheia.any():
            break
        cota[cheia] = t_peca[cheia]
        resto -= t_peca[cheia].sum()
        livre &= ~cheia
    cota[livre] = np.maximum(resto * peso[livre] / max(peso[livre].sum(), 1e-12), 12)
    # o erro máximo segura a forma de cada peça. A peça que pede bem mais
    # que a cota dela (um pônei: 600 triângulos para 3%) aceita o dobro do
    # erro, até ERRO_LIMITE — passou disso a forma quebra (um ovo vira
    # pirâmide); a que já cabe na cota não muda
    saida = []
    pts, tris, base = [], [], 0
    for k, alvo_k in zip(ids, cota):
        fk = f[peca == k]
        us = np.unique(fk)
        rm = np.full(n, -1)
        rm[us] = np.arange(len(us))
        if len(fk) <= alvo_k:
            saida.append(fk)
            pts.append(v[us])
            tris.append(rm[fk] + base)
            base += len(us)
            continue
        e = ERRO_FORMA if erro is None else erro
        sk = simplificar_forma(v[us], rm[fk], int(round(alvo_k)), e)
        while len(sk) > alvo_k * 1.3 and e * 2.0 <= ERRO_LIMITE:
            e *= 2.0
            sk = simplificar_forma(v[us], rm[fk], int(round(alvo_k)), e)
        saida.append(us[sk])
        if pontos_novos:
            # o mesmo número de triângulos que o erro pediu, no lugar ótimo
            pv, pf = decimar(v[us], rm[fk], len(sk))
            pts.append(pv)
            tris.append(pf + base)
            base += len(pv)
    if pontos_novos:
        return np.concatenate(pts), np.concatenate(tris)
    return np.concatenate(saida)


def normais_do_original(n_orig, inv, n_soldados):
    """A normal de cada ponto soldado: a média das normais do original
    naquele ponto — e se ali o original tinha uma QUINA (normais muito
    diferentes no mesmo lugar: a caixa do presente, a base do baú)."""
    soma = np.zeros((n_soldados, 3))
    np.add.at(soma, inv, n_orig)
    media = soma / np.maximum(np.linalg.norm(soma, axis=1, keepdims=True), 1e-12)
    perto = (n_orig * media[inv]).sum(1)
    minimo = np.ones(n_soldados)
    np.minimum.at(minimo, inv, perto)
    return media, minimo < math.cos(math.radians(35.0))


def normais_suaves(v, f, media, quina):
    """Normal por canto: a do original (suave); nas quinas do original, a
    média (por área) das faces vizinhas que dobram menos de ANGULO_QUINA
    em relação a esta face. Só as quinas de verdade duplicam vértices."""
    e1 = v[f[:, 1]] - v[f[:, 0]]
    e2 = v[f[:, 2]] - v[f[:, 0]]
    fn = np.cross(e1, e2)
    area = np.linalg.norm(fn, axis=1, keepdims=True)
    fnu = fn / np.maximum(area, 1e-12)
    incid = [[] for _ in range(len(v))]
    for i, tri in enumerate(f):
        for k in range(3):
            incid[tri[k]].append(i)
    lim = math.cos(math.radians(ANGULO_QUINA))
    cantos = np.zeros((len(f), 3, 3))
    for i, tri in enumerate(f):
        for k in range(3):
            if not quina[tri[k]]:
                cantos[i, k] = media[tri[k]]
                continue
            viz = incid[tri[k]]
            nv = fnu[viz]
            usar = nv @ fnu[i] >= lim
            s = (fn[viz][usar]).sum(0)
            cantos[i, k] = s / max(np.linalg.norm(s), 1e-12)
    # um vértice para cada (posição, normal)
    chave = np.concatenate([np.repeat(f.reshape(-1, 1), 1, 1), np.round(cantos.reshape(-1, 3) * 1000)], 1).astype(np.int64)
    _, primeiro, inv = np.unique(chave, axis=0, return_index=True, return_inverse=True)
    inv = inv.reshape(-1)
    pos = v[f.reshape(-1)[primeiro]]
    nor = cantos.reshape(-1, 3)[primeiro]
    return pos, nor, inv.reshape(-1, 3)


# ------------------------------------------------------------ sombreado dos cantinhos
## O SOMBREADO SUAVE DOS CANTINHOS (6.4, "oclusão de ambiente" assada):
## de cada ponto da fonte saem AO_RAIOS raios para o lado de fora; os que
## batem em outra parte do objeto perto (até AO_ALCANCE do tamanho dele)
## escurecem o ponto — o pescoço embaixo da cabeça do dino, entre as
## pernas, embaixo do telhado do carrossel, as emendas das bolotas da
## nuvem. Alcance curto (cantinhos, não sombra de longe: os raios da
## roda-gigante e as folhas da samambaia ficavam escuros). Vai na COR da fonte, então sai de graça no jogo (na textura ou
## no vértice): nenhuma conta a mais na placa. AO_FORCA: o quanto escurece
## o canto mais fechado (leve, de desenho animado).
AO_RAIOS = 32
AO_ALCANCE = (0.06, 0.05, 0.3)   # fração do tamanho, com mínimo e máximo em metros
AO_FORCA = 0.3


def sombrear_cantos(antigo):
    import trimesh
    from trimesh.ray.ray_pyembree import RayMeshIntersector
    v = antigo["arr"][VERTEX].astype(np.float64)
    n = antigo["arr"][NORMAL].astype(np.float64)
    f = antigo["ind"].reshape(-1, 3).astype(np.int64)
    vw, fw, inv = soldar(v, f)
    nw = np.zeros_like(vw)
    np.add.at(nw, inv, n)
    nw /= np.maximum(np.linalg.norm(nw, axis=1, keepdims=True), 1e-12)
    diag = float(np.linalg.norm(vw.max(0) - vw.min(0)))
    alcance = float(np.clip(AO_ALCANCE[0] * diag, AO_ALCANCE[1], AO_ALCANCE[2]))
    raios = RayMeshIntersector(trimesh.Trimesh(vertices=vw, faces=fw, process=False))
    # direções num hemisfério (mais perto da normal, como a luz difusa),
    # giradas de um ângulo diferente em cada ponto (sem listras)
    k = np.arange(AO_RAIOS) + 0.5
    r = np.sqrt(k / AO_RAIOS)
    a = k * math.pi * (3.0 - math.sqrt(5.0))
    loc = np.stack([r * np.cos(a), r * np.sin(a), np.sqrt(1.0 - r * r)], 1)
    t1 = np.cross(nw, np.where(np.abs(nw[:, 1:2]) < 0.9, [[0.0, 1.0, 0.0]], [[1.0, 0.0, 0.0]]))
    t1 /= np.maximum(np.linalg.norm(t1, axis=1, keepdims=True), 1e-12)
    t2 = np.cross(nw, t1)
    giro = np.random.default_rng(7).uniform(0, 2 * math.pi, len(vw))
    c, s_ = np.cos(giro)[:, None], np.sin(giro)[:, None]
    t1, t2 = t1 * c + t2 * s_, t2 * c - t1 * s_
    oclusao = np.zeros(len(vw))
    lote = max(1, 2000000 // AO_RAIOS)
    for i0 in range(0, len(vw), lote):
        sl = slice(i0, i0 + lote)
        m = len(vw[sl])
        d = (loc[None, :, 0:1] * t1[sl, None] + loc[None, :, 1:2] * t2[sl, None] + loc[None, :, 2:3] * nw[sl, None])
        d = d.reshape(-1, 3)
        o = np.repeat(vw[sl] + nw[sl] * diag * 2e-4, AO_RAIOS, 0)
        it, ir, pts = raios.intersects_id(o, d, multiple_hits=False, return_locations=True)
        dist = np.linalg.norm(pts - o[ir], axis=1)
        peso = np.clip(1.0 - dist / alcance, 0.0, 1.0) ** 2
        soma = np.zeros(m * AO_RAIOS)
        soma[ir] = peso
        oclusao[sl] = soma.reshape(m, AO_RAIOS).mean(1)
    # alisa um pouco (32 raios deixam grão): média com os vizinhos, 2 vezes
    from scipy.sparse import coo_matrix
    nv = len(vw)
    viz = coo_matrix((np.ones(fw.size * 2), (np.r_[fw.reshape(-1), np.roll(fw, 1, 1).reshape(-1)],
                                             np.r_[np.roll(fw, 1, 1).reshape(-1), fw.reshape(-1)])), shape=(nv, nv)).tocsr()
    viz.data[:] = 1.0
    grau = np.asarray(viz.sum(1)).ravel()
    for _ in range(2):
        oclusao = (oclusao + viz @ oclusao) / (1.0 + grau)
    fator = 1.0 - AO_FORCA * np.clip(oclusao * 1.6, 0.0, 1.0)
    novo = dict(antigo)
    novo["arr"] = dict(antigo["arr"])
    cor = antigo["arr"][COLOR].astype(np.float64).copy() if COLOR in antigo["arr"] else np.ones((len(v), 4))
    cor[:, :3] *= fator[inv][:, None]
    novo["arr"][COLOR] = cor.astype(np.float32)
    return novo


# ------------------------------------------------------------ amostras do original
def cor_por_raios(v, f, cor, uv_px, fx, pd, nd, lin, col, tri, arvore, a_pts, a_nor, a_cor, todos):
    """A COR DE CADA PIXEL PELO ORIGINAL, COMO NUM ASSADOR DE VERDADE (6.3).
    Antes cada pixel pegava a amostra do original mais perto: num olho (uma
    bolinha por cima do rosto, que a forma leve não tem) o pixel pegava ora
    o olho, ora o rosto embaixo, ora a bochecha do lado — olhos borrados e
    rabiscados. Agora, de cada ponto da forma leve sai um raio de FORA para
    DENTRO (começa a `dist` acima dela, pela normal) e a cor é a do primeiro
    lado de fora do original que ele encontra (a casca de fora: o olho por
    cima do rosto), interpolada no triângulo — as bordas saem como as do
    original. 4 raios por pixel (bordas lisas). `dist`: o quanto o original
    sai da forma leve (99,5% dos pontos dele), com folga."""
    import trimesh
    from trimesh.ray.ray_pyembree import RayMeshIntersector
    malha = trimesh.Trimesh(vertices=v, faces=f, process=False)
    raios = RayMeshIntersector(malha)
    diag = float(np.linalg.norm(v.max(0) - v.min(0)))
    # o quanto o original sai da forma leve (pontos da forma: os vértices e
    # o centro de cada pixel)
    centro = np.stack([col + 0.5, lin + 0.5], 1)
    w_c = _bary(uv_px, fx, tri, centro)
    p_c = np.einsum("pc,pcd->pd", w_c, pd[fx[tri]])
    longe = cKDTree(np.concatenate([p_c, pd, todos])).query(a_pts)[0]
    dist = float(np.clip(np.percentile(longe, 99.5) * 1.3, 0.006 * diag, 0.06 * diag))
    soma = np.zeros((len(tri), 3))
    for dx, dy in ((-0.25, -0.25), (0.25, -0.25), (-0.25, 0.25), (0.25, 0.25)):
        w = _bary(uv_px, fx, tri, centro + [dx, dy])
        p3 = np.einsum("pc,pcd->pd", w, pd[fx[tri]])
        n3 = np.einsum("pc,pcd->pd", w, nd[fx[tri]])
        n3 /= np.maximum(np.linalg.norm(n3, axis=1, keepdims=True), 1e-12)
        c = np.empty((len(tri), 3))
        falta = np.ones(len(tri), bool)
        it, ir, cc = _casca(malha, raios, cor, f, p3, n3, dist)
        c[ir] = cc
        falta[ir] = False
        # sem casca no caminho (raro): a amostra mais perto, como antes
        if falta.any():
            c[falta] = a_cor[procurar(arvore, a_nor, p3[falta], n3[falta]), :3]
        soma += tela_g4(s2l(np.clip(c, 0, 1)))
    return soma / 4.0


def _casca(malha, raios, cor, f, p3, n3, dist):
    """Raios de fora (a `dist` acima de cada ponto, pela normal) para dentro:
    a primeira face da FRENTE até `dist` abaixo do ponto. Devolve os
    triângulos, os raios que acharam e a cor interpolada no triângulo."""
    import trimesh
    origem = p3 + n3 * dist
    it, ir, loc = raios.intersects_id(origem, -n3, multiple_hits=True, max_hits=8, return_locations=True)
    t = np.einsum("pd,pd->p", loc - origem[ir], -n3[ir])
    ok = (t >= -1e-6) & (t <= dist * 2.0) & (np.einsum("pd,pd->p", malha.face_normals[it], n3[ir]) > 0.0)
    it, ir, loc, t = it[ok], ir[ok], loc[ok], t[ok]
    ordem = np.lexsort((t, ir))
    it, ir, loc = it[ordem], ir[ordem], loc[ordem]
    primeiro = np.r_[True, ir[1:] != ir[:-1]][:len(ir)]
    it, ir, loc = it[primeiro], ir[primeiro], loc[primeiro]
    bc = trimesh.triangles.points_to_barycentric(malha.triangles[it], loc)
    bc = np.clip(np.nan_to_num(bc), 0, 1)
    bc /= np.maximum(bc.sum(1, keepdims=True), 1e-12)
    return it, ir, np.einsum("pc,pcd->pd", bc, cor[f[it], :3])


def _bary(uv_px, fx, tri, pts):
    """Baricêntricas dos pontos (pixels) no triângulo de cada um (um pouco
    para fora vale: o pixel da borda)."""
    a, b, c = uv_px[fx[tri, 0]], uv_px[fx[tri, 1]], uv_px[fx[tri, 2]]
    d = (b[:, 1] - c[:, 1]) * (a[:, 0] - c[:, 0]) + (c[:, 0] - b[:, 0]) * (a[:, 1] - c[:, 1])
    d = np.where(np.abs(d) < 1e-12, 1e-12, d)
    w0 = ((b[:, 1] - c[:, 1]) * (pts[:, 0] - c[:, 0]) + (c[:, 0] - b[:, 0]) * (pts[:, 1] - c[:, 1])) / d
    w1 = ((c[:, 1] - a[:, 1]) * (pts[:, 0] - c[:, 0]) + (a[:, 0] - c[:, 0]) * (pts[:, 1] - c[:, 1])) / d
    w = np.stack([w0, w1, 1 - w0 - w1], 1)
    w = np.clip(w, -0.25, 1.25)
    return w / w.sum(1, keepdims=True)


def amostras(v, f, cor, passo):
    """Pontos espalhados pela superfície do original (cada triângulo numa
    grade com espaço `passo`), com a cor interpolada e a normal da face."""
    pts, cores, nors = [], [], []
    e1 = v[f[:, 1]] - v[f[:, 0]]
    e2 = v[f[:, 2]] - v[f[:, 0]]
    fn = np.cross(e1, e2)
    fn = fn / np.maximum(np.linalg.norm(fn, axis=1, keepdims=True), 1e-12)
    lado = np.maximum(np.linalg.norm(e1, axis=1), np.maximum(np.linalg.norm(e2, axis=1),
                      np.linalg.norm(v[f[:, 2]] - v[f[:, 1]], axis=1)))
    n_div = np.clip(np.ceil(lado / passo).astype(int), 1, 40)
    grades = {}
    for d in np.unique(n_div):
        b = []
        for i in range(d + 1):
            for j in range(d + 1 - i):
                b.append((i / d, j / d))
        b = np.array(b)
        grades[d] = np.stack([1 - b[:, 0] - b[:, 1], b[:, 0], b[:, 1]], 1)
    for d in np.unique(n_div):
        sel = np.where(n_div == d)[0]
        w = grades[d]                      # (k, 3)
        tri = f[sel]                       # (s, 3)
        p = np.einsum("kc,scd->skd", w, v[tri])
        c = np.einsum("kc,scd->skd", w, cor[tri])
        pts.append(p.reshape(-1, 3))
        cores.append(c.reshape(-1, 4))
        nors.append(np.repeat(fn[sel], len(w), 0))
    return np.concatenate(pts), np.concatenate(cores), np.concatenate(nors)


def procurar(arvore, a_nor, pontos, normais, k=16):
    """Para cada ponto, a amostra mais perto do MESMO LADO da superfície
    (folhas finas: o outro lado está quase no mesmo lugar)."""
    k = min(k, len(a_nor))
    _, idx = arvore.query(pontos, k=k)
    if idx.ndim == 1:
        idx = idx[:, None]
    bom = np.einsum("pkd,pd->pk", a_nor[idx], normais) > 0.15
    primeiro = np.where(bom.any(1), bom.argmax(1), 0)
    return idx[np.arange(len(idx)), primeiro]


# ------------------------------------------------------------ assar
def rasterizar(uv_px, f, tam):
    """Os pixels de cada triângulo no mapa UV: (linha, coluna, triângulo,
    pesos baricêntricos). Pixels a meio caminho da borda entram (sem frestas)."""
    linhas, colunas, tris, pesos = [], [], [], []
    for i, t in enumerate(f):
        a, b, c = uv_px[t[0]], uv_px[t[1]], uv_px[t[2]]
        x0 = int(max(math.floor(min(a[0], b[0], c[0])) - 1, 0))
        x1 = int(min(math.ceil(max(a[0], b[0], c[0])) + 1, tam - 1))
        y0 = int(max(math.floor(min(a[1], b[1], c[1])) - 1, 0))
        y1 = int(min(math.ceil(max(a[1], b[1], c[1])) + 1, tam - 1))
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        p = np.stack([xs.ravel(), ys.ravel()], 1)
        d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(d) < 1e-9:
            continue
        w0 = ((b[1] - c[1]) * (p[:, 0] - c[0]) + (c[0] - b[0]) * (p[:, 1] - c[1])) / d
        w1 = ((c[1] - a[1]) * (p[:, 0] - c[0]) + (a[0] - c[0]) * (p[:, 1] - c[1])) / d
        w2 = 1 - w0 - w1
        # meio pixel de folga (em baricêntrico, aproximado pela altura)
        folga = 0.6 / max(math.sqrt(abs(d)), 1.0)
        dentro = (w0 >= -folga) & (w1 >= -folga) & (w2 >= -folga)
        if not dentro.any():
            continue
        w = np.clip(np.stack([w0, w1, w2], 1)[dentro], 0, None)
        w /= w.sum(1, keepdims=True)
        linhas.append(p[dentro, 1].astype(int))
        colunas.append(p[dentro, 0].astype(int))
        tris.append(np.full(dentro.sum(), i))
        pesos.append(w)
    return np.concatenate(linhas), np.concatenate(colunas), np.concatenate(tris), np.concatenate(pesos)


def dilatar(img, cheio, vezes=PADDING * 3):
    """Espalha a cor das bordas das ilhas para os pixels vazios em volta
    (o mipmap não mistura o fundo preto nas bordas)."""
    img = img.copy()
    cheio = cheio.copy()
    for _ in range(vezes):
        soma = np.zeros_like(img)
        cont = np.zeros(cheio.shape)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (-1, 1), (1, -1), (1, 1)):
            m = np.roll(np.roll(cheio, dy, 0), dx, 1)
            soma += np.roll(np.roll(img, dy, 0), dx, 1) * m[..., None]
            cont += m
        novo = (~cheio) & (cont > 0)
        img[novo] = soma[novo] / cont[novo][:, None]
        cheio = cheio | novo
    if (~cheio).any():
        img[~cheio] = img[cheio].mean(0)
    return img


def forma_leve(fonte, alvo_tris, erro=None):
    """A FORMA LEVE (7.0) de uma fonte: soldada, simplificada peça por peça
    com os pontos no lugar ótimo e as normais suaves da fonte (só as quinas
    de verdade duplicam pontos). Devolve (pontos, normais, triângulos)."""
    vw, fw, inv = soldar(fonte["arr"][VERTEX].astype(np.float64), fonte["ind"].reshape(-1, 3).astype(np.int64))
    media, quina = normais_do_original(fonte["arr"][NORMAL].astype(np.float64), inv, len(vw))
    pv, pf = simplificar_pecas(vw, fw, alvo_tris, erro, pontos_novos=True)
    n, q = normais_nos_pontos(pv, pf, vw, media, quina)
    return normais_suaves(pv, pf, n, q)


def so_cor(antigo, alvo_tris, erro=None, forma=None):
    """Forma limpa do original, normais do original e a cor dele nos
    vértices (sem textura e sem cortes: o mínimo de vértices). Com `forma`
    (a fonte de grade normal, veja main), a forma e as normais vêm dela; a
    cor de cada ponto vem da fonte fina (a amostra mais perto, do mesmo
    lado)."""
    pos, nor, fn = forma_leve(forma if forma is not None else antigo, alvo_tris, erro)
    v = antigo["arr"][VERTEX].astype(np.float64)
    f = antigo["ind"].reshape(-1, 3).astype(np.int64)
    cor = antigo["arr"][COLOR].astype(np.float64) if COLOR in antigo["arr"] else np.ones((len(v), 4))
    diag = float(np.linalg.norm(v.max(0) - v.min(0)))
    a_pts, a_cor, a_nor = amostras(v, f, cor, diag / 400.0)
    cores = a_cor[procurar(cKDTree(a_pts), a_nor, pos, nor)]
    return _superficie(pos, nor, cores, None, fn)


def _superficie(pos, nor, cores, uv, fx):
    """Ordem boa para o cache e só os vértices usados, na ordem (a Mali
    calcula todos os vértices da faixa de cada desenho)."""
    ind = fx.reshape(-1).astype(np.uint32)
    otim = np.zeros_like(ind)
    mo.optimize_vertex_cache(otim, ind, vertex_count=len(pos))
    _, primeiro = np.unique(otim, return_index=True)
    seq = otim[np.sort(primeiro)].astype(np.int64)
    ordem = np.full(len(pos), -1, dtype=np.int64)
    ordem[seq] = np.arange(len(seq))
    listas = (1 << VERTEX) | (1 << NORMAL) | (1 << COLOR)
    arr = {VERTEX: pos[seq].astype(np.float32), NORMAL: nor[seq].astype(np.float32),
           COLOR: cores[seq].astype(np.float32)}
    if uv is not None:
        listas |= 1 << TEX_UV
        arr[TEX_UV] = uv[seq].astype(np.float32)
    return {"prim": TRIANGULOS, "listas": listas, "arr": arr, "ind": ordem[otim].astype(np.uint32)}


# uma peça solta (um pedaço da malha) vai sem textura quando a cor nos
# vértices reproduz o original nela: a diferença (0..1, em cada cor) em 99,5%
# dos pontos tem que ficar abaixo disto
LISO = 0.08


def _pecas_soltas(pos, fn):
    """Rótulo da peça solta de cada triângulo (pontos no mesmo lugar contam
    como um só: as quinas duplicadas não separam a peça)."""
    from scipy.sparse import coo_matrix
    from scipy.sparse.csgraph import connected_components
    _, unico = np.unique(np.round(pos / 1e-5).astype(np.int64), axis=0, return_inverse=True)
    unico = unico.ravel()
    fu = unico[fn]
    n = unico.max() + 1
    lig = coo_matrix((np.ones(fu.size), (fu.reshape(-1), np.roll(fu, 1, 1).reshape(-1))), shape=(n, n))
    _, rotulo = connected_components(lig, directed=False)
    return rotulo[fu[:, 0]]


def _liso(pos, nor, fn, arvore, a_nor, a_cor, cor_v):
    """Quais triângulos a cor nos vértices (cor_v) reproduz: pontos dentro de
    cada um comparados com o original."""
    b = np.array([(i / 4, j / 4) for i in range(5) for j in range(5 - i)])
    w = np.stack([1 - b[:, 0] - b[:, 1], b[:, 0], b[:, 1]], 1)          # (k, 3)
    p = np.einsum("kc,fcd->fkd", w, pos[fn]).reshape(-1, 3)
    n = np.einsum("kc,fcd->fkd", w, nor[fn]).reshape(-1, 3)
    n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)
    orig = a_cor[procurar(arvore, a_nor, p, n), :3].reshape(len(fn), len(w), 3)
    interp = np.einsum("kc,fcd->fkd", w, cor_v[fn][:, :, :3])
    return np.abs(orig - interp).max(2)                                  # (f, k)


def assar(nome, antigo, alvo_tris, tam, erro=None, forma=None):
    v = antigo["arr"][VERTEX].astype(np.float64)
    cor = antigo["arr"][COLOR].astype(np.float64) if COLOR in antigo["arr"] else np.ones((len(v), 4))
    f = antigo["ind"].reshape(-1, 3).astype(np.int64)
    # 1. e 2. a forma leve (da fonte de grade normal, se tiver: veja main),
    # com os pontos no lugar ótimo e as normais suaves da fonte
    pos, nor, fn = forma_leve(forma if forma is not None else antigo, alvo_tris, erro)
    # as amostras do original (cor, normal) para assar e comparar
    area = np.linalg.norm(np.cross(v[f[:, 1]] - v[f[:, 0]], v[f[:, 2]] - v[f[:, 0]]), axis=1).sum() / 2
    passo = math.sqrt(area / (tam * tam * 0.5)) * 0.6
    a_pts, a_cor, a_nor = amostras(v, f, cor, passo)
    arvore = cKDTree(a_pts)
    # 3. AS PEÇAS LISAS SEM TEXTURA: cada peça solta (uma barra da roda, um
    # graveto do ninho, uma folha) em que a cor nos vértices já reproduz o
    # original vai sem textura — a cor no vértice e o UV no branco do atlas.
    # Os cortes do mapa UV duplicam os vértices das bordas: numa peça com
    # dezenas de pedaços soltos eles dobravam os vértices (e na Mali-450
    # cada vértice conta). Só as peças com desenho vão para a textura.
    cor_v = a_cor[procurar(arvore, a_nor, pos, nor)]
    dif = _liso(pos, nor, fn, arvore, a_nor, a_cor, cor_v)
    peca = _pecas_soltas(pos, fn)
    lisa_peca = np.array([np.percentile(dif[peca == k], 99.5) < LISO for k in range(peca.max() + 1)])
    lisa = lisa_peca[peca]
    partes = []
    if lisa.any():
        fl_ = fn[lisa]
        us = np.unique(fl_)
        rm = np.full(len(pos), -1)
        rm[us] = np.arange(len(us))
        partes.append(_superficie(pos[us], nor[us], cor_v[us], np.full((len(us), 2), UV_BRANCO), rm[fl_]))
    img = None
    if (~lisa).any():
        fd = fn[~lisa]
        us = np.unique(fd)
        rm = np.full(len(pos), -1)
        rm[us] = np.arange(len(us))
        pd, nd, fd = pos[us], nor[us], rm[fd]
        # 4. UV das peças com desenho
        atlas = xatlas.Atlas()
        atlas.add_mesh(pd.astype(np.float32), fd.astype(np.uint32), nd.astype(np.float32))
        # pedaços grandes (cada corte no mapa duplica os vértices da borda):
        # aceita um pouco mais de esticada
        co = xatlas.ChartOptions()
        co.max_cost = 40.0
        co.normal_deviation_weight = 0.3
        co.straightness_weight = 2.0
        co.max_iterations = 4
        po = xatlas.PackOptions()
        po.resolution = tam
        po.padding = PADDING
        po.bilinear = True
        po.bruteForce = False
        atlas.generate(chart_options=co, pack_options=po)
        vmap, fx, uv = atlas[0]
        pd = pd[vmap]
        nd = nd[vmap]
        fx = fx.astype(np.int64)
        # 5. cor do original na textura: por RAIOS (6.3), 4 por pixel
        uv_px = uv * tam
        lin, col, tri, w = rasterizar(uv_px, fx, tam)
        rgb = cor_por_raios(v, f, cor, uv_px, fx, pd, nd, lin, col, tri, arvore, a_pts, a_nor, a_cor, pos)
        img = np.zeros((tam, tam, 3))
        cheio = np.zeros((tam, tam), bool)
        img[lin, col] = rgb
        cheio[lin, col] = True
        img = (np.clip(dilatar(img, cheio), 0, 1) * 255 + 0.5).astype(np.uint8)
        # 6. alfa (o que brilha) de cada vértice, do original; a cor é branca
        alfa = a_cor[procurar(arvore, a_nor, pd, nd), 3]
        cores = np.ones((len(pd), 4))
        cores[:, 3] = alfa
        partes.insert(0, _superficie(pd, nd, cores, uv, fx))
    sup = partes[0]
    for outra in partes[1:]:
        sup = _juntar(sup, outra)
    return sup, img


IMPORT = """[remap]

importer="texture"
type="StreamTexture"

[params]

compress/mode=2
compress/lossy_quality=1.0
compress/hdr_mode=0
compress/bptc_ldr=0
compress/normal_map=0
flags/repeat=0
flags/filter=true
flags/mipmaps=true
flags/anisotropic=false
flags/srgb=2
process/fix_alpha_border=true
process/premult_alpha=false
process/HDR_as_SRGB=false
process/invert_color=false
process/normal_map_invert_y=false
stream=false
size_limit=0
detect_3d=false
svg/scale=1.0
"""


# ------------------------------------------------------------ o baú aberto
# O BAÚ DO TESOURO ABRE: a tampa vira uma peça à parte (bau_tampa.res, com a
# origem na dobradiça — temas.gd a gira uma vez e ela fica aberta) e dentro
# do corpo aparece o TESOURO: um monte de ouro, moedas e joias com poucos
# triângulos e a cor nos vértices (o UV no quadradinho branco do atlas: o
# mesmo material do resto). As joias e algumas moedas brilham (o alfa da
# cor do vértice, como as lâmpadas).
BAU_CORTE = 0.45                 # a tampa começa aqui (o corpo vai até 0,46 por dentro dela)
BAU_DOBRADICA = (0.452, -0.297)  # (y, z) da dobradiça: atrás, embaixo da tampa
BAU_BOCA = (0.427, 0.294, 0.46)  # meia largura, meia fundura e altura da boca do corpo
UV_BRANCO = -1.0                 # UV das peças com cor no vértice (montar_atlas troca pelo branco)
## o DESENHO DO TESOURO (6.3): moedas e joias pintadas numa textura própria
## (pintar_tesouro, um pedaço do atlas) — nítidas, com pouca malha. O UV de
## quem usa esse desenho vem com u - 3 (montar_atlas leva para o pedaço).
UV_TESOURO = -3.0
TESOURO_TAM = 256
TESOURO_MONTE = (0.75, 0.53)     # o monte de ouro: u 0..0,75, v 0..0,53
TESOURO_MOEDA = (0.875, 0.125, 0.115)   # a cara da moeda: centro (u, v) e raio


def _sub(s, sel):
    """Só os triângulos `sel` de uma superfície (com os vértices deles)."""
    f = s["ind"].reshape(-1, 3)[sel]
    usados = np.unique(f)
    remap = np.full(len(s["arr"][VERTEX]), -1)
    remap[usados] = np.arange(len(usados))
    return {"prim": s["prim"], "listas": s["listas"], "arr": {k: a[usados] for k, a in s["arr"].items()},
            "ind": remap[f].reshape(-1).astype(np.uint32)}


def dividir_bau(antigo):
    """O baú original em corpo (com o cadeado) e tampa."""
    v = antigo["arr"][VERTEX].astype(np.float64)
    f = antigo["ind"].reshape(-1, 3).astype(np.int64)
    # o cadeado é uma peça solta (a menor): fica no corpo
    vw, fw, _ = soldar(v, f)
    from scipy.sparse import coo_matrix
    from scipy.sparse.csgraph import connected_components
    n = len(vw)
    lig = coo_matrix((np.ones(len(fw) * 3), (fw.reshape(-1), np.roll(fw, 1, 1).reshape(-1))), shape=(n, n))
    _, rotulo = connected_components(lig, directed=False)
    peca = rotulo[fw[:, 0]]
    maior = np.bincount(peca).argmax()
    tampa = (v[f].mean(1)[:, 1] > BAU_CORTE) & (peca == maior)
    return _sub(antigo, ~tampa), _sub(antigo, tampa)


def _juntar(a, b):
    """Duas superfícies numa (mesmas listas)."""
    n = len(a["arr"][VERTEX])
    return {"prim": a["prim"], "listas": a["listas"],
            "arr": {k: np.concatenate([a["arr"][k], b["arr"][k]]).astype(np.float32) for k in a["arr"]},
            "ind": np.concatenate([a["ind"], b["ind"] + n]).astype(np.uint32)}


class _Pecas:
    """Junta triângulos soltos (posição, normal, cor) numa superfície com UV
    no branco do atlas."""

    def __init__(self):
        self.pos, self.nor, self.cor, self.uv, self.ind = [], [], [], [], []
        self._vistos = {}

    def tri(self, pts, nors, cores, uvs=None):
        # o mesmo ponto (lugar, normal, cor e UV) é um vértice só. No Godot a
        # frente do triângulo é a do sentido HORÁRIO (a normal da regra da
        # mão direita aponta para trás): grava na ordem inversa
        if uvs is None:
            uvs = [np.array([UV_BRANCO, 0.0])] * 3
        for q, n, c, t in zip(pts[::-1], nors[::-1], cores[::-1], uvs[::-1]):
            chave = tuple(np.round(np.concatenate([q, n, c, t]), 5))
            if chave not in self._vistos:
                self._vistos[chave] = len(self.pos)
                self.pos.append(q)
                self.nor.append(n)
                self.cor.append(c)
                self.uv.append(t)
            self.ind.append(self._vistos[chave])

    def chato(self, pts, cor, centro):
        """Triângulo com a normal da face (quinas vivas: joias, paredes),
        virado para longe de `centro`."""
        n = np.cross(pts[1] - pts[0], pts[2] - pts[0])
        n = n / max(np.linalg.norm(n), 1e-12)
        if np.dot(n, np.mean(pts, 0) - centro) < 0:
            pts, n = pts[::-1], -n
        self.tri(pts, [n] * 3, [cor] * 3)

    def superficie(self, listas):
        nv = len(self.pos)
        arr = {VERTEX: np.array(self.pos, np.float32), NORMAL: np.array(self.nor, np.float32),
               COLOR: np.array(self.cor, np.float32), TEX_UV: np.array(self.uv, np.float32).reshape(nv, 2)}
        arr = {k: a for k, a in arr.items() if listas & (1 << k)}
        return {"prim": TRIANGULOS, "listas": listas, "arr": arr, "ind": np.array(self.ind, np.uint32)}


def _cor(hexa, alfa=0.0):
    h = hexa.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)] + [alfa])


def tesouro(listas):
    """O tesouro na boca do corpo: o monte de ouro com as moedas e joias
    PINTADAS (pintar_tesouro: nítidas de perto e de longe), três moedas
    grandes de pé no monte (a cara também pintada, com borda grossa),
    quatro joias lapidadas (as faces de cima claras, as de baixo escuras)
    e a parede de dentro (uma faixa escura logo abaixo da borda)."""
    rnd = np.random.RandomState(7)
    mx, mz, topo = BAU_BOCA
    p = _Pecas()
    # o monte de ouro: uma grade com uma corcova no meio, a borda logo
    # abaixo da boca; a cor vem do desenho (o vértice é branco; alguns
    # brilham — o alfa)
    nx, nz = 9, 7
    xs = np.linspace(-mx, mx, nx)
    zs = np.linspace(-mz, mz, nz)
    h = np.zeros((nz, nx))
    for i, z in enumerate(zs):
        for j, x in enumerate(xs):
            u, w = x / mx, z / mz
            h[i, j] = topo - 0.015 + 0.10 * (1 - u * u) * (1 - w * w)
            if 0 < i < nz - 1 and 0 < j < nx - 1:
                h[i, j] += rnd.uniform(-0.008, 0.008)
    gz, gx = np.gradient(h, zs, xs)
    um, vm = TESOURO_MONTE

    def ponto(i, j):
        n = np.array([-gx[i, j], 1.0, -gz[i, j]])
        c = np.array([1.0, 1.0, 1.0, 0.62 if (i * 7 + j * 3) % 9 == 0 else 0.0])
        t = np.array([UV_TESOURO + (xs[j] / mx * 0.5 + 0.5) * um, (zs[i] / mz * 0.5 + 0.5) * vm])
        return np.array([xs[j], h[i, j], zs[i]]), n / np.linalg.norm(n), c, t
    for i in range(nz - 1):
        for j in range(nx - 1):
            a, b, c, d = ponto(i, j), ponto(i, j + 1), ponto(i + 1, j + 1), ponto(i + 1, j)
            for tr in ((a, d, c), (a, c, b)):
                p.tri([q[0] for q in tr], [q[1] for q in tr], [q[2] for q in tr], [q[3] for q in tr])

    def altura(x, z):
        j = np.clip(np.searchsorted(xs, x) - 1, 0, nx - 2)
        i = np.clip(np.searchsorted(zs, z) - 1, 0, nz - 2)
        return h[i:i + 2, j:j + 2].mean()
    # três moedas grandes encostadas no monte (8 lados, com espessura)
    cu, cv, cr = TESOURO_MOEDA
    branco = np.array([1.0, 1.0, 1.0, 0.62])
    beira = _cor("#C8861A")
    for k, (x, z, inc_x, inc_z) in enumerate(((-0.17, 0.12, 0.9, 0.5), (0.2, 0.15, -0.8, 0.6), (0.04, -0.12, 0.3, -0.55))):
        r, esp = 0.06, 0.012
        n = np.array([inc_x, 1.0, inc_z])
        n /= np.linalg.norm(n)
        centro = np.array([x, altura(x, z) + r * 0.55, z])
        e1 = np.cross(n, [0.0, 1.0, 0.0])
        e1 /= np.linalg.norm(e1)
        e2 = np.cross(n, e1)
        ang = np.linspace(0, 2 * np.pi, 9)[:-1]
        topo_c = centro + n * esp * 0.5
        base_c = centro - n * esp * 0.5
        bt = [topo_c + r * (np.cos(a) * e1 + np.sin(a) * e2) for a in ang]
        bb = [base_c + r * (np.cos(a) * e1 + np.sin(a) * e2) for a in ang]
        uvs = [np.array([UV_TESOURO + cu + cr * np.cos(a), cv + cr * np.sin(a)]) for a in ang]
        uc = np.array([UV_TESOURO + cu, cv])
        for a in range(8):
            b2 = (a + 1) % 8
            # a cara (desenhada) e a borda (ouro escuro, quinas vivas)
            p.tri([topo_c, bt[a], bt[b2]], [n] * 3, [branco] * 3, [uc, uvs[a], uvs[b2]])
            p.chato([bt[a], bb[a], bb[b2]], beira, centro)
            p.chato([bt[a], bb[b2], bt[b2]], beira, centro)
    # joias lapidadas (octaedros de quinas vivas): as faces de cima claras e
    # as de baixo escuras — cada face uma cor lisa, bem definida
    for k, (cor, x, z) in enumerate((("#FF2D55", -0.24, -0.06), ("#2E7BFF", 0.25, -0.1),
                                     ("#2ED47A", -0.02, 0.19), ("#B25BFF", 0.31, 0.17))):
        base = _cor(cor, 0.6)
        claro = base.copy()
        claro[:3] = base[:3] * 0.55 + 0.45
        escuro = base.copy()
        escuro[:3] = base[:3] * 0.62
        r = 0.058 if k == 0 else 0.05
        centro = np.array([x, altura(x, z) + r * 0.6, z])
        giro = rnd.uniform(0, np.pi)
        e = [np.array([np.cos(giro + a), 0.0, np.sin(giro + a)]) for a in (0, np.pi / 2, np.pi, 3 * np.pi / 2)]
        cima, baixo = centro + [0, r * 1.15, 0], centro - [0, r * 1.15, 0]
        for a in range(4):
            q0, q1 = centro + r * e[a], centro + r * e[(a + 1) % 4]
            p.chato([cima, q1, q0], claro if a % 2 == 0 else base, centro)
            p.chato([baixo, q0, q1], escuro, centro)
    # a parede de dentro: faixa escura da borda até o ouro (sem ela, olhando
    # de cima, a parede do corpo — que só tem o lado de fora — some)
    madeira = _cor("#5C3014")
    y0, y1 = topo, topo - 0.05
    cantos = [(-mx, -mz), (mx, -mz), (mx, mz), (-mx, mz)]
    for a in range(4):
        (x0, z0), (x1, z1) = cantos[a], cantos[(a + 1) % 4]
        p0, p1 = np.array([x0, y0, z0]), np.array([x1, y0, z1])
        p2, p3 = np.array([x1, y1, z1]), np.array([x0, y1, z0])
        # virada para dentro: "longe" de um ponto do lado de fora da parede
        fora = (p0 + p2) / 2 * np.array([2.0, 1.0, 2.0])
        p.chato([p0, p2, p1], madeira, fora)
        p.chato([p0, p3, p2], madeira, fora)
    return p.superficie(listas)


def pintar_tesouro():
    """O desenho do tesouro (TESOURO_TAM x TESOURO_TAM, já como sai na
    tela, como os pedaços assados): à esquerda, em cima, o monte de ouro
    visto de cima — moedas umas sobre as outras (borda escura, cara clara
    com estrela e um brilho), joias lapidadas e pérolas; à direita, em
    cima, a cara de uma moeda grande (a das moedas de pé)."""
    from PIL import ImageDraw
    k = 2
    t = TESOURO_TAM * k
    img = Image.new("RGB", (t, t), (236, 190, 60))
    d = ImageDraw.Draw(img)
    rnd = np.random.RandomState(21)

    def moeda(cx, cy, r):
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(196, 140, 30))
        d.ellipse([cx - r * 0.86, cy - r * 0.86, cx + r * 0.86, cy + r * 0.86], fill=(255, 226, 96))
        d.ellipse([cx - r * 0.66, cy - r * 0.66, cx + r * 0.66, cy + r * 0.66], outline=(236, 182, 46), width=max(1, int(r * 0.09)))
        pts = []
        for i in range(10):
            a = -np.pi / 2 + np.pi * i / 5
            rr = r * (0.42 if i % 2 == 0 else 0.18)
            pts.append((cx + np.cos(a) * rr, cy + np.sin(a) * rr))
        d.polygon(pts, fill=(240, 186, 48))
        d.arc([cx - r * 0.74, cy - r * 0.74, cx + r * 0.74, cy + r * 0.74], 195, 255, fill=(255, 246, 200), width=max(1, int(r * 0.14)))

    def joia(cx, cy, r, cor):
        cor = np.array(cor, float)
        claro = tuple(int(c) for c in cor * 0.5 + 127)
        escuro = tuple(int(c) for c in cor * 0.6)
        base = tuple(int(c) for c in cor)
        out = [(cx + np.cos(a) * r, cy + np.sin(a) * r) for a in np.linspace(0, 2 * np.pi, 7)[:-1] + np.pi / 6]
        mesa = [(cx + np.cos(a) * r * 0.5, cy + np.sin(a) * r * 0.5) for a in np.linspace(0, 2 * np.pi, 7)[:-1] + np.pi / 6]
        d.polygon(out, fill=(60, 30, 20))
        for i in range(6):
            j = (i + 1) % 6
            cor_f = claro if i in (3, 4) else (escuro if i in (0, 1) else base)
            d.polygon([out[i], out[j], mesa[j], mesa[i]], fill=cor_f)
        d.polygon(mesa, fill=base)
        g = r * 0.28
        d.polygon([(mesa[4][0], mesa[4][1] - g), (mesa[4][0] + g * 0.3, mesa[4][1]), (mesa[4][0], mesa[4][1] + g),
                   (mesa[4][0] - g * 0.3, mesa[4][1])], fill=(255, 255, 255))

    def perola(cx, cy, r):
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(200, 196, 210))
        d.ellipse([cx - r * 0.85, cy - r * 0.95, cx + r * 0.7, cy + r * 0.6], fill=(250, 248, 255))
        d.ellipse([cx - r * 0.5, cy - r * 0.6, cx - r * 0.1, cy - r * 0.2], fill=(255, 255, 255))

    um, vm = TESOURO_MONTE
    w, h = int(t * um), int(t * vm)
    # o fundo do monte: ouro com um pouco de sombra entre as moedas
    for _ in range(500):
        x, y = rnd.uniform(0, w), rnd.uniform(0, h)
        r = rnd.uniform(8, 16) * k
        c = (int(rnd.uniform(205, 240)), int(rnd.uniform(160, 190)), 50)
        d.ellipse([x - r, y - r, x + r, y + r], fill=c)
    # moedas umas sobre as outras (as de baixo primeiro)
    for _ in range(230):
        moeda(rnd.uniform(-10, w + 10), rnd.uniform(-10, h + 10), rnd.uniform(11, 15) * k)
    # joias e pérolas por cima
    cores = [(255, 45, 85), (46, 123, 255), (46, 212, 122), (178, 91, 255), (255, 200, 40), (40, 220, 240)]
    for i in range(12):
        joia(rnd.uniform(40, w - 40), rnd.uniform(40, h - 40), rnd.uniform(14, 18) * k, cores[i % len(cores)])
    for _ in range(10):
        perola(rnd.uniform(20, w - 20), rnd.uniform(20, h - 20), rnd.uniform(6, 8) * k)
    # a cara da moeda grande
    cu, cv, cr = TESOURO_MOEDA
    moeda(cu * t, cv * t, cr * t)
    img = img.resize((TESOURO_TAM, TESOURO_TAM), Image.LANCZOS)
    a = np.asarray(img).astype(np.float64) / 255.0
    return (np.clip(tela_g4(s2l(a.reshape(-1, 3))).reshape(a.shape), 0, 1) * 255 + 0.5).astype(np.uint8)


def tampa_por_dentro(listas, tampa):
    """A tábua de baixo da tampa (o lado de dentro, que aparece com ela
    aberta) e a tampa com a origem na dobradiça."""
    v = tampa["arr"][VERTEX]
    baixo = v[:, 1].min() + 0.004
    x0, x1 = v[:, 0].min() + 0.012, v[:, 0].max() - 0.012
    z0, z1 = v[:, 2].min() + 0.012, v[:, 2].max() - 0.012
    p = _Pecas()
    escuro, claro = _cor("#4A260F"), _cor("#7A4420")
    a, b, c, d = (np.array([x0, baixo, z0]), np.array([x1, baixo, z0]),
                  np.array([x1, baixo, z1]), np.array([x0, baixo, z1]))
    n = np.array([0.0, -1.0, 0.0])
    p.tri([a, b, c], [n] * 3, [escuro, claro, escuro])
    p.tri([a, c, d], [n] * 3, [escuro, escuro, claro])
    s = _juntar(tampa, p.superficie(listas))
    s["arr"][VERTEX] = s["arr"][VERTEX] - np.array([0.0, BAU_DOBRADICA[0], BAU_DOBRADICA[1]], np.float32)
    return s


def _alocar(livres, t):
    """Um quadrado de lado t no atlas: o menor livre que serve, dividido em
    quatro até o tamanho certo (os lados são potências de 2)."""
    cand = [q for q in livres if q[2] >= t]
    if not cand:
        raise SystemExit("o atlas encheu")
    q = min(cand, key=lambda q: (q[2], q[1], q[0]))
    livres.remove(q)
    x, y, lado = q
    while lado > t:
        lado //= 2
        livres += [(x + lado, y, lado), (x, y + lado, lado), (x + lado, y + lado, lado)]
    return x, y


def montar_atlas(atuais, saida):
    """Junta os pedaços dos objetos com textura no ATLAS DE CADA FASE (7.0:
    atlas_<fase>.png, TEMAS_DO_OBJETO) e grava a malha de cada um
    (<id>.leve.msh) com o UV levado para o pedaço dele. Os que aparecem em
    mais de uma fase, o quadradinho branco e o tesouro ficam no MESMO lugar
    em todas (a malha é uma só), e todas as imagens têm a mesma altura."""
    from scipy import ndimage
    pecas = []
    for e in json.load(open(os.path.join(atuais, "indice.json"))):
        if "/cenario/" not in e["recurso"]:
            continue
        nome = os.path.basename(e["recurso"]).rsplit(".", 1)[0]
        pedaco = os.path.join(atuais, "pedacos", nome + ".png")
        local = os.path.join(atuais, e["id"] + ".local.msh")
        if not _e_nivel(nome) and os.path.exists(pedaco) and os.path.exists(local):
            pecas.append((nome, e["id"], np.asarray(Image.open(pedaco).convert("RGB")), ler_msh(local)[0]))
    if not pecas:
        return
    temas_de = {}
    for tema, nomes in TEMAS_DO_OBJETO.items():
        for n in nomes:
            temas_de.setdefault(n, []).append(tema)
    for nome, _, _, _ in pecas:
        if nome not in temas_de:
            raise SystemExit("objeto sem fase (TEMAS_DO_OBJETO): %s" % nome)
    # os maiores primeiro; primeiro os das várias fases (lugar comum)
    pecas.sort(key=lambda p: (len(temas_de[p[0]]) < 2, -p[2].shape[0], p[0]))
    comuns = [p for p in pecas if len(temas_de[p[0]]) > 1]
    livres = [(x, y, 2048) for y in range(0, 8192, 2048) for x in range(0, ATLAS_LARGURA, 2048)]
    lugares = {}
    for p in comuns:
        lugares[p[0]] = _alocar(livres, p[2].shape[0])
    des_tesouro = pintar_tesouro()
    tx, ty = _alocar(livres, TESOURO_TAM)
    bx, by = _alocar(livres, 16)
    usado = [by + 16, ty + TESOURO_TAM] + [lugares[p[0]][1] + p[2].shape[0] for p in comuns]
    for tema in TEMAS_DO_OBJETO:
        lv = list(livres)
        for p in pecas:
            if len(temas_de[p[0]]) == 1 and temas_de[p[0]][0] == tema:
                lugares[p[0]] = _alocar(lv, p[2].shape[0])
                usado.append(lugares[p[0]][1] + p[2].shape[0])
    altura = 512
    while altura < max(usado):
        altura *= 2
    if altura > 4096:
        raise SystemExit("o atlas passou de 4096 de altura (a Mali-450 não aceita): diminua as texturas")
    uv_branco = np.array([(bx + 8) / ATLAS_LARGURA, (by + 8) / altura], np.float32)
    imgs = {t: np.zeros((altura, ATLAS_LARGURA, 3), np.uint8) for t in TEMAS_DO_OBJETO}
    cheios = {t: np.zeros((altura, ATLAS_LARGURA), bool) for t in TEMAS_DO_OBJETO}
    for nome, ident, px, sup in pecas:
        x, y = lugares[nome]
        t = px.shape[0]
        for tema in temas_de[nome]:
            imgs[tema][y:y + t, x:x + t] = px
            cheios[tema][y:y + t, x:x + t] = True
        uv = sup["arr"][TEX_UV].astype(np.float64)
        novo = np.empty_like(uv)
        novo[:, 0] = (x + uv[:, 0] * t) / ATLAS_LARGURA
        novo[:, 1] = (y + uv[:, 1] * t) / altura
        # as partes com a cor no vértice (joias, bordas das moedas): no branco
        novo[uv[:, 0] <= UV_BRANCO] = uv_branco
        # as partes com o desenho do tesouro: no pedaço dele
        des = uv[:, 0] < (UV_BRANCO + UV_TESOURO) * 0.5
        novo[des, 0] = (tx + (uv[des, 0] - UV_TESOURO) * TESOURO_TAM) / ATLAS_LARGURA
        novo[des, 1] = (ty + uv[des, 1] * TESOURO_TAM) / altura
        sup = dict(sup)
        sup["arr"] = dict(sup["arr"])
        sup["arr"][TEX_UV] = novo.astype(np.float32)
        gravar_msh(os.path.join(atuais, ident + ".leve.msh"), [sup])
        print("  atlas %-6s: %-14s %4d px em (%4d, %4d)" % ("+".join(temas_de[nome]), nome, t, x, y))
    # o QUADRADINHO BRANCO (o branco como sai na tela com luz 1, como os
    # pedaços): as peças de uma cor só apontam o UV para o meio dele e a cor
    # delas vem do vértice — o mesmo material das de textura
    branco = (np.clip(tela_g4(s2l(np.ones((1, 3))))[0], 0, 1) * 255 + 0.5).astype(np.uint8)
    for tema in TEMAS_DO_OBJETO:
        imgs[tema][ty:ty + TESOURO_TAM, tx:tx + TESOURO_TAM] = des_tesouro
        cheios[tema][ty:ty + TESOURO_TAM, tx:tx + TESOURO_TAM] = True
        imgs[tema][by:by + 16, bx:bx + 16] = branco
        cheios[tema][by:by + 16, bx:bx + 16] = True
    n_cor = 0
    com_desenho = set(p[0] for p in pecas)
    for e in json.load(open(os.path.join(atuais, "indice.json"))):
        nome = os.path.basename(e["recurso"]).rsplit(".", 1)[0]
        leve = os.path.join(atuais, e["id"] + ".leve.msh")
        if "/cenario/" in e["recurso"] and nome not in com_desenho and not _e_nivel(nome) and os.path.exists(leve):
            sup = ler_msh(leve)[0]
            sup["arr"][TEX_UV] = np.tile(uv_branco, (len(sup["arr"][VERTEX]), 1))
            sup["listas"] |= 1 << TEX_UV
            gravar_msh(leve, [sup])
            n_cor += 1
    for tema in TEMAS_DO_OBJETO:
        img, cheio = imgs[tema], cheios[tema]
        # o que sobrou do atlas pega a cor do pedaço mais perto (os mipmaps de
        # longe não misturam preto nas bordas dos pedaços)
        if not cheio.all():
            _, (iy, ix) = ndimage.distance_transform_edt(~cheio, return_indices=True)
            img = img[iy, ix]
        caminho = os.path.join(saida, ATLAS % tema)
        Image.fromarray(img, "RGB").save(caminho, optimize=True)
        if not os.path.exists(caminho + ".import"):
            with open(caminho + ".import", "w", encoding="utf-8") as fi:
                fi.write(IMPORT)
    print("ATLAS %dx%d por fase com %d objetos com desenho e %d de uma cor só" % (ATLAS_LARGURA, altura, len(pecas), n_cor))


# ------------------------------------------------------------ versões de meio e de longe
## AS VERSÕES DE MEIO E DE LONGE (6.5 / 7.0): a mesma malha (o mesmo mapa UV
## no atlas) com menos triângulos, para as cópias que ficam pequenas na
## tela (scripts/temas.gd escolhe pelo tamanho da peça e a distância) e
## para o nível "normal" do governador do quadro. Grava <id>_meio.leve.msh
## e <id>_longe.leve.msh e as entradas no índice (o
## tools/malhas_leves.gd -- --importar cria <nome>_meio.res e _longe.res).
NIVEIS = (("meio", 0.45, 0.012), ("longe", 0.18, 0.02))
SEM_LONGE = ("bau", "bau_tampa", "lampada")


def _e_nivel(nome):
    return nome.endswith("_longe") or nome.endswith("_meio")


def gerar_niveis(atuais):
    caminho = os.path.join(atuais, "indice.json")
    indice = json.load(open(caminho))
    novos = []
    for e in indice:
        nome = os.path.basename(e["recurso"]).rsplit(".", 1)[0]
        leve = os.path.join(atuais, e["id"] + ".leve.msh")
        if "/cenario/" not in e["recurso"] or _e_nivel(nome) or nome in SEM_LONGE or not os.path.exists(leve):
            continue
        sup = ler_msh(leve)[0]
        pos = np.ascontiguousarray(sup["arr"][VERTEX].astype(np.float32))
        ind = np.ascontiguousarray(sup["ind"].astype(np.uint32))
        tris = len(ind) // 3
        linha = []
        for sufixo, fracao, erro in NIVEIS:
            destino = np.zeros_like(ind)
            qtd = mo.simplify(destino, ind, pos, target_index_count=max(60, int(tris * fracao)) * 3, target_error=erro)
            f = destino[:qtd].reshape(-1, 3)
            usados = np.unique(f)
            remap = np.full(len(pos), -1)
            remap[usados] = np.arange(len(usados))
            nivel = {"prim": sup["prim"], "listas": sup["listas"], "arr": {k: a[usados] for k, a in sup["arr"].items()},
                     "ind": remap[f].reshape(-1).astype(np.uint32)}
            ident = e["id"] + "_" + sufixo
            gravar_msh(os.path.join(atuais, ident + ".leve.msh"), [nivel])
            novos.append({"id": ident, "recurso": "res://modelos/cenario/%s_%s.res" % (nome, sufixo), "no": "", "superficies": []})
            linha.append("%s %5d" % (sufixo, len(f)))
        print("  níveis: %-14s perto %5d | %s" % (nome, tris, " | ".join(linha)))
    ids = {e["id"] for e in indice}
    indice += [n for n in novos if n["id"] not in ids]
    json.dump(indice, open(caminho, "w"), indent=1)


## VINCOS (7.0): nas peças de caixa com as bordas arredondadas (o baú e a
## tampa) a luz do cenário, feita por ponto, escurecia o triângulo inteiro
## de uma face lisa quando um canto dele ficava na borda (a normal de lado)
## — cunhas pretas na madeira. Nelas cada face pega só a média das vizinhas
## que dobram menos de VINCO graus: as faces ficam lisas e as bordas viram
## um vinco de desenho (só os pontos das bordas duplicam).
VINCO = {"bau": 40.0, "bau_tampa": 40.0}


def vincar(sup, angulo):
    """A mesma malha (os mesmos atributos) com as normais por canto: a média
    (por área) das faces vizinhas que dobram menos de `angulo` graus."""
    v = sup["arr"][VERTEX].astype(np.float64)
    f = sup["ind"].reshape(-1, 3).astype(np.int64)
    # as faces vizinhas pela POSIÇÃO (as costuras do UV não separam a borda)
    _, pos_id = np.unique(np.round(v, 5), axis=0, return_inverse=True)
    pos_id = pos_id.reshape(-1)
    fn = np.cross(v[f[:, 1]] - v[f[:, 0]], v[f[:, 2]] - v[f[:, 0]])
    fnu = fn / np.maximum(np.linalg.norm(fn, axis=1, keepdims=True), 1e-12)
    incid = [[] for _ in range(pos_id.max() + 1)]
    for i, tri in enumerate(f):
        for k in range(3):
            incid[pos_id[tri[k]]].append(i)
    lim = math.cos(math.radians(angulo))
    cantos = np.zeros((len(f), 3, 3))
    for i, tri in enumerate(f):
        for k in range(3):
            viz = incid[pos_id[tri[k]]]
            usar = fnu[viz] @ fnu[i] >= lim
            s = fn[viz][usar].sum(0)
            cantos[i, k] = s / max(np.linalg.norm(s), 1e-12)
    chave = np.concatenate([f.reshape(-1, 1), np.round(cantos.reshape(-1, 3) * 1000)], 1).astype(np.int64)
    _, primeiro, inv = np.unique(chave, axis=0, return_index=True, return_inverse=True)
    origem = f.reshape(-1)[primeiro]
    arr = {k: a[origem].copy() for k, a in sup["arr"].items()}
    arr[NORMAL] = cantos.reshape(-1, 3)[primeiro].astype(arr[NORMAL].dtype)
    return {"prim": sup["prim"], "listas": sup["listas"], "arr": arr, "ind": inv.reshape(-1).astype(np.uint32)}


def _gravar_assado(atuais, ident, nome, sup, img):
    """O pedaço da textura e a malha com o UV do pedaço (montar_atlas leva
    para o atlas); sem nenhuma peça com desenho, só a malha (o UV no branco)."""
    if nome in VINCO:
        sup = vincar(sup, VINCO[nome])
    pedaco = os.path.join(atuais, "pedacos", nome + ".png")
    local = os.path.join(atuais, ident + ".local.msh")
    if img is None:
        for velho in (pedaco, local):
            if os.path.exists(velho):
                os.remove(velho)
        gravar_msh(os.path.join(atuais, ident + ".leve.msh"), [sup])
        return
    os.makedirs(os.path.dirname(pedaco), exist_ok=True)
    Image.fromarray(img, "RGB").save(pedaco, optimize=True)
    gravar_msh(local, [sup])


def _no_indice(atuais, ident, recurso):
    """Uma peça nova (que ainda não existe no projeto) no índice: o
    tools/malhas_leves.gd -- --importar cria o recurso dela."""
    caminho = os.path.join(atuais, "indice.json")
    indice = json.load(open(caminho))
    if not any(e["id"] == ident for e in indice):
        indice.append({"id": ident, "recurso": recurso, "no": "", "superficies": []})
        json.dump(indice, open(caminho, "w"), indent=1)


def main():
    antigos, atuais, saida = sys.argv[1:4]
    so = set(sys.argv[4].split(",")) if len(sys.argv) > 4 else None
    if so == {"atlas"}:
        montar_atlas(atuais, saida)
        gerar_niveis(atuais)
        return
    if so == {"niveis"}:
        gerar_niveis(atuais)
        return
    os.makedirs(saida, exist_ok=True)
    ia = {os.path.basename(e["recurso"]): e for e in json.load(open(os.path.join(antigos, "indice.json")))}
    tot0 = tot1 = v0 = v1 = 0
    for e in json.load(open(os.path.join(atuais, "indice.json"))):
        if "/cenario/" not in e["recurso"]:
            continue
        arq = os.path.basename(e["recurso"])
        nome = arq.rsplit(".", 1)[0]
        if (so and nome not in so) or _e_nivel(nome):
            continue
        if arq not in ia:
            print("  sem original:", arq)
            continue
        antigo = sombrear_cantos(ler_msh(os.path.join(antigos, ia[arq]["id"] + ".msh"))[0])
        # A FORMA (6.4): as fontes finas (o desenho nítido) têm, onde
        # folhas e gravetos finos se encostam, arestas de 3 ou 4 triângulos
        # (a grade fina "costura" as duas folhas) — o simplificador não
        # mexe ali e a samambaia, o coral e o ninho não desciam de 1.000 a
        # 2.600 triângulos. A forma vem da mesma fonte numa grade normal
        # (<antigos>/forma, gerar.py com CENARIO_FINO=1), com bem menos
        # costuras; a cor, os olhos e o sombreado vêm da fina.
        caminho_forma = os.path.join(antigos, "forma", ia[arq]["id"] + ".msh")
        forma = ler_msh(caminho_forma)[0] if os.path.exists(caminho_forma) else None
        # (um objeto novo ainda não tem a malha do projeto: só o índice)
        caminho_atual = os.path.join(atuais, e["id"] + ".msh")
        atual = ler_msh(caminho_atual)[0] if os.path.exists(caminho_atual) else None
        tris_atual = len(atual["ind"]) // 3 if atual is not None else 0
        alvo = ALVO.get(nome, max(60, tris_atual))
        tam = 2048 if nome in TEX_2048 else (1024 if nome in TEX_1024 else
                                             (256 if nome in TEX_256 else (128 if nome in TEX_128 else 512)))
        pedaco = os.path.join(atuais, "pedacos", nome + ".png")
        local = os.path.join(atuais, e["id"] + ".local.msh")
        if nome in SO_COR:
            sup = so_cor(antigo, alvo, ERRO.get(nome), forma)
            tam = 0
            for velho in (pedaco, local):
                if os.path.exists(velho):
                    os.remove(velho)
            gravar_msh(os.path.join(atuais, e["id"] + ".leve.msh"), [sup])
        elif nome == "bau":
            # o corpo (com o tesouro dentro) e a tampa (uma peça nova)
            corpo, tampa = dividir_bau(antigo)
            f_corpo, f_tampa = dividir_bau(forma) if forma is not None else (None, None)
            sup, img = assar(nome, corpo, alvo, tam, ERRO.get(nome), f_corpo)
            sup = _juntar(sup, tesouro(sup["listas"]))
            _gravar_assado(atuais, e["id"], nome, sup, img)
            st, it = assar("bau_tampa", tampa, ALVO["bau_tampa"], tam, ERRO.get("bau_tampa"), f_tampa)
            st = tampa_por_dentro(st["listas"], st)
            _no_indice(atuais, "bau_tampa", "res://modelos/cenario/bau_tampa.res")
            _gravar_assado(atuais, "bau_tampa", "bau_tampa", st, it)
            print("  %-14s agora %5d tri %5d vert" % ("bau_tampa", len(st["ind"]) // 3, len(st["arr"][VERTEX])))
        else:
            sup, img = assar(nome, antigo, alvo, tam, ERRO.get(nome), forma)
            _gravar_assado(atuais, e["id"], nome, sup, img)
        t1 = len(sup["ind"]) // 3
        n1 = len(sup["arr"][VERTEX])
        tot0 += tris_atual
        tot1 += t1
        v0 += len(atual["arr"][VERTEX]) if atual is not None else 0
        v1 += n1
        print("  %-14s original %5d tri | antes %5d tri %5d vert | agora %5d tri %5d vert | textura %d" % (
            nome, len(antigo["ind"]) // 3, tris_atual, len(atual["arr"][VERTEX]) if atual is not None else 0, t1, n1, tam))
    print("TOTAL antes %d tri %d vert -> agora %d tri %d vert" % (tot0, v0, tot1, v1))
    # SO_ASSAR=1: só os pedaços (vários assadores em paralelo, cada um com
    # uma parte dos objetos); o atlas e os níveis depois, de uma vez: "atlas"
    if os.environ.get("SO_ASSAR"):
        return
    montar_atlas(atuais, saida)
    gerar_niveis(atuais)


if __name__ == "__main__":
    main()
