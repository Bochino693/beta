#!/bin/sh
# Poe no android/modelo_android/extras.zip o classes.dex do modelo Android
# oficial do Godot 3.6.3 com o RegularConfigChooser do Strike Kids (a tela da
# TV com antisserrilhado 4x da propria placa - fonte em src/) no lugar do
# original: o remendo_apk.jar (do GERAR_APK.bat e do montar_apk.sh) troca o
# classes.dex do oficial por ele. Rode de novo depois do modelo_android.py
# (ele refaz o extras.zip sem este classes.dex).
# Precisa de: JDK (javac), os modelos de exportacao do Godot 3.6.3 e o
# dalvik-dx 9.0.0_r3 (Maven Central; o mesmo do dex_dos_plugins.sh).
#   sh tools/android/TelaNitida/construir.sh
set -e
AQUI=$(cd "$(dirname "$0")" && pwd)
RAIZ=$(cd "$AQUI/../../.." && pwd)
. "$AQUI/../preparar_classes.sh"
FERRAMENTAS=${FERRAMENTAS:-$HOME/strikekids_ferramentas}
DX_JAR=${DX_JAR:-$FERRAMENTAS/dalvik-dx-9.0.0_r3.jar}
for f in "$DX_JAR" "$MODELOS/android_release.apk" "$RAIZ/android/modelo_android/extras.zip"; do
  [ -f "$f" ] || { echo "falta: $f" >&2; exit 1; }
done
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/classes" "$T/oficial"
# Java 8: o dx nao le classes mais novas
javac --release 8 -Xlint:all -Xlint:-options -encoding UTF-8 -cp "$CLASSES" -d "$T/classes" \
  "$AQUI"/src/org/godotengine/godot/xr/regular/RegularConfigChooser.java
(cd "$T/classes" && jar cf "$T/tela.jar" .)
java -cp "$DX_JAR" com.android.dx.command.Main --dex --min-sdk-version=21 --output="$T/tela.dex" "$T/tela.jar" \
  2>&1 | grep -v JAVA_TOOL_OPTIONS || true
unzip -q -o "$MODELOS/android_release.apk" classes.dex -d "$T/oficial"
# a classe do Strike Kids vem PRIMEIRO: o DexMerger fica com a primeira de
# cada nome (KEEP_FIRST) e todo o resto e o do oficial
java -cp "$DX_JAR" com.android.dx.merge.DexMerger "$T/classes.dex" "$T/tela.dex" "$T/oficial/classes.dex" \
  2>&1 | grep -v JAVA_TOOL_OPTIONS || true
[ -s "$T/classes.dex" ] || { echo "o DexMerger nao gerou o classes.dex" >&2; exit 1; }
# no extras.zip, com a mesma data dos outros (o zip sai igual a cada vez)
python3 -I - "$RAIZ/android/modelo_android/extras.zip" "$T/classes.dex" <<'PY'
import os, sys, zipfile
zip_, dex = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(zip_) as z:
    itens = [(i, z.read(i.filename)) for i in z.infolist() if i.filename != "classes.dex"]
novo = zipfile.ZipInfo("classes.dex", date_time=(2026, 1, 1, 0, 0, 0))
novo.compress_type = zipfile.ZIP_DEFLATED
novo.external_attr = 0o644 << 16
with zipfile.ZipFile(zip_ + ".parcial", "w") as z:
    for i, dados in itens:
        z.writestr(i, dados)
    z.writestr(novo, open(dex, "rb").read())
os.replace(zip_ + ".parcial", zip_)
print("ok: classes.dex (%d bytes) no %s" % (os.path.getsize(dex), os.path.basename(zip_)))
PY
