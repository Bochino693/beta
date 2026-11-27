"""Desenha a folha do SENSOR DA CANCELA (firmware 20): o HW-201 (sensor
infravermelho) no Arduino, a cancela fechada e aberta na frente dele e a
regra que o Arduino segue (credito x onde a cancela esta).

    python3 -I tools/desenhar_sensor_cancela.py [destino.svg]

Sem destino: arduino/1_RELE_principal/ligacao_sensor_cancela.svg. O PNG e o
PDF saem do SVG por qualquer navegador (Chrome: abrir o SVG e imprimir em
PDF).
"""
import os
import sys

W, H = 2400, 2230
SANS = "DejaVu Sans, Verdana, Arial, sans-serif"
TXT = "#1b2a41"
CINZA = "#5d6d7e"
AZUL_PLACA = "#1d5fa8"
AZUL_SENSOR = "#1f3f8f"
VERM = "#c62828"
PRETO = "#212121"
MARROM = "#8d6e63"
VERDE = "#2e7d32"
OURO = "#d4a017"

_s = []


def add(x):
    _s.append(x)


def esc(t):
    return t.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def rect(x, y, w, h, fill, stroke="none", sw=0, rx=0, op=None, extra=""):
    o = ' opacity="%s"' % op if op is not None else ""
    add('<rect x="%g" y="%g" width="%g" height="%g" rx="%g" fill="%s" stroke="%s" stroke-width="%g"%s %s/>'
        % (x, y, w, h, rx, fill, stroke, sw, o, extra))


def circ(x, y, r, fill, stroke="none", sw=0, op=None, extra=""):
    o = ' opacity="%s"' % op if op is not None else ""
    add('<circle cx="%g" cy="%g" r="%g" fill="%s" stroke="%s" stroke-width="%g"%s %s/>' % (x, y, r, fill, stroke, sw, o, extra))


def linha(x1, y1, x2, y2, cor, sw=4, dash=None, op=None):
    d = ' stroke-dasharray="%s"' % dash if dash else ""
    o = ' opacity="%s"' % op if op is not None else ""
    add('<line x1="%g" y1="%g" x2="%g" y2="%g" stroke="%s" stroke-width="%g" stroke-linecap="round"%s%s/>'
        % (x1, y1, x2, y2, cor, sw, d, o))


def fio(pts, cor, sw=10):
    d = "M %g %g " % pts[0] + " ".join("L %g %g" % p for p in pts[1:])
    add('<path d="%s" fill="none" stroke="#000" stroke-opacity="0.18" stroke-width="%g" stroke-linejoin="round" '
        'stroke-linecap="round" transform="translate(2,3)"/>' % (d, sw + 2))
    add('<path d="%s" fill="none" stroke="%s" stroke-width="%g" stroke-linejoin="round" stroke-linecap="round"/>'
        % (d, cor, sw))
    add('<path d="%s" fill="none" stroke="white" stroke-opacity="0.35" stroke-width="%g" stroke-linejoin="round" '
        'stroke-linecap="round" transform="translate(-1,-2)"/>' % (d, max(2, sw / 4)))


def texto(x, y, t, tam=26, cor=TXT, peso="normal", ancora="start"):
    partes = t.split("**")
    spans = "".join('<tspan font-weight="%s">%s</tspan>' % ("bold" if i % 2 else peso, esc(p))
                    for i, p in enumerate(partes) if p)
    add('<text x="%g" y="%g" font-family="%s" font-size="%g" fill="%s" text-anchor="%s">%s</text>'
        % (x, y, SANS, tam, cor, ancora, spans))


def bloco(x, y, linhas, tam=26, entre=1.45, cor=TXT):
    for i, l in enumerate(linhas):
        texto(x, y + i * tam * entre, l, tam, cor)


def caixa(x, y, w, h, titulo, cor):
    rect(x + 4, y + 6, w, h, "#000", rx=18, op=0.08)
    rect(x, y, w, h, "white", cor, 4, 18)
    add('<path d="M %g %g h %g v 58 h %g z" fill="%s"/>' % (x + 18, y, w - 36, -(w - 36), cor))
    rect(x, y, w, 58, cor, rx=18)
    rect(x, y + 30, w, 28, cor)
    texto(x + 26, y + 40, titulo, 27, "white", "bold")


def pino(x, y, cor=None):
    circ(x, y, 15, "url(#ouro)", "#7a5c00", 2)
    circ(x, y, 7, "#2b2b2b")
    if cor:
        circ(x, y, 19, "none", cor, 5)


def etiqueta(x, y, t, fundo, cor="white", tam=24):
    w = len(t) * tam * 0.62 + 26
    rect(x - w / 2, y - tam - 6, w, tam + 18, fundo, rx=9)
    texto(x, y + 1, t, tam, cor, "bold", "middle")


# ================================================================== partes
def cabecalho():
    rect(0, 0, W, 8, "#1d5fa8")
    texto(50, 78, "STRIKE KIDS · SENSOR DA CANCELA (HW-201)", 52, TXT, "bold")
    texto(50, 122, "firmware **20** · o **CRÉDITO MANDA** · o feixe só vale depois de **provar** que vê a cancela "
                   "andar · UM pulso por pedido, nunca dois", 28, CINZA)
    rect(50, 146, W - 100, 4, "#e3e8ee")


NX, NY, NW, NH = 70, 230, 1000, 300
PINOS_BAIXO = ["VIN", "GND", "RST", "5V", "A7", "A6", "A5", "A4", "A3", "A2", "A1", "A0"]


def px(nome):
    return NX + 70 + PINOS_BAIXO.index(nome) * 78


def nano():
    texto(NX, NY - 22, "ARDUINO (a mesma placa da máquina) — fileira de baixo", 26, TXT, "bold")
    rect(NX + 6, NY + 8, NW, NH, "#000", rx=24, op=0.12)
    rect(NX, NY, NW, NH, AZUL_PLACA, "#0f3d70", 3, 24)
    for k in range(9):
        linha(NX + 120 + k * 90, NY + 40, NX + 160 + k * 90, NY + 160, "#3f7cc4", 3, op=0.45)
    rect(NX + 380, NY + 70, 130, 130, "#1b1f23", "#0b0e10", 3, 6)
    texto(NX + 445, NY + 130, "ATMEGA", 18, "#aab4bd", "bold", "middle")
    texto(NX + 445, NY + 156, "328P", 18, "#aab4bd", "bold", "middle")
    texto(NX + 760, NY + 120, "ARDUINO NANO", 38, "white", "bold", "middle")
    texto(NX + 760, NY + 158, "firmware strike_kids_rele.ino · 20", 21, "#cfe3f7", "normal", "middle")
    yb = NY + NH - 50
    usados = {"5V": VERM, "GND": PRETO, "A4": MARROM}
    for nome in PINOS_BAIXO:
        x = px(nome)
        pino(x, yb, usados.get(nome))
        texto(x, yb - 34, nome, 22, "white" if nome in usados else "#aed6f1", "bold" if nome in usados else "normal", "middle")
    texto(NX, NY + NH + 150, "Os outros fios não mudam: **D8** → relé · **A2** moedeiro · **A1** START · **A0** configuração ·"
          , 22, CINZA)
    texto(NX, NY + NH + 182, "**D2 D3 D4 D5 D7** sensores da pista · **D6** fita de LED (opcional)", 22, CINZA)


SX, SY, SW, SH = 1250, 260, 520, 230   # a placa do sensor (deitada, LEDs IR para a direita)


def sensor_hw201(x=SX, y=SY, aceso=True, mini=False):
    k = 0.55 if mini else 1.0
    w, h = SW * k, SH * k
    rect(x + 5, y + 7, w, h, "#000", rx=16 * k, op=0.12)
    rect(x, y, w, h, AZUL_SENSOR, "#0e2457", 3, 16 * k)
    # trilhas
    for i in range(5):
        linha(x + (60 + i * 70) * k, y + 30 * k, x + (90 + i * 70) * k, y + 110 * k, "#3753a8", 3 * k, op=0.6)
    # potenciometro azul (parafusinho)
    rect(x + 150 * k, y + 40 * k, 92 * k, 92 * k, "#2e6fd1", "#123f8c", 2, 8 * k)
    circ(x + 196 * k, y + 86 * k, 30 * k, "#e8eef7", "#9aa9bd", 2)
    linha(x + 178 * k, y + 86 * k, x + 214 * k, y + 86 * k, "#55657a", 5 * k)
    linha(x + 196 * k, y + 68 * k, x + 196 * k, y + 104 * k, "#55657a", 5 * k)
    if not mini:
        texto(x + 196 * k, y + 160 * k, "ajuste da", 17, "#d6e1f5", "normal", "middle")
        texto(x + 196 * k, y + 180 * k, "distância", 17, "#d6e1f5", "normal", "middle")
    # chip LM393
    rect(x + 270 * k, y + 120 * k, 80 * k, 50 * k, "#1b1f23", "#0b0e10", 2, 4 * k)
    # LEDs da placa: energia (sempre) e "obstaculo" (a cancela na frente)
    circ(x + 300 * k, y + 52 * k, 9 * k, "#ff5252")
    if not mini:
        texto(x + 300 * k, y + 88 * k, "energia", 15, "#d6e1f5", "normal", "middle")
    cor_led = "#7CFC00" if aceso else "#304030"
    if aceso:
        circ(x + 390 * k, y + 52 * k, 24 * k, "#7CFC00", op=0.35)
    circ(x + 390 * k, y + 52 * k, 10 * k, cor_led, "#1b3b1b", 1.5)
    if not mini:
        texto(x + 390 * k, y + 88 * k, "sinal", 15, "#d6e1f5", "bold", "middle")
    # emissor (transparente) e receptor (preto) apontando para a direita
    ex = x + w
    rect(ex - 4, y + 30 * k, 58 * k, 52 * k, "#e8f4ff", "#9fb7cc", 2, 24 * k)
    rect(ex - 4, y + 120 * k, 58 * k, 52 * k, "#1a1a1a", "#000", 2, 24 * k)
    if not mini:
        texto(ex + 70 * k, y + 64 * k, "emissor IR", 17, CINZA)
        texto(ex + 70 * k, y + 154 * k, "receptor", 17, CINZA)
    # os 3 pinos (esquerda): VCC, GND, OUT
    nomes = [("VCC", VERM), ("GND", PRETO), ("OUT", MARROM)]
    pinos = {}
    for i, (nome, cor) in enumerate(nomes):
        py = y + (50 + i * 62) * k
        rect(x - 46 * k, py - 7 * k, 50 * k, 14 * k, "url(#ouro)", "#7a5c00", 1.5, 3)
        if not mini:
            texto(x + 14, py + 8, nome, 20, "white", "bold")
        pinos[nome] = (x - 46 * k, py)
    if not mini:
        texto(x + w / 2, y + h + 36, "HW-201 · sensor infravermelho (3 pinos)", 22, TXT, "bold", "middle")
    return pinos


def ligacao():
    pinos = sensor_hw201()
    yb = NY + NH - 50
    xs = {"VCC": px("5V"), "GND": px("GND"), "OUT": px("A4")}
    cores = {"VCC": VERM, "GND": PRETO, "OUT": MARROM}
    desce = {"VCC": 610, "GND": 640, "OUT": 580}
    vx = {"VCC": 1150, "GND": 1180, "OUT": 1120}
    for nome in ("OUT", "VCC", "GND"):
        x0 = xs[nome]
        xp, yp = pinos[nome]
        fio([(x0, yb), (x0, desce[nome]), (vx[nome], desce[nome]), (vx[nome], yp), (xp, yp)], cores[nome])
    etiqueta(px("A4"), 566, "A4 → OUT", MARROM, tam=22)
    etiqueta(px("5V"), 566, "5V → VCC", VERM, tam=22)
    etiqueta(px("GND"), 566, "GND → GND", PRETO, tam=22)


def cancela(x, y, fechada):
    titulo = "CANCELA FECHADA (sem crédito)" if fechada else "CANCELA ABERTA (com crédito / livre)"
    cor = VERM if fechada else VERDE
    caixa(x, y, 640, 520, titulo, cor)
    sx, sy = x + 40, y + 340
    sensor_hw201(sx, sy, aceso=fechada, mini=True)
    ex = sx + SW * 0.55 + 32           # ponta dos LEDs IR
    bx = x + 470                       # a cancela
    feixe = (sy + 31, sy + 85)         # emissor e receptor
    if fechada:
        rect(bx, y + 250, 44, 230, "url(#metal)", "#6c7a86", 3, 8)
        texto(bx + 22, y + 236, "cancela", 20, CINZA, "bold", "middle")
        linha(ex + 4, feixe[0], bx - 6, feixe[0] + 22, "#ff7043", 4, "9 6")
        linha(bx - 6, feixe[0] + 22, ex + 4, feixe[1], "#ff7043", 4, "9 6")
        texto(bx + 58, feixe[0] + 30, "reflete", 19, "#e64a19", "bold")
        texto(bx + 58, feixe[0] + 54, "e volta", 19, "#e64a19", "bold")
    else:
        rect(bx, y + 250, 44, 230, "none", "#b0bec5", 3, 8, extra='stroke-dasharray="10 8"')
        rect(bx, y + 70, 44, 150, "url(#metal)", "#6c7a86", 3, 8)
        linha(bx + 22, y + 290, bx + 22, y + 232, VERDE, 5)
        add('<path d="M %g %g l -14 22 h 28 z" fill="%s"/>' % (bx + 22, y + 226, VERDE))
        texto(bx + 58, y + 120, "cancela", 20, CINZA, "bold")
        texto(bx + 58, y + 144, "saiu da", 19, CINZA)
        texto(bx + 58, y + 166, "frente", 19, CINZA)
        linha(ex + 4, feixe[0], x + 625, feixe[0], "#ff7043", 4, "9 6", op=0.55)
        texto(bx + 58, feixe[0] + 36, "o feixe", 19, "#e64a19", "bold")
        texto(bx + 58, feixe[0] + 60, "se perde", 19, "#e64a19", "bold")
    bloco(x + 30, y + 112, [
        "LED \"sinal\" do sensor **ACESO**" if fechada else "LED \"sinal\" do sensor **APAGADO**",
        "OUT = **0** (LOW) no A4" if fechada else "OUT = **1** (HIGH) no A4",
        "o Arduino lê: **FECHADA**" if fechada else "o Arduino lê: **ABERTA**",
    ], 24, 1.5)


def porque():
    x, y, w, h = 1390, 760, 960, 520
    caixa(x, y, w, h, "AS DUAS PEÇAS: O RELÉ EMPURRA, O SENSOR CONFERE", "#37474f")
    bloco(x + 30, y + 112, [
        "**Antes (sem sensor):** o relé só dá um toque e a trava",
        "inverte. O Arduino **lembrava** de cabeça se tinha aberto ou",
        "fechado. Faltou luz, cabo puxado, relé que estalou sozinho",
        "→ a lembrança ficava errada e a cancela invertia tudo.",
        "",
        "**Agora (firmware 20): o CRÉDITO MANDA.** O feixe só vale",
        "depois de **provar** (mudar junto com um toque); feixe e",
        "memória discordam → **toque de teste** e o feixe responde.",
        "ao contrário → **1 toque**, **nunca 2**. Desligou aberta →",
        "ao ligar, sem crédito, **fecha antes do jogo abrir**.",
        "**REGULE:** LED aceso **só** com a cancela fechada.",
    ], 22, 1.42)


def regra():
    x, y, w, h = 50, 1310, 1320, 890
    caixa(x, y, w, h, "COMO O ARDUINO DECIDE: crédito = como DEVE estar · sensor = onde ESTÁ", "#1d5fa8")
    cols = [x + 30, x + 470, x + 830]
    yy = y + 110
    rect(x + 20, yy - 34, w - 40, 50, "#eef3f9", rx=8)
    for cx, t in zip(cols, ["MOMENTO", "O JOGO PEDE", "O ARDUINO FAZ"]):
        texto(cx, yy, t, 22, CINZA, "bold")
    linhas = [
        ("Liga a máquina", "(nada ainda)", "lê o sensor: já sabe onde ela está"),
        ("Tela inicial, 0 crédito", "FECHADA", "aberta? **1 pulso** · fechada? nada"),
        ("Entrou ficha", "ABERTA", "fechada? **1 pulso** · aberta? nada"),
        ("Bola rolada (com crédito)", "ABERTA (partida)", "nada: ela já está aberta"),
        ("Fim da partida, 0 crédito", "FECHADA", "**1 pulso** fecha"),
        ("Fim, sobrou crédito", "ABERTA", "nada"),
        ("Desligaram jogando", "ao ligar: FECHADA", "sensor diz aberta → **1 pulso**"),
        ("Modo livre", "ABERTA sempre", "**1 pulso** se fechada; depois nada"),
        ("Liga, jogo ainda carregando", "(o Arduino sozinho)", "em 10 s: sem ficha → **fecha**"),
        ("Última bola da partida", "FECHADA (no resultado)", "**1 pulso** fecha; sobrou crédito: nada"),
        ("Mão / bola no feixe", "(nada mudou)", "**nada** — o feixe não manda"),
        ("Pulsou e o feixe não mudou", "—", "**nunca 2º pulso**; memória + aviso"),
    ]
    for i, (m, p, f) in enumerate(linhas):
        ly = yy + 60 + i * 60
        if i % 2 == 0:
            rect(x + 20, ly - 36, w - 40, 56, "#f7f9fc", rx=6)
        texto(cols[0], ly, m, 24, TXT, "bold")
        texto(cols[1], ly, p, 24, TXT)
        texto(cols[2], ly, f, 24, TXT)


def ajustes():
    x, y, w, h = 1420, 1310, 930, 890
    caixa(x, y, w, h, "MONTAGEM E AJUSTE (uma vez)", "#6d4c41")
    bloco(x + 30, y + 110, [
        "**1.** Prenda o sensor onde a cancela **FECHADA**",
        "   passa bem na frente dos dois LEDs IR",
        "   (2 a 10 cm; aberta, ela sai da frente).",
        "**2.** Fios: **VCC → 5V**, **GND → GND**, **OUT → A4**.",
        "**3.** Gire o parafusinho azul até o LED \"sinal\"",
        "   **ACENDER** com a cancela fechada e **APAGAR**",
        "   com ela aberta.",
        "**4.** Grave o **strike_kids_rele.ino** (firmware 20)",
        "   com a cancela FECHADA. Serial: **OLA:STRIKE_KIDS:20**;",
        "   mande **INFO?**: ...**SENSOR_TRAVA=FECHADA**.",
        "**5.** Menu > **TESTE DA PORTA**: C abre / fecha;",
        "   **Z ou B** = conferir agora com o sensor.",
        "**6.** O TESTE DA PORTA mostra o feixe ao vivo:",
        "   \"LED ACESO → FECHADA\" tem que bater com a cancela.",
        "",
        "**No .ino (começo):**",
        "**USAR_SENSOR_TRAVA 1** — com o sensor (padrão)",
        "**SENSOR_TRAVA_FECHADA_LOW 1** — LED aceso =",
        "   fechada (o seu); ao contrário: **0**",
        "**PORTA_TEMPO_MOVER_MS 4000** — o tempo para o",
        "   feixe ver a cancela mudar",
        "**USAR_SENSOR_TRAVA 0** — sem sensor (EEPROM)",
    ], 23, 1.48)


DEFS = """<defs>
<linearGradient id="ouro" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffe28a"/><stop offset="0.5" stop-color="#d4a017"/><stop offset="1" stop-color="#8a6a00"/></linearGradient>
<linearGradient id="metal" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#9aa7b1"/><stop offset="0.45" stop-color="#eef2f5"/><stop offset="1" stop-color="#7d8a94"/></linearGradient>
</defs>"""


def desenhar(destino):
    del _s[:]
    rect(0, 0, W, H, "white")
    cabecalho()
    nano()
    ligacao()
    cancela(50, 760, True)
    cancela(720, 760, False)
    porque()
    regra()
    ajustes()
    corpo = _s[:]
    del _s[:]
    add('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">' % (W, H, W, H))
    add(DEFS)
    _s.extend(corpo)
    add("</svg>")
    with open(destino, "w", encoding="utf-8") as f:
        f.write("\n".join(_s) + "\n")
    print("ok:", destino)


if __name__ == "__main__":
    raiz = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "arduino", "1_RELE_principal")
    desenhar(sys.argv[1] if len(sys.argv) > 1 else os.path.join(raiz, "ligacao_sensor_cancela.svg"))
