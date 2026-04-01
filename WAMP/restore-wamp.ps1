<#
.SYNOPSIS
    Restaura o backup de PHP para um WampServer (novo ou existente).
.DESCRIPTION
    Copia as versoes PHP do backup local para o WampServer de destino e:
      - Ajusta automaticamente todos os caminhos absolutos nos arquivos .ini
        (ex: browscap, extension_dir) para refletir o novo caminho do Wamp
      - Copia a pasta php-tools para o local correto
      - Oferece opcao de sobrescrever ou ignorar versoes ja existentes
.NOTES
    Execute como Administrador.
    Requer que o backup-wamp.ps1 tenha sido executado antes.
#>

$ErrorActionPreference = "Stop"
$ScriptDir  = $PSScriptRoot
$BackupRoot = Join-Path $ScriptDir "php-backup"
$MetaFile   = Join-Path $BackupRoot "backup-meta.json"

# ─── Banner ───────────────────────────────────────────────────────────────────
Clear-Host
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         WAMP PHP RESTORE - Restauracao de Backup         ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ─── 1. Verificar se backup existe ───────────────────────────────────────────
if (-not (Test-Path $BackupRoot)) {
    Write-Host "  [ERRO] Pasta de backup nao encontrada: $BackupRoot" -ForegroundColor Red
    Write-Host "  Execute 'backup-wamp.ps1' primeiro para criar o backup." -ForegroundColor Yellow
    exit 1
}

# ─── 2. Ler metadados do backup ───────────────────────────────────────────────
$meta        = $null
$sourceWamp  = "D:\wamp64"   # fallback

if (Test-Path $MetaFile) {
    $meta       = Get-Content $MetaFile -Raw | ConvertFrom-Json
    $sourceWamp = $meta.SourceWampRoot
    Write-Host "  Backup criado em : $($meta.BackupDate)" -ForegroundColor DarkGray
    Write-Host "  Origem original  : $sourceWamp" -ForegroundColor DarkGray
    Write-Host "  Versoes no backup: $($meta.Versions -join ', ')" -ForegroundColor DarkGray
    Write-Host ""
} else {
    Write-Host "  [AVISO] backup-meta.json nao encontrado. Caminho de origem sera necessario." -ForegroundColor Yellow
    Write-Host ""
}

# ─── 3. Perguntar caminho de destino (novo WampServer) ───────────────────────
Write-Host "  Informe o caminho de instalacao do WampServer de DESTINO:" -ForegroundColor Yellow
Write-Host "  Exemplos:" -ForegroundColor DarkGray
Write-Host "    D:\wamp64            (instalacao padrao em D:)" -ForegroundColor DarkGray
Write-Host "    C:\wamp64            (instalacao padrao em C:)" -ForegroundColor DarkGray
Write-Host "    E:\dev\wampserver    (instalacao customizada)" -ForegroundColor DarkGray
Write-Host "    C:\Users\Joao\wamp64 (instalacao em pasta de usuario)" -ForegroundColor DarkGray
Write-Host ""

$wampDefault = "D:\wamp64"
$userInput   = Read-Host "  WampServer de DESTINO [$wampDefault]"
if ([string]::IsNullOrWhiteSpace($userInput)) { $userInput = $wampDefault }
$DestWampRoot = $userInput.TrimEnd('\', '/')
$DestPhpDir   = Join-Path $DestWampRoot "bin\php"

if (-not (Test-Path $DestWampRoot)) {
    Write-Host ""
    Write-Host "  [ERRO] Caminho nao encontrado: $DestWampRoot" -ForegroundColor Red
    Write-Host "  Verifique se o WampServer esta instalado neste local." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "  [OK] Destino: $DestPhpDir" -ForegroundColor Green

# Criar pasta php se nao existir
if (-not (Test-Path $DestPhpDir)) {
    New-Item -ItemType Directory -Path $DestPhpDir -Force | Out-Null
    Write-Host "  [OK] Pasta bin\php criada." -ForegroundColor Green
}

# ─── 4. Perguntar sobre sobrescrita ──────────────────────────────────────────
Write-Host ""
Write-Host "  Como tratar versoes PHP ja existentes no destino?" -ForegroundColor Yellow
Write-Host "    [1] Sobrescrever completamente  (recomendado para restauracao total)" -ForegroundColor White
Write-Host "    [2] Ignorar versoes ja existentes  (adiciona apenas versoes novas)" -ForegroundColor White
Write-Host "    [3] Fazer backup das existentes antes de sobrescrever" -ForegroundColor White
Write-Host ""
$overwriteMode = Read-Host "  Escolha [1/2/3]"
if ($overwriteMode -notmatch '^[123]$') { $overwriteMode = "1" }

# ─── 5. Listar itens do backup ────────────────────────────────────────────────
$backupPhpDirs = Get-ChildItem $BackupRoot -Directory |
                 Where-Object { $_.Name -match "^php\d" } |
                 Sort-Object Name
$backupTools   = Join-Path $BackupRoot "php-tools"
$hasTools      = Test-Path $backupTools

Write-Host ""
Write-Host "  Versoes no backup para restaurar:" -ForegroundColor Cyan
foreach ($d in $backupPhpDirs) { Write-Host "    • $($d.Name)" -ForegroundColor White }
if ($hasTools) { Write-Host "    • php-tools" -ForegroundColor White }
Write-Host ""

$confirm = Read-Host "  Iniciar restauracao? (S/N)"
if ($confirm -notmatch '^[Ss]') {
    Write-Host "  Restauracao cancelada." -ForegroundColor DarkGray
    exit 0
}

# ─── 6. Funcao de copia com progresso ────────────────────────────────────────
function Copy-FolderWithProgress {
    param($Source, $Destination, $Label, [switch]$Overwrite)

    $files = Get-ChildItem $Source -Recurse -File
    $total = $files.Count
    $done  = 0

    Write-Host "    Copiando $Label ($total arquivos)..." -ForegroundColor DarkGray

    foreach ($file in $files) {
        $relative = $file.FullName.Substring($Source.Length).TrimStart('\')
        $dest     = Join-Path $Destination $relative
        $destDir  = [System.IO.Path]::GetDirectoryName($dest)
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        if ($Overwrite -or -not (Test-Path $dest)) {
            Copy-Item $file.FullName -Destination $dest -Force
        }
        $done++
        if ($done % 100 -eq 0 -or $done -eq $total) {
            $pct = [math]::Round($done / $total * 100)
            Write-Progress -Activity "Restaurando $Label" -Status "$done/$total" -PercentComplete $pct
        }
    }
    Write-Progress -Activity "Restaurando $Label" -Completed
}

# ─── 7. Ajustar caminhos absolutos nos .ini ──────────────────────────────────
function Update-IniPaths {
    param($IniFile, $OldWampRoot, $NewWampRoot)

    if (-not (Test-Path $IniFile)) { return }

    # Normaliza barras para comparacao robusta
    $oldFwd = $OldWampRoot.Replace('\', '/')
    $newFwd = $NewWampRoot.Replace('\', '/')
    $oldBck = $OldWampRoot.Replace('/', '\')
    $newBck = $NewWampRoot.Replace('/', '\')

    $lines   = [System.IO.File]::ReadAllLines($IniFile, [System.Text.Encoding]::UTF8)
    $changed = $false

    $updated = $lines | ForEach-Object {
        $line = $_
        if ($line -match '^\s*;') { return $line }  # linha comentada, nao alterar

        # Substitui ambas as formas de barra
        $newLine = $line.Replace($oldFwd, $newFwd).Replace($oldBck, $newBck)

        # Caso misturado (ex: D:/wamp64\bin)
        $newLine = $newLine -replace [regex]::Escape($OldWampRoot.Replace('\','/')),  $newFwd
        $newLine = $newLine -replace [regex]::Escape($OldWampRoot.Replace('/','\\')), $newBck

        if ($newLine -ne $line) { $changed = $true }
        $newLine
    }

    if ($changed) {
        $content = $updated -join "`r`n"
        [System.IO.File]::WriteAllText($IniFile, $content, [System.Text.Encoding]::UTF8)
        return $true
    }
    return $false
}

# ─── 8. Restaurar cada versao PHP ────────────────────────────────────────────
Write-Host ""
Write-Host "  ─── Restaurando versoes PHP ──────────────────────────" -ForegroundColor Cyan

$results = @{ OK=[System.Collections.Generic.List[string]]::new(); Skipped=[System.Collections.Generic.List[string]]::new() }

foreach ($phpDir in $backupPhpDirs) {
    $destFolder = Join-Path $DestPhpDir $phpDir.Name
    $exists     = Test-Path $destFolder

    Write-Host ""
    Write-Host "  ─ $($phpDir.Name)" -ForegroundColor DarkCyan

    if ($exists -and $overwriteMode -eq "2") {
        Write-Host "    [SKIP] Ja existe no destino (modo: ignorar existentes)" -ForegroundColor DarkGray
        $results.Skipped.Add($phpDir.Name)
        continue
    }

    if ($exists -and $overwriteMode -eq "3") {
        $bkDir = "$destFolder`_bkp_$(Get-Date -Format 'yyyyMMddHHmm')"
        Write-Host "    Fazendo backup de seguranca -> $bkDir" -ForegroundColor DarkGray
        Copy-Item $destFolder -Destination $bkDir -Recurse -Force
    }

    Copy-FolderWithProgress -Source $phpDir.FullName -Destination $destFolder -Overwrite

    # Ajustar caminhos nos ini
    $iniFiles = @("php.ini", "phpForApache.ini") | ForEach-Object { Join-Path $destFolder $_ }
    $iniUpdated = 0
    foreach ($ini in $iniFiles) {
        if (Update-IniPaths -IniFile $ini -OldWampRoot $sourceWamp -NewWampRoot $DestWampRoot) {
            $iniUpdated++
        }
    }

    $pathMsg = ''
    if ($iniUpdated -gt 0) { $pathMsg = "  [$iniUpdated .ini atualizados]" }
    Write-Host "    [OK] $($phpDir.Name)$pathMsg" -ForegroundColor Green
    $results.OK.Add($phpDir.Name)
}

# ─── 9. Restaurar php-tools ───────────────────────────────────────────────────
if ($hasTools) {
    Write-Host ""
    Write-Host "  ─── Restaurando php-tools ────────────────────────────" -ForegroundColor Cyan
    $destTools = Join-Path $DestPhpDir "php-tools"
    Copy-FolderWithProgress -Source $backupTools -Destination $destTools -Overwrite

    # Ajustar caminhos em qualquer .ini dentro de php-tools
    Get-ChildItem $destTools -Filter "*.ini" -Recurse | ForEach-Object {
        Update-IniPaths -IniFile $_.FullName -OldWampRoot $sourceWamp -NewWampRoot $DestWampRoot | Out-Null
    }
    Write-Host "    [OK] php-tools" -ForegroundColor Green
}

# ─── 10. Resumo ───────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                RESTAURACAO CONCLUIDA!                   ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  Destino   : $DestPhpDir" -ForegroundColor White
Write-Host "  Restaurados: $($results.OK.Count) versoes PHP" -ForegroundColor White
if ($results.Skipped.Count -gt 0) {
    Write-Host "  Ignorados  : $($results.Skipped.Count) versoes (ja existiam)" -ForegroundColor DarkGray
}
Write-Host ""

if ($sourceWamp -ne $DestWampRoot) {
    Write-Host "  Caminhos ajustados:" -ForegroundColor Yellow
    Write-Host "    $sourceWamp  =>  $DestWampRoot" -ForegroundColor DarkGray
    Write-Host ""
}

Write-Host "  PROXIMOS PASSOS:" -ForegroundColor Yellow
Write-Host "    1. Reinicie o WampServer" -ForegroundColor White
Write-Host "    2. Verifique extensoes em phpinfo()" -ForegroundColor White
Write-Host "    3. Teste com: php -m | Select-String imagick" -ForegroundColor DarkCyan
Write-Host ""
