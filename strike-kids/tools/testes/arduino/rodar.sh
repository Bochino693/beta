#!/bin/bash
# Compila o firmware para as 4 placas e roda o teste no ATmega328P simulado.
#   tools/testes/arduino/rodar.sh [pasta da biblioteca Adafruit_NeoPixel]
# Precisa (Ubuntu): gcc-avr avr-libc arduino-core-avr simavr libsimavr-dev
set -e
AQUI=$(cd "$(dirname "$0")" && pwd)
NEO=${1:-$HOME/Arduino/libraries/Adafruit_NeoPixel}
T=$(mktemp -d)
for p in nano mega leonardo; do
  echo "== $p"; "$AQUI/compilar.sh" $p "$T/$p.elf" 1 "$NEO"
done
echo "== uno sem LEDs"; "$AQUI/compilar.sh" uno "$T/uno0.elf" 0
echo "== uno (simulado)"; "$AQUI/compilar.sh" uno "$T/uno.elf" 1 "$NEO"
gcc -O2 -o "$T/sim" "$AQUI/sim_firmware.c" -lsimavr -lelf
"$T/sim" "$T/uno.elf"
rm -rf "$T"
