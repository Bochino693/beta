"""Ajusta a importação das imagens para a edição OpenGL ES 2.0 (TV Box com
Mali-400/450 e pouca memória): o que é 3D sem transparência vai comprimido
na placa de vídeo (ETC1 no Android), o que repete ganha repetição, as
imagens grandes de tela encolhem para o tamanho em que aparecem.

    python3 -I tools/ajustar_importacao.py <pasta do projeto>

Depois abra o projeto no editor (ou rode o editor sem janela) para ele
reimportar.
"""
import fnmatch
import os
import re
import sys

# padrão -> parâmetros (a primeira regra que casar vale)
REGRAS = [
    ("texturas/pista_pronta.png", {"compress/mode": "0", "flags/srgb": "0", "flags/repeat": "0",
                                   "flags/mipmaps": "true", "process/fix_alpha_border": "false",
                                   "detect_3d": "false", "size_limit": "0"}),
    ("texturas/estrelas_ceu.png", {"compress/mode": "0", "flags/srgb": "0", "flags/repeat": "1",
                                   "flags/mipmaps": "false", "detect_3d": "false", "size_limit": "0"}),
    ("texturas/chao_*.png", {"compress/mode": "0", "flags/srgb": "0", "flags/repeat": "1",
                             "flags/mipmaps": "true", "flags/filter": "true", "detect_3d": "false",
                             "size_limit": "0"}),
    ("texturas/madeira.png", {"compress/mode": "2", "compress/lossy_quality": "1.0", "flags/repeat": "1",
                              "flags/mipmaps": "true", "detect_3d": "false", "size_limit": "0"}),
    ("texturas/bola_*.png", {"compress/mode": "2", "flags/repeat": "1", "flags/mipmaps": "true",
                             "detect_3d": "false", "size_limit": "1024"}),
    ("texturas/rosto_pino.png", {"compress/mode": "0", "detect_3d": "false", "size_limit": "1024"}),
    ("texturas/rosto_*.png", {"compress/mode": "0", "detect_3d": "false", "size_limit": "2048"}),
    ("texturas/*.png", {"compress/mode": "0", "detect_3d": "false"}),
    ("ui/splash*.png", {"compress/mode": "0", "detect_3d": "false", "flags/mipmaps": "false", "size_limit": "0"}),
    ("ui/logo.png", {"compress/mode": "0", "detect_3d": "false", "size_limit": "2048"}),
    ("ui/*.png", {"compress/mode": "0", "detect_3d": "false", "size_limit": "1024"}),
    ("ui/*/*.png", {"compress/mode": "0", "detect_3d": "false", "size_limit": "1024"}),
]

MODELO = """[remap]

importer="texture"
type="StreamTexture"

[deps]

source_file="res://{rel}"

[params]

compress/mode=0
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


def ajustar(proj, rel, params):
    caminho = os.path.join(proj, rel + ".import")
    if os.path.exists(caminho):
        texto = open(caminho, encoding="utf-8").read()
    else:
        texto = MODELO.format(rel=rel)
    antes = texto
    for k, v in params.items():
        padrao = re.compile(r"^" + re.escape(k) + r"=.*$", re.M)
        if padrao.search(texto):
            texto = padrao.sub(k + "=" + v, texto)
        else:
            texto = texto.rstrip("\n") + "\n" + k + "=" + v + "\n"
    if texto != antes:
        open(caminho, "w", encoding="utf-8").write(texto)
        return True
    return False


def main():
    proj = sys.argv[1]
    n = 0
    for raiz, _pastas, arquivos in os.walk(proj):
        if "/." in raiz or os.path.exists(os.path.join(raiz, ".gdignore")):
            continue
        for a in arquivos:
            if not a.endswith(".png"):
                continue
            rel = os.path.relpath(os.path.join(raiz, a), proj)
            for padrao, params in REGRAS:
                if fnmatch.fnmatch(rel, padrao):
                    if ajustar(proj, rel, params):
                        n += 1
                        print("ajustado", rel)
                    break
    print(n, "arquivos de importação ajustados")


if __name__ == "__main__":
    main()
