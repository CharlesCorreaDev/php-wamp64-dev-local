<#
.SYNOPSIS
    Instala e configura o banco de dados Browscap (Full) para todas as versoes PHP 7.2+ no WampServer.
.DESCRIPTION
    - Baixa o php_browscap.ini (versao Full) de browscap.org
    - Salva em D:\wamp64\bin\php\php-tools\browscap\
    - Atualiza php.ini e phpForApache.ini de todos os PHP >= 7.2
.NOTES
    Execute como Administrador.
#>

$ErrorActionPreference = "Stop"

# ─── Configuracoes ──────────────────────────────────────────────────────────────
$WampPhpRoot  = "D:\wamp64\bin\php"
$BrowscapDir  = "$WampPhpRoot\php-tools\browscap"
$BrowscapFile = "$BrowscapDir\browscap.ini"
$BrowscapUrl  = "https://browscap.org/stream?q=Full_PHP_BrowsCapINI"

# Prefixos de versao a IGNORAR (anteriores ao 7.2)
$SkipPrefixes = @("php5.", "php7.0.", "php7.1.")

# ─── Helpers ────────────────────────────────────────────────────────────────────
function Write-Step  { param($msg) Write-Host "`n>>> $msg" -ForegroundColor Cyan }
function Write-OK    { param($msg) Write-Host "    [OK]   $msg" -ForegroundColor Green }
function Write-SKIP  { param($msg) Write-Host "    [SKIP] $msg" -ForegroundColor DarkGray }
function Write-WARN  { param($msg) Write-Host "    [WARN] $msg" -ForegroundColor Yellow }

function ShouldSkip($dirName) {
    foreach ($prefix in $SkipPrefixes) {
        if ($dirName.ToLower().StartsWith($prefix)) { return $true }
    }
    return $false
}

# ─── 1. Criar diretorio central ──────────────────────────────────────────────────
Write-Step "Criando diretorio central do Browscap"
if (-not (Test-Path $BrowscapDir)) {
    New-Item -ItemType Directory -Path $BrowscapDir -Force | Out-Null
    Write-OK "Diretorio criado: $BrowscapDir"
} else {
    Write-OK "Diretorio ja existe: $BrowscapDir"
}

# ─── 2. Download ─────────────────────────────────────────────────────────────────
Write-Step "Baixando Browscap Full (~100MB)..."
Write-Host "    URL: $BrowscapUrl" -ForegroundColor DarkCyan

$ProgressPreference = 'SilentlyContinue'
try {
    Invoke-WebRequest -Uri $BrowscapUrl -OutFile $BrowscapFile -UseBasicParsing
} catch {
    Write-Host "`n[ERRO] Falha no download: $_" -ForegroundColor Red
    exit 1
}
$ProgressPreference = 'Continue'

$sizeMB = [math]::Round((Get-Item $BrowscapFile).Length / 1MB, 1)
Write-OK "Arquivo salvo: $BrowscapFile ($sizeMB MB)"

# ─── 3. Configurar php.ini em cada versao ────────────────────────────────────────
Write-Step "Atualizando arquivos .ini de cada versao PHP..."

$phpDirs = Get-ChildItem $WampPhpRoot -Directory |
           Where-Object { $_.Name -match "^php\d" } |
           Sort-Object Name

$totalOK   = 0
$totalSkip = 0

foreach ($phpDir in $phpDirs) {
    if (ShouldSkip $phpDir.Name) {
        Write-SKIP "$($phpDir.Name)  (versao < 7.2, ignorado conforme configuracao)"
        $totalSkip++
        continue
    }

    $iniFiles = @(
        (Join-Path $phpDir.FullName "php.ini"),
        (Join-Path $phpDir.FullName "phpForApache.ini")
    )

    foreach ($iniFile in $iniFiles) {
        $iniName = [System.IO.Path]::GetFileName($iniFile)

        if (-not (Test-Path $iniFile)) {
            Write-SKIP "$($phpDir.Name)\$iniName  (arquivo nao encontrado)"
            continue
        }

        $content = Get-Content $iniFile -Raw -Encoding UTF8

        # Remove qualquer linha browscap existente (comentada ou nao)
        $content = $content -replace '(?m)^[ \t]*;?[ \t]*browscap[ \t]*=.*(\r?\n)?', ''

        # Monta a diretiva com caminho usando / (compativel com PHP no Windows)
        $safePath  = $BrowscapFile.Replace('\', '/')
        $directive = "browscap = $safePath"

        # Insere apos [browscap] se existir, senao apos [PHP]
        if ($content -match '(?m)^\[browscap\]') {
            $content = $content -replace '(?m)(^\[browscap\])', "`$1`r`n$directive"
        } elseif ($content -match '(?m)^\[PHP\]') {
            $content = $content -replace '(?m)(^\[PHP\])', "`$1`r`n`r`n; Browscap - banco de dados de deteccao de browser`r`n$directive"
        } else {
            $content = $content.TrimEnd() + "`r`n`r`n; Browscap - banco de dados de deteccao de browser`r`n$directive`r`n"
        }

        # Remove linhas em branco excessivas (mais de 2 consecutivas)
        $content = $content -replace '(\r?\n){3,}', "`r`n`r`n"

        Set-Content -Path $iniFile -Value $content -NoNewline -Encoding UTF8
        Write-OK "$($phpDir.Name)\$iniName"
        $totalOK++
    }
}

# ─── 4. Resumo ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  BROWSCAP CONFIGURADO COM SUCESSO" -ForegroundColor Cyan
Write-Host "  Arquivos atualizados : $totalOK" -ForegroundColor White
Write-Host "  Versoes ignoradas    : $totalSkip (< 7.2)" -ForegroundColor White
Write-Host "  Arquivo browscap     : $BrowscapFile" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Reinicie o WampServer para aplicar as alteracoes." -ForegroundColor Yellow
Write-Host ""
