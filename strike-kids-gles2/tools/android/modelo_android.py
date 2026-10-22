"""Faz android/modelo_android/extras.zip: o que o modelo Android oficial do
Godot 3.6.3 (android_release.apk) precisa ganhar para virar o modelo do
Strike Kids - os plugins da câmera (StrikeCamera) e do Arduino
(StrikeSerial) no manifesto (meta-data dos plugins v1 e a atividade de
encaixe do Arduino), as classes deles (classes2.dex), os filtros USB, o
banner e o lançador da TV.

    python3 -I tools/android/modelo_android.py <android_release.apk oficial> <apktool.jar>

Com o modelo assim, o próprio Godot exporta o APK já com os plugins: o
GERAR_APK.bat (Windows) e o montar_apk.sh (Linux) só juntam o oficial com
os extras (tools/android/remendo_apk.jar), exportam e assinam - sem
apktool nem aapt2 na hora de gerar. Rode de novo quando mudar o manifesto
dos plugins, os filtros USB, o banner ou o classes2.dex - e depois o
tools/android/TelaNitida/construir.sh (põe nos extras o classes.dex com a
tela de antisserrilhado 4x da placa).
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

AQUI = os.path.dirname(os.path.abspath(__file__))
P = os.path.dirname(os.path.dirname(AQUI))
SAIDA = os.path.join(P, "android", "modelo_android", "extras.zip")


def trocar_uma(texto, velho, novo, nome):
    assert texto.count(velho) == 1, "manifesto do modelo inesperado: " + nome
    return texto.replace(velho, novo)


def injetar(manifesto):
    s = open(manifesto, encoding="utf-8").read()
    assert "org.godotengine.plugin.v1.Strike" not in s, "manifesto já injetado"
    gl = '<uses-feature android:glEsVersion="0x00020000" android:required="true"/>'
    # câmera e USB: nada obrigatório (a TV Box não tem câmera própria) - e,
    # para a TV, nem tela de toque nem o modo leanback. A permissão da
    # câmera vem daqui (e não do preset: a que o Godot 3 acrescenta sai com
    # o prefixo "android" no lugar do endereço do namespace, que nem todo
    # leitor de manifesto entende)
    s = trocar_uma(s, gl, gl + '''
    <uses-feature android:name="android.hardware.camera" android:required="false"/>
    <uses-feature android:name="android.hardware.camera.any" android:required="false"/>
    <uses-feature android:name="android.hardware.camera.external" android:required="false"/>
    <uses-feature android:name="android.hardware.usb.host" android:required="false"/>
    <uses-feature android:name="android.hardware.touchscreen" android:required="false"/>
    <uses-feature android:name="android.software.leanback" android:required="false"/>
    <uses-permission android:name="android.permission.CAMERA"/>''', "glEsVersion")
    # os plugins v1 (o Godot 3.6.3 procura "org.godotengine.plugin.v1.<Nome>"
    # no manifesto) e a atividade de encaixe do Arduino ("Usar por padrão")
    s = trocar_uma(s, "    </application>", '''        <meta-data android:name="org.godotengine.plugin.v1.StrikeCamera" android:value="com.lazersport.strikecamera.StrikeCamera"/>
        <activity android:excludeFromRecents="true" android:exported="true" android:name="com.lazersport.strikeserial.StrikeArduinoAtivo" android:noHistory="true" android:theme="@android:style/Theme.Translucent.NoTitleBar">
            <intent-filter>
                <action android:name="android.hardware.usb.action.USB_DEVICE_ATTACHED"/>
            </intent-filter>
            <meta-data android:name="android.hardware.usb.action.USB_DEVICE_ATTACHED" android:resource="@xml/strike_usb_arduino"/>
        </activity>
        <meta-data android:name="org.godotengine.plugin.v1.StrikeSerial" android:value="com.lazersport.strikeserial.StrikeSerial"/>
    </application>''', "fim do application")
    # lançador da TV (Android TV / Google TV), com o banner
    a = '<category android:name="android.intent.category.LAUNCHER"/>'
    s = trocar_uma(s, a, a + '\n                <category android:name="android.intent.category.LEANBACK_LAUNCHER"/>', "categoria LAUNCHER")
    assert "android:banner=" not in s, "banner já existe"
    s = trocar_uma(s, "<application ", '<application android:banner="@drawable/strike_banner" ', "application")
    open(manifesto, "w", encoding="utf-8").write(s)


def entra_nos_extras(nome):
    return nome.startswith("res/") or nome in ("resources.arsc", "AndroidManifest.xml", "classes2.dex")


def main():
    if len(sys.argv) != 3:
        sys.exit("uso: modelo_android.py <android_release.apk oficial> <apktool.jar>")
    oficial, apktool = sys.argv[1], sys.argv[2]
    t = tempfile.mkdtemp(prefix="modelo_android_")
    try:
        def apk(*args):
            subprocess.run(["java", "-jar", apktool] + list(args), check=True)
        apk("d", "-s", "-f", "-p", os.path.join(t, "fw"), "-o", os.path.join(t, "dec"), oficial)
        dec = os.path.join(t, "dec")
        # o apktool decodifica res/drawable-hdpi-v4/x.png em res/drawable-hdpi/
        # e o aapt2 remontaria sem o "-v4": o Godot não acharia os ícones e a
        # abertura para trocar pelos do jogo. Cada arquivo volta para a pasta
        # com o nome do oficial.
        oficiais = [i.filename for i in zipfile.ZipFile(oficial).infolist() if i.filename.startswith("res/")]
        for n in oficiais:
            _, d, f = n.split("/", 2)
            d0 = re.sub(r"-v\d+$", "", d)
            origem = os.path.join(dec, "res", d0, f)
            if d0 != d and os.path.exists(origem) and not os.path.exists(os.path.join(dec, "res", d, f)):
                os.makedirs(os.path.join(dec, "res", d), exist_ok=True)
                os.rename(origem, os.path.join(dec, "res", d, f))
        for d in os.listdir(os.path.join(dec, "res")):
            if not os.listdir(os.path.join(dec, "res", d)):
                os.rmdir(os.path.join(dec, "res", d))
        injetar(os.path.join(dec, "AndroidManifest.xml"))
        os.makedirs(os.path.join(dec, "res", "xml"), exist_ok=True)
        for f in ("StrikeSerial/res/xml/strike_usb_arduino.xml", "StrikeCamera/res/xml/strike_usb_webcam.xml"):
            shutil.copy(os.path.join(AQUI, f), os.path.join(dec, "res", "xml"))
        os.makedirs(os.path.join(dec, "res", "drawable-xhdpi"), exist_ok=True)
        shutil.copy(os.path.join(AQUI, "tv", "strike_banner.png"), os.path.join(dec, "res", "drawable-xhdpi"))
        shutil.copy(os.path.join(P, "android", "plugins", "classes2.dex"), dec)
        montado = os.path.join(t, "modelo.apk")
        apk("b", "-p", os.path.join(t, "fw"), dec, "-o", montado)

        zo = zipfile.ZipFile(oficial)
        zm = zipfile.ZipFile(montado)
        nomes_o = {i.filename for i in zo.infolist()}
        nomes_m = {i.filename for i in zm.infolist()}
        # (o que não é recurso, o remendo copia do oficial: bibliotecas,
        # classes.dex, META-INF...) os nomes que o Godot troca na exportação
        # (ícones e abertura) continuam lá
        sumiu = sorted(n for n in nomes_o if n.startswith("res/") and n not in nomes_m)
        assert not sumiu, "recursos do oficial com outro nome no modelo: %s" % sumiu[:10]
        os.makedirs(os.path.dirname(SAIDA), exist_ok=True)
        n = 0
        with zipfile.ZipFile(SAIDA + ".parcial", "w") as zs:
            for i in zm.infolist():
                if not entra_nos_extras(i.filename):
                    continue
                novo = zipfile.ZipInfo(i.filename, date_time=(2026, 1, 1, 0, 0, 0))
                novo.compress_type = i.compress_type
                novo.external_attr = 0o644 << 16
                zs.writestr(novo, zm.read(i.filename))
                n += 1
        os.replace(SAIDA + ".parcial", SAIDA)
        print("ok: %s (%d arquivos, %d bytes)" % (os.path.relpath(SAIDA, P), n, os.path.getsize(SAIDA)))
    finally:
        shutil.rmtree(t, ignore_errors=True)


if __name__ == "__main__":
    main()
