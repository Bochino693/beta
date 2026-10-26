"""Desenha a CARINHA DA BALEIA do fundo do mar (ui/ceu/baleia.png): dois
quadros lado a lado (olhos abertos | piscando, como sol.png e lua.png), no
mesmo estilo do sol e da lua — olho grande com brilhos, sorriso e bochecha
rosada — em fundo transparente. O astro3d.shader pinta o quadro nos dois
lados da cabeça da baleia (a cabeça fica para a DIREITA da imagem).

    python3 -I tools/assar_rosto_baleia.py ui/ceu/baleia.png
"""
import sys

from PIL import Image, ImageDraw, ImageFilter

Q = 256          # lado de cada quadro
SS = 4           # superamostragem (bordas lisas)
CONTORNO = (22, 34, 74, 255)


def quadro(piscando):
    n = Q * SS
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    # bochecha rosada (borrada)
    boch = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    db = ImageDraw.Draw(boch)
    s = SS
    db.ellipse([(150 - 20) * s, (150 - 11) * s, (150 + 20) * s, (150 + 11) * s], fill=(255, 120, 150, 170))
    boch = boch.filter(ImageFilter.GaussianBlur(4 * s))
    img.alpha_composite(boch)
    d = ImageDraw.Draw(img)
    cx, cy = 118, 108
    if not piscando:
        d.ellipse([(cx - 27) * s, (cy - 31) * s, (cx + 27) * s, (cy + 31) * s], fill=(255, 255, 255, 255),
                  outline=CONTORNO, width=6 * s)
        d.ellipse([(cx - 13) * s, (cy - 15) * s, (cx + 21) * s, (cy + 25) * s], fill=(30, 52, 120, 255))
        d.ellipse([(cx - 6) * s, (cy - 7) * s, (cx + 15) * s, (cy + 17) * s], fill=(8, 14, 40, 255))
        d.ellipse([(cx + 2) * s, (cy - 12) * s, (cx + 16) * s, (cy + 2) * s], fill=(255, 255, 255, 255))
        d.ellipse([(cx - 9) * s, (cy + 10) * s, (cx - 1) * s, (cy + 18) * s], fill=(255, 255, 255, 235))
    else:
        # olho fechado feliz (um arquinho)
        d.arc([(cx - 24) * s, (cy - 6) * s, (cx + 24) * s, (cy + 30) * s], 200, 340, fill=CONTORNO, width=7 * s)
    # sorriso
    d.arc([(150) * s, (118) * s, (214) * s, (172) * s], 20, 120, fill=CONTORNO, width=6 * s)
    return img.resize((Q, Q), Image.LANCZOS)


def principal(saida):
    folha = Image.new("RGBA", (Q * 2, Q), (0, 0, 0, 0))
    folha.paste(quadro(False), (0, 0))
    folha.paste(quadro(True), (Q, 0))
    folha.save(saida, optimize=True)
    print("baleia:", saida, folha.size)


if __name__ == "__main__":
    principal(sys.argv[1] if len(sys.argv) > 1 else "ui/ceu/baleia.png")
