#!/bin/bash
# Refaz android/plugins/classes2.dex: as classes dos plugins StrikeCamera e
# StrikeSerial (tiradas dos .aar) num dex só, para o APK legado do Godot 3.
# Já troca o dex no extras.zip do modelo Android (o GERAR_APK.bat e o
# montar_apk.sh usam o extras.zip pronto): mudança só no Java dos plugins
# não precisa do tools/android/modelo_android.py (apktool), que também põe
# este dex lá quando refaz o modelo. Os construir.sh dos plugins chamam
# este script no fim (o dex acompanha os .aar).
#   bash tools/android/dex_dos_plugins.sh
# DX_JAR: dalvik-dx 9.0.0_r3 (Maven Central), por padrão em FERRAMENTAS
# (~/strikekids_ferramentas), como no montar_apk.sh.
set -e
AQUI=$(cd "$(dirname "$0")" && pwd)
P=$(cd "$AQUI/../.." && pwd)
FERRAMENTAS=${FERRAMENTAS:-$HOME/strikekids_ferramentas}
DX_JAR=${DX_JAR:-$FERRAMENTAS/dalvik-dx-9.0.0_r3.jar}
for f in "$DX_JAR" "$P/android/plugins/StrikeCamera.aar" "$P/android/plugins/StrikeSerial.aar"; do
  [ -f "$f" ] || { echo "falta: $f" >&2; exit 1; }
done
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/camera" "$T/serial"
unzip -q -o "$P/android/plugins/StrikeCamera.aar" classes.jar -d "$T/camera"
unzip -q -o "$P/android/plugins/StrikeSerial.aar" classes.jar -d "$T/serial"
# minSdk 21, o mesmo do Godot 3.6.3
java -cp "$DX_JAR" com.android.dx.command.Main --dex --min-sdk-version=21 --output="$T/classes2.dex" \
  "$T/camera/classes.jar" "$T/serial/classes.jar" 2>&1 | grep -v JAVA_TOOL_OPTIONS || true
[ -s "$T/classes2.dex" ] || { echo "o dx não gerou o classes2.dex" >&2; exit 1; }
cp "$T/classes2.dex" "$P/android/plugins/classes2.dex"
echo "ok: android/plugins/classes2.dex ($(stat -c %s "$P/android/plugins/classes2.dex") bytes)"
EXTRAS="$P/android/modelo_android/extras.zip"
[ -f "$EXTRAS" ] || exit 0
# no extras.zip, com tudo o mais como estava (mesmas datas: sai igual a cada vez)
python3 -I - "$EXTRAS" "$P/android/plugins/classes2.dex" <<'PY'
import os, sys, zipfile
zip_, dex = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(zip_) as z:
    itens = [(i, z.read(i.filename)) for i in z.infolist()]
assert any(i.filename == "classes2.dex" for i, _ in itens), "extras.zip sem classes2.dex"
novo = open(dex, "rb").read()
with zipfile.ZipFile(zip_ + ".parcial", "w") as z:
    for i, dados in itens:
        z.writestr(i, novo if i.filename == "classes2.dex" else dados)
os.replace(zip_ + ".parcial", zip_)
print("ok: classes2.dex no %s" % os.path.basename(zip_))
PY
