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

- **Divulgação:** adesivos prontos para a gráfica (cartelas A4, redondos,
  letreiro, lateral e COMO JOGAR da máquina) e o comercial narrado com voz
  brasileira — [`strike-kids-gles2/divulgacao/`](strike-kids-gles2/divulgacao/)
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
