# Strike Kids — documento do jogo

Boliche infantil 3D para máquina arcade de 5 sensores, com dois mascotes
originais e fofinhos: **Bob** (o cachorrinho) e **Mia** (a gatinha).
Tema unissex e esportivo (azul-marinho, azul, laranja, amarelo e vermelho —
as cores da marca **Lazer & Sport**, que aparece por todo o jogo), 4
cenários, física de verdade e a **foto da criança** tirada pela câmera da
máquina. **Godot 4.6.1**, renderizador **Compatibility**
(OpenGL ES 3, TV Box Android — Proeletronic SmartPro 4K 2 GB ou a Pro Ultra
do Dragon Bowling), física **Jolt**, câmera USB (Sigma) pelo plugin StrikeCamera.

## 1. A proposta

| Dragon Bowling | Strike Kids |
| --- | --- |
| 2D, pista e pinos em imagem | 3D de verdade: pista, pinos, mascotes e cenários modelados |
| Câmera fixa com zoom | Câmera de cinema: segue o mascote, persegue a bola, vai aos pinos, treme no impacto, câmera lenta |
| Sem personagem | Bob e Mia jogam de verdade (passada, balanço, soltura na linha do sensor) e reagem a cada jogada |
| Resultado mostrado | Pinos caindo com física real, um derrubando o outro; REPLAY do strike: a mesma jogada (cada passo da física gravado) em câmera lenta lisa |
| Pinos somem | Máquina de pinos de verdade: barra varredora e mesa que desce com os pinos |
| Um tema | 4 cenários, um por rodada: Parque de Diversões, Espaço, Fundo do Mar, Selva dos Dinos |

Público: crianças de 3 a 10 anos, meninos e meninas. Partida curta (padrão
3 rodadas de até 3 bolas por jogador, igual ao Dragon Bowling), sempre
recompensadora. Sem setas na tela: a mira é sempre o STRIKE.

## 2. Mascotes (originais)

Estilo pelúcia, com proporção de bebê (cabeça grande e redonda, olhos no
meio do rosto, bochechas fofas), corpinho de pera, bracinhos e perninhas
curtos, pés de sola chata e cores em blocos limpos.

- **Bob** — cachorrinho caramelo, focinho e patas creme, nariz 3D,
  orelhas caídas marrons, camiseta azul com estrela amarela, lenço
  vermelho e rabinho enroladinho que abana (mais rápido quando está feliz).
  Cor do jogador 1 (azul, LED azul).
- **Mia** — gatinha cinza com três listrinhas na testa, focinho e patas
  brancos, nariz 3D, orelhas pontudas, laço azul, roupinha laranja de
  bolinhas com golinha branca, rabo comprido.
  Cor do jogador 2 (laranja, LED vermelho).

Rosto desenhado em alta resolução (atlas 4096×2048, 8 expressões de
1024 px): olhos grandes e escuros com dois brilhos, sobrancelha curtinha,
bochecha rosada e boquinha em "w" logo abaixo do nariz 3D — feliz,
piscando, empolgado (brilhinhos nos olhos), triste (pálpebra caída e
lagriminha), concentrado, surpreso, risada, piscadinha. Piscam sozinhos e
olham para a bola enquanto ela rola.

**Movimento suave e com peso de verdade** (`scripts/personagem.gd`): rig
com quadril, joelho, tornozelo e pé. IK de duas juntas nas pernas: o pé
que apoia fica travado no chão (não escorrega nem flutua), o joelho dobra
sozinho quando o corpo abaixa, o quadril desce (suave) se o pé não
alcançaria, e se o corpo anda ou gira o pé dá um passinho automático.
Prender e soltar o pé é sempre gradual (0,14 s), sem tranco. Pulos com
arco de gravidade; o corpo **nunca muda de tamanho** (sem encolher/esticar:
quem amortece a aterrissagem são os joelhos). Entre as poses-chave, curva
monotônica no tempo de cada chave (PCHIP: não passa do ponto nem troca de
velocidade de repente) e troca de animação **por inércia** (o gesto que
estava acontecendo continua e se acomoda na animação nova, com tempo
proporcional ao tamanho do movimento). Olhar e rabinho com mola
amortecida. Sombra de contato embaixo de cada pé.
Bancos de teste: `tools/testes/anim_teste.tscn` (fotos das poses) e
`tools/testes/anim_medir.tscn` (mede tremor, deformação e saltos dos pés
quadro a quadro: o pior tremor caiu de 146 mm para 26 mm e a deformação
de 1% para 0).

Animações (poses-chave, `scripts/animacoes.gd`): parado, pronto (bola no
peito), **arremesso** (passos + deslize, solta a bola no quadro certo),
assistindo, **comemora_strike** (pulo girando 360° com chuva de estrelas),
feliz (pulinho + palmas), triste, quase (mãos na cabeça), torcida, dança,
acenar, andar, vitória (pulinhos), escolhido.

## 3. Fluxo

1. **Abertura Lazer & Sport Games** (tema boliche kids): tarjas de cinema,
   a **bola com o alvo da Lazer & Sport** rola pela pista com a câmera
   colada nela, faz **STRIKE em câmera lenta** visto de lado e, por cima da
   explosão de pinos, a marca **LAZER & SPORT GAMES** "estoura" na tela
   (estrelinhas, brilho passando, "apresenta"). Depois a câmera voa pelo
   cenário até a tela inicial, onde chegam o Bob e a Mia (~9 s).
2. **Atração**: logo, botão "APERTE START" com volume, placa do recorde
   (com a foto); Bob e Mia dançam; câmera
   orbitando; de 9 em 9 s uma **jogada de demonstração** completa, e a cada
   demonstração o cenário muda (a atração mostra os 4).
3. **START** → "QUANTOS VÃO JOGAR?" (igual ao Dragon Bowling): cartões
   "1 JOGADOR — START 1 VEZ" e "2 JOGADORES — START 2 VEZES" com o botão
   START desenhado; o escolhido brilha; contagem escrita e barra de 4 s
   ("Vão jogar em 2? Aperte START de novo agora!"). Faixa de etapas no alto:
   1 JOGADORES › 2 AMIGO › 3 FOTO › 4 JOGAR.
4. 1 jogador: **escolha do amigo** — Bob e Mia em cima de **pódios 3D**
   nas cores deles (o do escolhido acende o anel de luz), com placas de
   nome que acompanham a câmera. A placa de instrução mostra os 5 sensores
   da máquina coloridos: esquerda = BOB, meio = OK, direita = MIA (START
   também confirma).
4b. **SORRIA!** (se tiver câmera): a imagem ao vivo aparece num círculo com
   o mascote do lado, contagem 3-2-1, flash e "QUE FOTO LINDA!". Com 2
   jogadores, uma foto para cada um.
5. **Partida**: em cada rodada nova, **cenário novo** (clarão, letreiro
   "FUNDO DO MAR!" e um passeio de câmera pelo lugar) → faixa "VEZ DA MIA!
   RODADA 2" → a **pista de frente** esperando a jogada, como a criança vê
   da máquina ("ROLE A BOLA! mire no STRIKE!"; o mascote fica fora do
   quadro) → sensor → **corte para o mascote arremessando** → bola rolando (rastro de arco-íris, luzes da pista
   correndo) → impacto com física → resultado (STRIKE!/SPARE!/UAU!/BOA!/
   QUASE!/OPS!, pontos voando para o placar) → replay (strike) → reação do
   mascote → **máquina de pinos** (câmera baixinha na frente dos pinos).
   A bola cai no fosso, entra na **caçapa** e volta rolando no **retorno de
   bolas** ao lado de quem joga.
   **Replay do strike**: cada passo da física (120 por segundo) é gravado
   com o seu instante; o replay mostra a MESMA jogada interpolando entre os
   passos, em câmera lenta constante (45%, 27% na batida, sempre suave):
   câmera rasante colada na bola, corte lateral na batida (som dos pinos
   mais grave, junto com a imagem) e plano aberto da explosão — com o
   rastro de arco-íris, os brilhinhos e o barulho da bola em câmera lenta.
6. **Fim de jogo**: cartão de cada jogador com a **foto grande**, pontos,
   1 a 3 estrelas e o **lugar no dia**; quadro **CLASSIFICAÇÃO DE HOJE**
   (5 primeiros com foto); VENCEU!/EMPATE!, NOVO RECORDE!, confete e
   fogos; botão "APERTE START PARA JOGAR DE NOVO".

**Telas com cara de 3D** (`scripts/painel3d.gd` + `shaders/painel3d.gdshader`):
placar, cartões, botões, faixas e avisos são placas com volume — frente em
degradê com verniz, filete de luz, lateral mais escura (espessura),
contorno azul-marinho e sombra no chão, como os objetos do cenário.
Desenhadas pixel a pixel no shader: nítidas de 720p a 4K.

**Marca Lazer & Sport**: só na imagem de inicialização e na **abertura**,
e num **balãozinho** (uns 60 cm, logo sem fundo) que flutua ao lado da pista no cenário do
**Parque de Diversões**. Nenhuma outra tela ou objeto leva a marca. A logo foi
redesenhada no dobro da resolução com bordas nítidas
(`tools/arte/gerar_marca.py`).

Sensor acionado durante animações não se perde (fica guardado por 10 s) e
encurta a espera; a mesma bola não conta duas vezes (1,2 s). Sem jogar por
45 s: aviso "AINDA ESTÁ AÍ?" com contagem; sem resposta, encerra.

**Sequência de strikes**: 2 ou mais seguidos mostram "PEGANDO FOGO!" e o
contador "N STRIKES SEGUIDOS!"; a próxima bola sai como **bola de fogo**
(rastro de fogo e chamas).

## 4. Jogada: física de verdade, resultado justo

- O sensor define **por onde a bola passa** na linha de falta (Z −0,43 m,
  X −0,21, C 0, V +0,21, B +0,43).
- **Ninguém empurra os pinos.** A bola (6,5 kg) bate nos pinos (1,5 kg,
  centro de massa de pino de verdade) e a física Jolt faz o resto: pinos
  voando, batendo uns nos outros, nas paredes laterais e no fundo.
- Para o jogo continuar justo e ajustável, a **linha** da bola (alvo,
  velocidade e efeito) vem de uma tabela calibrada
  (`dados/tabela_jogadas.json`, 3.834 jogadas simuladas com a mesma física,
  `tools/testes/calibrar.gd`). O jogo sorteia quão boa foi a jogada
  (`TABELA` em `scripts/jogada.gd`, por dificuldade e posição) e escolhe uma
  linha "garantida" para aquele resultado — garantida porque a linha e as
  vizinhas (2 cm para cada lado) deram o mesmo resultado na simulação. Na
  prática o resultado bate com o sorteio (±1 pino) em 86 a 98% das vezes.
- 2ª e 3ª bola: a mira é o pino da frente do grupo que sobrou, batendo pelo
  lado que joga ele em cima dos outros; a chance de acertar em cheio depende
  da dificuldade e de quão perto o sensor passa do grupo.
- Pista sem emendas: a bola rola numa peça lisa (óleo) e os pinos pisam numa
  peça própria com atrito de madeira seca.
- Pista infantil de **10,5 m** (linha de falta até o pino 1): a bola chega
  rápido; setas a 1/3 da pista. Canaletas em meia-cana de verdade (perfil
  liso, mais escuras no fundo), divisórias arredondadas que terminam na
  linha de falta.

Strikes na 1ª bola (400 jogadas simuladas por dificuldade, com
para-choques): fácil — centro 58%, meio 33–41%, lados 12–17%; normal —
centro 32%, meio 18–22%, lados 8–12%; difícil — centro 26%, meio 11–13%,
lados 2–3%.

Pontos: 10 por pino, +50 strike, +20 spare.

## 5. Foto da criança (`autoload/Fotos.gd`)

- Câmera USB (ex.: Sigma). O Godot 4.6 sozinho **ignora câmera externa no
  Android** e **não tem câmera no Windows**, então a imagem vem de:
  **plugin StrikeCamera** na TV Box (`addons/StrikeCamera`, Java em
  `tools/android/StrikeCamera`), **ffmpeg** no PC Windows (quadros RGB crus
  por um cano, lidos numa linha de execução separada) e o **CameraServer**
  no Linux. Resolução perto de 640×480.
- **TV Box: o mesmo método do jogo de soco.** O plugin tenta, nesta ordem,
  e passa sozinho para o próximo se um caminho abre e fica mudo (4,5 s;
  8 s na UVC): (1) **câmera do sistema** pela API clássica (é por ela que
  as TV Box publicam a webcam USB, como câmera LEGACY — da última para a
  primeira); (2) **Camera2**, preferindo a câmera EXTERNA; (3) **UVC
  direta** pela libuvc (AndroidUSBCamera 3.2.7, a do jogo de soco, chamada
  por reflexão; só no APK do Gradle, que a baixa do JitPack).
  - Permissão da câmera pedida logo que o jogo abre; se negada, de novo na
    tela de espera (no máximo a cada 60 s e 3 vezes, nunca na partida).
  - Permissão USB (só para a UVC): pedida só na tela de espera, depois de
    20 s sem câmera do sistema, e nunca se a webcam já apareceu como câmera
    do sistema (nesta abertura ou numa anterior: `user://fotos/camera.cfg`)
    — o Android conta zero câmeras por instantes logo após o boot. Uma
    atividade com filtro USB (classe 14 / 239-2) faz o Android oferecer
    "Usar por padrão" (a permissão fica guardada).
  - A câmera **acorda 15 s depois da abertura e fica ligada** (longe do
    pico de memória do carregamento). Sem ninguém vendo, o plugin só conta
    os quadros (`ver(false)`: nada copiado, nada sobe para a placa de
    vídeo); na prévia e na foto (`ver(true)`) os planos Y e UV viram duas
    texturas. Assim a foto sai na hora (câmera quente) e a webcam não
    abre/fecha a cada partida — no soco, isso mexia no driver USB e
    derrubava a TV Box. Vigia de 1 s (só o contador de quadros): app
    pausado (janela do Android) → reabre; sem imagem há 30 s → reabre do
    zero só na tela de espera, no máximo a cada 30 s e 3 vezes.
  - No PC a câmera liga no START e desliga uns segundos depois da foto.
- A foto: 1 jogador = 1 foto, 2 jogadores = 2 fotos ("SORRIA!" 3-2-1 para
  cada um). Espera até 4 s por um quadro **novo** e bom (nem escuro, nem
  chapado: contraste ≥ 0,04 numa grade 8×6) — nunca sai com a imagem da
  partida anterior. Câmera muda há muito tempo: o jogo pula o "SORRIA!" e
  usa os mascotes (`Fotos.pode_fotografar()`).
- A imagem (RGB ou YCbCr, conforme a câmera) é convertida num shader,
  recortada no quadrado do meio e espelhada; a foto (384×384) sai de uma
  SubViewport.
- Teste: `tools/testes/foto_teste.tscn` simula o plugin Android (webcam só
  no USB, câmera do sistema, câmera lenta e escura no começo, pausa do
  app, câmera muda) e confere permissões, câmera sempre ligada, 1 e 2
  fotos, sem foto velha e o limite de reaberturas. No menu do operador,
  "TESTE DA CÂMERA" mostra a imagem ao vivo ou, sem imagem em 6 s, o
  relatório do plugin (Android, câmeras, USB, permissões, libuvc e o
  diário); `CAMERA_TVBOX.bat` grava o mesmo pelo adb.
- Onde aparece: cartão do placar (foto redonda + mascote de selo), faixa
  "VEZ DE", estouro da foto no STRIKE, cartões da tela final e a
  **CLASSIFICAÇÃO DE HOJE** (`scripts/classificacao.gd`): os 10 melhores do
  dia, cada um com a sua foto; no fim da partida, "2º LUGAR HOJE!" no
  cartão e o quadro dos 5 primeiros (quem acabou de jogar brilha, com
  "VOCÊ!"); na atração, os 3 melhores de hoje com as fotos.
- Privacidade: fotos só na TV Box; as da partida ficam na memória; ficam
  gravadas só as da classificação do dia (apagadas na virada do dia) e a
  do recorde; tudo some ao zerar recordes. Opção no menu do operador
  para desligar, e "TESTE DA CÂMERA" para a instalação.

## 6. Máquina de pinos (`scripts/maquina.gd`)

Depois de cada bola, como num boliche de verdade:
1. A **barra** desce na frente dos pinos (proteção).
2. A **mesa** desce, pega os pinos que ficaram em pé (centralizando no
   lugar certo) e sobe.
3. A barra **varre** os caídos para o fosso — ela é um corpo físico e
   empurra os pinos de verdade.
4. A mesa desce e devolve os pinos; na rodada nova ela desce com os
   **10 pinos novinhos**. Barra sobe e a pista está pronta.

## 6b. Caçapa, gabinete e salão (`scripts/mundo.gd`, `scripts/perfis.gd`)

- **Caçapa**: paredes laterais acolchoadas com friso amarelo, cortina de
  veludo pregueada nas cores do cenário com **halo de luz atrás dos pinos**
  e estrelinhas, almofada de borracha embaixo. No fundo do fosso, a **boca
  da caçapa** (túnel escuro com moldura amarela e filete de luz) com uma
  **cortina de tiras de borracha** (uma MultiMesh) que abre quando a bola
  passa e balança depois; a "esteira" do fosso leva a bola até ela, e a
  bola reaparece rolando no **retorno de bolas** da área dos jogadores.
- **Portal no fim da pista**: gabinete alto (esconde a máquina de pinos),
  letreiro STRIKE KIDS com moldura, **arco de raios coloridos** girando
  devagar (`shaders/raios.gdshader`) com lâmpadas e duas **colunas**
  iluminadas — tudo nas cores de cada cenário (`Temas.CONFIG`: portal,
  gabinete, coluna, parede, fundo, halo).
- **Atrás dos jogadores**: tapete, **mureta** na cor do cenário, o letreiro
  STRIKE KIDS em dois postes, sofás e retorno de bolas; por cima da mureta
  aparece o próprio cenário (objetos do tema atrás da área), nada de chão
  infinito.
- **Pinos com reação**: medo quando a bola chega; depois da jogada os
  derrubados ficam **tontos** (estrelinhas) ou **bravinhos** (tremidinha de
  raiva) e os que ficaram de pé ficam felizes — vários dão **pulinhos** de
  comemoração (mais festa quando sobram muitos). Os pulos são animação
  (pino preso, sem física) e terminam exatamente no lugar; a máquina ainda
  recentraliza os pinos em pé antes da próxima bola.
- Peças feitas por **perfil extrudado** (cantos arredondados, normais
  lisas): nítidas de perto em 4K.

## 7. Cenários (`scripts/temas.gd`)

| Cenário | Céu e luz | Destaques |
| --- | --- | --- |
| Parque de Diversões | azul com nuvens, gramado listrado | arco-íris com lâmpadas, torres de circo (branco e vermelho), roda-gigante girando, carrossel, tendas, pirulitos azuis e amarelos, balões |
| Viagem ao Espaço | noite estrelada com nebulosa, chão de lua com crateras | planeta com anel atrás dos pinos, foguetes, disco voador dando voltas, planetinhas, cristais, estrelas cadentes |
| Fundo do Mar | azul-turquesa com raios de luz, areia com ondinhas | concha gigante, corais, algas balançando, cardumes de peixinhos, águas-vivas, tartarugas, bolhas subindo, baú |
| Selva dos Dinos | céu quente de aventura, selva verde | vulcão fumegando, dino pescoçudo espiando atrás dos pinos, pterossauros voando, palmeiras, ovos de dino, flores gigantes |

Cada cenário troca céu (shader com estrelas/raios), luz, neblina, terreno,
cores da pista (divisórias, faixas, canaletas), fundo dos pinos e letreiro.
Cada partida começa num cenário diferente (rodízio), e cada rodada passa
para o próximo.

## 8. Arte e técnica

- **Modelagem por SDF** (`tools/modelos/`): formas lisas soldadas (estilo
  vinil/massinha) → malha por Surface Nets → recursos nativos do Godot com
  **LOD automático**. Mascotes com partes articuladas (inclusive rabo e pés).
- **Bordas de cor nítidas (4K)**: onde a cor muda (listras, bolinhas,
  manchas), o modelador subdivide a malha duas vezes e suaviza a cor como
  um antisserrilhado — sem os "degraus" de cor. Listras dos para-choques e
  desenho do chão (grama listrada, crateras, ondas de areia, flores) são
  calculados no shader, pixel a pixel.
- **Nitidez**: MSAA, filtro anisotrópico, mipmaps em todas as imagens,
  compressão de alta qualidade (BPTC/ASTC) nos rostos, bola, madeira e
  letreiros; letreiros e logo em 1,6x.
- **Desempenho** (liso no PC e na TV Box):
  - malhas simplificadas pelo `tools/modelos/simplificar.py` (meshoptimizer,
    leva posição, normal e COR em conta: bordas de cor continuam nítidas) —
    Bob 120 mil → 26 mil triângulos, pino 14,6 mil → 2,4 mil, cenário
    1,1 milhão → 98 mil; lâmpadas de 64 triângulos;
  - peças paradas com o mesmo material juntadas numa malha só
    (`scripts/lote.gd`): 100 a 200 desenhos por quadro conforme a vista (eram ~450);
  - sem sombra do sol (no "Compatibilidade" ela desenha tudo 2 vezes):
    sombras pintadas nos pinos (uma MultiMesh que deita junto com o pino),
    bola e bichinhos;
  - imagem 3D **no tamanho da tela** (TV Box 1080 px com MSAA 4x — na Mali
    o MSAA é resolvido dentro da placa via `GL_EXT_multisampled_render_to_texture`;
    PC até 4K) e **nitidez automática**: se cair de ~52 quadros por segundo
    o 3D diminui 10% (até 70%) e, com folga, **volta a crescer** até 100%;
    o ponto bom fica guardado (`video/fator`); o operador pode fixar em
    100/90/80/70% ("Nitidez do 3D"); no PC, realce de bordas (tipo CAS) ao
    esticar;
  - superfícies grandes **sem luz por pixel** (pista, piso e arco do
    portal com a luz já pintada; marcações da pista com conta fixa por
    pixel); MSAA e brilho só no PC; cores convertidas por vértice no toon;
  - **interpolação da física** só para o que a física move (bola, pinos,
    mesa e barra da máquina): eles aparecem no lugar exato do instante de
    cada quadro, lisos em 60, 75 ou 144 Hz e com QPS oscilando; câmera,
    sombras e rastro seguem a posição interpolada; o resto do jogo (que
    anda a cada quadro) fica sem interpolação;
  - **câmera lenta sem mexer na física**: o passo da física é sempre de
    1/120 s (o mesmo da calibração das jogadas); na câmera lenta a física
    só dá menos passos por segundo (0,4 = 48/s) e a interpolação deixa a
    imagem lisa — o resultado da jogada não depende do QPS da máquina;
  - **medidor** (`scripts/medidor.gd`): painel de QPS/ms/CPU/placa de vídeo/
    desenhos/memória (F3 ou menu do operador) e TESTE DE DESEMPENHO de 20 s
    com qualidade recomendada (grava `user://desempenho.txt`); bancada
    `--benchmark` no PC mede o custo de cada parte;
  - **aquecimento** (`scripts/aquecer.gd`): na abertura, uma telinha
    escondida desenha uma amostra de cada material (todos os cenários,
    partículas, lâmpadas, painéis 2D) — sem engasgo na primeira vez;
  - PC em **tela cheia** (exclusiva), mouse some sozinho.
- **Shader toon** próprio: duas faixas de luz, sombra colorida, brilho de
  borda, rosto projetado (atlas). Contorno por casca invertida.
- **Pista** (boliche kids, tudo no shader, com bordas suaves por `fwidth`):
  madeira mel envernizada (reflete o céu e o portal colorido), **bordas de
  neon** na cor do cenário sempre acesas (luzes correndo para os pinos
  esperando a bola; na jogada, um brilho segue a bola), **setas
  arco-íris** com contorno branco, **trilha de estrelas** no meio da pista
  piscando em sequência até os pinos (a última é um "alvo" na frente do
  pino 1), pontos coloridos, linha de falta neon e holofote nos pinos.
  Na área de arremesso: pontos arco-íris e a estrela da saída.
- **Efeitos**: rastro de arco-íris (ou de fogo) da bola, brilhos, estrelas,
  poeira, confete 3D, fogos, câmera lenta, tremida, "soco" de zoom, flash,
  tarjas de cinema no replay.
- **Responsivo**: o lado menor da tela vale 1080; layout se reorganiza em
  pé ou deitado; a câmera escolhe a abertura que garante o enquadramento em
  qualquer proporção. Giro de 90° para monitor em pé no HDMI deitado.
- **Leve**: render 3D numa SubViewport com escala de resolução; qualidade
  automática (alta/média/baixa); só o cenário da vez fica ativo.

## 9. Ferramentas de produção

| Ferramenta | O que faz |
| --- | --- |
| `python3 tools/modelos/modelos.py` | gera as malhas (Bob, Mia, pino, cenário base, terrenos) |
| `python3 tools/modelos/temas.py` | gera os objetos dos 4 cenários |
| `godot --headless --path . --script res://tools/modelos/assar_modelos.gd` | converte para recursos do Godot com LOD (`-- temas` só os cenários) |
| `python3 tools/arte/gerar_arte.py` | rostos, texturas, letreiros, logo, ícones |
| `python3 tools/arte/diagrama_arduino.py` | desenho da ligação do Arduino com o passo a passo do START (`docs/ligacao_arduino.svg/.png/.pdf`) |
| `python3 tools/arte/gerar_marca.py` | logo Lazer & Sport em alta (inteira, alvo e placa), fundo da abertura e imagens de inicialização |
| `python3 tools/ajustar_importacao.py` | mipmaps e compressão de alta qualidade nas imagens (rodar depois de gerar artes) |
| `godot --path . res://tools/testes/anim_teste.tscn -- saida.png danca 0.2,0.6 lado` | folha de quadros de uma animação (pés, joelhos, pulos) |
| `godot --path . -- --instantes=pasta --em=2,5` | fotos do jogo rodando em instantes fixos (conferir nitidez, até 4K) |
| `godot --path . res://tools/testes/retratos.tscn` | retratos dos mascotes (placar/divulgação) |
| `godot --path . res://tools/testes/paineis.tscn -- saida.png` | amostra das placas com volume das telas |
| `godot --path . res://tools/testes/planos.tscn -- --saida=pasta [--plano=nome:pos:alvo:fov_v:fov_h]` | fotos de planos de câmera fixos (canaletas, caçapa, salão, espera da jogada) |
| `python3 tools/sons/gerar_sons.py` | efeitos e músicas originais |
| `godot --headless --path . --fixed-fps 120 res://tools/testes/calibrar.tscn` | calibra a tabela de jogadas (`-- --validar=normal` confere) |
| `godot --path . -- --roteiro=pasta` | teste automático: joga sozinho e tira fotos |
| `godot --path . -- --janela=720x1280 --benchmark [--configs=base,sem_portal]` | bancada de desempenho: custo de cada parte do desenho (placa de vídeo e quadro) em 4 vistas |
| `godot --path . --fixed-fps 50 -- --janela=540x960 --replay-teste[=pasta]` | faz um strike de demonstração e mede, quadro a quadro, a bola rolando (interpolada) e o replay (sem trancos) |
| `godot --path . -- --medidor` | abre o jogo já com o painel de desempenho (o mesmo do F3) |
| `godot --path . -- --camera-falsa` | simula a câmera no PC (imagem de teste) |

## 10. Arduino da máquina: sensores, porta e botão (`autoload/ArduinoBridge.gd`)

- **Ligação**: `docs/ligacao_arduino.pdf` (e `.png`) — o Nano visto de
  cima com os pinos na ordem real, cada fio (sensores, botões, servo ou
  relé, fita de LED, USB da TV Box), o mapa no Uno, como dar START, a
  primeira vez e os cuidados. Gerado por `tools/arte/diagrama_arduino.py`
  com os pinos do firmware.
- **Firmware** (`arduino/strike_kids/strike_kids.ino`, Uno/Nano/Pro Mini/
  Mega/Leonardo): lê os 5 sensores (D2 D3 D4 D5 D7, esquerda → direita,
  filtro de 2 ms e rearme de 120 ms para a bola balançando no sensor), o
  botão de configuração (A0), START (A1) e moedeiro (A2, pulsos de 20 ms);
  comanda a trava da porta por **servo** (D9, PWM do próprio Timer1 —
  firme mesmo com a fita de LED segurando o processador; movimento suave)
  e/ou **relé** (D8, polaridade e tempo máximo configuráveis para trava
  solenoide); acende a fita WS2812 (D6) com os efeitos do Dragon Bowling.
  O nível de repouso de cada sensor é **calibrado** (pista vazia) e fica na
  EEPROM: serve sensor normalmente aberto ou fechado. Sem notícia do jogo
  por 15 s com a porta aberta, ela fecha sozinha.
- **Protocolo** (texto, 9600): Arduino → jogo `OLA/PONG:STRIKE_KIDS:1`,
  `S:1..S:5`, `CFG`, `START`, `FICHA`, `SENS:00100` (ao vivo, no teste),
  `PORTA:ABERTA/FECHADA`, `CAL:OK:HHHHH`, `INFO:...`, `AVISO:SEM_JOGO`;
  jogo → Arduino `PING`, `PORTA:ABRE/FECHA`, `PORTA?`, `SENS?`,
  `TESTE:1/0`, `CALIBRA`, `INFO?` e os comandos de LED.
- **TV Box**: plugin **StrikeSerial** (`addons/StrikeSerial`, Java em
  `tools/android/StrikeSerial`) com driver USB-serial **próprio** — CDC/ACM
  (Arduinos originais, CH9102), CH340/CH341 (contas do divisor como o
  `ch341.c` do Linux), FTDI e CP210x —, sem biblioteca de fora (nada de
  JitPack: o APK pronto e o do Gradle levam). Lista em segundo plano,
  abre em segundo plano, lê numa linha de execução própria e junta as
  linhas; DTR+RTS ligados (o Uno reinicia e diz OLA). Atividade de encaixe
  com o filtro dos Arduinos: a janela de permissão oferece "Usar por
  padrão".
- **Jogo**: `S:n` vira a mesma ação da Zero Delay (Z X C V B), `CFG`
  vira a configuração, `START`/`FICHA` os botões — `InputEventAction` com
  a marca `arduino`, aceita pelo `ArcadeControls`. A porta **abre no
  START** (`_escolher_jogadores`) e **fecha** no fim da partida, na
  atração, na abertura, no teste de desempenho e no menu. Ao (re)conectar
  o jogo manda a porta como ela deve estar. Permissão USB: uma vez logo
  no começo (depois da janela da câmera) e depois só na espera ou no menu.
  Opções: porta invertida, sensores invertidos.
- **Menu do operador**: teste dos sensores (ao vivo, com contagem),
  calibrar sensores, teste da porta (com a confirmação do Arduino), teste
  da câmera; sem o Arduino, mostram o relatório (USB, chip, permissão).
- **Testes**: `tools/testes/arduino/rodar.sh` (firmware num ATmega328P
  simulado pelo simavr: 34 verificações), `tools/testes/arduino_teste.tscn`
  (plugin simulado: permissão, conexão, jogadas, porta, inversões, teste
  ao vivo, calibração, reconexão, firmware antigo e uma partida inteira só
  com o Arduino) e `tools/android/StrikeSerial/teste/rodar.sh` (contas dos
  chips).
