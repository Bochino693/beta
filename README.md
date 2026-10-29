# Strike Kids — boliche infantil (Bob & Mia) — TV Box Mali-450

Este repositório tem só a **edição OpenGL ES 2.0**, a que gera o APK da TV Box
com placa de vídeo **Mali-400/450** (como a TX9 "comum"):
[`strike-kids-gles2/`](strike-kids-gles2/) — o jogo no **Godot 3.6.3**
(renderizador GLES2, física Bullet), leve e liso nessa placa.

- **Gerar o APK no Windows:** dois cliques em `strike-kids-gles2/GERAR_APK.bat`
  (baixa sozinho o que faltar: Godot 3.6.3, Java, o modelo Android; sem Gradle).
  O APK sai em `strike-kids-gles2/APK-Pronto/StrikeKids_GLES2.apk`.
- **No Linux:** `bash strike-kids-gles2/tools/android/montar_apk.sh`.
- Como testar, gerar o APK e operar a máquina:
  [`strike-kids-gles2/LEIA-ME.txt`](strike-kids-gles2/LEIA-ME.txt).
- **Arduino da máquina — 2 versões, o mesmo jogo** (grave só a da sua montagem):
  [`strike-kids-gles2/arduino/`](strike-kids-gles2/arduino/)
  ([qual escolher](strike-kids-gles2/arduino/LEIA-ME.txt))
  - [`1_RELE_principal/`](strike-kids-gles2/arduino/1_RELE_principal/) — **a principal**: porta
    pela trava com **relé** (D8) e/ou servo, sem ponte H, como a primeira versão.
    Código `strike_kids_rele/strike_kids_rele.ino`, desenho `ligacao_arduino_rele.pdf`
    e o passo a passo [`LEIA-ME_RELE.txt`](strike-kids-gles2/arduino/1_RELE_principal/LEIA-ME_RELE.txt).
  - [`2_PONTE_H/`](strike-kids-gles2/arduino/2_PONTE_H/) — porta com **motor pela ponte H**.
    Código `strike_kids_ponte_h/strike_kids_ponte_h.ino`, desenho `ligacao_arduino_ponte_h.pdf`
    e o passo a passo [`LEIA-ME_PONTE_H.txt`](strike-kids-gles2/arduino/2_PONTE_H/LEIA-ME_PONTE_H.txt).

- **Divulgação:** o gabinete da máquina em **7 temas de adesivagem** (Branco,
  Vermelho, Azul, Espaço, Fundo do Mar, Selva dos Dinos e Parque de Diversões:
  catálogo para os clientes com as fotos 3D, planta com as medidas e os 12
  adesivos de cada tema para a gráfica), adesivos avulsos (cartelas, redondos,
  placas) e o comercial narrado com voz brasileira —
  [`strike-kids-gles2/divulgacao/`](strike-kids-gles2/divulgacao/)
  ([LEIA-ME](strike-kids-gles2/divulgacao/LEIA-ME.txt)); essa pasta não entra no APK.

Jogo de boliche infantil para máquina arcade de **5 sensores** (placa Zero
Delay, Arduino dos sensores/LEDs, câmera para a foto dos jogadores): mascotes
fofinhos (Bob, o cachorrinho, e Mia, a gatinha), 4 cenários (Parque de
Diversões, Espaço, Fundo do Mar, Selva dos Dinos), pinos com física de verdade
e máquina de pinos animada.

Outras versões (fora daqui): a principal, **Godot 4** (OpenGL ES 3, TV Box
Mali-G31/T820 e PC), no repositório **beta-advanced**; a versão **Unity**, no
repositório **beta-unity**. A versão Godot 4 que ficava na pasta `strike-kids/`
deste repositório continua no histórico do git e no beta-advanced.
