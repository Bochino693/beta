// Simula o firmware do Arduino no PC (tools/testes/arduino/testar_firmware.sh):
// tempo, pinos, serial e uma porta de verdade com os fins de curso.
#include "Arduino.h"
#include <cstdlib>
unsigned long t_ms = 0;
int pinLevel[32], pinOut[32], pinModeV[32], pinPwm[32];
volatile uint8_t TCCR1A, TCCR1B;
volatile uint16_t ICR1, OCR1A;
SerialMock Serial;
#include "EEPROM.h"
EEPROMMock EEPROM;
#include FIRMWARE

static int falhas = 0;
#define CONFERE(c, msg) do { if (!(c)) { printf("  FALHOU (t=%lu): %s\n", t_ms, msg); falhas++; } } while (0)

// porta de verdade: 0 = fechada ... 1000 = aberta, anda 1 por ms com o motor
int portaFisica = 500;
bool presa = false;
int motor() {  // 1 abrindo, -1 fechando, 0 parado/freado
  if (pinPwm[PONTE_EN] == 0 || pinOut[PONTE_IN1] == pinOut[PONTE_IN2]) return 0;
  int s = pinOut[PONTE_IN1] ? 1 : -1;
  return PONTE_INVERTIDA ? -s : s;
}
int motorBruto() { return pinOut[PONTE_IN1] * 10 + pinOut[PONTE_IN2]; }
void fisica() {
  if (!presa) portaFisica = constrain(portaFisica + motor(), 0, 1000);
  bool na_aberta = portaFisica >= 1000, na_fechada = portaFisica <= 0;
  pinLevel[FC_ABERTA_PINO] = (na_aberta != (FC_NF != 0)) ? LOW : HIGH;
  pinLevel[FC_FECHADA_PINO] = (na_fechada != (FC_NF != 0)) ? LOW : HIGH;
}
std::string saida;
// o rele: quantas vezes ligou (pulsos) e quando foi a ultima
int pulsos = 0;
unsigned long pulsoEm = 0, pulsoLigadoMs = 0;
bool releLigadoAgora() { return pinModeV[RELE_PINO] == OUTPUT && pinOut[RELE_PINO] == (RELE_LIGA_EM_LOW ? LOW : HIGH); }
void rodar(unsigned long ms) {
  for (unsigned long i = 0; i < ms; i++) {
    bool antes = releLigadoAgora();
    fisica(); loop(); t_ms++;
    bool depois = releLigadoAgora();
    if (depois && !antes) { pulsos++; pulsoEm = t_ms; pulsoLigadoMs = 0; }
    if (depois) pulsoLigadoMs++;
  }
  saida += Serial.out; Serial.out.clear();
}
void manda(const char *c) { for (const char *p = c; *p; p++) Serial.in.push_back(*p); Serial.in.push_back('\n'); }
int conta(const std::string &s) { int n = 0; size_t p = 0; while ((p = saida.find(s, p)) != std::string::npos) { n++; p += s.size(); } return n; }
std::string pega() { std::string s = saida; saida.clear(); return s; }
void iniciar() {
  for (int i = 0; i < 32; i++) pinLevel[i] = HIGH;
  fisica();
}
// roda ate aparecer a linha (ou estourar o tempo); devolve o tempo que levou
long ate(const char *linha, unsigned long max_ms) {
  unsigned long t0 = t_ms;
  while (t_ms - t0 < max_ms) { rodar(1); if (saida.find(linha) != std::string::npos) return (long)(t_ms - t0); }
  return -1;
}

// desliga e liga o Arduino (o Uno/Nano reinicia quando o jogo abre o USB):
// a memoria volta ao valor de fabrica, so a EEPROM fica
void religar() {
#if USAR_PONTE_H
  ponteAlvoAberta = false; ponteMov = 0; ponteNoAlvo = false; ponteFalhas = 0;
  ponteDesde = 0; ponteFreioAte = 0; pontePos = 1000; ponteInicioPos = 1000;
  ponteTempoAbre = PONTE_TEMPO_ABRE_MS; ponteTempoFecha = PONTE_TEMPO_FECHA_MS;
  ponteFC = PONTE_FIM_DE_CURSO;
#endif
  portaAberta = false; ultimoComando = 0; bufLen = 0;
  setup();
}

int main(int argc, char **argv) {
  std::string c = argc > 1 ? argv[1] : "";
  iniciar();
  if (c == "tempo") {
    setup(); saida += Serial.out; Serial.out.clear();
    CONFERE(saida.find("OLA:STRIKE_KIDS:6") != std::string::npos, "OLA ao ligar");
    rodar(2);
    CONFERE(motor() == -1, "ao ligar o motor fecha a porta");
    long t = ate("PORTA:FECHADA", 3000);
    printf("  ligou: fechou em %ld ms\n", t);
    CONFERE(t >= 1400 && t <= 1600, "fecha pelo tempo (1500 ms)");
    CONFERE(motorBruto() == 11, "freia ao parar");
    rodar(200);
    CONFERE(motorBruto() == 0 && motor() == 0, "solta o motor depois do freio");
    rodar(200);   // pausa de 300 ms depois de parar
    pega();
    manda("PORTA:ABRE");
    rodar(5);
    CONFERE(motor() == 1, "ABRE: motor abre");
    CONFERE(conta("PORTA:ABERTA") == 0, "so confirma quando chegar");
    t = ate("PORTA:ABERTA", 3000);
    printf("  abriu em %ld ms\n", t);
    CONFERE(t >= 1400 && t <= 1600, "abre pelo tempo");
    rodar(400); pega();
    manda("PORTA:ABRE");   // de novo: so confirma, nao mexe
    rodar(5);
    CONFERE(conta("PORTA:ABERTA") == 1 && motor() == 0, "ABRE repetido so confirma");
    // muda de ideia no meio
    pega();
    manda("PORTA:FECHA");
    rodar(700);
    CONFERE(motor() == -1, "fechando");
    manda("PORTA:ABRE");
    rodar(3);
    CONFERE(motor() == 0, "inverteu: para antes");
    rodar(250);
    CONFERE(motor() == 0, "pausa antes de inverter");
    t = ate("PORTA:ABERTA", 3000);
    printf("  voltou a abrir em %ld ms (andou ~700 fechando)\n", t);
    CONFERE(t >= 650 && t <= 850, "volta so o que andou (~700 ms)");
    CONFERE(conta("PORTA:FECHADA") == 0, "nao confirmou a fechada");
    // jogo sumiu com a porta aberta: fecha sozinha
    pega();
    t = ate("AVISO:SEM_JOGO", SEM_JOGO_FECHA_MS + 5000);
    CONFERE(t > 0, "SEM_JOGO fecha a porta");
    t = ate("PORTA:FECHADA", 3000);
    CONFERE(t > 1300, "... e o motor fecha");
    manda("INFO?");
    rodar(5);
    printf("  %s", pega().c_str());
  } else if (c == "fim_de_curso") {
    portaFisica = 400; fisica();
    setup(); pega(); Serial.out.clear();
    long t = ate("PORTA:FECHADA", 8000);
    printf("  ligou no meio: fechou em %ld ms (porta=%d)\n", t, portaFisica);
    CONFERE(t > 0 && portaFisica == 0, "fecha ate o fim de curso");
    rodar(200);
    CONFERE(motor() == 0, "parado");
    manda("PORTA:ABRE");
    t = ate("PORTA:ABERTA", 8000);
    printf("  abriu em %ld ms (porta=%d)\n", t, portaFisica);
    CONFERE(t > 900 && portaFisica == 1000, "abre ate o fim de curso");
    rodar(200);
    CONFERE(motor() == 0, "parado aberta");
    pega();
    manda("PORTA:FECHA");
    rodar(500);
    manda("PORTA:ABRE");   // mudou de ideia
    t = ate("PORTA:ABERTA", 8000);
    CONFERE(t > 0 && portaFisica == 1000, "volta a abrir");
    CONFERE(conta("AVISO") == 0, "sem aviso");
  } else if (c == "travou") {
    portaFisica = 400; presa = true; fisica();
    setup(); pega(); Serial.out.clear();
    long t = ate("AVISO:PORTA_TRAVOU", 8000);
    printf("  presa: aviso em %ld ms\n", t);
    CONFERE(t >= 5900 && t <= 6100, "para em 6 s");
    rodar(200);
    CONFERE(motor() == 0, "motor parado depois de travar");
    rodar(30000);
    printf("  avisos em 30 s: %d\n", conta("AVISO:PORTA_TRAVOU"));
    CONFERE(conta("AVISO:PORTA_TRAVOU") == 3, "tenta 3 vezes e desiste");
    CONFERE(motor() == 0, "desistiu: motor parado");
    presa = false; pega();
    manda("PORTA:FECHA");   // pedido de novo: tenta outra vez
    t = ate("PORTA:FECHADA", 8000);
    CONFERE(t > 0 && portaFisica == 0, "pedido novo tenta de novo e fecha");
  } else if (c == "invertida") {
    setup(); pega();
    rodar(2);
    CONFERE(motorBruto() == 10, "invertida: fechar = IN1 ligado");
  } else if (c == "ficha_nf") {
    pinLevel[FICHA_PINO] = LOW;      // moedeiro NF: fechado em repouso
    pinLevel[START_PINO] = LOW;      // START preso ao ligar
    setup(); pega();
    manda("INFO?"); rodar(5); pega();   // jogo antigo: FICHA simples
    rodar(1000);
    CONFERE(conta("FICHA") == 0, "moedeiro NF nao da ficha ao ligar");
    CONFERE(conta("START") == 0, "START preso ao ligar nao conta");
    for (int i = 0; i < 3; i++) { pinLevel[FICHA_PINO] = HIGH; rodar(50); pinLevel[FICHA_PINO] = LOW; rodar(100); }
    printf("  3 pulsos NF -> %d FICHA\n", conta("FICHA"));
    CONFERE(conta("FICHA") == 3, "1 ficha por pulso (NF)");
  } else if (c == "ficha_na") {
    setup(); pega();
    manda("INFO?"); rodar(5); pega();   // jogo antigo: FICHA simples
    rodar(100);
    for (int i = 0; i < 4; i++) { pinLevel[FICHA_PINO] = LOW; rodar(30); pinLevel[FICHA_PINO] = HIGH; rodar(70); }
    printf("  4 pulsos NA -> %d FICHA\n", conta("FICHA"));
    CONFERE(conta("FICHA") == 4, "1 ficha por pulso (NA)");
    pinLevel[START_PINO] = LOW; rodar(60); pinLevel[START_PINO] = HIGH; rodar(300);
    CONFERE(conta("START") == 1, "START");
    // bola no sensor do centro, balancando
    pinLevel[4] = LOW; rodar(10); pinLevel[4] = HIGH; rodar(3); pinLevel[4] = LOW; rodar(20); pinLevel[4] = HIGH; rodar(200);
    CONFERE(conta("\nS:3\n") == 1, "uma bola = um S:3");
    pinLevel[3] = LOW; rodar(10); pinLevel[3] = HIGH; rodar(10);
    CONFERE(conta("\nS:2\n") == 1, "S:2");
  } else if (c == "menu") {
    // o MENU DO OPERADOR troca o tempo do motor e o fim de curso
    setup(); pega();
    ate("PORTA:FECHADA", 3000);
    rodar(400); pega();
    manda("PONTE?");
    rodar(2);
    CONFERE(conta("PONTE:TEMPO:1500:FC:0") == 1, "PONTE? de fabrica");
    manda("PONTE:TEMPO:800");
    rodar(2);
    CONFERE(conta("PONTE:TEMPO:800:FC:0") == 1, "PONTE:TEMPO responde");
    manda("PORTA:ABRE");
    long t = ate("PORTA:ABERTA", 3000);
    printf("  tempo 800: abriu em %ld ms\n", t);
    CONFERE(t >= 700 && t <= 900, "abre no tempo do menu");
    rodar(400); pega();
    manda("PONTE:TEMPO:50");       // fora do limite: ignora
    manda("PONTE:TEMPO:99999");
    manda("PONTE:FC:7");
    rodar(3);
    // (fora do limite: responde o que vale; escrito errado - FC:7 - nem
    // responde: nao e comando do jogo)
    CONFERE(conta("PONTE:TEMPO:800:FC:0") == 2, "valor invalido nao muda");
    // muda o tempo com o motor andando: para e termina no tempo novo
    pega();
    manda("PORTA:FECHA");
    rodar(400);
    manda("PONTE:TEMPO:2000");
    t = ate("PORTA:FECHADA", 5000);
    printf("  trocou o tempo no meio: fechou %ld ms depois\n", t);
    // (andou 400 de 800 ms = metade; a outra metade em 2000 ms = 1000, + a pausa)
    CONFERE(t >= 1200 && t <= 1450, "termina no tempo novo (o que faltava)");
    // reinicia (o jogo abre o USB): o Arduino lembra o que o menu escolheu
    rodar(400); pega();
    portaFisica = 500; fisica();
    religar(); pega();
    manda("INFO?");
    rodar(2);
    std::string info = pega();
    printf("  %s", info.c_str());
    CONFERE(info.find("PONTE_H=TEMPO:TEMPO=2000") != std::string::npos, "guardou na EEPROM");
    t = ate("PORTA:FECHADA", 5000);
    CONFERE(t >= 1900 && t <= 2100, "ao ligar fecha no tempo guardado");
    // liga o fim de curso pelo menu
    rodar(400); pega();
    portaFisica = 300; fisica();   // (o tempo contou fechada; a porta de verdade nao)
    manda("PONTE:FC:1");
    rodar(2);
    CONFERE(conta("PONTE:TEMPO:2000:FC:1") == 1, "PONTE:FC:1 responde");
    manda("PORTA:FECHA");
    t = ate("PORTA:FECHADA", 8000);
    CONFERE(t > 0 && portaFisica == 0, "com o fim de curso do menu: fecha ate o micro-switch");
    rodar(400); pega();
    manda("PORTA:ABRE");
    t = ate("PORTA:ABERTA", 8000);
    CONFERE(t > 900 && portaFisica == 1000, "abre ate o micro-switch");
    // desliga de novo, com a porta parada aberta
    rodar(400); pega();
    manda("PONTE:FC:0");
    rodar(2);
    manda("PORTA:FECHA");
    t = ate("PORTA:FECHADA", 5000);
    CONFERE(t >= 1900 && t <= 2100 && portaFisica == 0, "sem fim de curso de novo: fecha pelo tempo");
    religar(); pega();
    manda("PONTE?");
    rodar(2);
    CONFERE(conta("PONTE:TEMPO:2000:FC:0") == 1, "guardou o FC:0");
  } else if (c == "so_ponte") {
    // sem servo e sem rele: so a ponte H
    setup(); pega();
    long t = ate("PORTA:FECHADA", 3000);
    CONFERE(t >= 1400 && t <= 1600, "fecha pela ponte H");
    CONFERE(TCCR1A == 0 && TCCR1B == 0, "sem servo: o Timer1 fica livre");
    CONFERE(pinModeV[RELE_PINO] != OUTPUT, "sem rele: o D8 fica livre");
    manda("INFO?");
    rodar(2);
    std::string info = pega();
    printf("  %s", info.c_str());
    CONFERE(info.find(":SERVO=0:RELE=0:PONTE_H=TEMPO") != std::string::npos, "INFO sem servo e sem rele");
  } else if (c == "sem_ponte") {
    setup(); pega();
    manda("PORTA:ABRE");
#if USAR_RELE && RELE_PULSO
    rodar(RELE_FIRME_MS + 5);
    CONFERE(conta("PORTA:ABERTA") == 1 && pulsos == 1, "sem ponte H: confirma junto com o pulso");
#else
    rodar(2);
    CONFERE(conta("PORTA:ABERTA") == 1, "sem ponte H: confirma na hora");
#endif
    manda("PONTE:TEMPO:800");   // jogo novo, Arduino sem ponte: ignora calado
    rodar(2);
    CONFERE(conta("PONTE") == 0, "sem ponte H: PONTE: ignorado");
    manda("INFO?");
    rodar(2);
    printf("  %s", pega().c_str());
  } else if (c == "rele") {
    // a versao do RELE com o rele de NIVEL (RELE_PULSO 0) e o servo: rele no
    // D8 e servo no D9, sem ponte H (D10-D12, A3 e A4 livres)
    setup(); pega();
    CONFERE(USAR_PONTE_H == 0 && USAR_RELE && USAR_SERVO && !RELE_PULSO, "rele de nivel e servo, sem ponte H");
    const int livres[5] = {PONTE_IN1, PONTE_IN2, PONTE_EN, FC_ABERTA_PINO, FC_FECHADA_PINO};
    for (int p : livres) CONFERE(pinModeV[p] == INPUT, "pinos da ponte H livres");
    bool desligado = RELE_LIGA_EM_LOW ? HIGH : LOW;
    CONFERE(pinModeV[RELE_PINO] == OUTPUT && pinOut[RELE_PINO] == desligado, "ao ligar: rele desligado (porta fechada)");
    manda("PORTA:ABRE");
    rodar(2);
    CONFERE(conta("PORTA:ABERTA") == 1, "abre: confirma na hora");
    CONFERE(pinOut[RELE_PINO] != desligado, "abre: rele liga");
    rodar(1000);
    CONFERE(servoAtual10 == SERVO_ABERTA * 10, "abre: servo no angulo da porta aberta");
    manda("PORTA:FECHA");
    rodar(2);
    CONFERE(conta("PORTA:FECHADA") == 1, "fecha: confirma na hora");
    CONFERE(pinOut[RELE_PINO] == desligado, "fecha: rele desliga");
    rodar(1000);
    CONFERE(servoAtual10 == SERVO_FECHADA * 10, "fecha: servo no angulo da porta fechada");
    manda("PONTE:TEMPO:800");
    manda("PONTE:FC:1");
    rodar(2);
    CONFERE(conta("PONTE") == 0, "PONTE: do menu ignorado calado");
    for (int p : livres) CONFERE(pinModeV[p] == INPUT && pinOut[p] == 0, "pinos da ponte H continuam livres");
    manda("INFO?");
    rodar(2);
    CONFERE(conta(":RELE=8") == 1 && conta(":PONTE_H=0:") == 1, "INFO: rele no D8 e sem ponte H");
    pega();
    manda("PORTA:ABRE");
    rodar(2);
    if (RELE_TEMPO_MAX_S > 0) {
      rodar(RELE_TEMPO_MAX_S * 1000UL + 100);
      CONFERE(pinOut[RELE_PINO] == desligado, "trava solenoide: rele solta depois do RELE_TEMPO_MAX_S");
      CONFERE(conta("PORTA:FECHADA") == 0, "trava solenoide: para o jogo a porta continua aberta");
    }
    rodar(SEM_JOGO_FECHA_MS + 100);
    CONFERE(conta("AVISO:SEM_JOGO") == 1 && conta("PORTA:FECHADA") == 1, "jogo sumiu: fecha sozinha");
    CONFERE(pinOut[RELE_PINO] == desligado, "jogo sumiu: rele desligado");
  } else if (c == "intruso") {
    // A TV BOX LIGANDO "FALA" COM O ARDUINO: um programa dela testa a porta
    // serial (comandos de modem AT), chega ruido e o eco das respostas. Nada
    // disso pode mexer na porta nem ligar o vigia do jogo.
#if USAR_RELE && RELE_PULSO && !USAR_PONTE_H
    EEPROM.update(EE_PORTA, 0); EEPROM.update(EE_PORTA + 1, 0xFF);   // (a porta ficou ABERTA)
#endif
    setup(); pega();
    const char *lixo[] = {"AT", "ATE0", "AT+CGMM", "AT+CPIN?", "ATI", "OLA:STRIKE_KIDS:6", "PORTA:ABERTA", "PORTA:FECHADA",
                          "PONG:STRIKE_KIDS:6", "FICHA:0", "INFO:STRIKE_KIDS:6:LEDS=1", "PONTE:TEMPO:1500:FC:0", "PONTE:TEMPO:800X",
                          "PORTA:ABREX", "XPING", "PINGS", "CALIBRAR", "S:1", "SENS:00000", "AVISO:SEM_JOGO", "~~##", "+++"};
    for (int k = 0; k < 6; k++) {
      for (const char *l : lixo) { manda(l); rodar(30); }
      rodar(20000);
    }
    rodar(300000);
    printf("  %d linhas de fora em 7 minutos -> pulsos=%d\n", 6 * (int)(sizeof lixo / sizeof lixo[0]), pulsos);
    CONFERE(pulsos == 0, "o que nao e do jogo nao da pulso no rele");
    CONFERE(conta("AVISO") == 0, "o que nao e do jogo nao liga o vigia (nada de SEM_JOGO)");
    CONFERE(conta("CAL:OK") == 0, "CALIBRAR (errado) nao calibra");
    CONFERE(!jogoFalou, "o vigia continua esperando o jogo de verdade");
#if USAR_PONTE_H
    CONFERE(ponteTempoAbre == PONTE_TEMPO_ABRE_MS, "a resposta PONTE:TEMPO:1500:FC:0 (eco) nao muda o tempo do motor");
#endif
    // agora o jogo de verdade: tudo funciona
    pega();
    manda("PING"); rodar(5);
    CONFERE(conta("PONG:STRIKE_KIDS:6") == 1, "o jogo de verdade e atendido");
#if USAR_RELE && RELE_PULSO && !USAR_PONTE_H
    manda("PORTA:ABRE"); rodar(2000);
    CONFERE(pulsos == 0 && conta("PORTA:ABERTA") == 1, "jogo pede aberta (ja estava): sem pulso");
    manda("PORTA:FECHA"); rodar(2000);
    CONFERE(pulsos == 1 && conta("PORTA:FECHADA") == 1, "jogo pede fechada: um pulso");
    // lixo no meio da partida tambem nao conta como o jogo falando
    pega();
    manda("PORTA:ABRE"); rodar(2000);
    for (int k = 0; k < 40; k++) { manda("AT"); rodar(1000); }
    CONFERE(conta("AVISO:SEM_JOGO") == 1 && pulsos == 3, "jogo sumiu (so lixo chegando): o vigia fecha mesmo assim");
#endif
  } else if (c == "pulso") {
#if USAR_RELE && RELE_PULSO && !USAR_PONTE_H
    // A VERSAO DO RELE COMO ELA E GRAVADA: rele de PULSO (um pulso troca a porta)
    const int livres[5] = {PONTE_IN1, PONTE_IN2, PONTE_EN, FC_ABERTA_PINO, FC_FECHADA_PINO};
    setup(); pega();
    for (int p : livres) CONFERE(pinModeV[p] == INPUT, "pinos da ponte H livres");
    CONFERE(pinModeV[RELE_PINO] == OUTPUT && !releLigadoAgora(), "ao ligar: rele desligado");
    // 1. LIGOU E NINGUEM FALOU: 5 minutos sem um pulso sequer
    rodar(300000);
    CONFERE(pulsos == 0, "ao energizar (sem jogo) o rele nao mexe");
    CONFERE(conta("AVISO") == 0, "sem jogo desde o comeco: nenhum aviso");
    // 2. o jogo conecta e pede FECHADA (modo fichas, sem credito): ja esta
    manda("PING"); manda("FICHAS:SYNC"); manda("PORTA:FECHA"); manda("INFO?");
    rodar(500);
    CONFERE(pulsos == 0 && conta("PORTA:FECHADA") == 1, "pedido igual a posicao: confirma sem pulso");
    CONFERE(conta(":RELE=8") == 1 && conta(":PONTE_H=0:") == 1 && conta(":PULSO=1") == 1, "INFO: rele de pulso no D8, sem ponte H");
    pega();
    // 3. CREDITO: UM pulso abre
    manda("PORTA:ABRE");
    rodar(RELE_FIRME_MS - 20);
    CONFERE(pulsos == 0, "espera o pedido ficar firme");
    rodar(40);
    CONFERE(pulsos == 1 && releLigadoAgora(), "credito: o pulso comeca");
    CONFERE(conta("PORTA:ABERTA") == 1, "confirma junto com o pulso");
    rodar(RELE_PULSO_MS + 20);
    CONFERE(!releLigadoAgora(), "o pulso acaba");
    printf("  pulso de %lu ms\n", pulsoLigadoMs);
    CONFERE(pulsoLigadoMs >= RELE_PULSO_MS - 2 && pulsoLigadoMs <= RELE_PULSO_MS + 5, "o pulso dura RELE_PULSO_MS");
    // 4. o jogo repete o pedido (reenvio, PING, de novo...): nenhum pulso a mais
    pega();
    for (int i = 0; i < 20; i++) { manda("PORTA:ABRE"); manda("PING"); rodar(700); }
    CONFERE(pulsos == 1, "pedido repetido 20 vezes: nenhum pulso a mais");
    CONFERE(conta("PORTA:ABERTA") == 20, "cada repeticao so confirma");
    // 5. abre e fecha juntos (o jogo mudou de ideia no mesmo instante): se anulam
    pega();
    manda("PORTA:FECHA"); rodar(60); manda("PORTA:ABRE"); rodar(2000);
    CONFERE(pulsos == 1, "fecha+abre em 60 ms: sem pulso");
    manda("PORTA:FECHA"); manda("PORTA:ABRE"); manda("PORTA:FECHA"); manda("PORTA:ABRE"); rodar(2000);
    CONFERE(pulsos == 1, "varios pedidos na mesma hora, terminando onde estava: sem pulso");
    // 6. FIM DA PARTIDA: UM pulso fecha; ficha logo em seguida: o outro pulso
    //    espera o descanso (a porta termina de andar)
    pega();
    manda("PORTA:FECHA");
    rodar(RELE_FIRME_MS + 20);
    CONFERE(pulsos == 2 && conta("PORTA:FECHADA") == 1, "fim da partida: um pulso fecha");
    unsigned long p2 = pulsoEm;
    manda("PORTA:ABRE");                      // ficha no meio do pulso
    rodar(RELE_PULSO_MS + RELE_DESCANSO_MS - 100);
    CONFERE(pulsos == 2, "outro pulso so depois do descanso");
    rodar(400);
    CONFERE(pulsos == 3 && conta("PORTA:ABERTA") == 1, "depois do descanso: o pulso que abre");
    printf("  entre dois pulsos: %lu ms\n", pulsoEm - p2);
    CONFERE(pulsoEm - p2 >= RELE_PULSO_MS + RELE_DESCANSO_MS, "descanso entre dois pulsos");
    rodar(3000);
    // 7. o Arduino REINICIA com a porta aberta (o jogo abriu o USB de novo, a
    //    luz piscou): lembra da EEPROM e nao pulsa
    religar(); pega();
    CONFERE(!releLigadoAgora(), "reiniciou: rele desligado");
    manda("PORTA?"); rodar(5);
    // (o PORTA? conta como o jogo falando: o vigia passa a valer)
    CONFERE(conta("PORTA:ABERTA") == 1, "reiniciou: lembra que a porta ficou aberta");
    religar(); pega();
    rodar(300000);
    CONFERE(pulsos == 3 && conta("AVISO") == 0, "reiniciou aberta e sem jogo: 5 minutos sem pulso");
    manda("PING"); manda("PORTA:ABRE"); rodar(1000);
    CONFERE(pulsos == 3 && conta("PORTA:ABERTA") == 1, "o jogo voltou querendo aberta: sem pulso");
    // 8. o jogo SOME com a porta aberta: fecha sozinha, com UM pulso
    pega();
    rodar(SEM_JOGO_FECHA_MS - 2000);
    CONFERE(pulsos == 3, "ainda dentro do tempo do vigia");
    rodar(4000);
    CONFERE(pulsos == 4 && conta("AVISO:SEM_JOGO") == 1 && conta("PORTA:FECHADA") == 1, "jogo sumiu: um pulso fecha");
    rodar(600000);
    CONFERE(pulsos == 4 && conta("AVISO:SEM_JOGO") == 1, "10 minutos sem jogo: nada mais");
    // 9. o jogo volta (modo livre: quer aberta): um pulso
    pega();
    manda("PING"); manda("PORTA:ABRE"); rodar(1000);
    CONFERE(pulsos == 5 && conta("PORTA:ABERTA") == 1, "o jogo voltou: um pulso abre");
    // 10. com PING chegando (jogo vivo) a porta fica aberta para sempre
    for (int i = 0; i < 300; i++) { manda("PING"); rodar(2000); }
    CONFERE(pulsos == 5, "10 minutos com o jogo vivo: aberta, sem pulso");
    // 11. ACERTAR: a porta de verdade esta ao contrario (mexeram com a mao)
    manda("PORTA:FECHA"); rodar(3000);
    CONFERE(pulsos == 6, "fecha");
    pega();
    manda("PORTA:ACERTA"); rodar(5);
    CONFERE(conta("PORTA:ABERTA") == 1, "acertar: o Arduino passa a lembrar aberta, sem pulso na hora");
    rodar(3000);
    CONFERE(pulsos == 7 && conta("PORTA:FECHADA") == 1, "o jogo quer fechada: um pulso acerta");
    // 12. linha pela metade (ruido) nao estraga o proximo comando
    pega();
    for (const char *p = "PORTA:AB"; *p; p++) Serial.in.push_back(*p);
    rodar(200);
    manda("PORTA:ABRE"); rodar(1000);
    CONFERE(pulsos == 8 && conta("PORTA:ABERTA") == 1, "lixo no serial: o comando seguinte vale");
    // 13. DESGASTE DA EEPROM: 2000 trocas de porta espalhadas por 32 enderecos
    int antes[1024]; memcpy(antes, EEPROM.gravacoes, sizeof antes);
    for (int i = 0; i < 2000; i++) {
      manda(i % 2 ? "PORTA:ABRE" : "PORTA:FECHA"); manda("PING");
      rodar(RELE_PULSO_MS + RELE_DESCANSO_MS + RELE_FIRME_MS + 50);
    }
    CONFERE(pulsos == 2008, "2000 trocas = 2000 pulsos");
    int pior = 0;
    for (int a = 0; a < 1024; a++) pior = max(pior, EEPROM.gravacoes[a] - antes[a]);
    printf("  2000 pulsos: o endereco mais gravado levou %d gravacoes\n", pior);
    CONFERE(pior <= 2000 / 32 + 2, "desgaste repartido por 32 enderecos");
    // ... e a posicao continua certa depois de reiniciar em qualquer ponto
    for (int i = 0; i < 70; i++) {
      bool quer = (i * 7 + i / 3) % 2;
      manda(quer ? "PORTA:ABRE" : "PORTA:FECHA");
      rodar(RELE_PULSO_MS + RELE_DESCANSO_MS + RELE_FIRME_MS + 50);
      int p0 = pulsos;
      religar(); pega();
      manda("PORTA?"); rodar(5);
      CONFERE(conta(quer ? "PORTA:ABERTA" : "PORTA:FECHADA") == 1 && pulsos == p0, "reinicia e lembra a posicao");
    }
#else
    CONFERE(false, "o cenario pulso e so da versao do rele de pulso");
#endif
  } else if (c == "antigo4") {
#if USAR_RELE && RELE_PULSO && !USAR_PONTE_H
    // gravado por cima do firmware 4, que guardava a porta num byte so
    EEPROM.m[EE_PORTA_ANTIGA] = 0xA1;
    setup(); pega();
    manda("PORTA?"); rodar(5);
    CONFERE(conta("PORTA:ABERTA") == 1 && pulsos == 0, "firmware 4 com a porta aberta: lembra, sem pulso");
    religar(); pega();
    manda("PORTA?"); rodar(5);
    CONFERE(conta("PORTA:ABERTA") == 1 && pulsos == 0, "... e continua lembrando");
#endif
  } else if (c == "fichas") {
    // FICHAS QUE NAO SE PERDEM: fila na EEPROM, confirmada pelo jogo
    for (uint16_t n = 0, i = 0; i < 20000; i++) {   // o contador circular, 2 voltas e meia
      if (lerContador(200) != n) { CONFERE(false, "contador circular"); break; }
      avancarContador(200, n);
    }
    setup(); pega();
    // 3 fichas com a TV Box ainda ligando (ninguem do outro lado)
    for (int i = 0; i < 3; i++) { pinLevel[FICHA_PINO] = LOW; rodar(30); pinLevel[FICHA_PINO] = HIGH; rodar(70); }
    rodar(5000);
    CONFERE(conta("FICHA") == 0, "sem jogo: a ficha espera na fila");
    religar(); pega();                      // o jogo abre o USB: o Uno reinicia
    rodar(1000);
    CONFERE(conta("FICHA") == 0, "reiniciou: continua esperando o jogo");
    manda("PING"); manda("FICHAS:SYNC"); manda("INFO?");
    rodar(20);
    CONFERE(conta("FICHA:0\n") == 1, "o jogo conectou: a 1a ficha da fila");
    CONFERE(conta(":FILA=3") == 1, "INFO: 3 fichas na fila");
    CONFERE(conta("\nFICHA\n") == 0, "jogo novo: nunca a FICHA simples");
    pega();
    rodar(1100);
    CONFERE(conta("FICHA:0\n") == 2 && conta("FICHA:1") == 0, "sem confirmacao: repete a mesma a cada 0,5 s");
    pega();
    manda("FICHA:OK:7");                    // confirmacao errada: ignora
    rodar(20);
    CONFERE(conta("FICHA:1") == 0, "confirmacao de outra ficha nao vale");
    manda("FICHA:OK:0");
    rodar(20);
    CONFERE(conta("FICHA:1\n") == 1, "confirmou a 0: sai a 1");
    manda("FICHA:OK:0");                    // confirmacao repetida (atrasada)
    rodar(20);
    CONFERE(conta("FICHA:2") == 0, "confirmacao repetida nao pula ficha");
    manda("FICHA:OK:1"); rodar(20);
    CONFERE(conta("FICHA:2\n") == 1, "sai a 2");
    // o Arduino reinicia ANTES de o jogo confirmar a 2: ela volta
    religar(); pega();
    manda("FICHAS:SYNC"); rodar(20);
    CONFERE(conta("FICHA:2\n") == 1, "reiniciou sem confirmar: a ficha volta (nao se perde)");
    manda("FICHA:OK:2"); rodar(700);
    pega();
    rodar(3000);
    CONFERE(conta("FICHA") == 0, "fila vazia: nada mais");
    // ficha com o jogo conectado: na hora
    pinLevel[FICHA_PINO] = LOW; rodar(30); pinLevel[FICHA_PINO] = HIGH; rodar(20);
    CONFERE(conta("FICHA:3\n") == 1, "ficha com o jogo conectado: avisa na hora");
    manda("FICHA:OK:3"); rodar(20);
    // 300 fichas seguidas com o Arduino reiniciando no meio (confirmacoes
    // perdidas): o jogo confirma cada aviso e conta cada numero uma vez so,
    // como o ArduinoBridge - nenhuma perdida, nenhuma em dobro
    pega();
    int vistas = 0, proxima = 4, repetidas = 0;
    for (int i = 0; i < 330; i++) {
      if (i < 300) { pinLevel[FICHA_PINO] = LOW; rodar(30); pinLevel[FICHA_PINO] = HIGH; rodar(60); }
      else rodar(600);
      std::string t = pega();
      size_t q = 0;
      while ((q = t.find("FICHA:", q)) != std::string::npos) {
        int id = atoi(t.c_str() + q + 6);
        q += 6;
        if (id == proxima) { vistas++; proxima++; } else if (id < proxima) repetidas++; else CONFERE(false, "ficha fora de ordem");
        char ok[24]; snprintf(ok, sizeof ok, "FICHA:OK:%d", id); manda(ok);
      }
      if (i % 37 == 0) { religar(); manda("FICHAS:SYNC"); }
    }
    printf("  300 fichas -> %d contadas (%d avisos repetidos, descartados pelo numero)\n", vistas, repetidas);
    CONFERE(vistas == 300, "300 fichas: uma por pulso do moedeiro");
    manda("INFO?"); rodar(5);
    CONFERE(conta(":FILA=0") == 1, "fila vazia no fim");
    int pior = 0;
    for (int a = EE_RECEBIDAS; a < EE_RECEBIDAS + 64; a++) pior = max(pior, EEPROM.gravacoes[a]);
    CONFERE(pior <= 304 / 32 + 2, "fichas: desgaste da EEPROM repartido");
  } else {
    printf("cenario?\n");
    return 2;
  }
  printf("%s %s\n", c.c_str(), falhas ? "FALHOU" : "OK");
  return falhas ? 1 : 0;
}
