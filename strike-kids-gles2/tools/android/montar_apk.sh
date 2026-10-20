#!/bin/bash
# APK pronto da TV Box da EDIÇÃO GLES2 (Godot 3.6.3, OpenGL ES 2.0, Mali-450),
# com a câmera e o Arduino:
#   bash tools/android/montar_apk.sh [saida.apk] [nome_da_versao]
# (sem saída: build/android/StrikeKids_GLES2.apk; sem versão: a do preset)
# 1. copia o projeto para uma pasta de trabalho;
# 2. exporta o preset "Android TV Box" com o Godot 3.6.3 headless (modelo
#    legado, sem Gradle, SEM assinar), com uma configuração do editor só dele;
# 3. tira as classes dos plugins (android/plugins/*.aar) para um classes2.dex;
# 4. abre o APK com o apktool, injeta os plugins v1, as atividades USB e o
#    lançador da TV no manifesto (manifesto.py), põe o classes2.dex, os
#    filtros USB e o banner, e remonta;
# 5. assina com a chave do projeto (uber-apk-signer);
# 6. confere (conferir_apk.py, com o androguard).
# Antes, refaça os .aar se mudou o Java: sh tools/android/StrikeCamera/construir.sh
# e sh tools/android/StrikeSerial/construir.sh.
#
# Variáveis (todas com padrão; as ferramentas ficam em FERRAMENTAS, por
# padrão ~/strikekids_ferramentas):
#   GODOT3       Godot 3.6.3 headless (Godot_v3.6.3-stable_linux_headless.64)
#   MODELOS      modelos de exportação 3.6.3 (~/.local/share/godot/templates/3.6.3.stable)
#   APKTOOL_JAR, DX_JAR, UBER_JAR   apktool 2.10, dx 9.0.0_r3, uber-apk-signer 1.3
#   PY           python com o androguard (para conferir; sem ele, só avisa)
#   TRAB         pasta de trabalho (apagada a cada vez)
#   CENARIO      leve|completo: troca strike/video/cenario só na cópia
#   WEBCAM_USB=1 põe também a atividade de encaixe da webcam USB (só serve com
#                a libuvc no APK; veja manifesto.py)
#   SEM_TV=1     sem o lançador/banner da Android TV
set -e
FERRAMENTAS=${FERRAMENTAS:-$HOME/strikekids_ferramentas}
AQUI=$(cd "$(dirname "$0")" && pwd)
P=$(cd "$AQUI/../.." && pwd)
SAIDA=$(realpath -m "${1:-$P/build/android/StrikeKids_GLES2.apk}")
NOME_VERSAO=${2:-}
GODOT3=${GODOT3:-$FERRAMENTAS/Godot_v3.6.3-stable_linux_headless.64}
MODELOS=${MODELOS:-$HOME/.local/share/godot/templates/3.6.3.stable}
APKTOOL_JAR=${APKTOOL_JAR:-$FERRAMENTAS/apktool_2.10.0.jar}
DX_JAR=${DX_JAR:-$FERRAMENTAS/dalvik-dx-9.0.0_r3.jar}
UBER_JAR=${UBER_JAR:-$FERRAMENTAS/uber-apk-signer-1.3.0.jar}
PY=${PY:-$FERRAMENTAS/venv_apk/bin/python}
TRAB=${TRAB:-${TMPDIR:-/tmp}/strikekids_gles2_apk}
CHAVE=$AQUI/strikekids.keystore
OPCOES=""
[ "${WEBCAM_USB:-0}" = 1 ] && OPCOES="$OPCOES --webcam-usb"
[ "${SEM_TV:-0}" = 1 ] && OPCOES="$OPCOES --sem-tv"

for f in "$GODOT3" "$MODELOS/android_release.apk" "$APKTOOL_JAR" "$DX_JAR" "$UBER_JAR" "$CHAVE" \
  "$P/android/plugins/StrikeCamera.aar" "$P/android/plugins/StrikeSerial.aar"; do
  [ -f "$f" ] || { echo "falta: $f" >&2; exit 1; }
done
[ "$(cat "$MODELOS/version.txt")" = "3.6.3.stable" ] || { echo "os modelos em $MODELOS não são do Godot 3.6.3" >&2; exit 1; }
MODELOS=$(cd "$MODELOS" && pwd)
case "$TRAB" in /|"$HOME"|"$P"|"$P"/*) echo "TRAB perigoso: $TRAB" >&2; exit 1 ;; esac
APKTOOL="java -jar $APKTOOL_JAR"
rm -rf "$TRAB"
mkdir -p "$TRAB/projeto" "$TRAB/saida" "$(dirname "$SAIDA")"

echo "== 1. projeto"
# (sem tools/, android/ e build/: nada disso entra no APK)
(cd "$P" && tar --exclude=./tools --exclude=./android --exclude=./build --exclude=./.git -cf - .) | tar -C "$TRAB/projeto" -xf -
NOME_VERSAO="$NOME_VERSAO" CENARIO="${CENARIO:-}" python3 -I - "$TRAB/projeto" <<'PY'
import os, re, sys
os.chdir(sys.argv[1])
p = 'export_presets.cfg'
s = open(p, encoding='utf-8').read()
i = s.index('name="Android TV Box"')
j = s.find('\n[preset.', s.index('.options]', i))
j = len(s) if j < 0 else j
b = s[i:j]
# o APK sai do Godot sem Gradle, sem assinar e sem plugins ligados (o manifesto
# e o classes2.dex dos plugins entram depois)
b = re.sub(r'(?m)^custom_build/use_custom_build=.*$', 'custom_build/use_custom_build=false', b)
b = re.sub(r'(?m)^package/signed=.*$', 'package/signed=false', b)
b = re.sub(r'(?m)^(plugins/[A-Za-z0-9_]+)=.*$', r'\1=false', b)
if os.environ['NOME_VERSAO']:
    b = re.sub(r'(?m)^version/name=.*$', 'version/name="%s"' % os.environ['NOME_VERSAO'], b)
open(p, 'w', encoding='utf-8').write(s[:i] + b + s[j:])
if os.environ['CENARIO']:
    p = 'project.godot'
    s = open(p, encoding='utf-8').read()
    s, n = re.subn(r'(?m)^video/cenario="[a-z]*"', 'video/cenario="%s"' % os.environ['CENARIO'], s)
    assert n == 1, 'strike/video/cenario'
    open(p, 'w', encoding='utf-8').write(s)
print('preparado (versão: %s, cenário: %s)' % (os.environ['NOME_VERSAO'] or 'a do preset', os.environ['CENARIO'] or 'o do projeto'))
PY
grep -n "^version/name\|^package/signed\|^custom_build/use_custom_build" "$TRAB/projeto/export_presets.cfg" | head -3

echo "== 2. exportar (Godot 3.6.3)"
# Configuração do editor só desta exportação (XDG_*: não mexe na do usuário
# nem atrapalha outro Godot aberto). O Godot 3 recusa exportar para Android
# sem: keystore de depuração, pasta do Java (bin/java) e um SDK do Android com
# platform-tools/adb e build-tools/*/apksigner - mesmo exportando SEM assinar.
# O SDK aqui é de mentira (nada é baixado): o adb só responde "nenhum
# aparelho" e o apksigner nunca é chamado (package/signed=false).
CASA=$TRAB/godot
SDK=$TRAB/sdk_falso
mkdir -p "$CASA/config/godot" "$CASA/data/godot/templates" "$CASA/cache" "$SDK/platform-tools" "$SDK/build-tools/falso"
ln -s "$MODELOS" "$CASA/data/godot/templates/3.6.3.stable"
cat > "$SDK/platform-tools/adb" <<'SH'
#!/bin/sh
# adb de mentira (o editor pergunta pelos aparelhos de tempos em tempos)
echo "List of devices attached"
exit 0
SH
cat > "$SDK/build-tools/falso/apksigner" <<'SH'
#!/bin/sh
# apksigner de mentira: o APK sai do Godot sem assinar; o montar_apk.sh assina
echo "apksigner falso: exporte com package/signed=false (o montar_apk.sh assina)" >&2
exit 1
SH
chmod +x "$SDK/platform-tools/adb" "$SDK/build-tools/falso/apksigner"
JAVA_DIR=${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")}
cat > "$CASA/config/godot/editor_settings-3.tres" <<TRES
[gd_resource type="EditorSettings" format=2]

[resource]
export/android/java_sdk_path = "$JAVA_DIR"
export/android/android_sdk_path = "$SDK"
export/android/debug_keystore = "$CHAVE"
export/android/debug_keystore_user = "strikekids"
export/android/debug_keystore_pass = "strikekids"
export/android/shutdown_adb_on_exit = false
TRES
cd "$TRAB/projeto"
XDG_CONFIG_HOME="$CASA/config" XDG_DATA_HOME="$CASA/data" XDG_CACHE_HOME="$CASA/cache" \
  timeout 2400 "$GODOT3" --no-window --path . --export "Android TV Box" "$TRAB/saida/sem_assinatura.apk" \
  > "$TRAB/export.log" 2>&1 || true
# (o "free a NULL RID" é do Godot sem tela: inofensivo)
grep -E "ERROR|WARNING|export:" "$TRAB/export.log" | grep -v "free a NULL RID" | tail -15 || true
if [ ! -s "$TRAB/saida/sem_assinatura.apk" ]; then
  echo "a exportação falhou (log: $TRAB/export.log)" >&2
  tail -40 "$TRAB/export.log" >&2
  exit 1
fi
ls -la "$TRAB/saida/sem_assinatura.apk"

echo "== 3. plugins -> classes2.dex"
mkdir -p "$TRAB/dex" "$TRAB/aar_camera" "$TRAB/aar_serial"
unzip -q -o "$P/android/plugins/StrikeCamera.aar" classes.jar -d "$TRAB/aar_camera"
unzip -q -o "$P/android/plugins/StrikeSerial.aar" classes.jar -d "$TRAB/aar_serial"
# minSdk 21, o mesmo do Godot 3.6.3
java -cp "$DX_JAR" com.android.dx.command.Main --dex --min-sdk-version=21 --output="$TRAB/dex/classes2.dex" \
  "$TRAB/aar_camera/classes.jar" "$TRAB/aar_serial/classes.jar" 2>&1 | grep -v JAVA_TOOL_OPTIONS || true
ls -la "$TRAB/dex/classes2.dex"

echo "== 4. decodificar, injetar, remontar"
# (o framework do apktool também fica na pasta de trabalho)
$APKTOOL d -s -f -p "$TRAB/apktool" -o "$TRAB/dec" "$TRAB/saida/sem_assinatura.apk" 2>&1 | grep -v JAVA_TOOL_OPTIONS | tail -2
# shellcheck disable=SC2086
python3 -I "$AQUI/manifesto.py" "$TRAB/dec" $OPCOES
mkdir -p "$TRAB/dec/res/xml"
cp "$AQUI/StrikeCamera/res/xml/strike_usb_webcam.xml" "$AQUI/StrikeSerial/res/xml/strike_usb_arduino.xml" "$TRAB/dec/res/xml/"
if [ "${SEM_TV:-0}" != 1 ]; then
  mkdir -p "$TRAB/dec/res/drawable-xhdpi"
  cp "$AQUI/tv/strike_banner.png" "$TRAB/dec/res/drawable-xhdpi/strike_banner.png"
fi
cp "$TRAB/dex/classes2.dex" "$TRAB/dec/"
$APKTOOL b -p "$TRAB/apktool" "$TRAB/dec" -o "$TRAB/montado.apk" 2>&1 | grep -v JAVA_TOOL_OPTIONS | tail -2
ls -la "$TRAB/montado.apk"

echo "== 5. assinar"
mkdir -p "$TRAB/assinado"
java -jar "$UBER_JAR" -a "$TRAB/montado.apk" -o "$TRAB/assinado" --ks "$CHAVE" --ksAlias strikekids \
  --ksPass strikekids --ksKeyPass strikekids 2>&1 | grep -E "verified|success|error|ERROR|Subject" || true
cp "$TRAB/assinado/montado-aligned-signed.apk" "$SAIDA"
ls -la "$SAIDA"

echo "== 6. conferir"
if [ -x "$PY" ] && "$PY" -I -c "import androguard" 2>/dev/null; then
  CERT=$(keytool -exportcert -alias strikekids -keystore "$CHAVE" -storepass strikekids 2>/dev/null | sha256sum | cut -d' ' -f1)
  # shellcheck disable=SC2086
  "$PY" -I "$AQUI/conferir_apk.py" "$SAIDA" --certificado "$CERT" $OPCOES
else
  echo "aviso: sem python com androguard ($PY): APK não conferido"
fi
echo MONTAR_OK
