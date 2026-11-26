// STRIKE KIDS - ARDUINO DA MAQUINA - VERSAO DO RELE (SEM PONTE H)
// ================================================================
// Le os 5 SENSORES da pista, o botao de CONFIGURACAO (e, se ligados, o
// START e o moedeiro), comanda a TRAVA da porta das bolas (rele e/ou
// servo) e a fita de LED. Conversa com a TV Box pelo cabo USB (9600, linhas
// de texto).
//
// DUAS VERSOES, O MESMO JOGO (o mesmo APK serve para as duas):
//   arduino/1_RELE_principal/strike_kids_rele (ESTA, A PRINCIPAL) - porta
//     pelo RELE e/ou SERVO, sem ponte H. Desenho:
//     1_RELE_principal/ligacao_arduino_rele.pdf e o passo a passo:
//     1_RELE_principal/LEIA-ME_RELE.txt
//   arduino/2_PONTE_H/strike_kids_ponte_h - porta com MOTOR DC ou ATUADOR
//     LINEAR por uma PONTE H. Desenho: 2_PONTE_H/ligacao_arduino_ponte_h.pdf
//   O codigo e o mesmo nas duas; so mudam USAR_PONTE_H, USAR_SERVO e
//   RELE_PULSO abaixo.
//
// Placas: Arduino Uno, Nano (original ou clone CH340), Pro Mini 5 V,
// Mega 2560 e Leonardo/Micro.
//
// LIGACOES (padrao - mude abaixo se precisar; desenho: ../ligacao_arduino_rele.pdf)
//   Sensores, da ESQUERDA para a DIREITA (olhando da crianca para os pinos):
//     S1 = D2   S2 = D3   S3 = D4 (centro)   S4 = D5   S5 = D7
//     Sensor optico/infravermelho com saida NPN, chave ou micro-switch:
//     o sinal no pino e o GND no GND do Arduino (o pino ja tem pull-up).
//     Sensor que precisa de 12 V: alimentacao pela fonte de 12 V, GND
//     comum com o Arduino, e SO o fio de sinal no pino (saida NPN).
//   Botao de CONFIGURACAO (entra e sai do menu do operador): A0 e GND
//   Botao START (opcional; o START da Zero Delay tambem vale): A1 e GND
//   Moedeiro / FICHA (opcional): sinal (COIN) em A2, GND no GND. Cada
//     pulso = 1 ficha (quantas fichas por partida: no menu do operador).
//     Moedeiro NA ou NF: os dois funcionam.
//   TRAVA (porta das bolas) - use um dos dois, ou os dois juntos (recebem
//   o mesmo comando):
//     RELE:  D8 -> entrada (IN) de um modulo rele 5 V (VCC no 5V, GND no
//            GND). Modulo que liga com HIGH: RELE_LIGA_EM_LOW 0. Sem rele:
//            USAR_RELE 0.
//            RELE_PULSO 1 (ESTA VERSAO): o rele da UM PULSO (RELE_PULSO_MS)
//            e a porta TROCA de posicao - um pulso abre, outro pulso fecha
//            (comando de porta/trava que alterna a cada toque).
//            RELE_PULSO 0: o rele fica LIGADO com a porta aberta (trava
//            solenoide / eletroima), como na primeira versao; veja
//            RELE_LIGADO_ABERTA e RELE_TEMPO_MAX_S.
//     SERVO: sinal no D9 (Mega: D11). Alimente o servo por uma fonte
//            de 5-6 V propria (servo grande puxa muita corrente) e ligue o
//            GND dessa fonte no GND do Arduino. Angulos: SERVO_FECHADA e
//            SERVO_ABERTA. Tem servo: USAR_SERVO 1.
//   D10, D11, D12, A3 e A4 ficam livres (sao da ponte H na outra versao).
//   Fita de LED WS2812 (NeoPixel), opcional: D6
//   LED da placa (D13): pisca a cada sensor/botao acionado.
//
// O RELE DE PULSO, PASSO A PASSO (o que esta versao garante):
//   * AO LIGAR O ARDUINO O RELE NAO MEXE. Nem na tomada, nem quando o jogo
//     abre o USB (o Uno/Nano reinicia nessa hora). A ultima posicao da
//     porta fica guardada na EEPROM; so um pedido DIFERENTE dela da pulso.
//   * UM PULSO POR MUDANCA, NUNCA EM SEQUENCIA: pedido igual a posicao de
//     agora so confirma (PORTA:ABERTA / PORTA:FECHADA), sem pulso. Abre e
//     fecha chegando juntos (menos de RELE_FIRME_MS) se anulam, sem pulso.
//     Entre dois pulsos ha sempre RELE_DESCANSO_MS (a porta termina de andar).
//   * QUEM MANDA E O JOGO: modo livre = porta sempre aberta; modo fichas =
//     fechada sem credito, UM pulso abre quando o credito entra, UM pulso
//     fecha no fim da partida (se nao sobrou credito) ou depois de muito
//     tempo sem ninguem jogar ("Fechar a trava sem jogar" no menu).
//   * O JOGO SUMIU (TV Box desligada, cabo solto) com a porta aberta, no
//     MODO FICHAS: fecha sozinha depois de SEM_JOGO_FECHA_MS (no MODO LIVRE
//     - o jogo avisa: MODO:LIVRE - a porta fica sempre aberta) - mas so depois de o jogo ter
//     falado pelo menos uma vez desde que o Arduino ligou (ligar o Arduino
//     antes da TV Box nao da pulso nenhum).
//   * (12) DESLIGARAM NO MEIO (a maquina ficou sem energia com a porta
//     aberta): sem energia a trava FECHA - ao ligar, o Arduino sabe que ela
//     esta fechada e nao da pulso nenhum ate o jogo pedir aberta (ficha ou
//     modo livre). Reiniciar SEM faltar energia (botao reset) nao confunde:
//     a memoria comum diz onde ela estava. (PORTA_FECHA_SEM_ENERGIA)
//   * (12) O JOGO NAO REINICIA MAIS O ARDUINO ao abrir o USB (jogo 8.8.2+,
//     sem DTR): nada de reinicio a cada conexao.
//   * (13) A MAQUINA LIGOU: o jogo (8.8.3+) avisa PORTA:LIGOU uma vez por
//     ligada da TV Box - a trava esta FECHADA (sem energia ela fecha), sem
//     pulso, mesmo que a memoria do Arduino tenha aguentado o desliga-liga.
//   * NA PRIMEIRA GRAVACAO deixe a porta FECHADA (a EEPROM comeca em
//     "fechada"). Se um dia a porta ficar ao contrario do que o jogo
//     mostra (alguem mexeu nela com a mao): menu do operador, TESTE DA
//     PORTA, "acertar" (comando PORTA:ACERTA) - ou "Porta invertida".
//
// FICHAS QUE NAO SE PERDEM: cada ficha do moedeiro e guardada na EEPROM
// antes de ser avisada ao jogo, e so sai da fila quando o jogo confirma
// (FICHA:<n> / FICHA:OK:<n>). Ficha posta com a TV Box ainda ligando, ou
// com o cabo solto, chega ao jogo assim que ele conectar.
//
// Sem fita de LED (ou sem a biblioteca "Adafruit NeoPixel" instalada):
// troque USAR_LEDS para 0.

#include <EEPROM.h>

// ------------------------------------------------------------ AJUSTES
#define USAR_LEDS 1          // 1 = tem fita de LED no D6 (biblioteca Adafruit NeoPixel)
#define LED_PINO 6
#define NUM_LEDS 60
#define BRILHO 180

const uint8_t SENSOR_PINOS[5] = {2, 3, 4, 5, 7};
#define CONFIG_PINO A0
#define START_PINO A1
#define FICHA_PINO A2
#define RELE_PINO 8
#define LED_PLACA 13

// ---- PORTA DAS BOLAS: o que esta ligado (todos recebem o mesmo comando)
#define USAR_PONTE_H 0            // 0 = SEM ponte H (esta versao). Com ponte H: arduino/2_PONTE_H
#define USAR_SERVO 0              // servo no D9 (Mega: D11); 0 = nao tem servo
#define USAR_RELE 1               // rele no D8 (de PULSO ou de NIVEL: RELE_PULSO abaixo); 0 = nao tem rele

// Ponte H da porta (motor DC ou atuador linear).
#define PONTE_IN1 10
#define PONTE_IN2 12
#define PONTE_INVERTIDA 0         // a porta abre quando devia fechar? troque para 1 (ou inverta OUT1/OUT2)
#define PONTE_VELOCIDADE_ABRE 255 // 0 a 255 - so vale com o ENA ligado no pino (sem o jumper)
#define PONTE_VELOCIDADE_FECHA 255 // fechar mais devagar (ex.: 180) e mais seguro para as maos
#define PONTE_FIM_DE_CURSO 0      // de fabrica: 1 = tem os micro-switches (A3 e A4). O MENU troca
#define FC_ABERTA_PINO A3         // fim de curso da porta ABERTA
#define FC_FECHADA_PINO A4        // fim de curso da porta FECHADA
#define FC_NF 0                   // 1 = micro-switch ligado no NF (normalmente fechado)
#define PONTE_TEMPO_ABRE_MS 1500UL  // de fabrica, SEM fim de curso: tempo para abrir tudo. O MENU troca
#define PONTE_TEMPO_FECHA_MS 1500UL // de fabrica, SEM fim de curso: tempo para fechar tudo. O MENU troca
#define PONTE_TEMPO_MIN_MS 300UL    // o que o menu pode escolher: de 0,3 s ...
#define PONTE_TEMPO_LIM_MS 15000UL  // ... a 15 s
#define PONTE_TEMPO_MAX_MS 6000UL   // COM fim de curso: nao chegou neste tempo (ou 2x o tempo do motor) -> para
#define PONTE_TENTATIVAS 3          // ... e tenta de novo, ate 3 vezes, a cada 3 s
#define PONTE_ESPERA_TRAVOU_MS 3000UL
#define PONTE_FREIO_MS 150UL      // ao parar: freia o motor este tempo e depois solta (0 = so solta)
#define PONTE_PAUSA_MS 300UL      // parada antes de inverter o sentido (protege a ponte e a caixa de reducao)

// Servo da trava: angulo com a porta FECHADA e ABERTA (0 a 180).
#define SERVO_FECHADA 0
#define SERVO_ABERTA 90
#define SERVO_GRAUS_POR_S 240     // velocidade do movimento
#define SERVO_SOLTA_PARADO 0      // 1 = para de segurar 1 s depois de chegar

// Rele da trava.
#define RELE_LIGA_EM_LOW 1        // modulo rele comum liga com LOW; o seu liga com HIGH? troque para 0
#define RELE_PULSO 1              // 1 = PULSO: cada pulso TROCA a porta (abre <-> fecha). 0 = NIVEL: rele ligado = porta aberta
// so com RELE_PULSO 1:
#define RELE_PULSO_MS 200UL       // quanto tempo o rele fica ligado em cada pulso
#define RELE_DESCANSO_MS 1000UL   // tempo minimo entre dois pulsos (a porta termina de andar)
#define RELE_FIRME_MS 150UL       // o pedido fica firme este tempo antes do pulso (abre+fecha juntos nao pulsam)
#define PORTA_FECHA_SEM_ENERGIA 1 // (12) 1 = SEM ENERGIA A TRAVA FICA FECHADA (comando de toque eletronico):
                                  // a maquina ligou na tomada -> o Arduino SABE que ela esta fechada, mesmo
                                  // que tenham desligado no meio da partida. Reiniciou SEM faltar energia
                                  // (botao reset): lembra onde ela estava. 0 = trava que guarda a posicao
                                  // sem energia: o Arduino lembra pela EEPROM (como ate o firmware 11)
// so com RELE_PULSO 0:
#define RELE_LIGADO_ABERTA 1      // 1 = rele ligado com a porta aberta; 0 = ligado com ela fechada
#define RELE_TEMPO_MAX_S 0        // 0 = sem limite. Trava SOLENOIDE comum nao pode ficar
                                  // ligada muito tempo: ponha 5 (liga 5 s e desliga)

#define FILTRO_SENSOR_MS 5        // o sinal precisa ficar assim este tempo (5 ms: ruido da fita/rele nao vira bola)
#define REARME_SENSOR_MS 120      // a mesma bola balancando no sensor nao conta 2 vezes
#define FILTRO_BOTAO_MS 50        // START/CONFIGURACAO: apertado de verdade (50 ms), ruido no fio nao conta
#define REARME_BOTAO_MS 700       // um aperto por vez (o START nao "aperta sozinho" em rajada)
// FICHA (A2): so conta o PULSO CERTO do moedeiro. O moedeiro manda 20-150 ms
// (o normal e 30-100 ms) e volta ao repouso; as fichas somam (5 pulsos = 5).
// Nao vira ficha: tranco no fio (menos de 15 ms), fio preso no GND ou
// encostado e segurado (mais de 250 ms), nem o moedeiro ligando depois do
// Arduino. NA ou NF tanto faz: o repouso e o nivel que fica parado 2 s.
#define FICHA_FILTRO_MS 5         // ruido menor que isto nem conta como mudanca
#define FICHA_PULSO_MIN_MS 15     // pulso mais curto que isto: tranco, nao e ficha
#define FICHA_PULSO_MAX_MS 250    // pulso mais longo que isto: fio preso/segurado, nao e ficha
#define FICHA_REPOUSO_MS 2000UL   // nivel parado este tempo vira o novo repouso
#define SEM_JOGO_FECHA_MS 30000UL // o jogo falou e sumiu este tempo: fecha a porta
#define VERSAO "13"

#if USAR_LEDS
#include <Adafruit_NeoPixel.h>
Adafruit_NeoPixel fita(NUM_LEDS, LED_PINO, NEO_GRB + NEO_KHZ800);
#endif

#if defined(__AVR_ATmega2560__) || defined(__AVR_ATmega1280__)
#define SERVO_PINO 11             // OC1A no Mega
#define PONTE_EN 9                // PWM do Timer2 no Mega
#else
#define SERVO_PINO 9              // OC1A no Uno/Nano/Pro Mini/Leonardo
#define PONTE_EN 11               // PWM do Timer2 (Uno/Nano) ou Timer0 (Leonardo)
#endif
#define PASSOS_POR_US (F_CPU / 8000000UL)  // Timer1 com prescaler 8

// ------------------------------------------------------------ tipos
// TODOS os tipos ficam aqui no comeco, antes da primeira funcao: a IDE do
// Arduino escreve sozinha a "declaracao" de cada funcao logo antes da
// primeira funcao do arquivo; um tipo declarado mais abaixo ainda nao
// existiria ali (era o erro "'Efeito' was not declared in this scope").
enum Efeito { MENU, IDLE, STRIKE, MISS, SPARE, NORMAL, BLUE, RED, OFF };

// ------------------------------------------------------------ entradas
struct Entrada {
  uint8_t pino;
  uint8_t repouso;      // nivel lido sem nada acionando (HIGH com pull-up)
  bool leitura;         // acionado agora (sem filtro)
  bool estavel;         // acionado (filtrado)
  unsigned long mudouEm;
  unsigned long ultimoEvento;
  uint8_t filtro;
  uint16_t rearme;
  const char *evento;
};

Entrada sensores[5];
Entrada botoes[2];   // CONFIGURACAO (A0) e START (A1); a FICHA (A2) tem o seu proprio (pulso)
uint8_t fichaRepouso = HIGH, fichaLeitura = HIGH, fichaEstavel = HIGH;
unsigned long fichaMudouEm = 0, fichaEstavelDesde = 0;
const char *const NOMES_SENSOR[5] = {"S:1", "S:2", "S:3", "S:4", "S:5"};

bool streamSensores = false;   // TESTE:1 -> manda SENS: a cada mudanca
unsigned long ultimoComando = 0;
unsigned long piscarAte = 0;

// ------------------------------------------------------------ porta
bool portaAberta = false;
int16_t servoAtual10 = SERVO_FECHADA * 10;  // decimos de grau
int16_t servoAlvo10 = SERVO_FECHADA * 10;
unsigned long servoPasso = 0;
unsigned long servoChegou = 0;
bool servoSegurando = true;
bool releLigado = false;        // a bobina do rele agora
unsigned long releMudouEm = 0;  // ligou / desligou
// rele de PULSO: a porta troca de posicao a cada pulso
bool releAberta = false;        // onde a porta ficou depois do ultimo pulso (guardado na EEPROM)
bool relePedida = false;        // onde o jogo quer a porta
unsigned long relePedidoEm = 0; // quando o pedido mudou
bool releDescansando = false;   // acabou de pulsar: espera RELE_DESCANSO_MS
uint16_t releTrocas = 0;        // contador de pulsos (par = fechada, impar = aberta)
// (12) A PORTA NA MEMORIA COMUM (RAM, fora da limpeza do comeco): ela
// sobrevive a um reinicio SEM faltar energia (botao reset, alguem abrindo a
// serial) e se apaga quando a energia cai - assim o Arduino sabe se a
// maquina ficou sem energia (e a trava fechou) ou se so reiniciou.
#define RAM_MARCA 0x5A3CC3A5UL
uint32_t ramMarca __attribute__((section(".noinit")));
uint8_t ramPorta __attribute__((section(".noinit")));
uint8_t ramPortaNeg __attribute__((section(".noinit")));
// o vigia do jogo so vale depois de o jogo falar (ligar o Arduino nao mexe na porta)
bool jogoFalou = false;
// MODO:LIVRE (o jogo diz): a porta fica sempre aberta - o vigia nunca fecha
bool modoLivre = false;

// ponte H: o motor anda ate a porta chegar e so entao confirma ao jogo
bool ponteAlvoAberta = false;   // para onde a porta vai
int8_t ponteMov = 0;            // 1 = abrindo, -1 = fechando, 0 = parado
bool ponteNoAlvo = false;       // chegou (e ja confirmou)
uint8_t ponteFalhas = 0;        // com fim de curso: vezes seguidas que nao chegou
unsigned long ponteDesde = 0;   // comecou a andar / parou
unsigned long ponteFreioAte = 0;
int16_t pontePos = 1000;        // sem fim de curso: 0 = fechada ... 1000 = aberta, contado
int16_t ponteInicioPos = 1000;  // pelo tempo (ao ligar nao se sabe: conta aberta e fecha tudo)
// o que o MENU DO OPERADOR escolheu (guardado na EEPROM; de fabrica: os PONTE_*)
unsigned long ponteTempoAbre = PONTE_TEMPO_ABRE_MS;
unsigned long ponteTempoFecha = PONTE_TEMPO_FECHA_MS;
bool ponteFC = PONTE_FIM_DE_CURSO;

// ------------------------------------------------------------ serial
char buf[24];
uint8_t bufLen = 0;
unsigned long ultimoByte = 0;   // linha pela metade ha muito tempo: lixo, descarta
#define LINHA_MAX_MS 60UL

void enviarSensores();
bool comandoDoJogo(const char *c);

// ============================================================ EEPROM
// endereco 0: 0x5B (marca)  1: niveis de repouso dos sensores (bit 1 = HIGH)
// endereco 2: 0x5C (marca da porta)  3-4: tempo do motor (ms)  5: fim de curso
#define EE_MARCA 0
#define EE_REPOUSO 1
#define EE_PONTE_MARCA 2
#define EE_PONTE_TEMPO 3
#define EE_PONTE_FC 5
#define EE_PORTA_ANTIGA 6  // firmware 4: 0xA1 = porta aberta (lido uma vez e passado para o contador)

// CONTADORES CIRCULARES na EEPROM (fichas recebidas, fichas confirmadas e
// trocas da porta). Cada passo grava UM byte, e cada contador se espalha por
// 32 enderecos: a EEPROM aguenta 100 mil gravacoes por endereco, assim sao
// mais de 3 milhoes de fichas (ou de pulsos da porta).
// O byte guarda a volta (modulo 256); a posicao dele guarda o resto.
const uint8_t CONT_SLOTS = 32;
const uint16_t CONT_MOD = 256U * CONT_SLOTS;
const uint8_t EE_RECEBIDAS = 16, EE_CONFIRMADAS = 48, EE_PORTA = 80;
uint16_t recebidas = 0, confirmadas = 0;
bool protocoloFicha = false;    // jogo novo: FICHA:<n> ate o jogo confirmar (FICHA:OK:<n>)
bool jogoAntigo = false;        // jogo antigo (so INFO?): FICHA simples
unsigned long fichaAvisadaEm = 0;
bool fichaAvisada = false;

uint16_t lerContador(uint8_t base) {
  uint8_t volta = EEPROM.read(base);
  for (uint8_t i = 1; i < CONT_SLOTS; ++i) {
    if (EEPROM.read(base + i) != volta) return ((uint16_t)volta * CONT_SLOTS + i) % CONT_MOD;
  }
  return (uint16_t)(uint8_t)(volta + 1) * CONT_SLOTS;
}

void avancarContador(uint8_t base, uint16_t &n) {
  EEPROM.update(base + n % CONT_SLOTS, n / CONT_SLOTS);
  n = (n + 1) % CONT_MOD;
}

// (12) a posicao da porta guardada na RAM (com a marca e o complemento)
void lembrarPortaRam(bool aberta) {
  ramPorta = aberta ? 1 : 0;
  ramPortaNeg = (uint8_t)~ramPorta;
  ramMarca = RAM_MARCA;
}

// a RAM ainda tem a porta? (so se a energia nao caiu desde a ultima vez)
bool portaRamValida() {
  return ramMarca == RAM_MARCA && ramPorta <= 1 && (uint8_t)~ramPorta == ramPortaNeg;
}

// fichas na fila (recebidas do moedeiro e ainda nao confirmadas pelo jogo)
uint16_t fichasNaFila() {
  return (recebidas + CONT_MOD - confirmadas) % CONT_MOD;
}

void registrarFicha() {
  if ((recebidas + 1) % CONT_MOD == confirmadas) {
    Serial.println(F("AVISO:FILA_FICHAS_CHEIA"));
    return;
  }
  // (10) a fila fica SO na memoria comum: comeca vazia toda vez que o
  // Arduino liga - nenhuma "ficha" antiga (tranco no fio guardado na
  // EEPROM por firmwares anteriores) aparece como credito na apresentacao
  recebidas = (recebidas + 1) % CONT_MOD;
}

// Uma ficha por vez para o jogo. Sem o jogo dizer quem e (FICHAS:SYNC ou
// INFO?), a ficha espera na fila - e chega assim que ele conectar.
void enviarFicha(unsigned long agora) {
  if (confirmadas == recebidas) return;
  if (protocoloFicha) {
    if (fichaAvisada && agora - fichaAvisadaEm < 500) return;
    Serial.print(F("FICHA:"));
    Serial.println((int)confirmadas);
    fichaAvisada = true;
    fichaAvisadaEm = agora;
  } else if (jogoAntigo) {
    Serial.println(F("FICHA"));
    confirmadas = (confirmadas + 1) % CONT_MOD;
  }
}

void carregarRepouso() {
  uint8_t mascara = 0x1F;  // padrao: todos em HIGH (pull-up, aciona em LOW)
  if (EEPROM.read(EE_MARCA) == 0x5B) mascara = EEPROM.read(EE_REPOUSO);
  for (uint8_t i = 0; i < 5; i++) sensores[i].repouso = (mascara >> i) & 1 ? HIGH : LOW;
}

void calibrar() {
  // le cada sensor varias vezes: o nivel de agora (pista vazia) e o repouso
  uint8_t mascara = 0;
  for (uint8_t i = 0; i < 5; i++) {
    uint8_t altos = 0;
    for (uint8_t k = 0; k < 15; k++) {
      if (digitalRead(sensores[i].pino) == HIGH) altos++;
      delay(2);
    }
    if (altos >= 8) mascara |= (1 << i);
  }
  EEPROM.update(EE_MARCA, 0x5B);
  EEPROM.update(EE_REPOUSO, mascara);
  carregarRepouso();
  for (uint8_t i = 0; i < 5; i++) {
    sensores[i].leitura = false;
    sensores[i].estavel = false;
  }
  Serial.print(F("CAL:OK:"));
  for (uint8_t i = 0; i < 5; i++) Serial.print(sensores[i].repouso == HIGH ? 'H' : 'L');
  Serial.println();
  enviarSensores();
}

// ============================================================ porta
uint16_t pulsoUs(int16_t graus10) {
  // como a biblioteca Servo: 544 us = 0 grau, 2400 us = 180 graus
  return 544 + (int32_t)graus10 * (2400 - 544) / 1800;
}

#if USAR_SERVO
void servoIniciar() {
  digitalWrite(SERVO_PINO, LOW);
  pinMode(SERVO_PINO, OUTPUT);
  // Timer1 no modo 14 (PWM rapido, topo = ICR1), prescaler 8: o pulso sai
  // do proprio Timer1, firme mesmo quando a fita de LED segura o processador.
  TCCR1A = _BV(COM1A1) | _BV(WGM11);
  TCCR1B = _BV(WGM13) | _BV(WGM12) | _BV(CS11);
  ICR1 = 20000UL * PASSOS_POR_US - 1;  // 20 ms
  OCR1A = pulsoUs(servoAtual10) * PASSOS_POR_US;
  servoSegurando = true;
}

void servoSegurar(bool sim) {
  if (sim == servoSegurando) return;
  servoSegurando = sim;
  if (sim) {
    TCCR1A |= _BV(COM1A1);
  } else {
    TCCR1A &= ~_BV(COM1A1);
    digitalWrite(SERVO_PINO, LOW);
  }
}

void tickServo(unsigned long agora) {
  if (servoAtual10 != servoAlvo10) {
    if (agora - servoPasso >= 10) {
      int16_t passo = (int16_t)((uint32_t)SERVO_GRAUS_POR_S * 10UL * (agora - servoPasso) / 1000UL);
      if (passo < 1) passo = 1;
      servoPasso = agora;
      if (servoAtual10 < servoAlvo10) {
        servoAtual10 = min((int16_t)(servoAtual10 + passo), servoAlvo10);
      } else {
        servoAtual10 = max((int16_t)(servoAtual10 - passo), servoAlvo10);
      }
      servoSegurar(true);
      OCR1A = pulsoUs(servoAtual10) * PASSOS_POR_US;
      if (servoAtual10 == servoAlvo10) servoChegou = agora;
    }
  } else if (SERVO_SOLTA_PARADO && servoSegurando && agora - servoChegou > 1000) {
    servoSegurar(false);
  }
}
#endif

void releEscrever(bool ligado) {
  releLigado = ligado;
  bool nivel = ligado ? !RELE_LIGA_EM_LOW : RELE_LIGA_EM_LOW;
  digitalWrite(RELE_PINO, nivel ? HIGH : LOW);
}

void confirmarPorta() {
  Serial.println(portaAberta ? F("PORTA:ABERTA") : F("PORTA:FECHADA"));
}

#if RELE_PULSO
// RELE DE PULSO: um pulso troca a porta de posicao. Daqui sai UM pulso por
// mudanca pedida - nunca dois seguidos, nunca sem pedido:
//   1. pulso em curso: so termina (RELE_PULSO_MS) e comeca o descanso;
//   2. descanso (RELE_DESCANSO_MS): nada acontece - a porta esta andando;
//   3. a porta ja esta onde o jogo pediu: nada;
//   4. pedido novo: espera ficar firme (RELE_FIRME_MS) e da o pulso.
void tickRele(unsigned long agora) {
  if (releLigado) {
    if (agora - releMudouEm >= RELE_PULSO_MS) {
      releEscrever(false);
      releMudouEm = agora;
      releDescansando = true;
    }
    return;
  }
  if (releDescansando) {
    if (agora - releMudouEm < RELE_DESCANSO_MS) return;
    releDescansando = false;
  }
  if (relePedida == releAberta) return;
  if (agora - relePedidoEm < RELE_FIRME_MS) return;
  releEscrever(true);
  releMudouEm = agora;
  releAberta = relePedida;
  avancarContador(EE_PORTA, releTrocas);   // a posicao nova fica guardada (vale depois de reiniciar)
  lembrarPortaRam(releAberta);
#if !USAR_PONTE_H
  confirmarPorta();
#endif
}

// A porta de verdade esta ao contrario do que o Arduino lembra (alguem
// mexeu nela com a mao, a primeira gravacao foi com ela aberta): troca so
// a lembranca, SEM pulso. Se o jogo quer a outra posicao, ai sim o tickRele
// da o pulso que acerta tudo.
void releAcertar() {
  releAberta = !releAberta;
  avancarContador(EE_PORTA, releTrocas);
  lembrarPortaRam(releAberta);
  relePedidoEm = millis();
}
#else
// RELE DE NIVEL: ligado = porta aberta (RELE_LIGADO_ABERTA)
void tickRele(unsigned long agora) {
  if (RELE_TEMPO_MAX_S > 0 && releLigado && agora - releMudouEm > (unsigned long)RELE_TEMPO_MAX_S * 1000UL) {
    releEscrever(false);  // protege a solenoide; a porta continua "aberta" para o jogo
  }
}
#endif

// ------------------------------------------------------------ ponte H
#if USAR_PONTE_H
// sentido: 1 = abre, -1 = fecha, 0 = solta o motor, 2 = freia
void ponteEscrever(int8_t sentido) {
  bool in1 = sentido == 2, in2 = sentido == 2;
  uint8_t vel = sentido == 2 ? 255 : 0;
  if (sentido == 1 || sentido == -1) {
    in1 = (sentido == 1) != (PONTE_INVERTIDA != 0);
    in2 = !in1;
    vel = sentido == 1 ? PONTE_VELOCIDADE_ABRE : PONTE_VELOCIDADE_FECHA;
  }
  digitalWrite(PONTE_IN1, in1 ? HIGH : LOW);
  digitalWrite(PONTE_IN2, in2 ? HIGH : LOW);
  analogWrite(PONTE_EN, vel);  // 0 = LOW, 255 = HIGH
}

bool fcAcionado(uint8_t pino) {
  bool baixo = digitalRead(pino) == LOW;
  return FC_NF ? !baixo : baixo;
}

// le 3 vezes: um ruido do motor no fio nao para a porta no meio
bool fimDeCurso(bool aberta) {
  uint8_t pino = aberta ? FC_ABERTA_PINO : FC_FECHADA_PINO;
  for (uint8_t k = 0; k < 3; k++) {
    if (!fcAcionado(pino)) return false;
    delayMicroseconds(100);
  }
  return true;
}

bool ponteChegou(bool aberta) {
  if (ponteFC) return fimDeCurso(aberta);
  return pontePos == (aberta ? 1000 : 0);
}

// com fim de curso: o tempo maximo para chegar (o do menu, folgado, ou 6 s)
unsigned long ponteLimite(bool abrindo) {
  unsigned long t = 2UL * (abrindo ? ponteTempoAbre : ponteTempoFecha);
  return t > PONTE_TEMPO_MAX_MS ? t : PONTE_TEMPO_MAX_MS;
}

void ponteParar(unsigned long agora) {
  ponteMov = 0;
  ponteDesde = agora;
  ponteEscrever(PONTE_FREIO_MS > 0 ? 2 : 0);
  ponteFreioAte = PONTE_FREIO_MS > 0 ? agora + PONTE_FREIO_MS : 0;
}

void ponteConfirmar() {
  ponteNoAlvo = true;
  ponteFalhas = 0;
  confirmarPorta();
}

// o tempo e o fim de curso que o MENU DO OPERADOR escolheu (guardados na EEPROM)
void carregarPonte() {
  if (EEPROM.read(EE_PONTE_MARCA) != 0x5C) return;   // nunca escolhido: os de fabrica
  unsigned long t = EEPROM.read(EE_PONTE_TEMPO) | ((unsigned long)EEPROM.read(EE_PONTE_TEMPO + 1) << 8);
  if (t >= PONTE_TEMPO_MIN_MS && t <= PONTE_TEMPO_LIM_MS) ponteTempoAbre = ponteTempoFecha = t;
  ponteFC = EEPROM.read(EE_PONTE_FC) == 1;
}

void guardarPonte() {
  EEPROM.update(EE_PONTE_MARCA, 0x5C);
  EEPROM.update(EE_PONTE_TEMPO, ponteTempoAbre & 0xFF);
  EEPROM.update(EE_PONTE_TEMPO + 1, (ponteTempoAbre >> 8) & 0xFF);
  EEPROM.update(EE_PONTE_FC, ponteFC ? 1 : 0);
}

void enviarPonte() {
  Serial.print(F("PONTE:TEMPO:"));
  Serial.print((int)ponteTempoAbre);
  Serial.print(F(":FC:"));
  Serial.println(ponteFC ? 1 : 0);
}

// mudou o ajuste: guarda; com o motor andando, para e recomeca no modo novo
void ponteMudou() {
  guardarPonte();
  ponteFalhas = 0;
  if (ponteMov != 0) ponteParar(millis());
}

// PONTE:TEMPO:1500 (ms) e PONTE:FC:0/1, do menu do operador. Devolve false
// se a linha nao e um desses escrito certinho (o eco da resposta
// PONTE:TEMPO:1500:FC:0, ruido): ai nada muda e nada responde.
bool ponteComando(const char *c) {
  if (!strncmp(c, "PONTE:TEMPO:", 12)) {
    char *fim;
    long t = strtol(c + 12, &fim, 10);
    if (fim == c + 12 || *fim) return false;   // so o numero, nada depois
    if (t >= (long)PONTE_TEMPO_MIN_MS && t <= (long)PONTE_TEMPO_LIM_MS && (unsigned long)t != ponteTempoAbre) {
      ponteTempoAbre = ponteTempoFecha = (unsigned long)t;
      ponteMudou();
    }
  } else if (!strncmp(c, "PONTE:FC:", 9)) {
    if ((c[9] != '0' && c[9] != '1') || c[10]) return false;
    bool fc = c[9] == '1';
    if (fc != ponteFC) {
      ponteFC = fc;
      // sem fim de curso: a porta parada no lugar conta como no fim dele; se
      // nao tinha chegado, conta do outro lado (anda o tempo todo)
      if (!fc) pontePos = (ponteNoAlvo == ponteAlvoAberta) ? 1000 : 0;
      ponteNoAlvo = false;   // confere de novo no modo novo (e confirma ao jogo)
      ponteMudou();
    }
  }
  enviarPonte();
  return true;
}

// o jogo pediu: a porta vai para la (o tickPonte anda com o motor)
void ponteIr(bool abrir) {
  if (abrir == ponteAlvoAberta) {
    if (ponteNoAlvo) {
      confirmarPorta();   // ja esta la
      return;
    }
    if (ponteMov != 0) return;   // ja esta indo
  }
  ponteAlvoAberta = abrir;
  ponteNoAlvo = false;
  ponteFalhas = 0;   // pedido novo: tenta de novo mesmo se tinha travado
}

void tickPonte(unsigned long agora) {
  if (ponteFreioAte && (long)(agora - ponteFreioAte) >= 0) {
    ponteFreioAte = 0;
    ponteEscrever(0);   // acabou o freio: solta o motor
  }
  if (ponteMov != 0) {
    bool abrindo = ponteMov > 0;
    unsigned long passou = agora - ponteDesde;
    if (!ponteFC) {
      long andou = (long)(passou * 1000UL / (abrindo ? ponteTempoAbre : ponteTempoFecha));
      pontePos = (int16_t)constrain(ponteInicioPos + (abrindo ? andou : -andou), 0L, 1000L);
    }
    if (abrindo != ponteAlvoAberta) {
      ponteParar(agora);   // o jogo mudou de ideia: para, espera e volta
    } else if (ponteChegou(abrindo)) {
      ponteParar(agora);
      ponteConfirmar();
    } else if (ponteFC && passou >= ponteLimite(abrindo)) {
      ponteParar(agora);   // o micro-switch nao chegou: algo segurando a porta?
      ponteFalhas++;
      Serial.println(F("AVISO:PORTA_TRAVOU"));
    }
    return;
  }
  if (ponteNoAlvo || ponteFalhas >= PONTE_TENTATIVAS) return;
  if (agora - ponteDesde < (ponteFalhas ? PONTE_ESPERA_TRAVOU_MS : PONTE_PAUSA_MS)) return;
  if (ponteChegou(ponteAlvoAberta)) {   // ja esta la (fim de curso acionado)
    ponteConfirmar();
    return;
  }
  ponteMov = ponteAlvoAberta ? 1 : -1;
  ponteDesde = agora;
  ponteInicioPos = pontePos;
  ponteFreioAte = 0;
  ponteEscrever(ponteMov);
}
#endif

// O jogo pediu a porta aberta ou fechada. Pedido repetido nao mexe em nada:
// so confirma de novo.
void porta(bool abrir) {
  portaAberta = abrir;
#if USAR_SERVO
  servoAlvo10 = (abrir ? SERVO_ABERTA : SERVO_FECHADA) * 10;
  servoPasso = millis();
#endif
#if USAR_RELE
#if RELE_PULSO
  if (abrir != relePedida) {
    relePedida = abrir;
    relePedidoEm = millis();
  }
#else
  bool ligar = RELE_LIGADO_ABERTA ? abrir : !abrir;
  if (ligar && !releLigado) releMudouEm = millis();
  releEscrever(ligar);
#endif
#endif
#if USAR_PONTE_H
  ponteIr(abrir);    // confirma (PORTA:ABERTA/FECHADA) quando a porta chegar
#elif USAR_RELE && RELE_PULSO
  if (abrir == releAberta) confirmarPorta();   // ja esta la: confirma sem pulso (senao, o pulso confirma)
#else
  confirmarPorta();
#endif
}

// a porta como ela esta (rele de pulso: onde o ultimo pulso a deixou)
bool portaDeVerdade() {
#if USAR_RELE && RELE_PULSO && !USAR_PONTE_H
  return releAberta;
#else
  return portaAberta;
#endif
}

// (13) PORTA:LIGOU - a trava esta FECHADA agora (a maquina acabou de ligar):
// o Arduino passa a saber disso SEM pulso. Daqui em diante so o pedido do
// jogo (credito / modo livre) mexe nela.
void portaLigou() {
#if USAR_RELE && RELE_PULSO && !USAR_PONTE_H
  if (!releLigado && !releDescansando) {
    if (releAberta) {
      releAberta = false;
      avancarContador(EE_PORTA, releTrocas);
    }
    lembrarPortaRam(false);
    relePedida = false;
    relePedidoEm = millis();
    portaAberta = false;
  }
#endif
  Serial.println(portaDeVerdade() ? F("PORTA:ABERTA") : F("PORTA:FECHADA"));
}

// ============================================================ entradas
void iniciarEntrada(Entrada &e, uint8_t pino, uint8_t filtro, uint16_t rearme, const char *evento) {
  e.pino = pino;
  e.repouso = HIGH;
  e.leitura = false;
  e.estavel = false;
  e.mudouEm = 0;
  e.ultimoEvento = 0;
  e.filtro = filtro;
  e.rearme = rearme;
  e.evento = evento;
  pinMode(pino, INPUT_PULLUP);
}

// o que ja esta acionado ao ligar (moedeiro NF, botao preso, bola parada no
// sensor) nao conta: so conta quando soltar e acionar de novo. (O Uno e o
// Nano reiniciam cada vez que o jogo abre o USB: antes, um moedeiro NF dava
// uma ficha de graca a cada vez.)
void assentarEntrada(Entrada &e) {
  e.leitura = digitalRead(e.pino) != e.repouso;
  e.estavel = e.leitura;
  e.mudouEm = millis();
}

// devolve true quando o estado filtrado mudou
bool tickEntrada(Entrada &e, unsigned long agora, bool &disparou) {
  disparou = false;
  bool ativo = digitalRead(e.pino) != e.repouso;
  if (ativo != e.leitura) {
    e.leitura = ativo;
    e.mudouEm = agora;
  }
  if (e.leitura != e.estavel && agora - e.mudouEm >= e.filtro) {
    e.estavel = e.leitura;
    if (e.estavel && (e.ultimoEvento == 0 || agora - e.ultimoEvento >= e.rearme)) {
      e.ultimoEvento = agora;
      disparou = true;
    }
    return true;
  }
  return false;
}

void enviarSensores() {
  Serial.print(F("SENS:"));
  for (uint8_t i = 0; i < 5; i++) Serial.print(sensores[i].estavel ? '1' : '0');
  Serial.println();
}

void piscar(unsigned long agora) {
  digitalWrite(LED_PLACA, HIGH);
  piscarAte = agora + 60;
}

// FICHA (A2): conta quando o nivel SAI do repouso e VOLTA dentro do tempo
// de um pulso de moedeiro (15-250 ms). Preso fora do repouso por 2 s: e o
// novo repouso (moedeiro NF, moedeiro ligado depois, fio preso) e nada conta.
void tickFicha(unsigned long agora) {
  uint8_t l = digitalRead(FICHA_PINO);
  if (l != fichaLeitura) {
    fichaLeitura = l;
    fichaMudouEm = agora;
  }
  if (fichaLeitura != fichaEstavel && agora - fichaMudouEm >= FICHA_FILTRO_MS) {
    unsigned long dur = fichaMudouEm - fichaEstavelDesde;   // quanto o nivel anterior durou
    uint8_t anterior = fichaEstavel;
    fichaEstavel = fichaLeitura;
    fichaEstavelDesde = fichaMudouEm;
    if (anterior != fichaRepouso && fichaEstavel == fichaRepouso &&
        dur >= FICHA_PULSO_MIN_MS && dur <= FICHA_PULSO_MAX_MS) {
      registrarFicha();   // a ficha vai para a fila; o enviarFicha avisa o jogo
      piscar(agora);
    }
  }
  if (fichaEstavel != fichaRepouso && agora - fichaEstavelDesde >= FICHA_REPOUSO_MS) fichaRepouso = fichaEstavel;
}

// ============================================================ LEDs
#if USAR_LEDS
Efeito efeito = MENU;
unsigned long ledUltimo = 0;
uint16_t menuOffset = 0;
int ondaPos = 0, ondaDir = 1, ondaVolta = 0, ondaMax = 0, ondaMs = 38, ondaRastro = 8;
uint8_t cR = 0, cG = 60, cB = 220, rR = 0, rG = 0, rB = 140;
unsigned long strikeSegura = 0;

void setTodos(uint32_t cor) {
  for (int i = 0; i < NUM_LEDS; i++) fita.setPixelColor(i, cor);
  fita.show();
}

void setOnda(Efeito e, int maxV, int ms, int rastro, uint8_t cr, uint8_t cg, uint8_t cb, uint8_t rr, uint8_t rg, uint8_t rb) {
  efeito = e;
  strikeSegura = 0;
  ondaPos = 0; ondaDir = 1; ondaVolta = 0;
  ondaMax = maxV; ondaMs = ms; ondaRastro = rastro;
  cR = cr; cG = cg; cB = cb; rR = rr; rG = rg; rB = rb;
  ledUltimo = 0;
}

// devolve false se nao era um comando da fita (o executar ignora a linha)
bool ledComando(const char *c) {
  if (!strcmp(c, "MENU")) { efeito = MENU; menuOffset = 0; ledUltimo = 0; }
  else if (!strcmp(c, "BLUE")) { efeito = BLUE; setTodos(fita.Color(0, 40, 255)); }
  else if (!strcmp(c, "RED")) { efeito = RED; setTodos(fita.Color(255, 0, 0)); }
  else if (!strcmp(c, "IDLE")) setOnda(IDLE, 0, 42, 8, 0, 45, 180, 0, 0, 100);
  else if (!strcmp(c, "MISS")) setOnda(MISS, 5, 15, 14, 255, 0, 0, 170, 0, 0);
  else if (!strcmp(c, "SPARE")) setOnda(SPARE, 5, 24, 11, 255, 170, 0, 180, 95, 0);
  else if (!strcmp(c, "NORMAL")) setOnda(NORMAL, 3, 22, 10, 0, 180, 255, 0, 90, 190);
  else if (!strcmp(c, "STRIKE")) setOnda(STRIKE, 8, 6, 22, 0, 80, 255, 0, 0, 255);
  else if (!strcmp(c, "OFF")) { efeito = OFF; setTodos(0); }
  else return false;
  return true;
}

void tickLeds(unsigned long agora) {
  if (strikeSegura && (long)(agora - strikeSegura) >= 0) {
    strikeSegura = 0;
    ledComando("IDLE");
  }
  if (efeito == MENU) {
    if (agora - ledUltimo < 20) return;
    ledUltimo = agora;
    // arco-iris andando (contas inteiras: rapido, nao atrasa os sensores)
    for (int i = 0; i < NUM_LEDS; i++) {
      uint16_t h = menuOffset + (uint16_t)((uint32_t)i * 65536UL / NUM_LEDS);
      fita.setPixelColor(i, fita.gamma32(fita.ColorHSV(h, 255, 255)));
    }
    fita.show();
    menuOffset += 420;
    return;
  }
  if (efeito == OFF || efeito == BLUE || efeito == RED) return;
  if (agora - ledUltimo < (unsigned long)ondaMs) return;
  ledUltimo = agora;
  fita.clear();
  for (int r = 0; r < ondaRastro; r++) {
    int pos = ondaPos - r * ondaDir;
    if (pos < 0 || pos >= NUM_LEDS) continue;
    if (r == 0) {
      fita.setPixelColor(pos, fita.Color(cR, cG, cB));
    } else {
      uint16_t t = 256 - (uint16_t)r * 256 / ondaRastro;
      fita.setPixelColor(pos, fita.Color((uint16_t)rR * t >> 8, (uint16_t)rG * t >> 8, (uint16_t)rB * t >> 8));
    }
  }
  fita.show();
  if (efeito == STRIKE) {
    ondaPos += ondaDir;
    if (ondaPos >= NUM_LEDS - 1) { ondaPos = NUM_LEDS - 1; ondaDir = -1; ondaVolta++; }
    else if (ondaPos <= 0) { ondaPos = 0; ondaDir = 1; ondaVolta++; }
  } else {
    ondaPos++;
    if (ondaPos >= NUM_LEDS + ondaRastro) { ondaPos = 0; ondaVolta++; }
  }
  if (ondaMax > 0 && ondaVolta >= ondaMax) {
    if (efeito == STRIKE) {
      setTodos(fita.Color(0, 50, 255));
      efeito = BLUE;
      strikeSegura = agora + 750;
      return;
    }
    ledComando("IDLE");
  }
}
#endif

// ============================================================ comandos
// SO O JOGO MANDA: uma linha so vale se for um comando do jogo, escrito
// certinho. Qualquer outra coisa que chegue pela serial (a TV Box ligando e
// testando a porta - comandos "AT" de modem, por exemplo -, ruido no cabo,
// eco) e ignorada INTEIRA: nao mexe na porta, nao liga o vigia do jogo e nao
// conta como o jogo falando. (No firmware 5 qualquer linha contava: a TV
// Box ligando "falava", o vigia achava que o jogo tinha sumido e dava um
// pulso no rele.)
void executar(const char *c) {
  if (!comandoDoJogo(c)) return;
  ultimoComando = millis();
  jogoFalou = true;
}

bool comandoDoJogo(const char *c) {
  if (!strcmp(c, "PING")) {
    Serial.println(F("PONG:STRIKE_KIDS:" VERSAO));
  } else if (!strcmp(c, "PORTA:ABRE")) {
    porta(true);
  } else if (!strcmp(c, "PORTA:FECHA")) {
    porta(false);
  } else if (!strcmp(c, "PORTA?")) {
    Serial.println(portaDeVerdade() ? F("PORTA:ABERTA") : F("PORTA:FECHADA"));
  } else if (!strcmp(c, "PORTA:LIGOU")) {
    // (13) O JOGO ACABOU DE LIGAR JUNTO COM A MAQUINA: a maquina ficou sem
    // energia e a trava FECHOU sozinha - ela esta fechada AGORA, nao importa
    // o que o Arduino lembrava (a memoria dele pode ter aguentado uns
    // instantes sem energia). So a lembranca muda: NENHUM pulso.
    portaLigou();
#if USAR_RELE && RELE_PULSO
  } else if (!strcmp(c, "PORTA:ACERTA")) {
    releAcertar();
    Serial.println(portaDeVerdade() ? F("PORTA:ABERTA") : F("PORTA:FECHADA"));
#endif
  } else if (!strcmp(c, "MODO:LIVRE")) {
    modoLivre = true;
  } else if (!strcmp(c, "MODO:FICHAS")) {
    modoLivre = false;
  } else if (!strcmp(c, "FICHAS:SYNC")) {
    protocoloFicha = true;    // jogo novo: confirma cada ficha
    jogoAntigo = false;
    fichaAvisada = false;     // avisa de novo a que estava esperando
  } else if (!strncmp(c, "FICHA:OK:", 9)) {
    char *fim;
    long id = strtol(c + 9, &fim, 10);
    if (protocoloFicha && fichaAvisada && fim != c + 9 && *fim == 0 && confirmadas != recebidas && id == (long)confirmadas) {
      confirmadas = (confirmadas + 1) % CONT_MOD;
      fichaAvisada = false;   // a proxima da fila sai ja no proximo loop
    }
  } else if (!strcmp(c, "SENS?")) {
    enviarSensores();
  } else if (!strcmp(c, "TESTE:1")) {
    streamSensores = true;
    enviarSensores();
  } else if (!strcmp(c, "TESTE:0")) {
    streamSensores = false;
  } else if (!strcmp(c, "CALIBRA")) {
    calibrar();
#if USAR_PONTE_H
  } else if (!strncmp(c, "PONTE:", 6) && strcmp(c, "PONTE?")) {
    return ponteComando(c);
  } else if (!strcmp(c, "PONTE?")) {
    enviarPonte();
#endif
  } else if (!strcmp(c, "INFO?")) {
    if (!protocoloFicha) jogoAntigo = true;   // jogo antigo: nunca manda FICHAS:SYNC
    Serial.print(F("INFO:STRIKE_KIDS:" VERSAO ":LEDS="));
    Serial.print(USAR_LEDS);
    Serial.print(F(":SERVO="));
    Serial.print(USAR_SERVO ? SERVO_PINO : 0);
    Serial.print(F(":RELE="));
    Serial.print(USAR_RELE ? RELE_PINO : 0);
    Serial.print(F(":PONTE_H="));
#if USAR_PONTE_H
    Serial.print(ponteFC ? F("FIM_DE_CURSO") : F("TEMPO"));
    Serial.print(F(":TEMPO="));
    Serial.print((int)ponteTempoAbre);
#else
    Serial.print('0');
#endif
    Serial.print(F(":REPOUSO="));
    for (uint8_t i = 0; i < 5; i++) Serial.print(sensores[i].repouso == HIGH ? 'H' : 'L');
    Serial.print(F(":PULSO="));
    Serial.print((USAR_RELE && RELE_PULSO) ? 1 : 0);
    Serial.print(F(":FILA="));
    Serial.print((int)fichasNaFila());
    Serial.println();
  } else {
#if USAR_LEDS
    return ledComando(c);
#else
    return false;
#endif
  }
  return true;
}

void lerSerial() {
  // linha pela metade ha muito tempo (ruido, cabo encaixando): joga fora,
  // para nao grudar no comeco do proximo comando
  if (bufLen && millis() - ultimoByte > LINHA_MAX_MS) bufLen = 0;
  uint8_t n = 0;
  while (Serial.available() && n++ < 32) {
    char c = Serial.read();
    ultimoByte = millis();
    if (c == '\n' || c == '\r') {
      if (bufLen) {
        buf[bufLen] = '\0';
        bufLen = 0;
        executar(buf);
      }
      continue;
    }
    if (c >= 'a' && c <= 'z') c -= 32;
    if ((c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == ':' || c == '?' || c == '_') {
      if (bufLen < sizeof(buf) - 1) buf[bufLen++] = c;
      else bufLen = 0;  // linha comprida demais: descarta
    }
  }
}

// ============================================================ setup / loop
#if defined(__AVR__) && USAR_RELE
// O RELE DESLIGADO NO PRIMEIRO INSTANTE: antes do setup(), antes ate dos
// objetos da fita de LED - logo depois que a memoria e preparada (secao
// .init5 do AVR, so escrita direta nos registradores do pino). O tempo do
// BOOTLOADER (a placa acabando de ligar ou reiniciando porque abriram a
// serial) vem antes disto e nenhum programa alcanca: nele o pino fica
// solto - veja no LEIA-ME o resistor de 10k que segura o rele desligado.
void releCedo() __attribute__((naked, used, section(".init5")));
void releCedo() {
  uint8_t bit = digitalPinToBitMask(RELE_PINO);
  uint8_t qual = digitalPinToPort(RELE_PINO);
  volatile uint8_t *saida = portOutputRegister(qual);
  volatile uint8_t *modo = portModeRegister(qual);
  if (RELE_LIGA_EM_LOW) *saida |= bit;
  else *saida &= ~bit;
  *modo |= bit;
}
#endif

void setup() {
  // tudo o que e da conversa com o jogo comeca do zero (o Uno/Nano reinicia
  // cada vez que o jogo abre o USB); so a EEPROM fica
  bufLen = 0;
  streamSensores = false;
  jogoFalou = false;
  modoLivre = false;
  ultimoComando = millis();
  recebidas = confirmadas = 0;   // fila vazia ao ligar (so ficha posta agora vale)
  protocoloFicha = jogoAntigo = fichaAvisada = false;
  portaAberta = false;
#if USAR_RELE
  // O RELE NAO MEXE AO LIGAR: desligado ja antes de o pino virar saida (o
  // modulo que liga com LOW nao da nem um estalo), e a porta fica onde a
  // EEPROM diz que ela ficou - so um pedido diferente do jogo da pulso.
  releEscrever(false);
  pinMode(RELE_PINO, OUTPUT);
  releMudouEm = millis();
  releDescansando = false;
#if RELE_PULSO
  releTrocas = lerContador(EE_PORTA);
  if (EEPROM.read(EE_PORTA_ANTIGA) == 0xA1) {
    // gravado por cima do firmware 4 com a porta aberta: leva para o contador
    if (releTrocas == 0) avancarContador(EE_PORTA, releTrocas);
    EEPROM.update(EE_PORTA_ANTIGA, 0xA0);
  }
  releAberta = (releTrocas & 1) != 0;
#if PORTA_FECHA_SEM_ENERGIA
  // (12) A MAQUINA LIGOU NA TOMADA: sem energia a trava fecha - ela esta
  // FECHADA, nao importa o que a EEPROM guardou (desligaram no meio da
  // partida, com a porta aberta). Reiniciou sem faltar energia: a RAM diz
  // onde ela esta. A EEPROM acompanha (sem pulso nenhum).
  releAberta = portaRamValida() ? ramPorta != 0 : false;
  if (((releTrocas & 1) != 0) != releAberta) avancarContador(EE_PORTA, releTrocas);
#endif
  lembrarPortaRam(releAberta);
  relePedida = releAberta;
  relePedidoEm = millis();
#if !USAR_PONTE_H
  portaAberta = releAberta;
#endif
#endif
#endif
#if USAR_PONTE_H
  ponteEscrever(0);
  pinMode(PONTE_IN1, OUTPUT);
  pinMode(PONTE_IN2, OUTPUT);
  pinMode(PONTE_EN, OUTPUT);
  // (os fins de curso com pull-up sempre: o menu pode ligar a qualquer hora)
  pinMode(FC_ABERTA_PINO, INPUT_PULLUP);
  pinMode(FC_FECHADA_PINO, INPUT_PULLUP);
  carregarPonte();   // o tempo e o fim de curso do menu, antes de mexer o motor
  ponteDesde = millis() - PONTE_PAUSA_MS;  // ja no 1o loop o motor fecha a porta
#endif
#if USAR_SERVO
  servoAtual10 = servoAlvo10 = (portaAberta ? SERVO_ABERTA : SERVO_FECHADA) * 10;
  servoIniciar();
#endif
  pinMode(LED_PLACA, OUTPUT);
  for (uint8_t i = 0; i < 5; i++) iniciarEntrada(sensores[i], SENSOR_PINOS[i], FILTRO_SENSOR_MS, REARME_SENSOR_MS, NOMES_SENSOR[i]);
  iniciarEntrada(botoes[0], CONFIG_PINO, FILTRO_BOTAO_MS, REARME_BOTAO_MS, "CFG");
  iniciarEntrada(botoes[1], START_PINO, FILTRO_BOTAO_MS, REARME_BOTAO_MS, "START");
  pinMode(FICHA_PINO, INPUT_PULLUP);
  carregarRepouso();
  Serial.begin(9600);
#if USAR_LEDS
  fita.begin();
  fita.setBrightness(BRILHO);
  fita.show();
#endif
  delay(50);
  // depois do pull-up assentar (e do repouso dos sensores carregado)
  for (uint8_t i = 0; i < 5; i++) assentarEntrada(sensores[i]);
  for (uint8_t i = 0; i < 2; i++) assentarEntrada(botoes[i]);
  // a ficha: o nivel de agora e o repouso (NA ou NF); so um pulso CERTO conta
  fichaLeitura = fichaEstavel = fichaRepouso = digitalRead(FICHA_PINO);
  fichaMudouEm = fichaEstavelDesde = millis();
  Serial.println(F("OLA:STRIKE_KIDS:" VERSAO));
}

// CADA COISA NO SEU TEMPO, NADA ESPERA NADA: o loop passa por tudo sem
// parar (sem delay). Sensores, botoes, fichas, rele, servo, ponte H, vigia
// do jogo e LEDs tem cada um o seu relogio; um comando chegando, um pulso
// do rele ou um efeito dos LEDs nunca seguram os sensores nem os outros.
void loop() {
  lerSerial();
  unsigned long agora = millis();   // depois dos comandos (eles marcam a hora com millis)
  bool mudouSensor = false;
  bool disparou;
  for (uint8_t i = 0; i < 5; i++) {
    if (tickEntrada(sensores[i], agora, disparou)) mudouSensor = true;
    if (disparou) {
      Serial.println(sensores[i].evento);
      piscar(agora);
    }
  }
  if (mudouSensor && streamSensores) enviarSensores();
  for (uint8_t i = 0; i < 2; i++) {
    tickEntrada(botoes[i], agora, disparou);
    if (disparou) {
      Serial.println(botoes[i].evento);
      piscar(agora);
    }
  }
  tickFicha(agora);     // so o pulso certo do moedeiro vira ficha
  enviarFicha(agora);
#if USAR_SERVO
  tickServo(agora);
#endif
#if USAR_RELE
  tickRele(agora);
#endif
#if USAR_PONTE_H
  tickPonte(agora);
#endif
  // VIGIA DO JOGO: o jogo falou e depois sumiu com a porta aberta -> fecha.
  // (Antes de o jogo falar a primeira vez nao vale: ligar o Arduino, ou a
  // TV Box ainda abrindo o jogo, nao mexe na porta.)
  // (no MODO LIVRE nunca: a porta e sempre aberta, com ou sem o jogo)
  if (jogoFalou && portaAberta && !modoLivre && agora - ultimoComando > SEM_JOGO_FECHA_MS) {
    porta(false);
    Serial.println(F("AVISO:SEM_JOGO"));
  }
  if (piscarAte && (long)(agora - piscarAte) >= 0) {
    piscarAte = 0;
    digitalWrite(LED_PLACA, LOW);
  }
#if USAR_LEDS
  // A fita de LED para as interrupcoes enquanto e atualizada (~2 ms com 60
  // LEDs): com um comando chegando pelo USB, os LEDs esperam ele terminar -
  // nenhuma letra do comando se perde.
  if (bufLen == 0 && !Serial.available()) tickLeds(agora);
#endif
}
