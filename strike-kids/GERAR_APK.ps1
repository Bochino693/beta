param(
    # 1 = topo do jogo na esquerda do HDMI, -1 = na direita, 0 = sem giro
    [ValidateSet(1, -1, 0)][int]$Giro = 1,
    # Instala na TV Box pelo adb depois de gerar (TV Box ligada no adb)
    [switch]$Instalar,
    # Leva o plugin USB do Arduino (LEDs) dentro do APK.
    [switch]$ComLeds,
    # Sem a camera (sem Gradle): so se o build com camera nao funcionar.
    [switch]$SemCamera
)
# A CAMERA USB (Sigma) precisa do plugin StrikeCamera dentro do APK, e
# plugin exige o build Gradle (na primeira vez ele baixa as dependencias:
# precisa de internet e demora alguns minutos). Se o Gradle falhar, o
# script gera sozinho um APK sem camera (o jogo funciona igual, sem fotos).
$ErrorActionPreference = "Stop"
$Projeto = $PSScriptRoot
$Saida = Join-Path $Projeto "build\android"
$PastaApk = Join-Path $Projeto "APK-Pronto"
$Apk = Join-Path $PastaApk "StrikeKids.apk"
# O Godot exporta aqui (junto com o .idsig da assinatura v4 e outros
# arquivos auxiliares); para APK-Pronto vai SO o .apk.
$ApkExportado = Join-Path $Saida "StrikeKids.apk"
$VersaoGodot = "4.6.1"
$PastaTemplates = Join-Path $env:APPDATA "Godot\export_templates\4.6.1.stable"

Write-Host "STRIKE KIDS - GERAR APK (TV BOX ANDROID)" -ForegroundColor Cyan

# Corrige automaticamente referencias antigas que dependiam do cache UID
# da maquina onde o projeto foi criado.
$ProjectGodot = Join-Path $Projeto "project.godot"
if (-not (Test-Path $ProjectGodot)) { throw "project.godot nao encontrado nesta pasta." }
$PresetAndroid = Join-Path $Projeto "export_presets.cfg"
if (-not (Test-Path $PresetAndroid)) { throw "export_presets.cfg nao encontrado nesta pasta." }
function Preparar([bool]$Camera, [bool]$Leds) {
    $Gradle = $Camera -or $Leds
    $Texto = [IO.File]::ReadAllText($PresetAndroid)
    $Texto = [Regex]::Replace($Texto, '(?m)^gradle_build/use_gradle_build=.*$', "gradle_build/use_gradle_build=$($Gradle.ToString().ToLower())")
    $Texto = [Regex]::Replace($Texto, '(?m)^gradle_build/min_sdk=.*$', 'gradle_build/min_sdk=""')
    $Texto = [Regex]::Replace($Texto, '(?m)^gradle_build/target_sdk=.*$', 'gradle_build/target_sdk=""')
    $Texto = [Regex]::Replace($Texto, '(?m)^package/show_in_android_tv=.*$', 'package/show_in_android_tv=false')
    [IO.File]::WriteAllText($PresetAndroid, $Texto, [Text.UTF8Encoding]::new($false))
    $Config = [IO.File]::ReadAllText($ProjectGodot)
    $Config = [Regex]::Replace($Config, '(?m)^tela/giro=.*$', "tela/giro=$Giro")
    # imagem de inicializacao (logo Lazer & Sport) ja girada como a tela do jogo
    if ($Giro -eq 1) { $Splash = "1" } elseif ($Giro -eq -1) { $Splash = "m1" } else { $Splash = "0" }
    $Config = [Regex]::Replace($Config, '(?m)^boot_splash/image\.android=.*$', "boot_splash/image.android=""res://ui/splash_giro_$Splash.png""")
    # plugins Android ligados (cada um so entra no APK se estiver ligado)
    $Plugins = @()
    $IgnCamera = Join-Path $Projeto "addons\StrikeCamera\.gdignore"
    $IgnLeds = Join-Path $Projeto "addons\DragonUsbSerial\.gdignore"
    $IgnTudo = Join-Path $Projeto "addons\.gdignore"
    if (Test-Path $IgnTudo) { Remove-Item -LiteralPath $IgnTudo -Force }
    if ($Camera) {
        $Plugins += '"res://addons/StrikeCamera/plugin.cfg"'
        if (Test-Path $IgnCamera) { Remove-Item -LiteralPath $IgnCamera -Force }
    } elseif (-not (Test-Path $IgnCamera)) { New-Item -ItemType File -Path $IgnCamera -Force | Out-Null }
    if ($Leds) {
        $Plugins += '"res://addons/DragonUsbSerial/plugin.cfg"'
        if (Test-Path $IgnLeds) { Remove-Item -LiteralPath $IgnLeds -Force }
    } elseif (-not (Test-Path $IgnLeds)) { New-Item -ItemType File -Path $IgnLeds -Force | Out-Null }
    $Config = [Regex]::Replace($Config, '(?ms)^\[editor_plugins\]\s*enabled=PackedStringArray\([^)]*\)\s*', '')
    if ($Plugins.Count -gt 0) {
        $Config = $Config.TrimEnd() + "`r`n`r`n[editor_plugins]`r`n`r`nenabled=PackedStringArray(" + ($Plugins -join ", ") + ")`r`n"
    }
    [IO.File]::WriteAllText($ProjectGodot, $Config, [Text.UTF8Encoding]::new($false))
    Write-Host ("Camera USB: " + $(if ($Camera) { "SIM (plugin StrikeCamera, Gradle)" } else { "nao" }))
    Write-Host ("LEDs (Arduino USB): " + $(if ($Leds) { "SIM" } else { "nao (use -ComLeds)" }))
}
$ComCamera = -not $SemCamera
Preparar $ComCamera $ComLeds.IsPresent
Write-Host "Giro da tela: $Giro"

$NomesGodot = @(
    "Godot_v4.6.1-stable_win64_console.exe",
    "Godot_v4.6.1-stable_win64.exe"
)
$PastasBusca = @($Projeto, "$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop")
$Godot = $null
foreach ($Pasta in $PastasBusca) {
    if (-not (Test-Path $Pasta)) { continue }
    foreach ($Nome in $NomesGodot) {
        $Godot = Get-ChildItem $Pasta -Recurse -File -Filter $Nome -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($Godot) { break }
    }
    if ($Godot) { break }
}
if (-not $Godot) {
    throw "Godot 4.6.1 nao encontrado. Extraia o ZIP completo do Godot 4.6.1 em Downloads."
}

$Sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } elseif ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } elseif (Test-Path "C:\AndroidSdk") { "C:\AndroidSdk" } elseif (Test-Path (Join-Path $env:LOCALAPPDATA "Android\Sdk")) { Join-Path $env:LOCALAPPDATA "Android\Sdk" } else { $null }
if (-not $Sdk -or -not (Test-Path (Join-Path $Sdk "platform-tools\adb.exe"))) {
    throw "Android SDK nao encontrado. Instale-o em C:\AndroidSdk ou defina ANDROID_HOME."
}
$env:ANDROID_HOME = $Sdk
$env:ANDROID_SDK_ROOT = $Sdk
# Sem -ComLeds: usa o template APK pronto do Godot (nao chama Gradle).
# Com -ComLeds: build Gradle (plugin USB do Arduino dentro do APK).

# O editor Godot le Java e Android SDK de editor_settings-4.6.tres.
# JAVA_HOME sozinho nao corrige uma configuracao antiga/corrompida.
$Jdks = New-Object System.Collections.Generic.List[string]
if ($env:JAVA_HOME) { $Jdks.Add($env:JAVA_HOME) }
$Javac = Get-Command javac.exe -ErrorAction SilentlyContinue
if ($Javac) { $Jdks.Add((Split-Path (Split-Path $Javac.Source -Parent) -Parent)) }
foreach ($Base in @("$env:ProgramFiles\Eclipse Adoptium", "$env:ProgramFiles\Java", "$env:ProgramFiles\Microsoft", "$env:ProgramFiles\Amazon Corretto", "C:\Program Files\Eclipse Adoptium")) {
    if (Test-Path $Base) {
        Get-ChildItem -LiteralPath $Base -Directory -ErrorAction SilentlyContinue | ForEach-Object { $Jdks.Add($_.FullName) }
    }
}
$JavaSdk = $null
foreach ($Candidato in ($Jdks | Select-Object -Unique)) {
    $JavaExe = Join-Path $Candidato "bin\java.exe"
    $JavacExe = Join-Path $Candidato "bin\javac.exe"
    if (-not (Test-Path $JavaExe) -or -not (Test-Path $JavacExe)) { continue }
    $InicioJava = New-Object System.Diagnostics.ProcessStartInfo
    $InicioJava.FileName = $JavaExe
    $InicioJava.Arguments = '-version'
    $InicioJava.UseShellExecute = $false
    $InicioJava.RedirectStandardError = $true
    $InicioJava.RedirectStandardOutput = $true
    try {
        $ProcessoJava = [System.Diagnostics.Process]::Start($InicioJava)
        $VersaoJava = $ProcessoJava.StandardError.ReadToEnd() + "`n" + $ProcessoJava.StandardOutput.ReadToEnd()
        $ProcessoJava.WaitForExit()
    } catch { continue }
    if ($VersaoJava -match '(?:version\s+|openjdk\s+)"?17(?:[.\s"]|$)') {
        $JavaSdk = (Resolve-Path -LiteralPath $Candidato).Path
        break
    }
}
if (-not $JavaSdk) {
    throw "JDK 17 nao encontrado. Instale OpenJDK 17 (com javac.exe), defina JAVA_HOME para a pasta do JDK e execute o BAT novamente."
}
$env:JAVA_HOME = $JavaSdk
Write-Host "JDK 17: $JavaSdk"
Write-Host "Android SDK: $Sdk"

$ConfiguracoesEditor = Join-Path $env:APPDATA "Godot\editor_settings-4.6.tres"
New-Item -ItemType Directory -Path (Split-Path $ConfiguracoesEditor -Parent) -Force | Out-Null
$ConfigEditor = if (Test-Path $ConfiguracoesEditor) { [IO.File]::ReadAllText($ConfiguracoesEditor) } else { "" }
if ($ConfigEditor -and -not $ConfigEditor.TrimStart().StartsWith('[gd_resource type="EditorSettings"')) {
    $BackupEditor = "$ConfiguracoesEditor.backup-$(Get-Date -Format yyyyMMdd-HHmmss)"
    Copy-Item -LiteralPath $ConfiguracoesEditor -Destination $BackupEditor
    Write-Host "Configuracao Godot invalida preservada em $BackupEditor"
    $ConfigEditor = ""
}
if (-not $ConfigEditor) { $ConfigEditor = "[gd_resource type=`"EditorSettings`" format=3]`r`n`r`n[resource]`r`n" }
$EntradasAndroid = @{
    'export/android/java_sdk_path' = $JavaSdk.Replace('\', '/')
    'export/android/android_sdk_path' = $Sdk.Replace('\', '/')
}
foreach ($Chave in $EntradasAndroid.Keys) {
    $Valor = $EntradasAndroid[$Chave].Replace('"', '\"')
    $Linha = "$Chave = `"$Valor`""
    if ($ConfigEditor -match "(?m)^$Chave\s*=") {
        $ConfigEditor = [Regex]::Replace($ConfigEditor, "(?m)^$Chave\s*=.*$", $Linha)
    } else {
        $ConfigEditor = [Regex]::Replace($ConfigEditor, '(?m)^\[resource\]\s*$', "[resource]`r`n$Linha")
    }
}
[IO.File]::WriteAllText($ConfiguracoesEditor, $ConfigEditor, [Text.UTF8Encoding]::new($false))

if (-not (Test-Path (Join-Path $PastaTemplates "android_release.apk"))) {
    Write-Host "[1/3] Baixando e instalando Export Templates 4.6.1..."
    $Temporaria = Join-Path $env:TEMP "strike-kids-godot-templates"
    New-Item -ItemType Directory -Path $Temporaria -Force | Out-Null
    $Zip = Join-Path $Temporaria "templates.zip"
    $Extraido = Join-Path $Temporaria "extraido"
    $Url = "https://github.com/godotengine/godot-builds/releases/download/4.6.1-stable/Godot_v4.6.1-stable_export_templates.tpz"
    Invoke-WebRequest -Uri $Url -OutFile $Zip -UseBasicParsing
    if (Test-Path $Extraido) { Remove-Item -LiteralPath $Extraido -Recurse -Force }
    Expand-Archive -LiteralPath $Zip -DestinationPath $Extraido -Force
    $Origem = Join-Path $Extraido "templates"
    if (-not (Test-Path (Join-Path $Origem "android_release.apk"))) {
        throw "Pacote de Export Templates invalido ou incompleto."
    }
    New-Item -ItemType Directory -Path $PastaTemplates -Force | Out-Null
    Copy-Item -Path (Join-Path $Origem "*") -Destination $PastaTemplates -Recurse -Force
} else {
    Write-Host "[1/3] Export Templates 4.6.1 confirmados."
}

if (($ComCamera -or $ComLeds) -and -not (Test-Path (Join-Path $Projeto "android\build\build.gradle"))) {
    Write-Host "Instalando o modelo de build Android (Gradle) no projeto..."
    $Inst = Start-Process -FilePath $Godot.FullName -ArgumentList "--headless --path `"$Projeto`" --install-android-build-template" -NoNewWindow -Wait -PassThru
    if (-not (Test-Path (Join-Path $Projeto "android\build\build.gradle"))) {
        if ($ComLeds) { throw "Nao foi possivel instalar o modelo de build Android (codigo $($Inst.ExitCode))." }
        Write-Host "AVISO: sem o modelo Gradle; o APK sai SEM a camera." -ForegroundColor Yellow
        $ComCamera = $false
        Preparar $false $false
    }
}

# APK RELEASE assinado com a chave debug local (sem depuracao, roda
# liso na TV Box) assinado com a chave debug do Godot.
$Keystore = Join-Path $env:APPDATA "Godot\keystores\debug.keystore"
if (-not (Test-Path $Keystore)) {
    $Keytool = $null
    if ($env:JAVA_HOME -and (Test-Path (Join-Path $env:JAVA_HOME "bin\keytool.exe"))) { $Keytool = Join-Path $env:JAVA_HOME "bin\keytool.exe" }
    elseif (Get-Command keytool -ErrorAction SilentlyContinue) { $Keytool = (Get-Command keytool).Source }
    if (-not $Keytool) { throw "Chave debug.keystore nao encontrada. Abra o Godot 4.6.1 uma vez (ele cria a chave) ou instale o JDK 17." }
    New-Item -ItemType Directory -Path (Split-Path $Keystore) -Force | Out-Null
    & $Keytool -genkeypair -v -keystore $Keystore -storepass android -keypass android -alias androiddebugkey -dname "CN=Android Debug,O=Android,C=US" -keyalg RSA -keysize 2048 -validity 9999
}
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $Keystore
$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = "androiddebugkey"
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = "android"

Write-Host "[2/3] Preparando pasta de saida..."
New-Item -ItemType Directory -Path $Saida -Force | Out-Null
New-Item -ItemType Directory -Path $PastaApk -Force | Out-Null
# APK-Pronto fica vazia antes de cada geracao: no fim ela tem so o APK.
Get-ChildItem -LiteralPath $PastaApk -Force | Remove-Item -Recurse -Force
Get-ChildItem -LiteralPath $Saida -File -Filter "*.apk*" -ErrorAction SilentlyContinue | Remove-Item -Force

Write-Host "[3/3] Exportando APK Android..."
# Mesmo fluxo do GERAR_APK_PRO_ULTRA.ps1 do Dragon Bowling.
# Nao cria uma sessao --editor --import separada: no Windows do usuario
# essa sessao termina em 0xC0000005 durante a importacao de fontes.
# O proprio exportador do Godot prepara os recursos necessarios.
$Log = Join-Path $Saida "exportacao-godot.log"
$ErrosLog = Join-Path $Saida "exportacao-godot-erros.log"
if (Test-Path $Log) { Remove-Item -LiteralPath $Log -Force }
if (Test-Path $ErrosLog) { Remove-Item -LiteralPath $ErrosLog -Force }

function Exportar() {
    if (Test-Path $Log) { Remove-Item -LiteralPath $Log -Force }
    if (Test-Path $ErrosLog) { Remove-Item -LiteralPath $ErrosLog -Force }
    if (Test-Path $ApkExportado) { Remove-Item -LiteralPath $ApkExportado -Force }
    $Argumentos = "--headless --path `"$Projeto`" --export-release `"Android TV Box`" `"$ApkExportado`""
    $Processo = Start-Process -FilePath $Godot.FullName -ArgumentList $Argumentos -NoNewWindow -Wait -PassThru -RedirectStandardOutput $Log -RedirectStandardError $ErrosLog
    if (Test-Path $Log) { Get-Content -LiteralPath $Log | Out-Host }
    if (Test-Path $ErrosLog) { Get-Content -LiteralPath $ErrosLog | Out-Host }
    $TextoLog = ""
    if (Test-Path $Log) { $TextoLog += [IO.File]::ReadAllText($Log) }
    if (Test-Path $ErrosLog) { $TextoLog += "`n" + [IO.File]::ReadAllText($ErrosLog) }
    if ($TextoLog -match "SCRIPT ERROR: Parse Error|Failed to load script|Failed to create an autoload") {
        throw "Existe erro de sintaxe em um script Godot. Consulte build\android\exportacao-godot.log."
    }
    return ($Processo.ExitCode -eq 0) -and (Test-Path $ApkExportado)
}
$Ok = Exportar
if (-not $Ok -and $ComCamera -and -not $ComLeds) {
    Write-Host "`nAVISO: o build com a camera (Gradle) falhou. Gerando o APK SEM camera..." -ForegroundColor Yellow
    Copy-Item -LiteralPath $Log -Destination (Join-Path $Saida "exportacao-com-camera.log") -Force -ErrorAction SilentlyContinue
    $ComCamera = $false
    Preparar $false $false
    $Ok = Exportar
}
if (-not $Ok) {
    throw "O APK nao foi criado. Consulte build\android\exportacao-godot.log e exportacao-godot-erros.log."
}
Copy-Item -LiteralPath $ApkExportado -Destination $Apk -Force
# Garante: nada alem do APK na pasta de entrega.
Get-ChildItem -LiteralPath $PastaApk -Force | Where-Object { $_.FullName -ne (Get-Item $Apk).FullName } | Remove-Item -Recurse -Force
$Tamanho = (Get-Item $Apk).Length
if ($Tamanho -lt 1MB) { throw "O APK foi criado incompleto (menos de 1 MB)." }

$Hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Apk).Hash
Write-Host "`nAPK GERADO COM SUCESSO" -ForegroundColor Green
Write-Host "Arquivo: $Apk"
Write-Host ("Tamanho: {0:N2} MB" -f ($Tamanho / 1MB))
Write-Host "SHA256: $Hash"
Write-Host "Instale este APK na TV Box. O jogo gira internamente; mantenha o HDMI em paisagem (deitado)."
if ($ComCamera) { Write-Host "Camera USB: incluida (ligue a webcam na TV Box e confira no menu do operador > TESTAR CAMERA)." }
else { Write-Host "Camera USB: NAO incluida neste APK (o jogo usa os mascotes no lugar das fotos)." -ForegroundColor Yellow }

if ($Instalar) {
    $Adb = Join-Path $Sdk "platform-tools\adb.exe"
    & $Adb install -r $Apk
    & $Adb shell monkey -p com.lazersport.strikekids -c android.intent.category.LAUNCHER 1
}
