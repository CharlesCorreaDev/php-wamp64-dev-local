$ErrorActionPreference = "Stop"

$phpRootDir = "D:\wamp64\bin\php"
$targetVersions = @(
    @{ Ver="7.4"; Path="php7.4.33"; VC="vc15" }
    @{ Ver="8.0"; Path="php8.0.30"; VC="vs16" }
    @{ Ver="8.1"; Path="php8.1.33"; VC="vs16" }
    @{ Ver="8.2"; Path="php8.2.29"; VC="vs16" }
    @{ Ver="8.2"; Path="php8.2.30"; VC="vs16" }
    @{ Ver="8.3"; Path="php8.3.28"; VC="vs16" }
    @{ Ver="8.4"; Path="php8.4.15"; VC="vs17" }
    @{ Ver="8.4"; Path="php8.4.19"; VC="vs17" }
    @{ Ver="8.5"; Path="php8.5.0";  VC="vs17" }
    @{ Ver="8.5"; Path="php8.5.4";  VC="vs17" }
)

Write-Host "--- Etapa 1: Download e Instalação de DLLs ---" -ForegroundColor Cyan

foreach ($target in $targetVersions) {
    $fullPath = Join-Path $phpRootDir $target.Path
    if (-not (Test-Path $fullPath)) { continue }

    $extDir = Join-Path $fullPath "ext"
    $destDll = Join-Path $extDir "php_interbase.dll"
    
    $dllUrl = ""
    if ($target.Ver -eq "7.4") {
        $dllUrl = "https://github.com/FirebirdSQL/php-firebird/releases/download/v1.1.1/php-7.4.16-interbase-1.1.1-win-x64-ts.dll"
    } elseif ($target.Ver -ge "8.3") {
        $dllName = "php_interbase-6.1.1-RC2-$($target.Ver)-$($target.VC).dll"
        $dllUrl = "https://github.com/FirebirdSQL/php-firebird/releases/download/v6.1.1-RC.2/$dllName"
    } else {
        $dllName = "php_$($target.Ver).0-interbase-3.0.1-win-x64-ts.dll"
        $dllUrl = "https://github.com/FirebirdSQL/php-firebird/releases/download/v3.0.1/$dllName"
    }

    Write-Host "-> $fullPath"
    try {
        Invoke-WebRequest -Uri $dllUrl -OutFile $destDll -ErrorAction Stop
        Write-Host "   [OK] DLL Instalada." -ForegroundColor Green
    } catch {
        Write-Host "   [ERRO] Falha no download: $_" -ForegroundColor Red
    }
}

Write-Host "`n--- Etapa 2: Limpeza de Duplicatas e Configuração ---" -ForegroundColor Cyan

foreach ($ver in (Get-ChildItem $phpRootDir -Directory)) {
    foreach ($ini in @("php.ini", "phpForApache.ini")) {
        $iniPath = Join-Path $ver.FullName $ini
        if (Test-Path $iniPath) {
            $content = Get-Content $iniPath
            $newContent = @()
            $foundInterbase = $false
            $changed = $false
            
            foreach ($line in $content) {
                if ($line -match '^\s*extension\s*=\s*(php_)?interbase(\.dll)?') {
                    if (-not $foundInterbase) {
                        $newContent += "extension=php_interbase.dll"
                        $foundInterbase = $true
                    } else {
                        $changed = $true # Duplicate found and removed
                    }
                } else {
                    $newContent += $line
                }
            }
            
            # If interbase was not found but should be there (for our target versions)
            if (-not $foundInterbase -and ($ver.Name -match '7\.4|8\.')) {
                $newContent = @("[PHP]", "extension=php_interbase.dll") + ($newContent | Where-Object { $_ -ne "[PHP]" })
                $changed = $true
            }

            if ($changed) {
                $newContent | Set-Content $iniPath
                Write-Host "   [FIX] $iniPath corrigido." -ForegroundColor Yellow
            }
        }
    }
}

Write-Host "`n--- Operação Concluída ---" -ForegroundColor Cyan
