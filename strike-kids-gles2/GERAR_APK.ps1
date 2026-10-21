param(
    # 1 = topo do jogo na esquerda do HDMI, -1 = na direita, 0 = sem giro
    [ValidateSet(1, -1, 0)][int]$Giro = 1,
    # Instala na TV Box pelo adb depois de gerar (TV Box ligada no adb)
    [switch]$Instalar,
    # Nome da versao (ex.: 5.7-gles2); sem ele vale o do export_presets.cfg
    [string]$Versao = "",
    # Caminho do Godot 3.6.3 (opcional: se nao achar, o script baixa)
    [string]$CaminhoGodot = "",
    # Pasta de trabalho (opcional: o padrao e C:\StrikeKidsGLES2)
    [string]$PastaTrabalho = ""
)
# STRIKE KIDS - EDICAO OPENGL ES 2.0 (Godot 3.6.3) - GERAR APK DA TV BOX.
# Rode pelo GERAR_APK.bat.
#
# Faz tudo sozinho e mostra cada passo na tela (o mesmo caminho do APK
# pronto, tools/android/montar_apk.sh, agora no Windows):
#  - trabalha numa COPIA do projeto numa pasta curta e sem acentos
#    (C:\StrikeKidsGLES2): o projeto original nao e alterado;
#  - acha ou BAIXA o que faltar: Godot 3.6.3, Java, o "platform-tools" do
#    Android (o adb: o Godot 3 exige), o modelo Android do Godot 3.6.3 (so
#    o android_release.apk, ~50 MB, nao o pacote inteiro) e o assinador
#    (uber-apk-signer). NAO precisa de Gradle nem do SDK inteiro;
#  - monta o MODELO do Strike Kids: o oficial + android\modelo_android\
#    extras.zip (os plugins da camera StrikeCamera e do Arduino StrikeSerial
#    no manifesto, as classes deles, a permissao da camera, os filtros USB e
#    o banner da TV - feito no Linux por tools\android\modelo_android.py);
#  - exporta o jogo com o Godot 3.6.3 (ja sai com os plugins), assina com a
#    chave do projeto e confere;
#  - nenhum passo fica parado para sempre: cada programa tem tempo-limite.
# 1a vez: de 5 a 20 min (downloads). Depois: 2 a 4 min.
# Historico completo: build\android\GERACAO-COMPLETA.log (envie se falhar).

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch { }
try { Add-Type -AssemblyName System.IO.Compression } catch { }
try { Add-Type -AssemblyName System.IO.Compression.FileSystem } catch { }

$Projeto = $PSScriptRoot.TrimEnd('\')
$IdGodot = "3.6.3.stable"
$ExeGodot = "Godot_v3.6.3-stable_win64.exe"
$UrlBase = "https://github.com/godotengine/godot/releases/download/3.6.3-stable"
$UrlGodot = "$UrlBase/Godot_v3.6.3-stable_win64.exe.zip"
$UrlTemplates = "$UrlBase/Godot_v3.6.3-stable_export_templates.tpz"
$NomeTpz = "Godot_v3.6.3-stable_export_templates.tpz"
$UrlPlatformTools = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
# assinador: versao fixa, conferida pelo SHA-256 (o mesmo do montar_apk.sh)
$UrlAssinador = "https://github.com/patrickfav/uber-apk-signer/releases/download/v1.3.0/uber-apk-signer-1.3.0.jar"
$ShaAssinador = "e1299fd6fcf4da527dd53735b56127e8ea922a321128123b9c32d619bba1d835"
$NomePreset = "Android TV Box"
$Pacote = "com.lazersport.strikekids.gles2"
$NomeApk = "StrikeKids_GLES2.apk"

$PastaLogs = Join-Path $Projeto "build\android"
$LogGeral = Join-Path $PastaLogs "GERACAO-COMPLETA.log"
$script:Etapa = 0
$script:TotalEtapas = 9
$script:Inicio = Get-Date

# ------------------------------------------------------------------ tela

function Titulo([string]$Texto) {
    $script:Etapa++
    Write-Host ""
    Write-Host ("[{0}/{1}] {2}" -f $script:Etapa, $script:TotalEtapas, $Texto) -ForegroundColor Cyan
}
function Info([string]$Texto) { Write-Host "    $Texto" }
function Ok([string]$Texto) { Write-Host "    OK: $Texto" -ForegroundColor Green }
function Aviso([string]$Texto) { Write-Host "    AVISO: $Texto" -ForegroundColor Yellow }

function Pasta([string]$Caminho) {
    [void][IO.Directory]::CreateDirectory($Caminho)
    return $Caminho
}

function Apagar([string]$Caminho) {
    if ($Caminho -and (Test-Path -LiteralPath $Caminho)) {
        Remove-Item -LiteralPath $Caminho -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ------------------------------------------------------- rodar programas

# Junta argumentos como o Windows espera (aspas so onde precisa).
function Juntar-Argumentos([string[]]$Lista) {
    $partes = foreach ($a in $Lista) {
        if ($a -eq '') { '""' }
        elseif ($a -match '[\s";=,&()^|<>]') { '"' + (($a -replace '(\\*)"', '$1$1\"') -replace '(\\+)$', '$1$1') + '"' }
        else { $a }
    }
    return ($partes -join ' ')
}

# Mostra na tela o que o programa escreveu no log desde a ultima leitura.
function Mostrar-Novo([string]$Arquivo, [long]$Posicao, [bool]$Tudo) {
    if (-not (Test-Path -LiteralPath $Arquivo)) { return $Posicao }
    try {
        $fs = New-Object IO.FileStream($Arquivo, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
    } catch { return $Posicao }
    try {
        if ($fs.Length -le $Posicao) { return $Posicao }
        [void]$fs.Seek($Posicao, [IO.SeekOrigin]::Begin)
        $n = [int][Math]::Min([long]4MB, [long]($fs.Length - $Posicao))
        $buf = New-Object byte[] $n
        $lidos = $fs.Read($buf, 0, $n)
        if ($lidos -le 0) { return $Posicao }
        # so ate o ultimo fim de linha; o resto fica para a proxima leitura
        $fim = $lidos - 1
        if (-not $Tudo) {
            while ($fim -ge 0 -and $buf[$fim] -ne 10 -and $buf[$fim] -ne 13) { $fim-- }
            if ($fim -lt 0) {
                if ($lidos -lt 4MB) { return $Posicao }
                $fim = $lidos - 1
            }
        }
        $texto = [Text.Encoding]::UTF8.GetString($buf, 0, $fim + 1)
        foreach ($linha in ($texto -split "`r`n|`n|`r")) {
            $l = $linha.TrimEnd()
            if (-not $l) { continue }
            # barras de progresso (sdkmanager): no maximo uma a cada 3 s
            if ($l -match '^\s*\[[=> ]*\]\s*\d+%' -or $l -match '^\s*\d+%') {
                if (((Get-Date) - $script:UltimoProgresso).TotalSeconds -lt 3) { continue }
                $script:UltimoProgresso = Get-Date
            }
            if ($l.Length -gt 300) { $l = $l.Substring(0, 300) + " ..." }
            Write-Host "      $l" -ForegroundColor Gray
            $script:UltimaSaida = Get-Date
        }
        return $Posicao + $fim + 1
    } finally { $fs.Dispose() }
}

# Roda um programa mostrando a saida ao vivo, com tempo-limite (nunca trava
# para sempre). Devolve o codigo de saida (-999 = estourou o tempo).
function Executar {
    param(
        [string]$Programa,
        [string[]]$Argumentos = @(),
        [string]$Log,
        [int]$LimiteMin = 30,
        [string]$Rotulo = "",
        [string]$Entrada = "",
        [string]$Diretorio = "",
        [switch]$Quieto
    )
    $exe = $Programa
    $linha = Juntar-Argumentos $Argumentos
    if ($Programa -match '\.(bat|cmd)$') {
        # .bat roda pelo cmd: /s /c "<linha inteira entre aspas>"
        $exe = $env:ComSpec
        $linha = '/d /s /c "' + (Juntar-Argumentos (@($Programa) + $Argumentos)) + '"'
    }
    $logErros = "$Log.erros"
    Apagar $Log
    Apagar $logErros
    $opcoes = @{
        FilePath = $exe
        NoNewWindow = $true
        PassThru = $true
        RedirectStandardOutput = $Log
        RedirectStandardError = $logErros
    }
    if ($linha) { $opcoes.ArgumentList = $linha }
    if ($Entrada) { $opcoes.RedirectStandardInput = $Entrada }
    if ($Diretorio) { $opcoes.WorkingDirectory = $Diretorio }
    $p = Start-Process @opcoes
    try { $null = $p.Handle } catch { }   # guarda o handle: sem isso o ExitCode pode vir vazio
    $pos = @{ $Log = 0L; $logErros = 0L }
    $comeco = Get-Date
    $script:UltimaSaida = $comeco
    $script:UltimoProgresso = $comeco.AddSeconds(-10)
    $estourou = $false
    while (-not $p.HasExited) {
        Start-Sleep -Milliseconds 700
        if (-not $Quieto) {
            foreach ($f in @($Log, $logErros)) { $pos[$f] = Mostrar-Novo $f $pos[$f] $false }
        }
        $agora = Get-Date
        $min = ($agora - $comeco).TotalMinutes
        if (($agora - $script:UltimaSaida).TotalSeconds -ge 60) {
            Write-Host ("      ... {0} trabalhando ha {1} min (normal, nao feche a janela)" -f $Rotulo, [int][Math]::Floor($min)) -ForegroundColor DarkGray
            $script:UltimaSaida = $agora
        }
        if ($min -ge $LimiteMin) {
            $estourou = $true
            Aviso "$Rotulo passou de $LimiteMin min: interrompido."
            try {
                Start-Process -FilePath "taskkill.exe" -ArgumentList "/PID $($p.Id) /T /F" -NoNewWindow -Wait -RedirectStandardOutput (Join-Path $script:Logs "taskkill.txt") -RedirectStandardError (Join-Path $script:Logs "taskkill-erros.txt")
            } catch { try { $p.Kill() } catch { } }
            break
        }
    }
    try { $p.WaitForExit(60000) | Out-Null } catch { }
    if (-not $Quieto) {
        foreach ($f in @($Log, $logErros)) { $pos[$f] = Mostrar-Novo $f $pos[$f] $true }
    }
    if ($estourou) { return -999 }
    return [int]$p.ExitCode
}

# Saida curta de um programa (ex.: "java -version"), com tempo-limite.
function Saida-De([string]$Programa, [string[]]$Argumentos, [int]$Segundos = 60) {
    try {
        $psi = New-Object Diagnostics.ProcessStartInfo
        $psi.FileName = $Programa
        $psi.Arguments = Juntar-Argumentos $Argumentos
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        $p = [Diagnostics.Process]::Start($psi)
        $o = $p.StandardOutput.ReadToEndAsync()
        $e = $p.StandardError.ReadToEndAsync()
        if (-not $p.WaitForExit($Segundos * 1000)) {
            try { $p.Kill() } catch { }
            return ""
        }
        return ($o.Result + "`n" + $e.Result)
    } catch { return "" }
}

function Ler-Log([string]$Log) {
    $t = ""
    foreach ($f in @($Log, "$Log.erros")) {
        if (Test-Path -LiteralPath $f) {
            try { $t += [IO.File]::ReadAllText($f) + "`n" } catch { }
        }
    }
    return $t
}

# --------------------------------------------------------------- downloads

function Nova-Requisicao([string]$Url) {
    $r = [Net.HttpWebRequest]::Create($Url)
    $r.UserAgent = "StrikeKids-GerarApk"
    $r.Timeout = 60000
    $r.ReadWriteTimeout = 300000
    $r.AllowAutoRedirect = $true
    return $r
}

function Ler-Texto-Url([string]$Url) {
    $resp = (Nova-Requisicao $Url).GetResponse()
    try {
        $sr = New-Object IO.StreamReader($resp.GetResponseStream())
        return $sr.ReadToEnd()
    } finally { $resp.Close() }
}

function Copiar-Com-Progresso($Entrada, $Saida, [long]$Total) {
    $buf = New-Object byte[] 1048576
    $feito = 0L
    $proximo = 10
    $n = $Entrada.Read($buf, 0, $buf.Length)
    while ($n -gt 0) {
        $Saida.Write($buf, 0, $n)
        $feito += $n
        if ($Total -gt 0) {
            $pct = [int][Math]::Floor(100.0 * $feito / $Total)
            if ($pct -ge $proximo) {
                Write-Host ("      {0,3}%  ({1:N0} de {2:N0} MB)" -f $pct, ($feito / 1MB), ($Total / 1MB))
                $proximo = $pct + 10
            }
        }
        $n = $Entrada.Read($buf, 0, $buf.Length)
    }
    return $feito
}

function Baixar-Net([string]$Url, [string]$Arquivo) {
    $resp = (Nova-Requisicao $Url).GetResponse()
    try {
        $entrada = $resp.GetResponseStream()
        $saida = [IO.File]::Create($Arquivo)
        try { [void](Copiar-Com-Progresso $entrada $saida $resp.ContentLength) }
        finally { $saida.Dispose(); $entrada.Dispose() }
    } finally { $resp.Close() }
}

# Baixa um arquivo (curl.exe do Windows, que continua de onde parou;
# se nao der, pelo .NET). Devolve $true se o arquivo ficou pronto.
function Baixar([string]$Url, [string]$Destino, [string]$Nome) {
    if (Test-Path -LiteralPath $Destino) { return $true }
    [void](Pasta (Split-Path $Destino -Parent))
    $parte = "$Destino.parte"
    Info "Baixando $Nome ..."
    Info "  $Url"
    $curl = $null
    if ($env:SystemRoot) { $curl = Join-Path $env:SystemRoot "System32\curl.exe" }
    if ($curl -and (Test-Path -LiteralPath $curl)) {
        for ($i = 1; $i -le 3; $i++) {
            if ($i -eq 3) { Apagar $parte }
            & $curl -L --fail --retry 3 --retry-delay 5 --connect-timeout 30 -C - -o $parte $Url
            $cod = $LASTEXITCODE
            if ($cod -eq 0 -and (Test-Path -LiteralPath $parte)) {
                Move-Item -LiteralPath $parte -Destination $Destino -Force
                return $true
            }
            if ($cod -eq 22) { break }   # 404 etc.: tentar de novo nao adianta
            Aviso "download interrompido (curl $cod); tentando de novo ($i/3)..."
            Start-Sleep -Seconds 3
        }
    }
    try {
        Apagar $parte
        Baixar-Net $Url $parte
        Move-Item -LiteralPath $parte -Destination $Destino -Force
        return $true
    } catch {
        Apagar $parte
        Aviso "nao consegui baixar $Nome ($($_.Exception.Message))"
        return $false
    }
}

# ------------------------------------------------------------------- zips

function Zip-Valido([string]$Arquivo, [long]$Minimo = 1MB) {
    if (-not (Test-Path -LiteralPath $Arquivo)) { return $false }
    if ((Get-Item -LiteralPath $Arquivo).Length -lt $Minimo) { return $false }
    try {
        $z = [IO.Compression.ZipFile]::OpenRead($Arquivo)
        $n = $z.Entries.Count
        $z.Dispose()
        return ($n -gt 0)
    } catch { return $false }
}

function Extrair-Zip([string]$Zip, [string]$Destino) {
    [void](Pasta $Destino)
    $z = [IO.Compression.ZipFile]::OpenRead($Zip)
    try {
        foreach ($e in $z.Entries) {
            $alvo = [IO.Path]::Combine($Destino, $e.FullName)
            if ($e.FullName.EndsWith('/') -or $e.FullName.EndsWith('\')) {
                [void][IO.Directory]::CreateDirectory($alvo)
                continue
            }
            [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($alvo))
            [IO.Compression.ZipFileExtensions]::ExtractToFile($e, $alvo, $true)
        }
    } finally { $z.Dispose() }
}

# Tira do zip so os arquivos pedidos: @{ "pasta/arquivo" = "destino" }
function Extrair-DoZip([string]$Zip, [hashtable]$Quero) {
    $z = [IO.Compression.ZipFile]::OpenRead($Zip)
    try {
        foreach ($nome in @($Quero.Keys)) {
            $e = $z.GetEntry($nome)
            if (-not $e) { throw "$nome nao esta em $Zip" }
            [void](Pasta (Split-Path $Quero[$nome] -Parent))
            [IO.Compression.ZipFileExtensions]::ExtractToFile($e, $Quero[$nome], $true)
        }
    } finally { $z.Dispose() }
}

# --------------------------------------- zip remoto (so a parte Android)

function Ler-Faixa([string]$Url, [long]$Inicio, [long]$Fim) {
    $req = Nova-Requisicao $Url
    $req.AddRange($Inicio, $Fim)
    $resp = $req.GetResponse()
    try {
        if ([int]$resp.StatusCode -ne 206) { throw "o servidor nao aceitou download parcial (HTTP $([int]$resp.StatusCode))" }
        $entrada = $resp.GetResponseStream()
        try {
            $ms = New-Object IO.MemoryStream
            $entrada.CopyTo($ms)
            return , $ms.ToArray()
        } finally { $entrada.Dispose() }
    } finally { $resp.Close() }
}

function Tamanho-Remoto([string]$Url) {
    $req = Nova-Requisicao $Url
    $req.AddRange(0L, 0L)
    $resp = $req.GetResponse()
    try {
        $faixa = $resp.Headers["Content-Range"]
        if ([int]$resp.StatusCode -ne 206 -or -not $faixa) { throw "o servidor nao aceitou download parcial" }
        return [long]($faixa.Split('/')[1])
    } finally { $resp.Close() }
}

function Baixar-Faixa([string]$Url, [long]$Inicio, [long]$Tamanho, $Saida) {
    $feito = 0L
    $proximo = 10
    while ($feito -lt $Tamanho) {
        $n = [long][Math]::Min([long]16MB, [long]($Tamanho - $feito))
        $bytes = $null
        for ($t = 1; $t -le 5; $t++) {
            try {
                $bytes = Ler-Faixa $Url ($Inicio + $feito) ($Inicio + $feito + $n - 1)
                if ($bytes.Length -ne $n) { throw "parte incompleta" }
                break
            } catch {
                if ($t -eq 5) { throw }
                Start-Sleep -Seconds (3 * $t)
            }
        }
        $Saida.Write($bytes, 0, $bytes.Length)
        $feito += $n
        $pct = [int][Math]::Floor(100.0 * $feito / $Tamanho)
        if ($Tamanho -ge 4MB -and $pct -ge $proximo) {
            Write-Host ("      {0,3}%  ({1:N0} de {2:N0} MB)" -f $pct, ($feito / 1MB), ($Tamanho / 1MB))
            $proximo = $pct + 10
        }
    }
}

# Le o indice (fim) do zip remoto e baixa so os arquivos pedidos,
# em partes de 16 MB (cada parte com novas tentativas).
function Extrair-Remoto([string]$Url, [hashtable]$Quero) {
    $total = Tamanho-Remoto $Url
    $tamCauda = [long][Math]::Min([long]65557, $total)
    $cauda = Ler-Faixa $Url ($total - $tamCauda) ($total - 1)
    $i = -1
    for ($k = $cauda.Length - 22; $k -ge 0; $k--) {
        if ($cauda[$k] -eq 0x50 -and $cauda[$k + 1] -eq 0x4B -and $cauda[$k + 2] -eq 5 -and $cauda[$k + 3] -eq 6) { $i = $k; break }
    }
    if ($i -lt 0) { throw "indice do zip nao encontrado" }
    $tamIndice = [long][BitConverter]::ToUInt32($cauda, $i + 12)
    $posIndice = [long][BitConverter]::ToUInt32($cauda, $i + 16)
    if ($posIndice -eq 4294967295 -or $tamIndice -eq 4294967295) { throw "zip64 nao suportado" }
    $indice = Ler-Faixa $Url $posIndice ($posIndice + $tamIndice - 1)
    $achados = @{}
    $p = 0
    while ($p + 46 -le $indice.Length -and [BitConverter]::ToUInt32($indice, $p) -eq 0x02014B50) {
        $nNome = [BitConverter]::ToUInt16($indice, $p + 28)
        $nExtra = [BitConverter]::ToUInt16($indice, $p + 30)
        $nComent = [BitConverter]::ToUInt16($indice, $p + 32)
        $nome = [Text.Encoding]::UTF8.GetString($indice, $p + 46, $nNome)
        if ($Quero.ContainsKey($nome)) {
            $achados[$nome] = @{
                Metodo = [int][BitConverter]::ToUInt16($indice, $p + 10)
                Comprimido = [long][BitConverter]::ToUInt32($indice, $p + 20)
                Real = [long][BitConverter]::ToUInt32($indice, $p + 24)
                Local = [long][BitConverter]::ToUInt32($indice, $p + 42)
            }
        }
        $p += 46 + $nNome + $nExtra + $nComent
    }
    foreach ($nome in @($Quero.Keys)) {
        if (-not $achados.ContainsKey($nome)) { throw "$nome nao esta no pacote" }
    }
    foreach ($nome in @($Quero.Keys)) {
        $a = $achados[$nome]
        $cab = Ler-Faixa $Url $a.Local ($a.Local + 29)
        if ([BitConverter]::ToUInt32($cab, 0) -ne 0x04034B50) { throw "cabecalho invalido em $nome" }
        $dados = $a.Local + 30 + [BitConverter]::ToUInt16($cab, 26) + [BitConverter]::ToUInt16($cab, 28)
        $destino = $Quero[$nome]
        [void](Pasta (Split-Path $destino -Parent))
        $temp = "$destino.baixando"
        Info ("{0} ({1:N0} MB)" -f (Split-Path $nome -Leaf), ($a.Comprimido / 1MB))
        $fs = [IO.File]::Create($temp)
        try { if ($a.Comprimido -gt 0) { Baixar-Faixa $Url $dados $a.Comprimido $fs } }
        finally { $fs.Dispose() }
        if ($a.Metodo -eq 0) {
            Move-Item -LiteralPath $temp -Destination $destino -Force
        } elseif ($a.Metodo -eq 8) {
            $ent = [IO.File]::OpenRead($temp)
            try {
                $ds = New-Object IO.Compression.DeflateStream($ent, [IO.Compression.CompressionMode]::Decompress)
                $sai = [IO.File]::Create($destino)
                try { $ds.CopyTo($sai, 1048576) } finally { $sai.Dispose(); $ds.Dispose() }
            } finally { $ent.Dispose() }
            Apagar $temp
        } else { throw "compressao $($a.Metodo) nao suportada em $nome" }
        if ((Get-Item -LiteralPath $destino).Length -ne $a.Real) {
            Apagar $destino
            throw "$nome veio com tamanho errado"
        }
    }
}

# ------------------------------------------------------- pasta de trabalho

function Gravavel([string]$Caminho) {
    try {
        [void][IO.Directory]::CreateDirectory($Caminho)
        $t = Join-Path $Caminho ".teste-escrita"
        [IO.File]::WriteAllText($t, "ok")
        Remove-Item -LiteralPath $t -Force
        return $true
    } catch { return $false }
}

function Escolher-Trabalho {
    $opcoes = @()
    if ($PastaTrabalho) { $opcoes += $PastaTrabalho }
    if ($env:SystemDrive) { $opcoes += (Join-Path $env:SystemDrive "StrikeKidsGLES2") }
    if ($env:PUBLIC) { $opcoes += (Join-Path $env:PUBLIC "StrikeKidsGLES2") }
    if ($env:LOCALAPPDATA) { $opcoes += (Join-Path $env:LOCALAPPDATA "StrikeKidsGLES2") }
    # de preferencia sem espacos nem acentos (o Java e o Godot gostam)
    foreach ($c in $opcoes) {
        if ($c -match '^[A-Za-z0-9:\\/._-]+$' -and (Gravavel $c)) { return $c.TrimEnd('\') }
    }
    foreach ($c in $opcoes) {
        if ($c -and (Gravavel $c)) { return $c.TrimEnd('\') }
    }
    throw "nao consegui criar a pasta de trabalho (tente -PastaTrabalho D:\SKG2)."
}

# ------------------------------------------------------------------ Godot

function Versao-Godot([string]$Exe) {
    $s = (Saida-De $Exe @("--version") 90).Trim()
    if ($s -match '(\d+\.\d+(?:\.\d+)?\.[a-z0-9]+)') { return $Matches[1] }
    return ""
}

function Achar-Godot {
    $lista = New-Object Collections.Generic.List[string]
    foreach ($c in @($CaminhoGodot, $env:GODOT, $env:GODOT_BIN)) {
        if ($c -and (Test-Path -LiteralPath $c -PathType Leaf)) {
            $lista.Add(($c -replace '_console\.exe$', '.exe'))
        }
    }
    $pastas = @($Projeto, (Split-Path $Projeto -Parent))
    if ($env:USERPROFILE) {
        $pastas += @((Join-Path $env:USERPROFILE "Downloads"), (Join-Path $env:USERPROFILE "Desktop"),
            (Join-Path $env:USERPROFILE "OneDrive\Desktop"), (Join-Path $env:USERPROFILE "Documents"))
    }
    try { $pastas += [Environment]::GetFolderPath("Desktop") } catch { }
    try { $pastas += [Environment]::GetFolderPath("MyDocuments") } catch { }
    $pastas += @("C:\Godot", "D:\Godot")
    if ($env:ProgramFiles) { $pastas += (Join-Path $env:ProgramFiles "Godot") }
    if ($env:LOCALAPPDATA) { $pastas += (Join-Path $env:LOCALAPPDATA "Programs") }
    foreach ($d in ($pastas | Where-Object { $_ } | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $d)) { continue }
        $achado = Get-ChildItem -LiteralPath $d -Recurse -Depth 3 -File -Filter $ExeGodot -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($achado) { $lista.Add($achado.FullName) }
    }
    foreach ($c in $lista) {
        if (Test-Path -LiteralPath $c) { return $c }
    }
    return $null
}


function Garantir-Godot {
    $pasta = Pasta (Join-Path $script:Trabalho "godot")
    $destino = Join-Path $pasta $ExeGodot
    if (-not (Test-Path -LiteralPath $destino)) {
        $achado = Achar-Godot
        if ($achado) {
            Info "Godot encontrado: $achado"
            Copy-Item -LiteralPath $achado -Destination $destino -Force
        } else {
            Info "Godot 3.6.3 nao encontrado no PC: baixando (~40 MB)."
            $zip = Join-Path $script:Downloads "Godot_v3.6.3-stable_win64.exe.zip"
            if (-not (Baixar $UrlGodot $zip "Godot 3.6.3")) { throw "nao consegui baixar o Godot 3.6.3. Baixe em godotengine.org (versao 3.6.3, a comum, nao a Mono) e rode de novo." }
            if (-not (Zip-Valido $zip 10MB)) { Apagar $zip; throw "o download do Godot veio corrompido; rode de novo." }
            Extrair-Zip $zip $pasta
            if (-not (Test-Path -LiteralPath $destino)) {
                $x = Get-ChildItem -LiteralPath $pasta -Recurse -File -Filter $ExeGodot | Select-Object -First 1
                if ($x) { Move-Item -LiteralPath $x.FullName -Destination $destino -Force }
            }
        }
    }
    if (-not (Test-Path -LiteralPath $destino)) { throw "Godot 3.6.3 indisponivel." }
    Get-ChildItem -LiteralPath $pasta -File -Filter "*.exe" | ForEach-Object { try { Unblock-File -LiteralPath $_.FullName } catch { } }
    # modo "autocontido": configuracoes e modelos deste Godot ficam nesta
    # pasta (editor_data); nao mexe no Godot que voce usa no dia a dia
    [IO.File]::WriteAllText((Join-Path $pasta "_sc_"), "")
    $script:Godot = $destino
    $script:DadosGodot = Pasta (Join-Path $pasta "editor_data")
    $v = Versao-Godot $destino
    if ($v -and -not $v.StartsWith("3.6.3.")) {
        Apagar $destino
        throw "o Godot encontrado e a versao $v; esta edicao precisa do 3.6.3 (rode de novo: o script baixa o certo)."
    }
    Ok "Godot $(if ($v) { $v } else { '3.6.3' }) em $pasta"
}

# ------------------------------------------------------------------- Java

# Versao do Java numa pasta (JDK ou JRE: so precisa do bin\java.exe).
function Versao-Java([string]$Pasta) {
    if (-not $Pasta) { return 0 }
    $java = Join-Path $Pasta "bin\java.exe"
    if (-not (Test-Path -LiteralPath $java)) { return 0 }
    $s = Saida-De $java @("-version") 60
    if ($s -match 'version "(\d+)(?:\.(\d+))?') {
        $maior = [int]$Matches[1]
        if ($maior -eq 1 -and $Matches[2]) { $maior = [int]$Matches[2] }
        return $maior
    }
    return 0
}

function Garantir-Java {
    $candidatos = New-Object Collections.Generic.List[string]
    foreach ($c in @($env:JAVA_HOME, $env:JDK_HOME)) { if ($c) { $candidatos.Add($c.TrimEnd('\')) } }
    foreach ($cmd in @(Get-Command java.exe -All -ErrorAction SilentlyContinue)) {
        $candidatos.Add((Split-Path (Split-Path $cmd.Path -Parent) -Parent))
    }
    # o Java baixado por esta geracao e o da geracao da versao Godot 4
    # (C:\StrikeKidsBuild\jdk), se existir
    $bases = @((Join-Path $script:Trabalho "jdk"))
    if ($env:SystemDrive) { $bases += (Join-Path $env:SystemDrive "StrikeKidsBuild\jdk") }
    foreach ($pf in @($env:ProgramFiles, ${env:ProgramW6432})) {
        if (-not $pf) { continue }
        foreach ($n in @("Eclipse Adoptium", "Java", "Microsoft", "Zulu", "Amazon Corretto", "BellSoft", "OpenJDK", "Semeru", "RedHat", "Android\Android Studio")) {
            $bases += (Join-Path $pf $n)
        }
    }
    foreach ($b in $bases) {
        if (-not (Test-Path -LiteralPath $b)) { continue }
        $candidatos.Add($b)
        Get-ChildItem -LiteralPath $b -Directory -ErrorAction SilentlyContinue | ForEach-Object { $candidatos.Add($_.FullName) }
    }
    $escolhido = $null
    $versao = 0
    foreach ($c in ($candidatos | Select-Object -Unique)) {
        $v = Versao-Java $c
        # o remendo do modelo e o assinador rodam do Java 11 em diante (17 e o recomendado)
        if ($v -ge 11 -and $v -le 25) {
            if ($v -eq 17) { $escolhido = $c; $versao = 17; break }
            if (-not $escolhido) { $escolhido = $c; $versao = $v }
        }
    }
    if (-not $escolhido) {
        Info "Java nao encontrado: baixando o JDK 17 (~190 MB)."
        $zip = Join-Path $script:Downloads "jdk17-windows-x64.zip"
        $urls = @(
            "https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse?project=jdk",
            "https://aka.ms/download-jdk/microsoft-jdk-17-windows-x64.zip"
        )
        foreach ($u in $urls) {
            if ((Baixar $u $zip "Java JDK 17") -and (Zip-Valido $zip 50MB)) { break }
            Apagar $zip
        }
        if (-not (Test-Path -LiteralPath $zip)) { throw "nao consegui baixar o Java. Instale o 'Temurin 17 JDK' (adoptium.net) e rode de novo." }
        $destJdk = Join-Path $script:Trabalho "jdk"
        Apagar $destJdk
        Info "Extraindo o Java..."
        Extrair-Zip $zip $destJdk
        foreach ($d in (Get-ChildItem -LiteralPath $destJdk -Directory)) {
            $v = Versao-Java $d.FullName
            if ($v -ge 11) { $escolhido = $d.FullName; $versao = $v; break }
        }
        if (-not $escolhido) { throw "o Java baixado nao funcionou." }
    }
    $script:JavaHome = (Resolve-Path -LiteralPath $escolhido).Path.TrimEnd('\')
    $script:Java = Join-Path $script:JavaHome "bin\java.exe"
    $env:JAVA_HOME = $script:JavaHome
    $env:PATH = (Join-Path $script:JavaHome "bin") + ";" + $env:PATH
    Ok "Java $versao em $($script:JavaHome)"
}

# ------------------------------------------------------------ Android (adb)

# O Godot 3.6.3 so exporta para Android com uma pasta de SDK que tenha
# platform-tools\adb.exe e build-tools\<versao>\apksigner.bat - mesmo
# exportando SEM assinar. Aqui o "SDK" e uma pasta propria
# (C:\StrikeKidsGLES2\android-sdk): o platform-tools de verdade (copiado de
# um Android SDK deste PC ou baixado, ~10 MB) e um apksigner.bat de mentira
# (o APK sai do Godot sem assinar; quem assina e o passo "Assinar").
function Garantir-Adb {
    $sdk = Pasta (Join-Path $script:Trabalho "android-sdk")
    $pt = Join-Path $sdk "platform-tools"
    $adb = Join-Path $pt "adb.exe"
    if (-not (Test-Path -LiteralPath $adb)) {
        $candidatos = @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, "C:\Android\Sdk", "C:\Android\android-sdk")
        if ($env:SystemDrive) { $candidatos += @((Join-Path $env:SystemDrive "AndroidSdk"), (Join-Path $env:SystemDrive "StrikeKidsBuild\android-sdk")) }
        if ($env:LOCALAPPDATA) { $candidatos += (Join-Path $env:LOCALAPPDATA "Android\Sdk") }
        if (${env:ProgramFiles(x86)}) { $candidatos += (Join-Path ${env:ProgramFiles(x86)} "Android\android-sdk") }
        $origem = $null
        foreach ($c in @($candidatos | Where-Object { $_ } | Select-Object -Unique)) {
            if (Test-Path -LiteralPath (Join-Path $c "platform-tools\adb.exe")) { $origem = Join-Path $c "platform-tools"; break }
        }
        if ($origem) {
            Info "copiando o platform-tools de $origem"
            [void](Pasta $pt)
            Get-ChildItem -LiteralPath $origem -Force | Copy-Item -Destination $pt -Recurse -Force
        } else {
            $zip = Join-Path $script:Downloads "platform-tools-latest-windows.zip"
            if (-not (Zip-Valido $zip 2MB)) { Apagar $zip }
            if (-not (Baixar $UrlPlatformTools $zip "Android platform-tools (adb)")) { throw "nao consegui baixar o platform-tools do Android (dl.google.com)." }
            if (-not (Zip-Valido $zip 2MB)) { Apagar $zip; throw "o download do platform-tools veio corrompido; rode de novo." }
            Apagar $pt
            Extrair-Zip $zip $sdk
        }
    }
    if (-not (Test-Path -LiteralPath $adb)) { throw "o adb (platform-tools) nao ficou pronto em $pt." }
    $bt = Pasta (Join-Path $sdk "build-tools\so-para-o-godot")
    $falso = "@echo off`r`nrem apksigner de mentira: o Godot exporta SEM assinar e o GERAR_APK assina depois`r`nexit /b 1`r`n"
    [IO.File]::WriteAllText((Join-Path $bt "apksigner.bat"), $falso)
    $script:Sdk = $sdk
    $script:Adb = $adb
    Ok "adb pronto em $pt"
}

# -------------------------------------------------- modelo Android do Godot

function Garantir-Modelo {
    # o modelo OFICIAL fica guardado aqui; o do Strike Kids (Montar-Modelo)
    # vai para onde o Godot procura
    $alvo = Join-Path (Pasta (Join-Path $script:Trabalho "modelo")) "android_release_oficial.apk"
    $script:ModeloOficial = $alvo
    if (Zip-Valido $alvo 10MB) { Ok "modelo Android oficial $IdGodot pronto"; return }
    # 1) ja instalado pelo Godot 3.6.3 deste PC
    $origens = @()
    if ($env:APPDATA) { $origens += (Join-Path $env:APPDATA "Godot\templates\$IdGodot\android_release.apk") }
    foreach ($o in $origens) {
        if (Zip-Valido $o 10MB) {
            Info "copiando o modelo de $o"
            Copy-Item -LiteralPath $o -Destination $alvo -Force
            if (Zip-Valido $alvo 10MB) { Ok "modelo Android copiado do Godot deste PC"; return }
        }
    }
    # 2) o pacote .tpz ja baixado (Downloads, Desktop, pasta do projeto)
    $locais = @((Join-Path $script:Downloads $NomeTpz), (Join-Path $Projeto $NomeTpz), (Join-Path (Split-Path $Projeto -Parent) $NomeTpz))
    if ($env:USERPROFILE) { $locais += @((Join-Path $env:USERPROFILE "Downloads\$NomeTpz"), (Join-Path $env:USERPROFILE "Desktop\$NomeTpz")) }
    foreach ($tpz in $locais) {
        if (-not (Zip-Valido $tpz 100MB)) { continue }
        Info "extraindo do pacote $tpz"
        try { Extrair-DoZip $tpz @{ "templates/android_release.apk" = $alvo } } catch { Aviso $_.Exception.Message }
        if (Zip-Valido $alvo 10MB) { Ok "modelo Android extraido"; return }
    }
    # 3) baixa so o android_release.apk de dentro do pacote oficial
    Info "Baixando so o modelo Android de dentro do pacote oficial do Godot 3.6.3..."
    try { Extrair-Remoto $UrlTemplates @{ "templates/android_release.apk" = $alvo } } catch { Aviso "download parcial falhou ($($_.Exception.Message)); baixando o pacote inteiro." }
    if (Zip-Valido $alvo 10MB) { Ok "modelo Android baixado"; return }
    # 4) o pacote inteiro, com retomada
    $tpz = Join-Path $script:Downloads $NomeTpz
    if (-not (Baixar $UrlTemplates $tpz "modelos do Godot 3.6.3 (pacote inteiro)")) { throw "nao consegui baixar os modelos do Godot 3.6.3." }
    Extrair-DoZip $tpz @{ "templates/android_release.apk" = $alvo }
    if (-not (Zip-Valido $alvo 10MB)) { throw "o modelo Android do Godot 3.6.3 ficou incompleto." }
    Ok "modelo Android pronto"
}

# Junta o modelo oficial com os extras do Strike Kids (plugins da camera e do
# Arduino, permissao da camera, filtros USB, banner) e poe o resultado onde o
# Godot (autocontido) procura: editor_data\templates\3.6.3.stable.
function Montar-Modelo {
    $pasta = Pasta (Join-Path $script:DadosGodot "templates\$IdGodot")
    [IO.File]::WriteAllText((Join-Path $pasta "version.txt"), "$IdGodot`n")
    $alvo = Join-Path $pasta "android_release.apk"
    $remendo = Join-Path $Projeto "tools\android\remendo_apk.jar"
    $extras = Join-Path $Projeto "android\modelo_android\extras.zip"
    Apagar $alvo
    $cod = Executar $script:Java @("-jar", $remendo, $script:ModeloOficial, $extras, $alvo) -Log (Join-Path $script:Logs "modelo-strike.log") -LimiteMin 5 -Rotulo "modelo"
    if ($cod -ne 0 -or -not (Zip-Valido $alvo 10MB)) { throw "nao consegui montar o modelo Android do Strike Kids (veja modelo-strike.log)." }
    Ok "modelo Android do Strike Kids (com a camera e o Arduino) pronto"
}

# ------------------------------------------------------------- assinador

function Sha256([string]$Arquivo) {
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Arquivo).Hash.ToLower()
}

function Garantir-Jar([string]$Url, [string]$Sha, [string]$Nome) {
    $pasta = Pasta (Join-Path $script:Trabalho "ferramentas")
    $destino = Join-Path $pasta (Split-Path $Url -Leaf)
    if ((Test-Path -LiteralPath $destino) -and ((Sha256 $destino) -ne $Sha)) { Apagar $destino }
    if (-not (Test-Path -LiteralPath $destino)) {
        if (-not (Baixar $Url $destino $Nome)) { throw "nao consegui baixar o $Nome." }
        if ((Sha256 $destino) -ne $Sha) {
            Apagar $destino
            throw "o $Nome baixado nao confere (SHA-256 diferente); rode de novo."
        }
    }
    return $destino
}

function Garantir-Ferramentas {
    $script:Assinador = Garantir-Jar $UrlAssinador $ShaAssinador "uber-apk-signer 1.3.0"
    Ok "assinador: $($script:Assinador)"
}

# --------------------------------------------------- copia do projeto

function Copiar-Projeto {
    $script:Copia = Pasta (Join-Path $script:Trabalho "projeto")
    # limpa a copia anterior, menos o cache de importacao (.import): assim
    # a 2a vez e bem mais rapida
    Get-ChildItem -LiteralPath $script:Copia -Force | Where-Object { $_.Name -ne '.import' } | Remove-Item -Recurse -Force
    # tools, android e build nao vao para o APK (o que precisa deles, este
    # script pega direto do projeto)
    $fora = @('.import', 'tools', 'android', 'build', 'APK-Pronto', '.git') | ForEach-Object { Join-Path $Projeto $_ }
    $argumentos = @($Projeto, $script:Copia, '/E', '/R:2', '/W:1', '/NFL', '/NDL', '/NJH', '/NJS', '/NP', '/XD') + $fora + @('/XF', 'GERAR_APK.bat', 'GERAR_APK.ps1')
    & robocopy.exe @argumentos | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "falha ao copiar o projeto para $($script:Copia) (robocopy $LASTEXITCODE)." }
    if (-not (Test-Path -LiteralPath (Join-Path $script:Copia "project.godot"))) { throw "a copia do projeto ficou incompleta." }
    Ok "projeto copiado para $($script:Copia)"
}

# Na COPIA: o preset sai sem Gradle, sem assinar e sem plugins ligados (os
# plugins vem no modelo do Strike Kids), a versao (se pedida), o giro da
# tela e a imagem de abertura ja girada como a tela do jogo.
function Preparar-Copia {
    $utf8 = New-Object Text.UTF8Encoding($false)
    $presets = Join-Path $script:Copia "export_presets.cfg"
    $t = [IO.File]::ReadAllText($presets)
    $i = $t.IndexOf('name="' + $NomePreset + '"')
    if ($i -lt 0) { throw "o preset '$NomePreset' nao esta no export_presets.cfg." }
    $k = $t.IndexOf('.options]', $i)
    if ($k -lt 0) { throw "o preset '$NomePreset' esta sem opcoes no export_presets.cfg." }
    $j = $t.IndexOf("`n[preset.", $k)
    if ($j -lt 0) { $j = $t.Length }
    $b = $t.Substring($i, $j - $i)
    $b = [Regex]::Replace($b, '(?m)^custom_build/use_custom_build=[^\r\n]*', 'custom_build/use_custom_build=false')
    $b = [Regex]::Replace($b, '(?m)^package/signed=[^\r\n]*', 'package/signed=false')
    $b = [Regex]::Replace($b, '(?m)^(plugins/[A-Za-z0-9_]+)=[^\r\n]*', '$1=false')
    # a permissao da camera ja vem no modelo do Strike Kids
    $b = [Regex]::Replace($b, '(?m)^permissions/camera=[^\r\n]*', 'permissions/camera=false')
    if ($Versao) {
        $b = [Regex]::Replace($b, '(?m)^version/name=[^\r\n]*', ('version/name="' + $Versao.Replace('"', '').Replace('$', '$$') + '"'))
    }
    $t = $t.Substring(0, $i) + $b + $t.Substring($j)
    [IO.File]::WriteAllText($presets, $t, $utf8)
    $m = [Regex]::Match($b, '(?m)^version/name="([^"]*)"')
    if ($m.Success) { $script:NomeVersao = $m.Groups[1].Value } else { $script:NomeVersao = "?" }
    $proj = Join-Path $script:Copia "project.godot"
    $c = [IO.File]::ReadAllText($proj)
    $c = [Regex]::Replace($c, '(?m)^tela/giro=[^\r\n]*', "tela/giro=$Giro")
    if ($Giro -eq 1) { $s = "1" } elseif ($Giro -eq -1) { $s = "m1" } else { $s = "0" }
    if (Test-Path -LiteralPath (Join-Path $script:Copia "ui\splash_giro_$s.png")) {
        $c = [Regex]::Replace($c, '(?m)^boot_splash/image=[^\r\n]*', ('boot_splash/image="res://ui/splash_giro_' + $s + '.png"'))
    }
    [IO.File]::WriteAllText($proj, $c, $utf8)
    Ok "versao $($script:NomeVersao), giro $Giro"
}

# A chave de assinatura do Strike Kids vai JUNTO do projeto
# (tools\android\strikekids.keystore): o APK gerado em qualquer PC (e o APK
# pronto) instala POR CIMA do anterior na TV Box, sem perder os recordes.
function Preparar-Chave {
    $origem = Join-Path $Projeto "tools\android\strikekids.keystore"
    if (-not (Test-Path -LiteralPath $origem)) { throw "falta a chave do projeto: $origem" }
    $script:Chave = Join-Path (Pasta (Join-Path $script:Trabalho "chave")) "strikekids.keystore"
    Copy-Item -LiteralPath $origem -Destination $script:Chave -Force
}

# O Godot (autocontido) le daqui o Java, o "SDK" e a chave de depuracao
# (o Godot 3 exige uma, mesmo exportando sem assinar).
function Escrever-ConfigEditor {
    $arq = Join-Path $script:DadosGodot "editor_settings-3.tres"
    $j = $script:JavaHome.Replace('\', '/')
    $s = $script:Sdk.Replace('\', '/')
    $k = $script:Chave.Replace('\', '/')
    $texto = "[gd_resource type=""EditorSettings"" format=2]`n`n[resource]`n" +
        "export/android/java_sdk_path = ""$j""`n" +
        "export/android/android_sdk_path = ""$s""`n" +
        "export/android/debug_keystore = ""$k""`n" +
        "export/android/debug_keystore_user = ""strikekids""`n" +
        "export/android/debug_keystore_pass = ""strikekids""`n" +
        "export/android/shutdown_adb_on_exit = true`n"
    [IO.File]::WriteAllText($arq, $texto, (New-Object Text.UTF8Encoding($false)))
}

# ---------------------------------------------------------------- exportar

function Exportar {
    $saida = Pasta (Join-Path $script:Trabalho "saida")
    Get-ChildItem -LiteralPath $saida -Force | Remove-Item -Recurse -Force
    $apk = Join-Path $saida "sem_assinatura.apk"
    $log = Join-Path $script:Logs "exportar.log"
    for ($tentativa = 1; $tentativa -le 2; $tentativa++) {
        $cod = Executar $script:Godot @("--no-window", "--path", $script:Copia, "--export", $NomePreset, $apk) -Log $log -LimiteMin 40 -Rotulo "Godot" -Diretorio $script:Copia
        if (Zip-Valido $apk 5MB) { return $apk }
        $texto = Ler-Log $log
        if ($texto -match 'SCRIPT ERROR: Parse Error|Failed to load script|Failed to create an autoload') {
            throw "erro de script no projeto Godot (veja $log)."
        }
        if ($texto -match 'configuration errors') {
            Mostrar-Motivo $log
            throw "o Godot recusou a configuracao da exportacao Android (veja $log)."
        }
        if ($tentativa -eq 1) { Aviso "o Godot terminou sem o APK (codigo $cod); tentando de novo..." }
    }
    Mostrar-Motivo $log
    throw "o Godot nao gerou o APK (veja $log)."
}

function Mostrar-Motivo([string]$Log) {
    $linhas = @((Ler-Log $Log) -split "`r`n|`n")
    $trecho = @($linhas | Where-Object { $_ -match 'ERROR|error:|FAILURE|Could not|failed|Unable' -and $_ -notmatch "Cannot open file 'res://\.import" } | Select-Object -Last 15)
    foreach ($l in $trecho) { if ($l.Trim()) { Write-Host "      $l" -ForegroundColor Yellow } }
}

# ------------------------------------------------------ assinar e conferir

function Assinar([string]$Apk) {
    $pasta = Join-Path $script:Trabalho "assinado"
    $base = @("-jar", $script:Assinador, "-a", $Apk, "-o", $pasta, "--ks", $script:Chave, "--ksAlias", "strikekids", "--ksPass", "strikekids", "--ksKeyPass", "strikekids")
    # 2a tentativa sem o zipalign do assinador (o APK do Godot ja sai alinhado)
    foreach ($extra in @(@(), @("--skipZipAlign"))) {
        Apagar $pasta
        [void](Pasta $pasta)
        $cod = Executar $script:Java ($base + $extra) -Log (Join-Path $script:Logs "assinar.log") -LimiteMin 10 -Rotulo "assinador"
        $assinado = Get-ChildItem -LiteralPath $pasta -File -Filter "*-signed.apk" | Select-Object -First 1
        if ($cod -eq 0 -and $assinado) {
            Ok "APK assinado com a chave do Strike Kids"
            return $assinado.FullName
        }
        if ($extra.Count -eq 0) { Aviso "o assinador falhou (codigo $cod); tentando sem o zipalign..." }
    }
    throw "nao consegui assinar o APK (veja assinar.log)."
}

function Conferir-Apk([string]$Apk) {
    $z = [IO.Compression.ZipFile]::OpenRead($Apk)
    try {
        $nomes = @{}
        foreach ($e in $z.Entries) { $nomes[$e.FullName] = $e.Length }
    } finally { $z.Dispose() }
    $precisa = @("AndroidManifest.xml", "classes.dex", "classes2.dex", "resources.arsc", "assets/project.binary",
        "lib/armeabi-v7a/libgodot_android.so", "lib/arm64-v8a/libgodot_android.so", "res/xml/strike_usb_arduino.xml",
        "res/drawable-xhdpi/strike_banner.png")
    foreach ($n in $precisa) {
        if (-not $nomes.ContainsKey($n)) { throw "o APK ficou sem $n." }
    }
    $dados = @($nomes.Keys | Where-Object { $_ -like "assets/.import/*" }).Count
    if ($dados -lt 20) { throw "o APK ficou sem os arquivos do jogo (assets/.import: $dados)." }
    Ok ("conteudo conferido ({0} arquivos importados do jogo, 32 e 64 bits)" -f $dados)
    $cod = Executar $script:Java @("-jar", $script:Assinador, "-a", $Apk, "--onlyVerify") -Log (Join-Path $script:Logs "verificar.log") -LimiteMin 5 -Rotulo "assinador" -Quieto
    $texto = Ler-Log (Join-Path $script:Logs "verificar.log")
    if ($cod -ne 0 -or $texto -notmatch 'signature verified' -or $texto -notmatch ' 0 errors') { throw "a assinatura do APK nao conferiu (veja verificar.log)." }
    Ok "assinatura conferida (v1 + v2 + v3)"
}

# --------------------------------------------------------------- principal

function Principal {
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " STRIKE KIDS - GERAR APK DA TV BOX - EDICAO OPENGL ES 2.0" -ForegroundColor Cyan
    Write-Host " (Godot 3.6.3, para TV Box com Mali-400/450, como a TX9)" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " A 1a vez baixa o que faltar e pode levar de 5 a 20 min."
    Write-Host " Nao feche a janela. Se clicar dentro dela e o texto parar,"
    Write-Host " aperte ESC (o Windows pausa a janela quando se seleciona texto)."
    Write-Host " Projeto: $Projeto"
    if (-not (Test-Path -LiteralPath (Join-Path $Projeto "project.godot"))) {
        throw "project.godot nao encontrado. Extraia o ZIP inteiro e rode o GERAR_APK.bat de dentro da pasta strike-kids-gles2."
    }
    foreach ($f in @("android\modelo_android\extras.zip", "tools\android\remendo_apk.jar", "tools\android\strikekids.keystore")) {
        if (-not (Test-Path -LiteralPath (Join-Path $Projeto $f))) { throw "falta $f no projeto (extraia o ZIP inteiro)." }
    }
    if (-not [Environment]::Is64BitOperatingSystem) { throw "este gerador precisa do Windows 64 bits." }
    if ($Instalar) { $script:TotalEtapas = 10 }

    Titulo "Pasta de trabalho"
    $script:Trabalho = Escolher-Trabalho
    $script:Downloads = Pasta (Join-Path $script:Trabalho "downloads")
    $script:Logs = Pasta (Join-Path $script:Trabalho "logs")
    $env:TEMP = Pasta (Join-Path $script:Trabalho "tmp")
    $env:TMP = $env:TEMP
    Ok $script:Trabalho
    try {
        $drive = Split-Path $script:Trabalho -Qualifier
        $livre = (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$drive'").FreeSpace
        Info ("Espaco livre em {0} {1:N1} GB" -f $drive, ($livre / 1GB))
        if ($livre -lt 3GB) { Aviso "pouco espaco: a 1a geracao precisa de uns 2 GB (Godot, Java, modelo, importacao)." }
    } catch { }

    Titulo "Godot 3.6.3"
    Garantir-Godot

    Titulo "Java"
    Garantir-Java

    Titulo "Android: adb (o Godot 3 exige)"
    Garantir-Adb

    Titulo "Modelo Android (o do Godot 3.6.3 + camera e Arduino)"
    Garantir-Modelo
    Montar-Modelo

    Titulo "Assinador"
    Garantir-Ferramentas

    Titulo "Copia do projeto e exportacao (Godot)"
    Copiar-Projeto
    Preparar-Copia
    Preparar-Chave
    Escrever-ConfigEditor
    Info "Exportando com o Godot 3.6.3. Na 1a vez ele ainda importa as imagens"
    Info "e os sons (alguns minutos, as vezes sem escrever nada): e normal."
    $semAssinatura = Exportar
    Ok ("APK do Godot: {0:N1} MB (ja com a camera e o Arduino)" -f ((Get-Item -LiteralPath $semAssinatura).Length / 1MB))

    Titulo "Assinando e conferindo"
    $assinado = Assinar $semAssinatura
    Conferir-Apk $assinado

    Titulo "Entregando o APK"
    $pastaApk = Pasta (Join-Path $Projeto "APK-Pronto")
    Get-ChildItem -LiteralPath $pastaApk -Force | Remove-Item -Recurse -Force
    $final = Join-Path $pastaApk $NomeApk
    Copy-Item -LiteralPath $assinado -Destination $final -Force
    $tamanho = (Get-Item -LiteralPath $final).Length
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $final).Hash
    $minutos = [int][Math]::Ceiling(((Get-Date) - $script:Inicio).TotalMinutes)
    Write-Host ""
    Write-Host "APK GERADO COM SUCESSO" -ForegroundColor Green
    Write-Host "  Arquivo: $final"
    Write-Host ("  Tamanho: {0:N1} MB   (levou {1} min)" -f ($tamanho / 1MB), $minutos)
    Write-Host "  Versao:  $($script:NomeVersao)   pacote: $Pacote"
    Write-Host "  SHA256:  $hash"
    Write-Host "  Arduino (5 sensores, porta das bolas, botao de configuracao, LEDs): INCLUIDO." -ForegroundColor Green
    Write-Host "  Na 1a vez a TV Box pergunta sobre o Arduino no USB: marque 'Usar por padrao' e OK."
    Write-Host "  Camera: INCLUIDA (camera do sistema e Camera2). Na 1a vez permita a CAMERA." -ForegroundColor Green
    Write-Host "  Instala AO LADO da versao Godot 4 (pacote diferente): nao substitui."
    Write-Host "  Instale este APK na TV Box (pendrive + gerenciador de arquivos, ou adb)."

    if ($Instalar) {
        Titulo "Instalando na TV Box (adb)"
        $cod = Executar $script:Adb @("install", "-r", $final) -Log (Join-Path $script:Logs "adb-instalar.log") -LimiteMin 10 -Rotulo "adb"
        if ($cod -eq 0) {
            [void](Executar $script:Adb @("shell", "monkey", "-p", $Pacote, "-c", "android.intent.category.LAUNCHER", "1") -Log (Join-Path $script:Logs "adb-abrir.log") -LimiteMin 2 -Rotulo "adb" -Quieto)
            Ok "instalado e aberto na TV Box"
        } else {
            Aviso "o adb nao instalou (TV Box conectada? depuracao ligada?). Se aparecer INSTALL_FAILED_UPDATE_INCOMPATIBLE, desinstale o Strike Kids (OpenGL ES 2.0) da TV Box e rode de novo."
        }
        try { [void](Executar $script:Adb @("kill-server") -Log (Join-Path $script:Logs "adb-parar.log") -LimiteMin 1 -Rotulo "adb" -Quieto) } catch { }
    }
}

# ------------------------------------------------------------------ inicio

# (".  .\GERAR_APK.ps1" so carrega as funcoes, sem gerar: usado nos testes)
if ($MyInvocation.InvocationName -ne '.') {
    $CodigoSaida = 1
    try { [void][IO.Directory]::CreateDirectory($PastaLogs) } catch { }
    $transcrevendo = $false
    try { Start-Transcript -LiteralPath $LogGeral -Force | Out-Null; $transcrevendo = $true } catch {
        try { Start-Transcript -Path $LogGeral -Force | Out-Null; $transcrevendo = $true } catch { }
    }
    try {
        Principal
        $CodigoSaida = 0
    } catch {
        Write-Host ""
        Write-Host "FALHA: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.InvocationInfo) { Write-Host ("  (linha {0} do GERAR_APK.ps1)" -f $_.InvocationInfo.ScriptLineNumber) -ForegroundColor DarkGray }
        Write-Host "Envie o arquivo: $LogGeral" -ForegroundColor Red
        if ($script:Logs) { Write-Host "(e, se puder, a pasta $($script:Logs))" -ForegroundColor Red }
    } finally {
        # os logs de cada programa tambem vao para build\android do projeto
        try {
            if ($script:Logs -and (Test-Path -LiteralPath $script:Logs)) {
                Get-ChildItem -LiteralPath $script:Logs -File | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $PastaLogs -Force -ErrorAction SilentlyContinue }
            }
        } catch { }
        if ($transcrevendo) { try { Stop-Transcript | Out-Null } catch { } }
    }
    exit $CodigoSaida
}
