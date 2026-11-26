#!/bin/bash
# TESTE DO FIRMWARE DO ARDUINO NO PC (sem placa): compila as duas versoes
# - arduino/1_RELE_principal (RELE/SERVO, sem ponte H) e
# arduino/2_PONTE_H (PONTE H) - com um Arduino de mentira (mock/)
# e simula a porta (ponte H pelo tempo e com fim de curso, porta presa,
# inversao, o tempo e o fim de curso escolhidos no menu, so a ponte H sem
# servo e rele; SO O JOGO MANDA - "AT", ruido e eco da TV Box ligando nao
# mexem na porta nem ligam o vigia; o rele de PULSO - nenhum pulso ao ligar, um pulso por
# mudanca, descanso entre pulsos, vigia do jogo, desgaste da EEPROM - e o de
# NIVEL com o servo, sem ponte H), as FICHAS (fila na EEPROM confirmada pelo
# jogo), o moedeiro NA e NF (so o pulso certo de 15-250 ms conta), o START e os sensores. Confere tambem que as
# duas versoes tem o MESMO codigo (so o comentario do comeco e as linhas
# USAR_PONTE_H, USAR_SERVO e RELE_PULSO mudam).
#
#     bash tools/testes/arduino/testar_firmware.sh
#
# Precisa so do g++. Cada variante troca um ajuste do .ino (sed) e compila.
set -e
AQUI="$(cd "$(dirname "$0")" && pwd)"
RELE="$AQUI/../../../arduino/1_RELE_principal/strike_kids_rele/strike_kids_rele.ino"
PONTE="$AQUI/../../../arduino/2_PONTE_H/strike_kids_ponte_h/strike_kids_ponte_h.ino"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
falhou=0
# o mesmo codigo nas duas: tira o comentario do comeco e a linha do USAR_PONTE_H
corpo() { sed -n '/^#include <EEPROM.h>/,$p' "$1" | grep -v -e '^#define USAR_PONTE_H ' -e '^#define USAR_SERVO ' -e '^#define RELE_PULSO '; }
if ! diff <(corpo "$RELE") <(corpo "$PONTE") > "$TMP/diferenca"; then
  echo "  FALHOU: as duas versoes do .ino tem codigo diferente:"; cat "$TMP/diferenca"; falhou=1
fi
grep -q '^#define USAR_PONTE_H 0 ' "$RELE" || { echo "  FALHOU: strike_kids_rele sem USAR_PONTE_H 0"; falhou=1; }
grep -q '^#define USAR_PONTE_H 1 ' "$PONTE" || { echo "  FALHOU: strike_kids_ponte_h sem USAR_PONTE_H 1"; falhou=1; }
grep -q '^#define RELE_PULSO 1 ' "$RELE" || { echo "  FALHOU: strike_kids_rele sem RELE_PULSO 1"; falhou=1; }
grep -q '^#define RELE_PULSO 0 ' "$PONTE" || { echo "  FALHOU: strike_kids_ponte_h sem RELE_PULSO 0"; falhou=1; }
variante() {  # nome, .ino, sed
  sed "$3" "$2" > "$TMP/fw_$1.ino"
  g++ -std=gnu++17 -Wall -Wextra -Wno-unused-parameter -I"$AQUI/mock" -I"$TMP" \
    -DFIRMWARE="\"fw_$1.ino\"" "$AQUI/teste_firmware.cpp" -o "$TMP/t_$1"
}
variante padrao "$PONTE" 's/x/x/'
variante fc "$PONTE" 's/^#define PONTE_FIM_DE_CURSO 0/#define PONTE_FIM_DE_CURSO 1/'
variante fcnf "$PONTE" 's/^#define PONTE_FIM_DE_CURSO 0/#define PONTE_FIM_DE_CURSO 1/; s/^#define FC_NF 0/#define FC_NF 1/'
variante inv "$PONTE" 's/^#define PONTE_INVERTIDA 0/#define PONTE_INVERTIDA 1/'
variante soponte "$PONTE" 's/^#define USAR_SERVO 1/#define USAR_SERVO 0/; s/^#define USAR_RELE 1/#define USAR_RELE 0/'
variante rele "$RELE" 's/x/x/'
# (16) sem o sensor da cancela: lembra pela EEPROM (o firmware ate o 15)
SEMSENSOR='s/^#define USAR_SENSOR_TRAVA 1 /#define USAR_SENSOR_TRAVA 0 /'
variante relesemsensor "$RELE" "$SEMSENSOR"
# (15) a trava que FECHA sozinha sem energia (PORTA_FECHA_SEM_ENERGIA 1)
variante relefecha "$RELE" "s/^#define PORTA_FECHA_SEM_ENERGIA 0 /#define PORTA_FECHA_SEM_ENERGIA 1 /; $SEMSENSOR"
NIVEL='s/^#define RELE_PULSO 1 /#define RELE_PULSO 0 /; s/^#define USAR_SERVO 0 /#define USAR_SERVO 1 /'
variante nivel "$RELE" "$NIVEL"
variante nivel5 "$RELE" "$NIVEL; s/^#define RELE_TEMPO_MAX_S 0 /#define RELE_TEMPO_MAX_S 5 /"
variante semleds "$RELE" "s/^#define USAR_LEDS 1/#define USAR_LEDS 0/; $SEMSENSOR"
variante pulsohigh "$RELE" "s/^#define RELE_LIGA_EM_LOW 1 /#define RELE_LIGA_EM_LOW 0 /; $SEMSENSOR"
variante pulsohighsensor "$RELE" 's/^#define RELE_LIGA_EM_LOW 1 /#define RELE_LIGA_EM_LOW 0 /'
grep -q '^#define RELE_TEMPO_MAX_S 5 ' "$TMP/fw_nivel5.ino" || { echo "  FALHOU: variante nivel5"; falhou=1; }
grep -q '^#define RELE_PULSO 0 ' "$TMP/fw_nivel.ino" || { echo "  FALHOU: variante nivel"; falhou=1; }
grep -q '^#define RELE_LIGA_EM_LOW 0 ' "$TMP/fw_pulsohigh.ino" || { echo "  FALHOU: variante pulsohigh"; falhou=1; }
grep -q '^#define USAR_SENSOR_TRAVA 0 ' "$TMP/fw_relesemsensor.ino" || { echo "  FALHOU: variante relesemsensor"; falhou=1; }
grep -q '^#define PORTA_FECHA_SEM_ENERGIA 1 ' "$TMP/fw_relefecha.ino" || { echo "  FALHOU: variante relefecha"; falhou=1; }
for t in "padrao tempo" "padrao ficha_nf" "padrao ficha_na" "fc fim_de_curso" "fc travou" \
         "fcnf fim_de_curso" "inv invertida" "padrao menu" "soponte so_ponte" \
         "relesemsensor pulso" "pulsohigh pulso" "semleds pulso" "relesemsensor desliga_jogando" "pulsohigh desliga_jogando" "relesemsensor antigo4" "relefecha energia" "relesemsensor ligou" "relefecha ligou" "pulsohigh ligou" "relefecha intruso" "rele fichas" "padrao fichas" \
         "relesemsensor intruso" "pulsohigh intruso" "padrao intruso" \
         "rele livre" "rele pinos" "padrao pinos" \
         "nivel rele" "nivel5 rele" "relesemsensor sem_ponte" "semleds sem_ponte" "nivel sem_ponte" \
         "rele ficha_nf" "rele ficha_na" "rele ficha_pulso" "padrao ficha_pulso" \
         "rele sensor" "rele sensor_travou" "pulsohighsensor sensor" "pulsohighsensor sensor_travou"; do
  set -- $t
  "$TMP/t_$1" "$2" || falhou=1
done
[ $falhou = 0 ] && echo "FIRMWARE OK" || { echo "FIRMWARE COM ERRO"; exit 1; }
