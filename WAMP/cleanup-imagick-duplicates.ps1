<#
.SYNOPSIS
    Remove entradas duplicadas de 'extension=imagick' em todos os .ini do WampServer.
.DESCRIPTION
    Abordagem linha-por-linha (imune a problemas de \r\n Windows).
    Garante exatamente UMA declaracao ativa de extension=php_imagick.dll.
    Remove TODAS as ocorrencias (comentadas ou nao) e reinsere uma unica.
#>

$ErrorActionPreference = "Stop"
$WampPhpRoot  = "D:\wamp64\bin\php"
$SkipPrefixes = @("php5.", "php7.0.")

function ShouldSkip($name) {
    foreach ($p in $SkipPrefixes) { if ($name.StartsWith($p)) { return $true } }
    return $false
}

# Verifica se uma linha e uma declaracao de imagick (ativa ou comentada)
function IsImagickLine($line) {
    # Normaliza: remove \r e espacos de borda
    $l = $line.TrimEnd("`r", " ", "`t")
    # Aceita: extension=imagick, extension=php_imagick.dll, ;extension=imagick, etc.
    return $l -match '(?i)^\s*;?\s*extension\s*=\s*(php_)?imagick(\.dll)?\s*$'
}

# Verificacao rapida — conta ativos (sem ;)
function CountActive($lines) {
    $count = 0
    foreach ($l in $lines) {
        $clean = $l.TrimEnd("`r", " ", "`t")
        if ($clean -match '(?i)^\s*extension\s*=\s*(php_)?imagick(\.dll)?\s*$') { $count++ }
    }
    return $count
}

Write-Host ""
Write-Host "=== Limpando duplicatas de extension=imagick ===" -ForegroundColor Cyan

$totalFixed = 0
$totalOk    = 0

$phpDirs = Get-ChildItem $WampPhpRoot -Directory |
           Where-Object { $_.Name -match "^php\d" } |
           Sort-Object Name

foreach ($phpDir in $phpDirs) {
    if (ShouldSkip $phpDir.Name) { continue }

    $iniFiles = @(
        (Join-Path $phpDir.FullName "php.ini"),
        (Join-Path $phpDir.FullName "phpForApache.ini")
    )

    foreach ($iniFile in $iniFiles) {
        $iniName = [System.IO.Path]::GetFileName($iniFile)
        if (-not (Test-Path $iniFile)) { continue }

        # Ler linha por linha (preserva encoding original)
        $lines      = [System.IO.File]::ReadAllLines($iniFile, [System.Text.Encoding]::UTF8)
        $activeCount = CountActive $lines

        if ($activeCount -le 1) {
            Write-Host "  [OK]   $($phpDir.Name)\$iniName  ($activeCount declaracao ativa)" -ForegroundColor DarkGray
            $totalOk++
            continue
        }

        # Remover TODAS as linhas imagick (ativas e comentadas)
        $filtered = [System.Collections.Generic.List[string]]::new()
        $removed  = 0
        foreach ($line in $lines) {
            if (IsImagickLine $line) {
                $removed++
            } else {
                $filtered.Add($line)
            }
        }

        # Inserir UMA declaracao antes do primeiro extension= ativo encontrado
        $directive  = "extension=php_imagick.dll"
        $inserted   = $false
        $finalLines = [System.Collections.Generic.List[string]]::new()

        foreach ($line in $filtered) {
            $clean = $line.TrimEnd("`r", " ", "`t")
            if (-not $inserted -and $clean -match '(?i)^\s*extension\s*=') {
                $finalLines.Add($directive)
                $inserted = $true
            }
            $finalLines.Add($line)
        }

        # Se nao encontrou nenhum extension=, adiciona no final
        if (-not $inserted) {
            $finalLines.Add("")
            $finalLines.Add("; ImageMagick")
            $finalLines.Add($directive)
        }

        # Salvar (UTF-8 sem BOM, com CRLF)
        $newContent = $finalLines -join "`r`n"
        # Remover linhas em branco excessivas (mais de 2 consecutivas)
        $newContent = [regex]::Replace($newContent, '(\r\n){3,}', "`r`n`r`n")
        [System.IO.File]::WriteAllText($iniFile, $newContent, [System.Text.Encoding]::UTF8)

        Write-Host "  [FIXED] $($phpDir.Name)\$iniName  (removidas $removed, inserida 1)" -ForegroundColor Green
        $totalFixed++
    }
}

Write-Host ""
Write-Host "══════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Arquivos corrigidos : $totalFixed" -ForegroundColor $(if ($totalFixed -gt 0) { "Green" } else { "White" })
Write-Host "  Ja estavam OK       : $totalOk" -ForegroundColor White
Write-Host "══════════════════════════════════════════════" -ForegroundColor Cyan

if ($totalFixed -gt 0) {
    Write-Host ""
    Write-Host "  Reinicie o WampServer para aplicar." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  Verificacao rapida:" -ForegroundColor DarkCyan
Write-Host "  & 'D:\wamp64\bin\php\php7.4.33\php.exe' -m 2>&1 | Select-String 'imagick|Warning'" -ForegroundColor DarkGray
Write-Host ""
