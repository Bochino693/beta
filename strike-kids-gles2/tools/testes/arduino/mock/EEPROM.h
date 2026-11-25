#pragma once
struct EEPROMMock {
  uint8_t m[1024];
  int gravacoes[1024];   // quantas vezes cada endereco foi gravado de verdade
  EEPROMMock() { memset(m, 0xFF, sizeof m); memset(gravacoes, 0, sizeof gravacoes); }
  uint8_t read(int a) { return m[a]; }
  void update(int a, uint8_t v) { if (m[a] != v) { m[a] = v; gravacoes[a]++; } }
};
extern EEPROMMock EEPROM;
