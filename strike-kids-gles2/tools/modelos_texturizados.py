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

# triângulos de cada objeto: os do modelo atual (o orçamento que já cabe
# na Mali-450) vezes FATOR — agora nenhum vai para as bordas de cor
FATOR = 0.6
ALVO = {
    # formas redondas grandes precisam de um pouco mais para o contorno
    "balao": 240, "lampada": 64, "nuvem": 200, "planeta": 420, "ovo_dino": 380,
    # os que aparecem às dezenas (cada corte do mapa UV conta em cada cópia)
    "cristal": 260, "palmeira": 300,
    # peças finas ou com o rosto miúdo: mais triângulos e erro menor (o olho
    # do peixe é uma bolinha por cima do rosto: com poucos triângulos ela
    # some da forma e o desenho dela se espalha)
    "roda": 640, "peixe": 400,
    # o baú em duas peças (o corpo e a tampa, que abre)
    "bau": 220, "bau_tampa": 200,
}
# erro máximo da forma de cada peça (fração do tamanho); o padrão é ERRO_FORMA
ERRO = {"roda": 0.012, "peixe": 0.011, "ovo_dino": 0.06, "cristal": 0.05, "palmeira": 0.05}
# textura de cada objeto (lado em pixels): 512 nos grandes e nos que têm
# rosto ou desenho miúdo; 256 nos outros
TEX_512 = ("vulcao", "navio", "carrossel", "roda", "torre", "planeta_anel", "arco_iris", "tenda", "cristal",
           "dino", "tartaruga", "peixe", "ptero", "ovo_dino", "donut", "foguete", "ovni",
           "estrela_mar", "cupcake", "presente", "bau", "bau_tampa", "pirulito")
TEX_128 = ()
# SEM TEXTURA: as peças de uma cor só ou quase (plantas, pedras, nuvens,
# balões, lâmpadas) espalhadas às dezenas pelo cenário — a textura não
# acrescenta desenho e os cortes do mapa UV somariam vértices em cada
# cópia. Nelas: a forma limpa do original e a cor dele nos vértices.
# (pedras, pedra da lua, palmeira e planeta têm desenho — musgo, crateras,
# anéis do tronco — e vão com textura)
SO_COR = ("arvore_escura", "arvore_laranja", "arvore_verde", "balao", "lampada", "nuvem",
          "samambaia", "alga", "coral", "coral_roxo", "estrela_3d", "agua_viva", "cabine", "roda_base")
ANGULO_QUINA = 75.0
PADDING = 4
# o atlas: largura fixa; a altura é a potência de 2 que couber (a Mali-450
# só faz mipmap em textura de lado potência de 2)
ATLAS_LARGURA = 2048
ATLAS = "atlas.png"


# ------------------------------------------------------------ cor na tela
def s2l(c):
    return c * (c * (c * 0.305306011 + 0.682171111) + 0.012522878)


def viva(c):
    lum = c @ np.array([0.299, 0.587, 0.114])
    sat = c.max(axis=1) - c.min(axis=1)
    k = 1.08 + 0.32 * (1.0 - sat)
    c = lum[:, None] + (c - lum[:, None]) * k[:, None]
    return np.clip(c * 1.07 - 0.035, 0.0, 1.0)


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


def simplificar_forma(v, f, alvo_tris, erro=None):
    ind = np.ascontiguousarray(f.reshape(-1).astype(np.uint32))
    pos = np.ascontiguousarray(v.astype(np.float32))
    if len(f) <= alvo_tris:
        return f
    destino = np.zeros_like(ind)
    qtd = mo.simplify(destino, ind, pos, target_index_count=alvo_tris * 3,
                      target_error=ERRO_FORMA if erro is None else erro)
    return destino[:qtd].reshape(-1, 3)


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


# ------------------------------------------------------------ amostras do original
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


def so_cor(antigo, alvo_tris, erro=None):
    """Forma limpa do original, normais do original e a cor dele nos
    vértices (sem textura e sem cortes: o mínimo de vértices)."""
    v = antigo["arr"][VERTEX].astype(np.float64)
    cor = antigo["arr"][COLOR].astype(np.float64) if COLOR in antigo["arr"] else np.ones((len(v), 4))
    f = antigo["ind"].reshape(-1, 3).astype(np.int64)
    vw, fw, inv = soldar(v, f)
    fl = simplificar_forma(vw, fw, alvo_tris, erro)
    usados = np.unique(fl)
    remap = np.full(len(vw), -1)
    remap[usados] = np.arange(len(usados))
    vl = vw[usados]
    fl = remap[fl]
    media, quina = normais_do_original(antigo["arr"][NORMAL].astype(np.float64), inv, len(vw))
    pos, nor, fn = normais_suaves(vl, fl, media[usados], quina[usados])
    # a cor de cada ponto: a do próprio vértice do original naquele lugar
    # (a média, se o original tinha mais de uma cor ali)
    soma = np.zeros((len(vw), 4))
    np.add.at(soma, inv, cor)
    cont = np.bincount(inv, minlength=len(vw))[:, None]
    cor_soldada = (soma / np.maximum(cont, 1))[usados]
    # (normais_suaves duplicou os pontos das quinas: a cor vai junto)
    chave_pos = {tuple(np.round(p, 6)): i for i, p in enumerate(vl)}
    cores = np.array([cor_soldada[chave_pos[tuple(np.round(p, 6))]] for p in pos])
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


def assar(nome, antigo, alvo_tris, tam, erro=None):
    v = antigo["arr"][VERTEX].astype(np.float64)
    cor = antigo["arr"][COLOR].astype(np.float64) if COLOR in antigo["arr"] else np.ones((len(v), 4))
    f = antigo["ind"].reshape(-1, 3).astype(np.int64)
    # 1. forma
    vw, fw, inv = soldar(v, f)
    fl = simplificar_forma(vw, fw, alvo_tris, erro)
    usados = np.unique(fl)
    remap = np.full(len(vw), -1)
    remap[usados] = np.arange(len(usados))
    vl = vw[usados]
    fl = remap[fl]
    # 2. normais (as do original)
    n_orig = antigo["arr"][NORMAL].astype(np.float64)
    media, quina = normais_do_original(n_orig, inv, len(vw))
    pos, nor, fn = normais_suaves(vl, fl, media[usados], quina[usados])
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
        # 5. cor do original na textura
        uv_px = uv * tam
        lin, col, tri, w = rasterizar(uv_px, fx, tam)
        p3 = np.einsum("pc,pcd->pd", w, pd[fx[tri]])
        n3 = np.einsum("pc,pcd->pd", w, nd[fx[tri]])
        n3 /= np.maximum(np.linalg.norm(n3, axis=1, keepdims=True), 1e-12)
        achou = procurar(arvore, a_nor, p3, n3)
        rgb = tela_g4(s2l(np.clip(a_cor[achou, :3], 0, 1)))
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
compress/lossy_quality=0.7
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
        self.pos, self.nor, self.cor, self.ind = [], [], [], []
        self._vistos = {}

    def tri(self, pts, nors, cores):
        # o mesmo ponto (lugar, normal e cor) é um vértice só. No Godot a
        # frente do triângulo é a do sentido HORÁRIO (a normal da regra da
        # mão direita aponta para trás): grava na ordem inversa
        for q, n, c in zip(pts[::-1], nors[::-1], cores[::-1]):
            chave = tuple(np.round(np.concatenate([q, n, c]), 5))
            if chave not in self._vistos:
                self._vistos[chave] = len(self.pos)
                self.pos.append(q)
                self.nor.append(n)
                self.cor.append(c)
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
               COLOR: np.array(self.cor, np.float32), TEX_UV: np.full((nv, 2), UV_BRANCO, np.float32)}
        arr = {k: a for k, a in arr.items() if listas & (1 << k)}
        return {"prim": TRIANGULOS, "listas": listas, "arr": arr, "ind": np.array(self.ind, np.uint32)}


def _cor(hexa, alfa=0.0):
    h = hexa.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)] + [alfa])


def tesouro(listas):
    """O tesouro na boca do corpo: monte de ouro, moedas, joias e a parede
    de dentro (uma faixa escura logo abaixo da borda)."""
    rnd = np.random.RandomState(7)
    mx, mz, topo = BAU_BOCA
    p = _Pecas()
    # o monte de ouro: uma grade com uma corcova no meio, a borda logo
    # abaixo da boca; cada ponto um ouro um pouco diferente (parece moeda
    # sobre moeda) e alguns brilham
    nx, nz = 9, 7
    xs = np.linspace(-mx, mx, nx)
    zs = np.linspace(-mz, mz, nz)
    h = np.zeros((nz, nx))
    for i, z in enumerate(zs):
        for j, x in enumerate(xs):
            u, w = x / mx, z / mz
            h[i, j] = topo - 0.015 + 0.10 * (1 - u * u) * (1 - w * w)
            if 0 < i < nz - 1 and 0 < j < nx - 1:
                h[i, j] += rnd.uniform(-0.012, 0.012)
    gz, gx = np.gradient(h, zs, xs)
    ouros = [_cor("#FFC93C"), _cor("#F2A91E"), _cor("#FFE07A"), _cor("#E8961A")]
    grade_cor = {}
    for i in range(nz):
        for j in range(nx):
            c = ouros[rnd.randint(len(ouros))].copy()
            if rnd.uniform() < 0.12:
                c[3] = 0.62
            grade_cor[i, j] = c

    def ponto(i, j):
        n = np.array([-gx[i, j], 1.0, -gz[i, j]])
        return np.array([xs[j], h[i, j], zs[i]]), n / np.linalg.norm(n), grade_cor[i, j]
    for i in range(nz - 1):
        for j in range(nx - 1):
            a, b, c, d = ponto(i, j), ponto(i, j + 1), ponto(i + 1, j + 1), ponto(i + 1, j)
            for t in ((a, d, c), (a, c, b)):
                p.tri([q[0] for q in t], [q[1] for q in t], [q[2] for q in t])

    def altura(x, z):
        j = np.clip(np.searchsorted(xs, x) - 1, 0, nx - 2)
        i = np.clip(np.searchsorted(zs, z) - 1, 0, nz - 2)
        return h[i:i + 2, j:j + 2].mean()
    # moedas por cima (discos de 6 lados, inclinados)
    for k in range(7):
        x, z = rnd.uniform(-mx * 0.7, mx * 0.7), rnd.uniform(-mz * 0.6, mz * 0.75)
        centro = np.array([x, altura(x, z) + 0.012, z])
        inc = rnd.uniform(-0.6, 0.6, 2)
        n = np.array([inc[0], 1.0, inc[1]])
        n /= np.linalg.norm(n)
        e1 = np.cross(n, [0.0, 0.0, 1.0])
        e1 /= np.linalg.norm(e1)
        e2 = np.cross(n, e1)
        borda = [centro + 0.045 * (np.cos(a) * e1 + np.sin(a) * e2) for a in np.linspace(0, 2 * np.pi, 7)[:-1]]
        claro, ouro = _cor("#FFF0A0", 0.62 if k % 2 == 0 else 0.0), _cor("#FFC93C")
        for a in range(6):
            p.tri([centro, borda[a], borda[(a + 1) % 6]], [n] * 3, [claro, ouro, ouro])
    # joias (octaedros de quinas vivas) que brilham
    for k, (cor, x, z) in enumerate((("#FF2D55", -0.20, 0.10), ("#2E7BFF", 0.17, -0.06),
                                     ("#2ED47A", 0.02, 0.17), ("#B25BFF", 0.27, 0.15))):
        c = _cor(cor, 0.6)
        r = 0.05 if k == 0 else 0.042
        centro = np.array([x, altura(x, z) + r * 0.55, z])
        giro = rnd.uniform(0, np.pi)
        e = [np.array([np.cos(giro + a), 0.0, np.sin(giro + a)]) for a in (0, np.pi / 2, np.pi, 3 * np.pi / 2)]
        cima, baixo = centro + [0, r * 1.25, 0], centro - [0, r * 1.25, 0]
        for a in range(4):
            q0, q1 = centro + r * e[a], centro + r * e[(a + 1) % 4]
            p.chato([cima, q1, q0], c, centro)
            p.chato([baixo, q0, q1], c, centro)
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
    """Junta os pedaços de todos os objetos com textura num atlas e grava a
    malha de cada um (<id>.leve.msh) com o UV levado para o pedaço dele."""
    from scipy import ndimage
    pecas = []
    for e in json.load(open(os.path.join(atuais, "indice.json"))):
        if "/cenario/" not in e["recurso"]:
            continue
        nome = os.path.basename(e["recurso"]).rsplit(".", 1)[0]
        pedaco = os.path.join(atuais, "pedacos", nome + ".png")
        local = os.path.join(atuais, e["id"] + ".local.msh")
        if os.path.exists(pedaco) and os.path.exists(local):
            pecas.append((nome, e["id"], np.asarray(Image.open(pedaco).convert("RGB")), ler_msh(local)[0]))
    if not pecas:
        return
    # os maiores primeiro, cada um no primeiro lugar livre de cima para baixo
    pecas.sort(key=lambda p: (-p[2].shape[0], p[0]))
    livres = [(x, y, 512) for y in range(0, 8192, 512) for x in range(0, ATLAS_LARGURA, 512)]
    lugares = [_alocar(livres, p[2].shape[0]) for p in pecas]
    bx, by = _alocar(livres, 16)
    altura = 512
    while altura < max([y + p[2].shape[0] for (x, y), p in zip(lugares, pecas)] + [by + 16]):
        altura *= 2
    uv_branco = np.array([(bx + 8) / ATLAS_LARGURA, (by + 8) / altura], np.float32)
    img = np.zeros((altura, ATLAS_LARGURA, 3), np.uint8)
    cheio = np.zeros((altura, ATLAS_LARGURA), bool)
    for (x, y), (nome, ident, px, sup) in zip(lugares, pecas):
        t = px.shape[0]
        img[y:y + t, x:x + t] = px
        cheio[y:y + t, x:x + t] = True
        uv = sup["arr"][TEX_UV].astype(np.float64)
        novo = np.empty_like(uv)
        novo[:, 0] = (x + uv[:, 0] * t) / ATLAS_LARGURA
        novo[:, 1] = (y + uv[:, 1] * t) / altura
        # as partes com a cor no vértice (o tesouro do baú): no branco
        novo[uv[:, 0] <= UV_BRANCO] = uv_branco
        sup = dict(sup)
        sup["arr"] = dict(sup["arr"])
        sup["arr"][TEX_UV] = novo.astype(np.float32)
        gravar_msh(os.path.join(atuais, ident + ".leve.msh"), [sup])
        print("  atlas: %-14s %4d px em (%4d, %4d)" % (nome, t, x, y))
    # o quadradinho BRANCO (o branco como sai na tela com luz 1, como os
    # pedaços): as peças de uma cor só apontam o UV para o meio dele e a cor
    # delas vem do vértice — o mesmo material das de textura
    img[by:by + 16, bx:bx + 16] = (np.clip(tela_g4(s2l(np.ones((1, 3))))[0], 0, 1) * 255 + 0.5).astype(np.uint8)
    cheio[by:by + 16, bx:bx + 16] = True
    n_cor = 0
    com_desenho = set(p[0] for p in pecas)
    for e in json.load(open(os.path.join(atuais, "indice.json"))):
        nome = os.path.basename(e["recurso"]).rsplit(".", 1)[0]
        leve = os.path.join(atuais, e["id"] + ".leve.msh")
        if "/cenario/" in e["recurso"] and nome not in com_desenho and os.path.exists(leve):
            sup = ler_msh(leve)[0]
            sup["arr"][TEX_UV] = np.tile(uv_branco, (len(sup["arr"][VERTEX]), 1))
            sup["listas"] |= 1 << TEX_UV
            gravar_msh(leve, [sup])
            n_cor += 1
    # o que sobrou do atlas pega a cor do pedaço mais perto (os mipmaps de
    # longe não misturam preto nas bordas dos pedaços)
    if not cheio.all():
        _, (iy, ix) = ndimage.distance_transform_edt(~cheio, return_indices=True)
        img = img[iy, ix]
    caminho = os.path.join(saida, ATLAS)
    Image.fromarray(img, "RGB").save(caminho, optimize=True)
    if not os.path.exists(caminho + ".import"):
        with open(caminho + ".import", "w", encoding="utf-8") as fi:
            fi.write(IMPORT)
    # as texturas de um objeto só (as da primeira versão) saem
    for nome, _, _, _ in pecas:
        for velho in (os.path.join(saida, nome + ".png"), os.path.join(saida, nome + ".png.import")):
            if os.path.exists(velho):
                os.remove(velho)
    print("ATLAS %dx%d com %d objetos com desenho e %d de uma cor só" % (ATLAS_LARGURA, altura, len(pecas), n_cor))


def _gravar_assado(atuais, ident, nome, sup, img):
    """O pedaço da textura e a malha com o UV do pedaço (montar_atlas leva
    para o atlas); sem nenhuma peça com desenho, só a malha (o UV no branco)."""
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
        return
    os.makedirs(saida, exist_ok=True)
    ia = {os.path.basename(e["recurso"]): e for e in json.load(open(os.path.join(antigos, "indice.json")))}
    tot0 = tot1 = v0 = v1 = 0
    for e in json.load(open(os.path.join(atuais, "indice.json"))):
        if "/cenario/" not in e["recurso"]:
            continue
        arq = os.path.basename(e["recurso"])
        nome = arq.rsplit(".", 1)[0]
        if so and nome not in so:
            continue
        if arq not in ia:
            print("  sem original:", arq)
            continue
        antigo = ler_msh(os.path.join(antigos, ia[arq]["id"] + ".msh"))[0]
        atual = ler_msh(os.path.join(atuais, e["id"] + ".msh"))[0]
        tris_atual = len(atual["ind"]) // 3
        alvo = ALVO.get(nome, max(60, int(round(tris_atual * FATOR))))
        tam = 512 if nome in TEX_512 else (128 if nome in TEX_128 else 256)
        pedaco = os.path.join(atuais, "pedacos", nome + ".png")
        local = os.path.join(atuais, e["id"] + ".local.msh")
        if nome in SO_COR:
            sup = so_cor(antigo, alvo, ERRO.get(nome))
            tam = 0
            for velho in (pedaco, local):
                if os.path.exists(velho):
                    os.remove(velho)
            gravar_msh(os.path.join(atuais, e["id"] + ".leve.msh"), [sup])
        elif nome == "bau":
            # o corpo (com o tesouro dentro) e a tampa (uma peça nova)
            corpo, tampa = dividir_bau(antigo)
            sup, img = assar(nome, corpo, alvo, tam, ERRO.get(nome))
            sup = _juntar(sup, tesouro(sup["listas"]))
            _gravar_assado(atuais, e["id"], nome, sup, img)
            st, it = assar("bau_tampa", tampa, ALVO["bau_tampa"], tam, ERRO.get("bau_tampa"))
            st = tampa_por_dentro(st["listas"], st)
            _no_indice(atuais, "bau_tampa", "res://modelos/cenario/bau_tampa.res")
            _gravar_assado(atuais, "bau_tampa", "bau_tampa", st, it)
            print("  %-14s agora %5d tri %5d vert" % ("bau_tampa", len(st["ind"]) // 3, len(st["arr"][VERTEX])))
        else:
            sup, img = assar(nome, antigo, alvo, tam, ERRO.get(nome))
            _gravar_assado(atuais, e["id"], nome, sup, img)
        t1 = len(sup["ind"]) // 3
        n1 = len(sup["arr"][VERTEX])
        tot0 += tris_atual
        tot1 += t1
        v0 += len(atual["arr"][VERTEX])
        v1 += n1
        print("  %-14s original %5d tri | antes %5d tri %5d vert | agora %5d tri %5d vert | textura %d" % (
            nome, len(antigo["ind"]) // 3, tris_atual, len(atual["arr"][VERTEX]), t1, n1, tam))
    print("TOTAL antes %d tri %d vert -> agora %d tri %d vert" % (tot0, v0, tot1, v1))
    montar_atlas(atuais, saida)


if __name__ == "__main__":
    main()
