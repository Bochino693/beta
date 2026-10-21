#!/bin/sh
# Monta android/plugins/StrikeSerial.aar e StrikeSerial.gdap (plugin Android v1
# do Godot 3.6.3 do Arduino: USB serial próprio - CDC, CH340, FTDI e CP210x -
# sem biblioteca de fora).
# Precisa de: JDK (javac), os modelos de exportação do Godot 3.6.3 instalados
# (o android_source.zip traz as classes do Godot 3) e internet (Maven Central)
# na primeira vez - ou o android-all.jar já baixado pela versão Godot 4.
#   sh tools/android/StrikeSerial/construir.sh
# O APK da TV Box não usa o build Gradle: o tools/android/montar_apk.sh tira as
# classes deste .aar e as põe no APK (classes2.dex + manifesto).
set -e
AQUI=$(cd "$(dirname "$0")" && pwd)
RAIZ=$(cd "$AQUI/../../.." && pwd)
. "$AQUI/../preparar_classes.sh"
T=$(mktemp -d)
mkdir -p "$T/esqueleto" "$T/classes" "$T/aar"
# o Fragment do androidx só para compilar (não entra no .aar)
javac --release 8 -Xlint:all -Xlint:-options -encoding UTF-8 -d "$T/esqueleto" \
  "$AQUI"/../stubs/androidx/fragment/app/Fragment.java
# Java 8: o dx do montar_apk.sh não lê classes mais novas
javac --release 8 -Xlint:all -Xlint:-options -encoding UTF-8 -cp "$CLASSES:$T/esqueleto" \
  -d "$T/classes" "$AQUI"/src/com/lazersport/strikeserial/*.java
(cd "$T/classes" && jar cf "$T/aar/classes.jar" .)
cp "$AQUI/AndroidManifest.xml" "$T/aar/AndroidManifest.xml"
# o filtro dos Arduinos (atividade de encaixe: "Usar por padrão")
cp -r "$AQUI/res" "$T/aar/res"
printf 'int xml strike_usb_arduino 0x7f140001\n' > "$T/aar/R.txt"
mkdir -p "$RAIZ/android/plugins"
rm -f "$RAIZ/android/plugins/StrikeSerial.aar"
(cd "$T/aar" && jar cfM "$RAIZ/android/plugins/StrikeSerial.aar" AndroidManifest.xml classes.jar R.txt res)
# a descrição do plugin para o Godot 3 (só vale com "Use Custom Build"; o
# preset "Android TV Box" deixa desligado e o montar_apk.sh injeta o plugin)
cat > "$RAIZ/android/plugins/StrikeSerial.gdap" <<'GDAP'
; Plugin Android v1 (Godot 3.6.3) do Arduino no USB da TV Box.
; Feito por tools/android/StrikeSerial/construir.sh (fonte Java lá).

[config]

name="StrikeSerial"
binary_type="local"
binary="StrikeSerial.aar"

[dependencies]

local=[]
remote=[]
custom_maven_repos=[]
GDAP
rm -rf "$T"
echo "ok: android/plugins/StrikeSerial.aar e StrikeSerial.gdap"
# o dex pronto dos dois plugins; depois refaça o extras.zip do modelo Android
bash "$AQUI/../dex_dos_plugins.sh" || echo "aviso: rode tools/android/dex_dos_plugins.sh (android/plugins/classes2.dex)"
echo "agora: python3 -I tools/android/modelo_android.py <android_release.apk> <apktool.jar>"
