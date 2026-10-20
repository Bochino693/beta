# Põe no manifesto decodificado (apktool) do APK legado do Godot 3.6.3 o que os
# plugins StrikeCamera e StrikeSerial pedem (o mesmo dos AndroidManifest.xml
# deles, com o meta-data dos plugins v1) e o lançador da TV. Quem chama é o
# montar_apk.sh, que também copia res/xml, o banner e o classes2.dex.
#   python3 -I manifesto.py <pasta_decodificada> [--webcam-usb] [--sem-tv]
#   --webcam-usb  põe também a atividade de encaixe da WEBCAM USB
#                 (StrikeUsbAtivo, filtro res/xml/strike_usb_webcam.xml). Fora
#                 por padrão, como no APK Godot 4: sem a libuvc no APK a
#                 permissão USB da webcam não serve para nada, e com o filtro o
#                 Android perguntava "abrir o Strike Kids?" a cada boot com a
#                 câmera ligada.
#   --sem-tv      sem a categoria LEANBACK_LAUNCHER e sem o banner (só o
#                 lançador comum).
import os
import re
import sys

args = sys.argv[1:]
opcoes = {a for a in args if a.startswith('--')}
pastas = [a for a in args if not a.startswith('--')]
desconhecidas = opcoes - {'--webcam-usb', '--sem-tv'}
if len(pastas) != 1 or desconhecidas:
    sys.exit('uso: manifesto.py <pasta_decodificada> [--webcam-usb] [--sem-tv]')
webcam_usb = '--webcam-usb' in opcoes
tv = '--sem-tv' not in opcoes

p = os.path.join(pastas[0], 'AndroidManifest.xml')
s = open(p, encoding='utf-8').read()
assert 'org.godotengine.plugin.v1.Strike' not in s, 'manifesto já injetado (decodifique de novo)'


def trocar_uma(texto, velho, novo, nome):
    assert texto.count(velho) == 1, nome
    return texto.replace(velho, novo)


# As <uses-permission> que o Godot 3.6.3 acrescenta (permissions/* do preset)
# saem com o namespace "android" (o prefixo) no lugar da URI. O Android aceita
# (acha o atributo pelo id), mas o apktool decodifica como
# <uses-permission xmlns:n1="android" n1:name="..."/> e o aapt2 recompilaria
# SEM o android:name: a permissão da câmera sumiria do APK. Volta a ser android:name.
def _namespace_certo(m):
    prefixo = m.group(2)
    atributos = re.sub(r'(?<=\s)%s:' % re.escape(prefixo), 'android:', m.group(3))
    return '<%s%s%s>' % (m.group(1), atributos, m.group(4))


s, n = re.subn(r'<([\w.-]+) xmlns:(\w+)="android"((?:\s+[\w:.-]+="[^"]*")*)\s*(/?)>', _namespace_certo, s)
assert 'xmlns:' not in s.split('<manifest', 1)[1].split('>', 1)[1], 'namespace estranho que sobrou no manifesto'
assert '<uses-permission android:name="android.permission.CAMERA"/>' in s, 'permissao CAMERA (permissions/camera no preset)'
print('permissões com o namespace consertado:', n)


# câmera e USB: nada obrigatório (a TV Box não tem câmera própria) - e, para a
# TV, nem tela de toque nem o modo leanback
m = re.findall(r'<uses-feature android:glEsVersion="0x000[23]0000" android:required="true"/>', s)
assert len(m) == 1, 'glEsVersion'
recursos = '''
    <uses-feature android:name="android.hardware.camera" android:required="false"/>
    <uses-feature android:name="android.hardware.camera.any" android:required="false"/>
    <uses-feature android:name="android.hardware.camera.external" android:required="false"/>
    <uses-feature android:name="android.hardware.usb.host" android:required="false"/>'''
if tv:
    recursos += '''
    <uses-feature android:name="android.hardware.touchscreen" android:required="false"/>
    <uses-feature android:name="android.software.leanback" android:required="false"/>'''
s = trocar_uma(s, m[0], m[0] + recursos, 'glEsVersion')

# os plugins v1 (o Godot 3.6.3 procura "org.godotengine.plugin.v1.<Nome>" no
# manifesto) e a atividade de encaixe do Arduino ("Usar por padrão")
plugins = '''        <meta-data android:name="org.godotengine.plugin.v1.StrikeCamera" android:value="com.lazersport.strikecamera.StrikeCamera"/>
'''
if webcam_usb:
    plugins += '''        <activity android:excludeFromRecents="true" android:exported="true" android:name="com.lazersport.strikecamera.StrikeUsbAtivo" android:noHistory="true" android:theme="@android:style/Theme.Translucent.NoTitleBar">
            <intent-filter>
                <action android:name="android.hardware.usb.action.USB_DEVICE_ATTACHED"/>
            </intent-filter>
            <meta-data android:name="android.hardware.usb.action.USB_DEVICE_ATTACHED" android:resource="@xml/strike_usb_webcam"/>
        </activity>
'''
plugins += '''        <activity android:excludeFromRecents="true" android:exported="true" android:name="com.lazersport.strikeserial.StrikeArduinoAtivo" android:noHistory="true" android:theme="@android:style/Theme.Translucent.NoTitleBar">
            <intent-filter>
                <action android:name="android.hardware.usb.action.USB_DEVICE_ATTACHED"/>
            </intent-filter>
            <meta-data android:name="android.hardware.usb.action.USB_DEVICE_ATTACHED" android:resource="@xml/strike_usb_arduino"/>
        </activity>
        <meta-data android:name="org.godotengine.plugin.v1.StrikeSerial" android:value="com.lazersport.strikeserial.StrikeSerial"/>
'''
s = trocar_uma(s, '    </application>', plugins + '    </application>', 'fim do application')

# lançador da TV (Android TV / Google TV): o jogo aparece também na fileira de
# apps, com o banner (res/drawable-xhdpi/strike_banner.png, 320x180: o logo
# sobre a cor do splash; o montar_apk.sh copia)
if tv:
    a = '<category android:name="android.intent.category.LAUNCHER"/>'
    s = trocar_uma(s, a, a + '\n                <category android:name="android.intent.category.LEANBACK_LAUNCHER"/>', 'categoria LAUNCHER')
    assert 'android:banner=' not in s, 'banner já existe'
    s = trocar_uma(s, '<application ', '<application android:banner="@drawable/strike_banner" ', 'application')

open(p, 'w', encoding='utf-8').write(s)
print('manifesto ok (webcam usb: %s, tv: %s)' % ('sim' if webcam_usb else 'nao', 'sim' if tv else 'nao'))
