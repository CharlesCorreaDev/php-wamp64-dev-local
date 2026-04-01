$phpRootDir = "D:\wamp64\bin\php"
$versions = Get-ChildItem -Path $phpRootDir -Directory | Where-Object { $_.Name -match '^php' }

Write-Host "--- Iniciando Limpeza Global de Duplicatas ---" -ForegroundColor Cyan

foreach ($ver in $versions) {
    Write-Host "`nVerificando $($ver.Name)..." -ForegroundColor Gray
    $iniFiles = @("php.ini", "phpForApache.ini")
    foreach ($ini in $iniFiles) {
        $iniPath = Join-Path $ver.FullName $ini
        if (Test-Path $iniPath) {
            $content = Get-Content $iniPath
            $newContent = @()
            $loadedExtensions = @{} # Dictionary to track what's already loaded
            $changed = $false
            
            foreach ($line in $content) {
                # Match active extension lines (not commented out)
                if ($line -match '^\s*(extension|zend_extension)\s*=\s*(.*)') {
                    $type = $Matches[1]
                    $ext = $Matches[2].Trim().Replace('"', '').Replace("'", "")
                    
                    # Normalize extension name (extract filename if it's a path)
                    $extName = Split-Path $ext -Leaf
                    
                    if ($loadedExtensions.ContainsKey($extName.ToLower())) {
                        # Duplicate found! Comment it out.
                        $newContent += "; DUPLICATE REMOVED: $line"
                        $changed = $true
                        Write-Host "   [DUP] Removida duplicata de '$extName' em $ini" -ForegroundColor Yellow
                    } else {
                        $newContent += $line
                        $loadedExtensions[$extName.ToLower()] = $true
                    }
                } else {
                    $newContent += $line
                }
            }
            
            if ($changed) {
                $newContent | Set-Content $iniPath
                Write-Host "   [OK] $ini atualizado." -ForegroundColor Green
            }
        }
    }
}

Write-Host "`n--- Limpeza Concluída ---" -ForegroundColor Cyan
