# -*- coding: utf-8 -*-
"""
NARRACAO DO COMERCIAL (voz brasileira, uma frase por arquivo)
=============================================================

Gera as frases do comercial com o Kokoro (modelo de voz aberto, licenca
Apache 2.0 - pode ser usado em propaganda) nas vozes pf_dora (feminina) e
pm_alex (masculina), em ../comercial/narracao (+ linhas.json com a duracao
e a legenda de cada frase, que o montar_comercial.py usa).

    pip install kokoro-onnx soundfile
    (o modelo kokoro-v1.0.onnx e as vozes voices-v1.0.bin estao nas
     versoes publicadas do kokoro-onnx no GitHub)
    python3 narracao.py kokoro-v1.0.onnx voices-v1.0.bin

A "fala" usa a grafia que a voz pronuncia certo ("Straik Kids",
"istraique", "Mi-a"); a "legenda" e o texto que aparece no video. Cada
frase foi conferida por transcricao automatica (Whisper): a transcricao
saiu igual ao texto.

Para usar a voz de um locutor: grave cada frase (texto da legenda) com o
mesmo nome de arquivo (pf_dora_abre.wav, ...), acerte as duracoes no
linhas.json e rode o montar_comercial.py de novo.
"""
import json
import os
import sys

import numpy as np
import soundfile as sf
from kokoro_onnx import Kokoro

SAIDA = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "comercial", "narracao")
VOZES = ["pf_dora", "pm_alex"]
LINHAS = [
    # (chave, fala para a voz, legenda, velocidade)
    ("abre", "Olha só: chegou o Straik Kids, o boliche infantil em três dê!",
     "Olha só: chegou o STRIKE KIDS, o boliche infantil 3D!", 1.06),
    ("amigo", "Escolha o seu amigo: o cachorrinho Bob, ou a gatinha Mi-a!",
     "Escolha o seu amigo: o cachorrinho Bob ou a gatinha Mia!", 1.06),
    ("foto", "Sorria pra câmera: a sua foto vai pro placar!",
     "Sorria pra câmera: a sua foto vai pro placar!", 1.06),
    ("jogar", "É só rolar a bola, derrubar os pinos, e fazer istráique!",
     "É só rolar a bola, derrubar os pinos e fazer STRIKE!", 1.06),
    ("replay", "E ainda tem replay em câmera lenta!",
     "E ainda tem REPLAY em câmera lenta!", 1.06),
    ("cenarios", "A cada rodada, um cenário novo: espaço, fundo do mar, selva dos dinos, e parque de diversões!",
     "A cada rodada, um cenário novo: espaço, fundo do mar, selva dos dinos e parque de diversões!", 1.06),
    ("amigos", "Jogue sozinho, ou com um amigo!",
     "Jogue sozinho ou com um amigo!", 1.06),
    ("fogo", "Dois istráiques seguidos... e a bola pega fogo!",
     "Dois STRIKES seguidos... e a bola PEGA FOGO!", 1.06),
    ("ranking", "No final, a sua foto entra na classificação do dia!",
     "No final, a sua foto entra na classificação do dia!", 1.06),
    ("final", "Straik Kids: diversão garantida no seu parque, shopping ou bufê infantil!",
     "STRIKE KIDS: diversão garantida no seu parque, shopping ou buffet infantil!", 1.0),
    ("marca", "Lazer and Sport.", "Lazer & Sport", 1.0),
]


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    k = Kokoro(sys.argv[1], sys.argv[2])
    os.makedirs(SAIDA, exist_ok=True)
    info = {}
    for voz in VOZES:
        info[voz] = []
        for chave, fala, legenda, vel in LINHAS:
            a, sr = k.create(fala, voice=voz, speed=vel, lang="pt-br")
            a = np.asarray(a, np.float32)
            # tira o silêncio das pontas (sem comer o "ch"/"s" do começo)
            idx = np.nonzero(np.abs(a) > np.max(np.abs(a)) * 0.004)[0]
            a = a[max(0, idx[0] - int(0.12 * sr)): idx[-1] + int(0.15 * sr)]
            nome = "%s_%s.wav" % (voz, chave)
            sf.write(os.path.join(SAIDA, nome), a, sr)
            info[voz].append({"chave": chave, "arquivo": nome, "dur": round(len(a) / sr, 3), "legenda": legenda, "fala": fala})
            print(voz, chave, "%.2f s" % (len(a) / sr))
    with open(os.path.join(SAIDA, "linhas.json"), "w", encoding="utf-8") as f:
        json.dump(info, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
