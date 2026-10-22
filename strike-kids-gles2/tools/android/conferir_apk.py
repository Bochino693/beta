# Confere o APK pronto da TV Box (edição GLES2, Godot 3.6.3) feito pelo
# montar_apk.sh: assinatura (e se é a chave do projeto), manifesto (pacote,
# permissões, recursos opcionais, plugins v1, atividades USB, TV), as duas
# ABIs do Godot, o projeto em assets/ e o classes2.dex com os dois plugins e
# os métodos que o GDScript chama (com @UsedByGodot e tipos que o JNI do Godot
# 3.6.3 converte). Precisa do androguard (python do venv):
#   python -I conferir_apk.py <apk> [--certificado <sha256>] [--webcam-usb] [--sem-tv]
# Sai com código 1 se algo falhar.
import hashlib
import sys

from loguru import logger

logger.remove()
from androguard.core.apk import APK  # noqa: E402
from androguard.core.dex import DEX, TypeMapItem  # noqa: E402

ARGS = sys.argv[1:]
if not ARGS or ARGS[0].startswith('--'):
    sys.exit('uso: conferir_apk.py <apk> [--certificado <sha256>] [--webcam-usb] [--sem-tv]')
CAMINHO = ARGS[0]
CERTIFICADO = ARGS[ARGS.index('--certificado') + 1].lower().replace(':', '') if '--certificado' in ARGS else ''
WEBCAM_USB = '--webcam-usb' in ARGS
TV = '--sem-tv' not in ARGS

NS = '{http://schemas.android.com/apk/res/android}'
PACOTE = 'com.lazersport.strikekids.gles2'
ABIS = ['arm64-v8a', 'armeabi-v7a']
PLUGINS = {
    'StrikeCamera': 'com.lazersport.strikecamera.StrikeCamera',
    'StrikeSerial': 'com.lazersport.strikeserial.StrikeSerial',
}
S = 'Ljava/lang/String;'
DIC = 'Lorg/godotengine/godot/Dictionary;'
# o que o GDScript chama (Fotos.gd / ArduinoBridge.gd): nome -> (argumentos, retorno)
API = {
    'Lcom/lazersport/strikecamera/StrikeCamera;': {
        'estado': ('', S), 'fonte': ('', S), 'tem_permissao': ('', 'Z'), 'listar': ('', S),
        'ver': ('Z', 'V'), 'quadros': ('', 'I'), 'largura': ('', 'I'), 'altura': ('', 'I'),
        'quadro': ('', DIC), 'usb_pendente': ('', 'Z'), 'pedir_usb': ('', S),
        'abrir': (S + 'II', 'Z'), 'fechar': ('', 'V'), 'relatorio': ('', S),
    },
    'Lcom/lazersport/strikeserial/StrikeSerial;': {
        'listar': ('', S), 'permissao_pendente': ('', 'Z'), 'pedir_permissao': (S, S),
        'estado': ('', S), 'erro': ('', S), 'abrir': (S + 'I', 'V'), 'ler': ('', S),
        'escrever': (S, 'Z'), 'fechar': ('', 'V'), 'relatorio': ('', S),
    },
}
# tipos que o JNISingleton do Godot 3.6.3 sabe chamar (get_jni_type) e devolver
# (o retorno byte[] NÃO existe lá: "[B" só como argumento ou dentro de um Dictionary)
ARG_OK = {'Z', 'I', 'F', 'D', S, '[I', '[B', '[F', '[' + S, DIC}
RET_OK = {'V', 'Z', 'I', 'F', 'D', S, '[I', '[F', '[' + S, DIC}
USED = 'Lorg/godotengine/godot/plugin/UsedByGodot;'

falhas = []


def checar(ok, texto):
    print(('ok     ' if ok else 'FALHA  ') + texto)
    if not ok:
        falhas.append(texto)


a = APK(CAMINHO)
m = a.get_android_manifest_xml()
app = m.find('application')
res = a.get_android_resources()


def recurso(rid):
    try:
        return res.get_resource_xml_name(int(rid.lstrip('@'), 16))
    except Exception:
        return str(rid)


print('== APK', CAMINHO)
print('pacote:', a.get_package(), '| versão:', a.get_androidversion_name(), '| código:', a.get_androidversion_code())
print('minSdk:', a.get_min_sdk_version(), '| targetSdk:', a.get_target_sdk_version(), '| atividade principal:', a.get_main_activity())
checar(a.get_package() == PACOTE, 'pacote ' + PACOTE)

# assinatura
v = (a.is_signed_v1(), a.is_signed_v2(), a.is_signed_v3())
checar(v[1] or v[2], 'assinado (v1/v2/v3: %s/%s/%s)' % v)
if CERTIFICADO:
    certs = {hashlib.sha256(c.dump()).hexdigest() for c in a.get_certificates()}
    checar(CERTIFICADO in certs, 'assinado com a chave do projeto (sha256 %s...)' % CERTIFICADO[:16])

# permissões e recursos opcionais
perms = sorted(a.get_permissions())
print('permissões:', perms)
checar('android.permission.CAMERA' in perms, 'permissão CAMERA')
feats = {(f.get(NS + 'name'), f.get(NS + 'required')) for f in m.findall('uses-feature')}
gles = [f.get(NS + 'glEsVersion') for f in m.findall('uses-feature') if f.get(NS + 'glEsVersion')]
print('uses-feature:', sorted(str(f) for f in feats), '| glEsVersion:', gles)
checar(gles in (['0x00020000'], ['0x20000'], ['131072']), 'OpenGL ES 2.0 (glEsVersion 0x00020000)')
opcionais = ['android.hardware.camera', 'android.hardware.camera.any', 'android.hardware.camera.external',
             'android.hardware.usb.host'] + (['android.hardware.touchscreen', 'android.software.leanback'] if TV else [])
for nome in opcionais:
    checar((nome, 'false') in feats, 'uses-feature %s opcional' % nome)

# as duas ABIs do Godot (TV Box de 32 e de 64 bits) e o projeto em assets/
arquivos = a.get_files()
print('abis:', sorted({f.split('/')[1] for f in arquivos if f.startswith('lib/')}))
for abi in ABIS:
    checar('lib/%s/libgodot_android.so' % abi in arquivos, 'lib/%s/libgodot_android.so' % abi)
checar('assets/project.binary' in arquivos, 'projeto exportado (assets/project.binary)')

# plugins v1 (o Godot 3.6.3 só procura "org.godotengine.plugin.v1.")
meta = {md.get(NS + 'name'): md.get(NS + 'value') for md in app.findall('meta-data')}
for k in sorted(meta):
    print('meta-data', k, '=', meta[k])
for nome, classe in PLUGINS.items():
    checar(meta.get('org.godotengine.plugin.v1.' + nome) == classe, 'meta-data org.godotengine.plugin.v1.%s = %s' % (nome, classe))
checar(not any(k.startswith('org.godotengine.plugin.v2.') for k in meta), 'nenhum meta-data de plugin v2 (Godot 4)')

# atividades
atividades = {act.get(NS + 'name'): act for act in app.findall('activity')}
principal = atividades.get('com.godot.game.GodotApp')
checar(principal is not None, 'atividade com.godot.game.GodotApp')
if principal is not None:
    cats = [c.get(NS + 'name') for f in principal.findall('intent-filter') for c in f.findall('category')]
    print('GodotApp: screenOrientation =', principal.get(NS + 'screenOrientation'),
          '(11 = userLandscape: o sensor_landscape do projeto no Godot 3) | categorias:', cats)
    checar('android.intent.category.LAUNCHER' in cats, 'GodotApp no lançador (LAUNCHER)')
    if TV:
        checar('android.intent.category.LEANBACK_LAUNCHER' in cats, 'GodotApp no lançador da TV (LEANBACK_LAUNCHER)')
if TV:
    banner = app.get(NS + 'banner')
    checar(banner is not None and 'strike_banner' in recurso(banner), 'banner da TV: %s' % (recurso(banner) if banner else '-'))
usb = [('com.lazersport.strikeserial.StrikeArduinoAtivo', 'strike_usb_arduino')]
if WEBCAM_USB:
    usb.append(('com.lazersport.strikecamera.StrikeUsbAtivo', 'strike_usb_webcam'))
else:
    checar('com.lazersport.strikecamera.StrikeUsbAtivo' not in atividades, 'sem a atividade da webcam USB (sem libuvc no APK)')
for nome, xml in usb:
    act = atividades.get(nome)
    checar(act is not None, 'atividade USB ' + nome)
    if act is None:
        continue
    acoes = [c.get(NS + 'name') for f in act.findall('intent-filter') for c in f.findall('action')]
    rec = [recurso(md.get(NS + 'resource')) for md in act.findall('meta-data')]
    print('   exported=%s noHistory=%s ações=%s filtro=%s' % (act.get(NS + 'exported'), act.get(NS + 'noHistory'), acoes, rec))
    checar('android.hardware.usb.action.USB_DEVICE_ATTACHED' in acoes and any(xml in r for r in rec),
           '   USB_DEVICE_ATTACHED com res/xml/%s.xml' % xml)
    checar('res/xml/%s.xml' % xml in arquivos, '   res/xml/%s.xml no APK' % xml)

# dex: o Godot no classes.dex, os plugins no classes2.dex
print('dex:', sorted(n for n in arquivos if n.endswith('.dex')))
d1 = DEX(a.get_file('classes.dex'))
nomes1 = {c.get_name() for c in d1.get_classes()}
for k in ['Lorg/godotengine/godot/plugin/GodotPlugin;', USED, 'Lorg/godotengine/godot/Dictionary;', 'Lorg/godotengine/godot/Godot;']:
    checar(k in nomes1, 'classes.dex tem ' + k)
# a escolha da tela com o antisserrilhado 4x da placa (tools/android/TelaNitida)
checar(any('tela com antisserrilhado' in str(x) for x in d1.get_strings()),
       'classes.dex com a tela de antisserrilhado da placa (TelaNitida)')
checar('classes2.dex' in arquivos, 'classes2.dex no APK')
d2 = DEX(a.get_file('classes2.dex'))
cm = d2.CM
classes2 = {c.get_name(): c for c in d2.get_classes()}
print('classes2:', len(classes2), 'classes')
for k in ['Lcom/lazersport/strikecamera/StrikeCamera;', 'Lcom/lazersport/strikecamera/StrikeUsbAtivo;',
          'Lcom/lazersport/strikeserial/StrikeSerial;', 'Lcom/lazersport/strikeserial/StrikeArduinoAtivo;',
          'Lcom/lazersport/strikeserial/SerialUtil;']:
    checar(k in classes2, 'classes2.dex tem ' + k)
checar(not any(k.startswith('Landroidx/') for k in classes2), 'classes2.dex sem androidx (o esqueleto do Fragment não vazou)')

conjuntos = {s.get_off(): s for s in d2.map_list.get_item_type(TypeMapItem.ANNOTATION_SET_ITEM)}
anotacoes = {i.get_off(): i for i in d2.map_list.get_item_type(TypeMapItem.ANNOTATION_ITEM)}


def expostos(c):
    """{nome: (argumentos, retorno)} dos métodos com @UsedByGodot."""
    r = {}
    adi = c.annotations_directory_item
    if adi is None:
        return r
    for ma in adi.get_method_annotations():
        tipos = [cm.get_type(anotacoes[ao.get_annotation_off()].get_annotation().get_type_idx())
                 for ao in conjuntos[ma.get_annotations_off()].get_annotation_off_item()]
        if USED in tipos:
            _, nome, (args, ret) = cm.get_method(ma.get_method_idx())
            r[nome] = (args.strip('()').replace(' ', ''), ret)
    return r


for classe, api in API.items():
    c = classes2.get(classe)
    if c is None:
        continue
    checar(c.get_superclassname() == 'Lorg/godotengine/godot/plugin/GodotPlugin;', classe + ' estende GodotPlugin')
    exp = expostos(c)
    faltam = [n for n in api if exp.get(n) != api[n]]
    checar(not faltam, '%s: %d métodos @UsedByGodot com os tipos do GDScript%s' % (
        classe.split('/')[-1].rstrip(';'), len(api), (' - diferentes: %s' % faltam) if faltam else ''))
    for n, (args, ret) in sorted(exp.items()):
        partes = []
        i = 0
        while i < len(args):
            j = i
            while args[j] == '[':
                j += 1
            j = args.index(';', j) + 1 if args[j] == 'L' else j + 1
            partes.append(args[i:j])
            i = j
        ruins = [t for t in partes if t not in ARG_OK] + ([ret] if ret not in RET_OK else [])
        if ruins:
            checar(False, '   %s(%s)%s: tipo que o JNI do 3.6.3 não converte: %s' % (n, args, ret, ruins))

print('CONFERIDO: ' + ('OK' if not falhas else 'FALHOU (%d)' % len(falhas)))
sys.exit(1 if falhas else 0)
