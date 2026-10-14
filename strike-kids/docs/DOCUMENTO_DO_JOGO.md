# Strike Kids — documento do jogo

Boliche infantil 3D para máquina arcade de 5 sensores, com dois mascotes
originais e fofinhos: **Bob** (o cachorrinho) e **Mia** (a gatinha).
Tema unissex, 4 cenários e física de verdade. Mesma plataforma do Dragon
Bowling Pro Ultra: **Godot 4.6.1**, renderizador **Compatibility** (OpenGL
ES 3, roda em TV Box Android 10), física **Jolt**.

## 1. A proposta

| Dragon Bowling | Strike Kids |
| --- | --- |
| 2D, pista e pinos em imagem | 3D de verdade: pista, pinos, mascotes e cenários modelados |
| Câmera fixa com zoom | Câmera de cinema: segue o mascote, persegue a bola, vai aos pinos, treme no impacto, câmera lenta |
| Sem personagem | Bob e Mia jogam de verdade (passada, balanço, soltura na linha do sensor) e reagem a cada jogada |
| Resultado mostrado | Pinos caindo com física real, um derrubando o outro; REPLAY do strike com câmera colada nos pinos |
| Pinos somem | Máquina de pinos de verdade: barra varredora e mesa que desce com os pinos |
| Um tema | 4 cenários, um por rodada: Parque de Diversões, Espaço, Fundo do Mar, Selva dos Dinos |

Público: crianças de 3 a 10 anos, meninos e meninas. Partida curta (padrão
3 rodadas de até 3 bolas por jogador, igual ao Dragon Bowling), sempre
recompensadora. Sem setas na tela: a mira é sempre o STRIKE.

## 2. Mascotes (originais)

- **Bob** — cachorrinho caramelo de orelhas caídas, focinho creme, camiseta
  turquesa com estrela amarela e lenço vermelho, rabinho que abana (mais
  rápido quando está feliz). Cor do jogador 1 (turquesa, LED azul).
- **Mia** — gatinha cinza-clarinho rajada, nariz e orelhas rosados,
  vestido lilás de bolinhas, gola branca e laço amarelo, rabo comprido.
  Cor do jogador 2 (roxo, LED vermelho).

Rosto desenhado (atlas de 8 expressões): feliz, piscando, empolgado (olhos
de estrela), triste (lagriminha), concentrado, surpreso, risada, piscadinha.
Piscam sozinhos e olham para a bola enquanto ela rola.

Animações (poses-chave, `scripts/animacoes.gd`): parado, pronto (bola no
peito), **arremesso** (passos + deslize, solta a bola no quadro certo),
assistindo, **comemora_strike** (pulo girando 360° com chuva de estrelas),
feliz (pulinho + palmas), triste, quase (mãos na cabeça), torcida, dança,
acenar, andar, vitória (pulinhos), escolhido.

## 3. Fluxo

1. **Abertura** (3 s): câmera desce do céu até os mascotes.
2. **Atração**: logo, "APERTE START", recorde; Bob e Mia dançam; câmera
   orbitando; de 9 em 9 s uma **jogada de demonstração** completa, e a cada
   demonstração o cenário muda (a atração mostra os 4).
3. **START** → "QUANTOS VÃO JOGAR?" (3 s; START de novo = 2 jogadores).
4. 1 jogador: **escolha do amigo** rolando a bola para a esquerda (Bob) ou
   direita (Mia), ou START.
5. **Partida**: em cada rodada nova, **cenário novo** (clarão, letreiro
   "FUNDO DO MAR!" e um passeio de câmera pelo lugar) → faixa "VEZ DA MIA!
   RODADA 2" → mascote pronto com a bola ("ROLE A BOLA! mire no STRIKE!") →
   sensor → arremesso → bola rolando (rastro de arco-íris, luzes da pista
   correndo) → impacto com física → resultado (STRIKE!/SPARE!/UAU!/BOA!/
   QUASE!/OPS!, pontos voando para o placar) → replay (strike) → reação do
   mascote → **máquina de pinos** (câmera baixinha na frente dos pinos).
6. **Fim de jogo**: cartões com pontos, 1 a 3 estrelas, STRIKES/SPARES,
   VENCEU!/EMPATE!, NOVO RECORDE!, confete e fogos; START joga de novo.

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

Strikes na 1ª bola (400 jogadas simuladas por dificuldade, com
para-choques): fácil — centro 58%, meio 33–41%, lados 12–17%; normal —
centro 32%, meio 18–22%, lados 8–12%; difícil — centro 26%, meio 11–13%,
lados 2–3%.

Pontos: 10 por pino, +50 strike, +20 spare.

## 5. Máquina de pinos (`scripts/maquina.gd`)

Depois de cada bola, como num boliche de verdade:
1. A **barra** desce na frente dos pinos (proteção).
2. A **mesa** desce, pega os pinos que ficaram em pé (centralizando no
   lugar certo) e sobe.
3. A barra **varre** os caídos para o fosso — ela é um corpo físico e
   empurra os pinos de verdade.
4. A mesa desce e devolve os pinos; na rodada nova ela desce com os
   **10 pinos novinhos**. Barra sobe e a pista está pronta.

## 6. Cenários (`scripts/temas.gd`)

| Cenário | Céu e luz | Destaques |
| --- | --- | --- |
| Parque de Diversões | azul com nuvens, gramado listrado | arco-íris com lâmpadas, torres doces, roda-gigante girando, carrossel, tendas, pirulitos, balões |
| Viagem ao Espaço | noite estrelada com nebulosa, chão de lua com crateras | planeta com anel atrás dos pinos, foguetes, disco voador dando voltas, planetinhas, cristais, estrelas cadentes |
| Fundo do Mar | azul-turquesa com raios de luz, areia com ondinhas | concha gigante, corais, algas balançando, cardumes de peixinhos, águas-vivas, tartarugas, bolhas subindo, baú |
| Selva dos Dinos | céu quente de aventura, selva verde | vulcão fumegando, dino pescoçudo espiando atrás dos pinos, pterossauros voando, palmeiras, ovos de dino, flores gigantes |

Cada cenário troca céu (shader com estrelas/raios), luz, neblina, terreno,
cores da pista (divisórias, faixas, canaletas), fundo dos pinos e letreiro.
Cada partida começa num cenário diferente (rodízio), e cada rodada passa
para o próximo.

## 7. Arte e técnica

- **Modelagem por SDF** (`tools/modelos/`): formas lisas soldadas (estilo
  vinil/massinha) → malha por Surface Nets → recursos nativos do Godot com
  **LOD automático**. Mascotes com partes articuladas (inclusive o rabo).
- **Shader toon** próprio: duas faixas de luz, sombra colorida, brilho de
  borda, rosto projetado (atlas). Contorno por casca invertida.
- **Pista**: madeira com verniz, setas e pontos de pista (decoração de
  boliche de verdade), linha de falta, marcas dos pinos e luzes que correm
  acompanhando a bola (tudo no shader).
- **Efeitos**: rastro de arco-íris (ou de fogo) da bola, brilhos, estrelas,
  poeira, confete 3D, fogos, câmera lenta, tremida, "soco" de zoom, flash,
  tarjas de cinema no replay.
- **Responsivo**: o lado menor da tela vale 1080; layout se reorganiza em
  pé ou deitado; a câmera escolhe a abertura que garante o enquadramento em
  qualquer proporção. Giro de 90° para monitor em pé no HDMI deitado.
- **Leve**: render 3D numa SubViewport com escala de resolução; qualidade
  automática (alta/média/baixa); só o cenário da vez fica ativo.

## 8. Ferramentas de produção

| Ferramenta | O que faz |
| --- | --- |
| `python3 tools/modelos/modelos.py` | gera as malhas (Bob, Mia, pino, cenário base, terrenos) |
| `python3 tools/modelos/temas.py` | gera os objetos dos 4 cenários |
| `godot --headless --path . --script res://tools/modelos/assar_modelos.gd` | converte para recursos do Godot com LOD (`-- temas` só os cenários) |
| `python3 tools/arte/gerar_arte.py` | rostos, texturas, letreiros, logo, ícones |
| `godot --path . res://tools/testes/retratos.tscn` | retratos dos mascotes (placar/divulgação) |
| `python3 tools/sons/gerar_sons.py` | efeitos e músicas originais |
| `godot --headless --path . --fixed-fps 120 res://tools/testes/calibrar.tscn` | calibra a tabela de jogadas (`-- --validar=normal` confere) |
| `godot --path . -- --roteiro=pasta` | teste automático: joga sozinho e tira fotos |

## 9. LEDs no Android (plugin USB)

O APK padrão (como no Pro Ultra) usa o modelo pronto do Godot, sem Gradle,
e por isso não leva o plugin USB do Arduino. Para LEDs: no editor, Projeto >
Configurações > Plugins, ative **DragonUsbSerial**; no preset Android ligue
**Use Gradle Build** e instale o modelo de build Android (Projeto >
Instalar Modelo de Build Android). O `ArduinoBridge` já está pronto
(mesmo protocolo do Dragon Bowling).
