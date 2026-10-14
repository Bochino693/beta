#include <Adafruit_NeoPixel.h>
#include <string.h>

#define LED_PIN   6
#define NUM_LEDS  60
#define BRILHO    180
#define START_PIN  2  // Botao entre D2 e GND
#define CREDIT_PIN 3  // Botao entre D3 e GND
#define DEBOUNCE_MS 35

Adafruit_NeoPixel fita(NUM_LEDS, LED_PIN, NEO_GRB + NEO_KHZ800);

enum Estado { MENU, IDLE, STRIKE, MISS, SPARE, NORMAL, BLUE, RED, OFF };
Estado estado = MENU;

int onda_pos = 0;
int onda_dir = 1;
int onda_volta = 0;
int onda_maxVoltas = 0;
int onda_ms = 38;
int onda_rastro = 8;

uint8_t cR = 0, cG = 60, cB = 220;
uint8_t rR = 0, rG = 0, rB = 140;

unsigned long onda_ultimo = 0;
unsigned long menu_ultimo = 0;
uint16_t menu_offset = 0;

char buf[12];
uint8_t buf_len = 0;

struct Botao {
  uint8_t pin;
  bool lastRead;
  bool stable;
  unsigned long changedAt;
  const char *event;
};
Botao startButton = {START_PIN, HIGH, HIGH, 0, "START"};
Botao creditButton = {CREDIT_PIN, HIGH, HIGH, 0, "CREDIT"};
unsigned long strikeHoldUntil = 0;

void setup() {
  pinMode(START_PIN, INPUT_PULLUP);
  pinMode(CREDIT_PIN, INPUT_PULLUP);
  Serial.begin(9600);
  fita.begin();
  fita.setBrightness(BRILHO);
  fita.show();
  cmdMenu();
  Serial.println(F("READY:DRAGON_BOWLING:1"));
}

void loop() {
  lerSerial();
  tickBotao(startButton);
  tickBotao(creditButton);
  if (strikeHoldUntil && (long)(millis() - strikeHoldUntil) >= 0) {
    strikeHoldUntil = 0;
    cmdIdle();
  }

  if (estado == MENU) {
    tickMenuRainbow();
  } else if (estado != OFF && estado != BLUE && estado != RED) {
    tickOnda();
  }
}

void tickBotao(Botao &button) {
  bool reading = digitalRead(button.pin);
  if (reading != button.lastRead) button.changedAt = millis();
  button.lastRead = reading;
  if (reading != button.stable && millis() - button.changedAt >= DEBOUNCE_MS) {
    button.stable = reading;
    if (reading == LOW) Serial.println(button.event);
  }
}

void lerSerial() {
  // Processa somente um lote pequeno por ciclo para nao atrasar os botoes.
  uint8_t count = 0;
  while (Serial.available() && count++ < 32) {
    char c = Serial.read();
    if (c == '\n' || c == '\r') {
      if (buf_len) {
        buf[buf_len] = '\0';
        executarComando(buf);
        buf_len = 0;
      }
      continue;
    }
    if (c >= 'a' && c <= 'z') c -= 32;
    if (c >= 'A' && c <= 'Z') {
      if (buf_len < sizeof(buf) - 1) buf[buf_len++] = c;
      else buf_len = 0;
    }
  }
}

void executarComando(const char *cmd) {
  if (strcmp(cmd, "PING") == 0) {
    Serial.println(F("PONG:DRAGON_BOWLING:1"));
  } else if (strcmp(cmd, "MENU") == 0) {
    cmdMenu();
  } else if (strcmp(cmd, "BLUE") == 0) {
    cmdBlue();
  } else if (strcmp(cmd, "RED") == 0) {
    cmdRed();
  } else if (strcmp(cmd, "STRIKE") == 0) {
    cmdStrike();
  } else if (strcmp(cmd, "SPARE") == 0) {
    cmdSpare();
  } else if (strcmp(cmd, "MISS") == 0) {
    cmdMiss();
  } else if (strcmp(cmd, "NORMAL") == 0) {
    cmdNormal();
  } else if (strcmp(cmd, "IDLE") == 0) {
    cmdIdle();
  } else if (strcmp(cmd, "OFF") == 0) {
    cmdOff();
  }
}

void cmdMenu() {
  estado = MENU;
  menu_offset = 0;
  menu_ultimo = 0;
}

void cmdBlue() {
  estado = BLUE;
  setTodos(fita.Color(0, 40, 255));
}

void cmdRed() {
  estado = RED;
  setTodos(fita.Color(255, 0, 0));
}

void setOnda(
  Estado e,
  int maxV,
  int ms,
  int rastro,
  uint8_t cr,
  uint8_t cg,
  uint8_t cb,
  uint8_t rr,
  uint8_t rg,
  uint8_t rb
) {
  estado = e;
  strikeHoldUntil = 0;
  onda_pos = 0;
  onda_dir = 1;
  onda_volta = 0;
  onda_maxVoltas = maxV;
  onda_ms = ms;
  onda_rastro = rastro;

  cR = cr;
  cG = cg;
  cB = cb;

  rR = rr;
  rG = rg;
  rB = rb;

  onda_ultimo = 0;
}

void cmdIdle() {
  setOnda(IDLE, 0, 42, 8, 0, 45, 180, 0, 0, 100);
}

void cmdMiss() {
  setOnda(MISS, 5, 15, 14, 255, 0, 0, 170, 0, 0);
}

void cmdSpare() {
  setOnda(SPARE, 5, 24, 11, 255, 170, 0, 180, 95, 0);
}

void cmdNormal() {
  setOnda(NORMAL, 3, 22, 10, 0, 180, 255, 0, 90, 190);
}

void cmdStrike() {
  setOnda(STRIKE, 8, 6, 22, 0, 80, 255, 0, 0, 255);
}

void cmdOff() {
  estado = OFF;
  apagar();
}

void tickMenuRainbow() {
  unsigned long agora = millis();

  if (agora - menu_ultimo < 18) {
    return;
  }

  menu_ultimo = agora;

  for (int i = 0; i < NUM_LEDS; i++) {
    uint16_t hue1 = menu_offset + (i * 65536L / NUM_LEDS);
    uint16_t hue2 = menu_offset * 2 + ((NUM_LEDS - i) * 65536L / NUM_LEDS);

    uint32_t cor1 = fita.gamma32(fita.ColorHSV(hue1, 255, 255));
    uint32_t cor2 = fita.gamma32(fita.ColorHSV(hue2, 220, 120));

    uint8_t r1 = (uint8_t)(cor1 >> 16);
    uint8_t g1 = (uint8_t)(cor1 >> 8);
    uint8_t b1 = (uint8_t)cor1;

    uint8_t r2 = (uint8_t)(cor2 >> 16);
    uint8_t g2 = (uint8_t)(cor2 >> 8);
    uint8_t b2 = (uint8_t)cor2;

    uint8_t r = (uint8_t)((r1 * 3 + r2) / 4);
    uint8_t g = (uint8_t)((g1 * 3 + g2) / 4);
    uint8_t b = (uint8_t)((b1 * 3 + b2) / 4);

    int brilho_pulso = 185 + (int)(sin((i * 0.34) + (menu_offset * 0.00035)) * 70.0);
    brilho_pulso = constrain(brilho_pulso, 80, 255);

    r = (uint8_t)((int)r * brilho_pulso / 255);
    g = (uint8_t)((int)g * brilho_pulso / 255);
    b = (uint8_t)((int)b * brilho_pulso / 255);

    fita.setPixelColor(i, fita.Color(r, g, b));
  }

  fita.show();

  menu_offset += 420;
}

void tickOnda() {
  unsigned long agora = millis();

  if (agora - onda_ultimo < (unsigned long)onda_ms) {
    return;
  }

  onda_ultimo = agora;

  apagarSemShow();

  for (int r = 0; r < onda_rastro; r++) {
    int pos = onda_pos - (r * onda_dir);

    if (pos < 0 || pos >= NUM_LEDS) {
      continue;
    }

    float t = 1.0f - (float)r / (float)onda_rastro;

    uint8_t R;
    uint8_t G;
    uint8_t B;

    if (r == 0) {
      R = cR;
      G = cG;
      B = cB;
    } else {
      R = (uint8_t)(rR * t);
      G = (uint8_t)(rG * t);
      B = (uint8_t)(rB * t);
    }

    fita.setPixelColor(pos, fita.Color(R, G, B));
  }

  fita.show();

  if (estado == STRIKE) {
    onda_pos += onda_dir;

    if (onda_pos >= NUM_LEDS - 1) {
      onda_pos = NUM_LEDS - 1;
      onda_dir = -1;
      onda_volta++;
    } else if (onda_pos <= 0) {
      onda_pos = 0;
      onda_dir = 1;
      onda_volta++;
    }
  } else {
    onda_pos++;

    if (onda_pos >= NUM_LEDS + onda_rastro) {
      onda_pos = 0;
      onda_volta++;
    }
  }

  if (onda_maxVoltas > 0 && onda_volta >= onda_maxVoltas) {
    if (estado == STRIKE) {
      setTodos(fita.Color(0, 50, 255));
      estado = BLUE;
      strikeHoldUntil = millis() + 750;
      return;
    }

    cmdIdle();
  }
}

void apagarSemShow() {
  for (int i = 0; i < NUM_LEDS; i++) {
    fita.setPixelColor(i, 0);
  }
}

void apagar() {
  apagarSemShow();
  fita.show();
}

void setTodos(uint32_t cor) {
  for (int i = 0; i < NUM_LEDS; i++) {
    fita.setPixelColor(i, cor);
  }

  fita.show();
}
