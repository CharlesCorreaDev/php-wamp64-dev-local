$phpToolsPath = "D:\wamp64\bin\php\php-tools"
$phpRootDir = "D:\wamp64\bin\php"

Write-Host "--- Starting PHP Extension Cleanup ---" -ForegroundColor Cyan

Get-ChildItem -Path $phpRootDir -Directory -Filter "php*" | ForEach-Object {
    $ver = $_.Name
    $iniFiles = @("php.ini", "phpForApache.ini")
    
    foreach ($iniName in $iniFiles) {
        $iniPath = Join-Path $_.FullName $iniName
        if (Test-Path $iniPath) {
            Write-Host "Processing $ver -> $iniName" -ForegroundColor Yellow
            
            $content = Get-Content $iniPath
            $newContent = @()
            $injectedBlockRemoved = $false
            
            # WampServer php.ini usually starts with [PHP] at line 1.
            # We look for extension= lines in the first 20 lines that are known injections.
            for ($i = 0; $i -lt $content.Count; $i++) {
                $line = $content[$i].Trim()
                
                # If we are in the first 20 lines and it's an extension line
                if ($i -gt 0 -and $i -lt 20 -and $line -match "^extension\s*=\s*") {
                    # Extract extension name (e.g., php_curl.dll or curl)
                    $extMatch = [regex]::Match($line, "^extension\s*=\s*(?:php_)?(\w+)(?:\.dll)?")
                    if ($extMatch.Success) {
                        $extName = $extMatch.Groups[1].Value
                        # Check if it exists later in the file (normalized search)
                        $pattern = "^\s*extension\s*=\s*(?:php_)?$extName(?:\.dll)?"
                        $isDuplicate = $false
                        for ($j = 20; $j -lt $content.Count; $j++) {
                            if ($content[$j] -match $pattern) {
                                $isDuplicate = $true
                                break
                            }
                        }
                        
                        if ($isDuplicate) {
                            Write-Host "  [REMOVED] Duplicate '$extName' at line $($i+1)" -ForegroundColor DarkGray
                            $injectedBlockRemoved = $true
                            continue # Skip adding this line
                        }
                    }
                }
                $newContent += $content[$i]
            }
            
            if ($injectedBlockRemoved) {
                $newContent | Set-Content $iniPath
                Write-Host "  [DONE] Saved $iniName" -ForegroundColor Green
            } else {
                Write-Host "  [KEEP] No duplicates found in top block." -ForegroundColor Cyan
            }
        }
    }
}

Write-Host "--- Cleanup Complete ---" -ForegroundColor Cyan
