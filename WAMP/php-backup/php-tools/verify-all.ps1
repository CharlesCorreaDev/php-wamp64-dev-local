$phpDir = "D:\wamp64\bin\php"
$tools = @("phpunit", "phpstan", "psalm", "phpcs", "phpcbf", "phpmd", "rector", "php-cs-fixer", "snyk")

Write-Host "--- PHP & Xdebug Status ---" -ForegroundColor Cyan
$phpFolders = Get-ChildItem -Path $phpDir -Directory -Filter "php*"
foreach ($folder in $phpFolders) {
    $phpExe = Join-Path $folder.FullName "php.exe"
    if (Test-Path $phpExe) {
        $ver = & $phpExe -v
        $xdebug = $ver | Select-String "Xdebug"
        if ($xdebug) {
            Write-Host "$($folder.Name): OK ($($xdebug.ToString().Trim()))" -ForegroundColor Green
        } else {
            Write-Host "$($folder.Name): No Xdebug" -ForegroundColor Yellow
        }
    }
}

Write-Host "`n--- Tools Status ---" -ForegroundColor Cyan
foreach ($tool in $tools) {
    $batPath = Join-Path $toolsDir "$tool.bat"
    if (Test-Path $batPath) {
        Write-Host "$($tool): Found ($batPath)" -ForegroundColor Green
    } else {
        Write-Host "$($tool): NOT FOUND" -ForegroundColor Red
    }
}

Write-Host "`n--- PHPCompatibility Check ---" -ForegroundColor Cyan
$phpcs = Get-Command phpcs -ErrorAction SilentlyContinue
if ($phpcs) {
    & phpcs -i | Select-String "PHPCompatibility"
}
