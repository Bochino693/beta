#!/bin/bash
# Refaz tools/android/remendo_apk.jar (Java 8 em diante: roda com o Java que
# o GERAR_APK.bat achar ou baixar).
set -e
AQUI=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
javac --release 8 -d "$T" "$AQUI/RemendoApk.java"
# data fixa nas entradas do jar: o mesmo fonte dá o mesmo jar
jar --create --file "$AQUI/../remendo_apk.jar" --main-class RemendoApk --date=2026-01-01T00:00:00Z -C "$T" .
echo "ok: tools/android/remendo_apk.jar"
