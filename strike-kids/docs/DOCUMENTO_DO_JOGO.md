# Strike Kids — documento do jogo

Boliche infantil 3D para máquina arcade de 5 sensores, com dois robozinhos
originais: **Turbo** (menino-robô herói) e **Rosi** (menina-robô rosinha).
Mesma plataforma do Dragon Bowling Pro Ultra: **Godot 4.6.1**, renderizador
**Compatibility** (OpenGL ES 3, roda em TV Box Android 10), física **Jolt**.

## 1. A proposta

| Dragon Bowling | Strike Kids |
| --- | --- |
| 2D, pista e pinos em imagem | 3D de verdade: pista, pinos, personagens e cenário modelados |
| Câmera fixa com zoom | Câmera de cinema: segue o personagem, persegue a bola, vai aos pinos, treme no impacto, câmera lenta |
| Sem personagem | Turbo e Rosi jogam de verdade (passada, balanço, soltura na linha do sensor, pose final) e reagem a cada jogada |
| Resultado mostrado | REPLAY do strike com câmera colada nos pinos |
| Tema dragão | Parque Doce no céu: arco-íris, torres de doce, pirulitos, balões, nuvens |

Público: crianças de 3 a 10 anos. Partida curta (padrão 3 rodadas de até 3
bolas por jogador, igual ao Dragon Bowling), sempre recompensadora.

## 2. Personagens (originais)

Inspirados no estilo dos heróis-robô dos desenhos clássicos, **sem copiar
nenhum personagem existente** (importante para vender e divulgar a máquina).

- **Turbo** — menino-robô. Rosto de pele clara, cabelo azul-noite espetado,
  antena com luz amarela, orelhas de alto-falante com anel azul que brilha,
  corpo branco, núcleo azul no peito, short azul-marinho com cinto amarelo,
  botas-jato vermelhas. Cor do jogador 1 (LED azul).
- **Rosi** — menina-robô toda rosinha. Cabelo rosa com franja e
  maria-chiquinha com laços amarelos, presilha de estrela, antena de
  coração, vestido rosa com coração que brilha, botas magenta com jatos.
  Cor do jogador 2 (LED vermelho/rosa).

Rosto desenhado (atlas de 8 expressões): feliz, piscando, empolgado (olhos
de estrela), triste (lagriminha), concentrado, surpreso, risada, piscadinha.
Piscam sozinhos e olham para a bola enquanto ela rola.

Animações (poses-chave, `scripts/animacoes.gd`): parado, pronto (bola no
peito), **arremesso** (3 passos + deslize, solta a bola no quadro certo),
assistindo, **comemora_strike** (agacha, liga os jatos, voa girando 360°),
feliz (pulinho + palmas), triste, quase (mãos na cabeça), torcida, dança de
robô, acenar, andar, vitória (voando), escolhido.

Os nomes "Turbo" e "Rosi" são provisórios: trocar em `scripts/hud.gd`
(textos) e `scripts/principal.gd` ("VEZ DO TURBO").

## 3. Fluxo

1. **Abertura** (3 s): câmera desce do céu até os personagens.
2. **Atração**: logo, "APERTE START", recorde; Turbo e Rosi dançam; câmera
   orbitando; de 9 em 9 s uma **jogada de demonstração** completa.
3. **START** → "QUANTOS VÃO JOGAR?" (3 s; START de novo = 2 jogadores).
4. 1 jogador: **escolha do robô** rolando a bola para a esquerda (Turbo) ou
   direita (Rosi), ou START.
5. **Partida**: faixa "VEZ DA ROSI! RODADA 2" → personagem pronto com a bola,
   luzes dos sensores convidando ("ROLE A BOLA!") → sensor → arremesso →
   bola rolando (rastro de arco-íris, luzes da pista correndo) → impacto →
   resultado (STRIKE!/SPARE!/UAU!/BOA!/QUASE!/OPS!, pontos voando para o
   placar) → replay (strike) → reação do personagem bem de perto.
6. **Fim de jogo**: cartões com pontos, 1 a 3 estrelas, STRIKES/SPARES,
   VENCEU!/EMPATE!, NOVO RECORDE!, confete e fogos; START joga de novo.

Sensor acionado durante animações não se perde (fica guardado por 10 s) e
encurta a espera; a mesma bola não conta duas vezes (1,2 s). Sem jogar por
45 s: aviso "AINDA ESTÁ AÍ?" com contagem; sem resposta, encerra.

## 4. Jogada (justa e ajustável)

`scripts/jogada.gd`:
- O sensor define a **linha da bola** (Z −0,43 m, X −0,21, C 0, V +0,21,
  B +0,43).
- Na 1ª bola, sorteia quantos pinos caem pela **tabela da dificuldade**;
  nas seguintes, a chance de limpar depende de quão perto a linha passa do
  grupo de pinos restante.
- Escolhe QUAIS pinos (os mais próximos da linha e da frente: um centro com
  8 pinos deixa o clássico 7-10).
- No strike, mira o "bolso" (entre o pino 1 e o 3 ou o 2) com leve efeito.
- Física Jolt de verdade; pinos não planejados ficam "teimosos" (mais
  pesados e amortecidos: balançam e ficam); os planejados que resistirem
  levam um empurrão 0,5 s depois do impacto. No strike os pinos ainda dão um
  pulinho de desenho animado.

Pontos: 10 por pino, +50 strike, +20 spare.

## 5. Arte e técnica

- **Modelagem por SDF** (`tools/modelos/`): formas lisas soldadas (estilo
  vinil/massinha) → malha por Surface Nets → recursos nativos do Godot com
  **LOD automático**. Personagens com 10 partes articuladas.
- **Shader toon** próprio: duas faixas de luz, sombra colorida, brilho de
  borda, rosto projetado (atlas), partes que brilham (núcleo, antena,
  orelhas). Contorno por casca invertida com espessura constante na tela.
- **Pista**: madeira com verniz, setas, pontos, linha de falta, marcas dos
  pinos e luzes que correm acompanhando a bola (tudo no shader).
- **Fundo dos pinos**: veludo roxo com estrelas piscando (os pinos brancos
  saltam na tela), arco-íris, torres de doce, letreiro com o logo e
  lâmpadas que correm/piscam (padrão calculado na CPU).
- **Céu** em shader, gramado com morros, 46 objetos do Parque Doce, nuvens
  andando, balões balançando.
- **Efeitos**: rastro de arco-íris da bola, brilhos, estrelas, poeira,
  confete 3D, fogos, jatos das botas com luz, câmera lenta, tremida, "soco"
  de zoom, flash, tarjas de cinema no replay.
- **Responsivo**: o lado menor da tela vale 1080; layout se reorganiza em
  pé ou deitado; a câmera escolhe a abertura que garante o enquadramento em
  qualquer proporção. Giro de 90° para monitor em pé no HDMI deitado.
- **Leve**: render 3D numa SubViewport com escala de resolução; qualidade
  automática (alta/média/baixa).

## 6. Ferramentas de produção

| Ferramenta | O que faz |
| --- | --- |
| `python3 tools/modelos/modelos.py` | gera as malhas (Turbo, Rosi, pino, cenário, terreno) |
| `godot --headless --path . --script res://tools/modelos/assar_modelos.gd` | converte para recursos do Godot com LOD |
| `python3 tools/arte/gerar_arte.py` | rostos, texturas, letreiros, logo, ícones |
| `godot --path . res://tools/testes/retratos.tscn` | retratos dos personagens (placar/divulgação) |
| `python3 tools/sons/gerar_sons.py` | efeitos e músicas originais |
| `godot --path . -- --roteiro=pasta` | teste automático: joga sozinho e tira fotos |

## 7. LEDs no Android (plugin USB)

O APK padrão (como no Pro Ultra) usa o modelo pronto do Godot, sem Gradle,
e por isso não leva o plugin USB do Arduino. Para LEDs: no editor, Projeto >
Configurações > Plugins, ative **DragonUsbSerial**; no preset Android ligue
**Use Gradle Build** e instale o modelo de build Android (Projeto >
Instalar Modelo de Build Android). O `ArduinoBridge` já está pronto
(mesmo protocolo do Dragon Bowling).
