<#
.SYNOPSIS
    Cria um backup completo das versoes PHP e php-tools do WampServer.
.DESCRIPTION
    Copia para a pasta onde este script esta localizado:
      - Todas as pastas php* de D:\wamp64\bin\php\ (ou caminho informado)
      - A pasta php-tools (browscap, ferramentas customizadas, etc.)
      - Quaisquer DLLs/OCX soltas na pasta raiz de cada PHP

    O backup pode ser restaurado com o script restore-wamp.ps1.
.NOTES
    Execute como Administrador.
    O backup pode ocupar varios GB dependendo das versoes instaladas.
#>

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot

# ─── Banner ───────────────────────────────────────────────────────────────────
Clear-Host
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         WAMP PHP BACKUP - Criacao de Backup              ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ─── 1. Perguntar caminho do WampServer ──────────────────────────────────────
Write-Host "  Informe o caminho de instalacao do WampServer:" -ForegroundColor Yellow
Write-Host "  Exemplos: D:\wamp64   C:\wamp64   E:\dev\wamp64" -ForegroundColor DarkGray
Write-Host ""

$wampDefault = "D:\wamp64"
$userInput   = Read-Host "  WampServer path [$wampDefault]"
if ([string]::IsNullOrWhiteSpace($userInput)) { $userInput = $wampDefault }
$WampRoot = $userInput.TrimEnd('\', '/')

$WampPhpDir = Join-Path $WampRoot "bin\php"

if (-not (Test-Path $WampPhpDir)) {
    Write-Host ""
    Write-Host "  [ERRO] Pasta nao encontrada: $WampPhpDir" -ForegroundColor Red
    Write-Host "  Verifique o caminho e tente novamente." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "  [OK] WampServer encontrado em: $WampRoot" -ForegroundColor Green

# ─── 2. Definir destino do backup ────────────────────────────────────────────
$BackupRoot = Join-Path $ScriptDir "php-backup"
Write-Host "  [OK] Destino do backup     : $BackupRoot" -ForegroundColor Green
Write-Host ""

# ─── 3. Listar itens a copiar ────────────────────────────────────────────────
$phpFolders    = Get-ChildItem $WampPhpDir -Directory | Where-Object { $_.Name -match "^php\d" }
$toolsFolder   = Join-Path $WampPhpDir "php-tools"
$hasTools      = Test-Path $toolsFolder

Write-Host "  Itens que serao copiados:" -ForegroundColor Cyan
foreach ($f in $phpFolders) {
    $sizeMB = [math]::Round((Get-ChildItem $f.FullName -Recurse -File | Measure-Object Length -Sum).Sum / 1MB, 1)
    Write-Host "    • $($f.Name)  (~$sizeMB MB)" -ForegroundColor White
}
if ($hasTools) {
    $toolsMB = [math]::Round((Get-ChildItem $toolsFolder -Recurse -File | Measure-Object Length -Sum).Sum / 1MB, 1)
    Write-Host "    • php-tools  (~$toolsMB MB)" -ForegroundColor White
}

Write-Host ""
$totalGB = [math]::Round((Get-ChildItem $WampPhpDir -Recurse -File |
    Where-Object { $_.FullName -notmatch "\\php-tools\\" -or $hasTools } |
    Measure-Object Length -Sum).Sum / 1GB, 2)
Write-Host "  Tamanho total estimado: ~$totalGB GB" -ForegroundColor Yellow
Write-Host ""

$confirm = Read-Host "  Deseja continuar? (S/N)"
if ($confirm -notmatch '^[Ss]') {
    Write-Host "  Backup cancelado." -ForegroundColor DarkGray
    exit 0
}

# ─── 4. Criar pasta de backup ─────────────────────────────────────────────────
if (-not (Test-Path $BackupRoot)) {
    New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
}

# Salvar metadados do backup (raiz original para o restore saber de onde veio)
$meta = @{
    BackupDate    = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    SourceWampRoot = $WampRoot
    SourcePhpDir  = $WampPhpDir
    Versions      = @($phpFolders | ForEach-Object { $_.Name })
}
$meta | ConvertTo-Json | Set-Content (Join-Path $BackupRoot "backup-meta.json") -Encoding UTF8

Write-Host ""

# ─── 5. Funcao de copia com progresso ────────────────────────────────────────
function Copy-FolderWithProgress {
    param($Source, $Destination, $Label)

    $files = Get-ChildItem $Source -Recurse -File
    $total = $files.Count
    $done  = 0

    Write-Host "  Copiando $Label ($total arquivos)..." -ForegroundColor DarkCyan

    foreach ($file in $files) {
        $relative = $file.FullName.Substring($Source.Length).TrimStart('\')
        $dest     = Join-Path $Destination $relative
        $destDir  = [System.IO.Path]::GetDirectoryName($dest)
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        Copy-Item $file.FullName -Destination $dest -Force
        $done++
        if ($done % 50 -eq 0 -or $done -eq $total) {
            $pct = [math]::Round($done / $total * 100)
            Write-Progress -Activity "Copiando $Label" -Status "$done/$total arquivos" -PercentComplete $pct
        }
    }
    Write-Progress -Activity "Copiando $Label" -Completed
    Write-Host "  [OK]   $Label" -ForegroundColor Green
}

# ─── 6. Copiar versoes PHP ────────────────────────────────────────────────────
Write-Host "  ─── Copiando versoes PHP ─────────────────────────" -ForegroundColor Cyan
foreach ($phpDir in $phpFolders) {
    $dest = Join-Path $BackupRoot $phpDir.Name
    Copy-FolderWithProgress -Source $phpDir.FullName -Destination $dest -Label $phpDir.Name
}

# ─── 7. Copiar php-tools ──────────────────────────────────────────────────────
if ($hasTools) {
    Write-Host ""
    Write-Host "  ─── Copiando php-tools ───────────────────────────" -ForegroundColor Cyan
    $dest = Join-Path $BackupRoot "php-tools"
    Copy-FolderWithProgress -Source $toolsFolder -Destination $dest -Label "php-tools"
}

# ─── 8. Resumo ───────────────────────────────────────────────────────────────
$backupSizeMB = [math]::Round((Get-ChildItem $BackupRoot -Recurse -File | Measure-Object Length -Sum).Sum / 1MB, 1)
$toolsLabel   = if ($hasTools) { 'php-tools' } else { '(sem php-tools)' }

Write-Host ''
Write-Host 'Backup concluido!' -ForegroundColor Green
Write-Host '  ─────────────────────────────────────────────────────────' -ForegroundColor Green
Write-Host "  Local   : $BackupRoot" -ForegroundColor White
Write-Host "  Versoes : $($phpFolders.Count) versoes PHP + $toolsLabel" -ForegroundColor White
Write-Host "  Tamanho : $backupSizeMB MB no total" -ForegroundColor White
Write-Host ''
Write-Host '  Para restaurar em outro WampServer, execute:' -ForegroundColor Yellow
Write-Host '  .\restore-wamp.ps1' -ForegroundColor DarkCyan
Write-Host ''
