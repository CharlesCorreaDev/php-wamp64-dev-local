<#
.SYNOPSIS
    Instala a extensao php_imagick (ImageMagick) para todas as versoes PHP 7.4+ no WampServer.
.DESCRIPTION
    - Baixa o ZIP correto de windows.php.net para cada versao PHP (mapeando compilador e ABI)
    - Extrai php_imagick.dll para a pasta ext\ de cada PHP
    - Extrai as DLLs nativas do ImageMagick (CORE_RL_*, FILTER_RL_*, etc.) para a raiz do PHP
    - Habilita extension=imagick no php.ini e phpForApache.ini de cada versao
    - Ignora PHP < 7.4 (sem suporte no imagick 3.8.1)
    - PHP 8.5 tentado, ignorado graciosamente se o build nao existir
.NOTES
    Execute como Administrador.
    Versao imagick: 3.8.1
    Fonte: https://windows.php.net/downloads/pecl/releases/imagick/3.8.1/
#>

$ErrorActionPreference = "Stop"

# ─── Configuracoes ───────────────────────────────────────────────────────────────
$WampPhpRoot  = "D:\wamp64\bin\php"
$ImagickVer   = "3.8.1"
$BaseUrl      = "https://windows.php.net/downloads/pecl/releases/imagick/$ImagickVer"
$TempDir      = "$env:TEMP\imagick-install"

# Mapeamento: prefixo-de-pasta => @(phpMajorMinor, compilador)
# Apenas ThreadSafe (TS) x64, que e o padrao do WampServer
$PhpMap = [ordered]@{
    "php7.4"  = @{ PhpVer = "7.4";  Compiler = "vc15" }
    "php8.0"  = @{ PhpVer = "8.0";  Compiler = "vs16" }
    "php8.1"  = @{ PhpVer = "8.1";  Compiler = "vs16" }
    "php8.2"  = @{ PhpVer = "8.2";  Compiler = "vs16" }
    "php8.3"  = @{ PhpVer = "8.3";  Compiler = "vs16" }
    "php8.4"  = @{ PhpVer = "8.4";  Compiler = "vs17" }
    "php8.5"  = @{ PhpVer = "8.5";  Compiler = "vs17" }
}

# Prefixos a ignorar completamente (sem suporte no imagick 3.8.1)
$SkipPrefixes = @("php5.", "php7.0.", "php7.1.", "php7.2.", "php7.3.")

# ─── Helpers ─────────────────────────────────────────────────────────────────────
function Write-Step  { param($msg) Write-Host "`n>>> $msg" -ForegroundColor Cyan }
function Write-OK    { param($msg) Write-Host "    [OK]   $msg" -ForegroundColor Green }
function Write-SKIP  { param($msg) Write-Host "    [SKIP] $msg" -ForegroundColor DarkGray }
function Write-WARN  { param($msg) Write-Host "    [WARN] $msg" -ForegroundColor Yellow }
function Write-ERR   { param($msg) Write-Host "    [ERRO] $msg" -ForegroundColor Red }

function ShouldSkip($dirName) {
    foreach ($prefix in $SkipPrefixes) {
        if ($dirName.ToLower().StartsWith($prefix)) { return $true }
    }
    return $false
}

function GetMapKey($dirName) {
    foreach ($key in $PhpMap.Keys) {
        if ($dirName.ToLower().StartsWith($key)) { return $key }
    }
    return $null
}

function Enable-Extension($iniFile, $extName) {
    if (-not (Test-Path $iniFile)) { return }

    $content = Get-Content $iniFile -Raw -Encoding UTF8

    # Remove entradas existentes (comentadas ou nao) para evitar duplicatas
    $content = $content -replace "(?m)^[ \t]*;?[ \t]*extension[ \t]*=[ \t]*(?:php_)?$extName(?:\.dll)?[ \t]*(\r?\n)?", ""

    # Procura bloco [ExtensionList] ou adiciona antes do primeiro extension= existente
    $directive = "extension=php_$extName.dll"

    if ($content -match "(?m)^\[ExtensionList\]") {
        $content = $content -replace "(?m)(^\[ExtensionList\])", "`$1`r`n$directive"
    } elseif ($content -match "(?m)^extension\s*=") {
        # Insere antes do primeiro extension=
        $content = $content -replace "(?m)(^extension\s*=)", "$directive`r`n`$1"
    } else {
        $content = $content.TrimEnd() + "`r`n`r`n; ImageMagick`r`n$directive`r`n"
    }

    $content = $content -replace '(\r?\n){3,}', "`r`n`r`n"
    Set-Content -Path $iniFile -Value $content -NoNewline -Encoding UTF8
}

# ─── Preparacao ──────────────────────────────────────────────────────────────────
Write-Step "Preparando diretorio temporario"
if (Test-Path $TempDir) { Remove-Item $TempDir -Recurse -Force }
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
Write-OK "Temp: $TempDir"

$ProgressPreference = 'SilentlyContinue'

# ─── Processar cada versao PHP ───────────────────────────────────────────────────
$phpDirs = Get-ChildItem $WampPhpRoot -Directory |
           Where-Object { $_.Name -match "^php\d" } |
           Sort-Object Name

$results = @{ OK=[System.Collections.Generic.List[string]]::new(); Skip=[System.Collections.Generic.List[string]]::new(); Fail=[System.Collections.Generic.List[string]]::new() }

foreach ($phpDir in $phpDirs) {
    $dirName = $phpDir.Name
    Write-Host ""
    Write-Host "  ─── $dirName ───────────────────────────────────" -ForegroundColor DarkCyan

    # Verificar se deve ignorar
    if (ShouldSkip $dirName) {
        Write-SKIP "Versao < 7.4 (sem suporte no imagick $ImagickVer)"
        $results.Skip.Add($dirName)
        continue
    }

    $mapKey = GetMapKey $dirName
    if (-not $mapKey) {
        Write-WARN "Versao nao mapeada: $dirName. Pulando..."
        $results.Skip.Add($dirName)
        continue
    }

    $phpVer   = $PhpMap[$mapKey].PhpVer
    $compiler = $PhpMap[$mapKey].Compiler
    $zipName  = "php_imagick-$ImagickVer-$phpVer-ts-$compiler-x64.zip"
    $zipUrl   = "$BaseUrl/$zipName"
    $zipPath  = Join-Path $TempDir $zipName
    $extDir   = $extractDir = Join-Path $phpDir.FullName "ext"

    Write-Host "    PHP $phpVer | Compilador: $compiler | Arquivo: $zipName" -ForegroundColor DarkGray

    # ── Download ──────────────────────────────────────────────────────────────
    Write-Host "    Baixando de $zipUrl..." -ForegroundColor DarkGray
    try {
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
    } catch {
        # Para PHP 8.5 ou builds inexistentes, apenas avisa e continua
        Write-WARN "Build nao disponivel para $dirName ($phpVer-ts-$compiler-x64). Pulando."
        Write-WARN "Causa: $_"
        $results.Fail.Add("$dirName (build nao disponivel)")
        continue
    }
    Write-OK "Download concluido: $zipName"

    # ── Extrair ───────────────────────────────────────────────────────────────
    $extractPath = Join-Path $TempDir "$dirName-extracted"
    if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }
    New-Item -ItemType Directory -Path $extractPath -Force | Out-Null

    try {
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
    } catch {
        Write-ERR "Falha ao extrair $zipName : $_"
        $results.Fail.Add("$dirName (erro de extracao)")
        continue
    }

    # ── Copiar php_imagick.dll para ext\ ──────────────────────────────────────
    $imagickDll = Get-ChildItem $extractPath -Filter "php_imagick.dll" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $imagickDll) {
        Write-ERR "php_imagick.dll nao encontrada no ZIP de $dirName"
        $results.Fail.Add("$dirName (php_imagick.dll ausente no ZIP)")
        continue
    }

    if (-not (Test-Path $extDir)) {
        New-Item -ItemType Directory -Path $extDir -Force | Out-Null
    }

    Copy-Item $imagickDll.FullName -Destination (Join-Path $extDir "php_imagick.dll") -Force
    Write-OK "php_imagick.dll -> ext\"

    # ── Copiar DLLs nativas do ImageMagick para a raiz do PHP ─────────────────
    # (CORE_RL_*, FILTER_RL_*, FILTER_CT_*, vcomp*.dll, etc.)
    $nativeDlls = Get-ChildItem $extractPath -Filter "*.dll" -Recurse |
                  Where-Object { $_.Name -ne "php_imagick.dll" }

    $copyCount = 0
    foreach ($dll in $nativeDlls) {
        $dest = Join-Path $phpDir.FullName $dll.Name
        Copy-Item $dll.FullName -Destination $dest -Force
        $copyCount++
    }
    Write-OK "$copyCount DLL(s) nativa(s) copiada(s) para a raiz de $dirName"

    # ── Habilitar extensao nos .ini ───────────────────────────────────────────
    $iniFiles = @(
        (Join-Path $phpDir.FullName "php.ini"),
        (Join-Path $phpDir.FullName "phpForApache.ini")
    )

    foreach ($iniFile in $iniFiles) {
        $iniName = [System.IO.Path]::GetFileName($iniFile)
        if (-not (Test-Path $iniFile)) {
            Write-SKIP "$iniName nao encontrado"
            continue
        }
        Enable-Extension -iniFile $iniFile -extName "imagick"
        Write-OK "extension=php_imagick habilitado em $iniName"
    }

    $results.OK.Add($dirName)
}

$ProgressPreference = 'Continue'

# ─── Limpeza ─────────────────────────────────────────────────────────────────────
Write-Step "Limpando arquivos temporarios"
if (Test-Path $TempDir) {
    Remove-Item $TempDir -Recurse -Force
    Write-OK "Removido: $TempDir"
}

# ─── Resumo Final ─────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  RESULTADO DA INSTALACAO DO IMAGICK" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Instalados com sucesso ($($results.OK.Count)):" -ForegroundColor Green
foreach ($v in $results.OK)   { Write-Host "    + $v" -ForegroundColor Green }
Write-Host ""
if ($results.Fail.Count -gt 0) {
    Write-Host "  Falhas / builds indisponiveis ($($results.Fail.Count)):" -ForegroundColor Yellow
    foreach ($v in $results.Fail) { Write-Host "    ! $v" -ForegroundColor Yellow }
    Write-Host ""
}
Write-Host "  Ignorados / sem suporte ($($results.Skip.Count)):" -ForegroundColor DarkGray
foreach ($v in $results.Skip) { Write-Host "    - $v" -ForegroundColor DarkGray }
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  PROXIMO PASSO:" -ForegroundColor Yellow
Write-Host "    Reinicie o WampServer e execute:" -ForegroundColor White
Write-Host "    php -m | Select-String imagick" -ForegroundColor DarkCyan
Write-Host ""
