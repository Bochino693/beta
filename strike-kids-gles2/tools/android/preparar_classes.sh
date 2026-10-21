# Parte comum de StrikeCamera/construir.sh e StrikeSerial/construir.sh
# (". preparar_classes.sh", depois de definir AQUI e RAIZ): deixa em $CACHE
# (tools/android/.cache) as classes só para COMPILAR os plugins - no aparelho
# valem as da TV Box e as do APK - e põe o classpath em $CLASSES.
#  - android-all.jar: classes do Android 10, do Maven Central (aproveita o
#    mesmo jar já baixado pela versão Godot 4, se houver), conferido pelo SHA-1
#    publicado lá;
#  - godot3-classes.jar: classes do Godot 3.6.3 (GodotPlugin v1, UsedByGodot,
#    Dictionary), tiradas do android_source.zip dos modelos de exportação.
ANDROID_ALL_URL=https://repo1.maven.org/maven2/org/robolectric/android-all/10-robolectric-5803371/android-all-10-robolectric-5803371.jar
ANDROID_ALL_SHA1=873cbe64a7ac6fc2f9f5e2f6a24967fcc7a28ff8
CACHE=${CACHE:-$AQUI/../.cache}
MODELOS=${MODELOS:-$HOME/.local/share/godot/templates/3.6.3.stable}
mkdir -p "$CACHE"
# (130 MB que não vão para o git)
[ -f "$CACHE/.gitignore" ] || printf '*\n' > "$CACHE/.gitignore"

if [ ! -f "$CACHE/android-all.jar" ]; then
  # a versão Godot 4 (pasta irmã strike-kids) talvez já tenha o mesmo jar
  G4=${ANDROID_ALL:-$RAIZ/../strike-kids/tools/android/StrikeCamera/.cache/android-all.jar}
  if [ -f "$G4" ]; then
    cp "$G4" "$CACHE/android-all.jar.tmp"
  else
    curl -sSfL -o "$CACHE/android-all.jar.tmp" "$ANDROID_ALL_URL"
  fi
  if [ "$(sha1sum "$CACHE/android-all.jar.tmp" | cut -d' ' -f1)" != "$ANDROID_ALL_SHA1" ]; then
    rm -f "$CACHE/android-all.jar.tmp"
    echo "erro: android-all.jar com SHA-1 diferente do Maven Central" >&2
    exit 1
  fi
  mv "$CACHE/android-all.jar.tmp" "$CACHE/android-all.jar"
fi

if [ ! -f "$CACHE/godot3-classes.jar" ]; then
  if [ "$(cat "$MODELOS/version.txt" 2>/dev/null)" != "3.6.3.stable" ]; then
    echo "erro: modelos de exportação do Godot 3.6.3 não encontrados em $MODELOS (use MODELOS=pasta)" >&2
    exit 1
  fi
  # extraído numa pasta só dele; daqui só sai o classes.jar
  T3=$(mktemp -d)
  unzip -q -o "$MODELOS/android_source.zip" libs/release/godot-lib.release.aar -d "$T3"
  unzip -q -o "$T3/libs/release/godot-lib.release.aar" classes.jar -d "$T3"
  mv "$T3/classes.jar" "$CACHE/godot3-classes.jar"
  rm -rf "$T3"
fi

CLASSES="$CACHE/android-all.jar:$CACHE/godot3-classes.jar"
