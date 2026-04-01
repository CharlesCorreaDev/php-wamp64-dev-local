$phpDir = "D:\wamp64\bin\php"
$toolsDir = "D:\wamp64\bin\php\php-tools"
$xdebugDir = Join-Path $toolsDir "xdebug_logs"
if (!(Test-Path $xdebugDir)) { New-Item -ItemType Directory -Path $xdebugDir }

$xdebugMap = @{
    "5.6" = "https://xdebug.org/files/php_xdebug-2.5.5-5.6-vc11-x86_64.dll"
    "7.0" = "https://xdebug.org/files/php_xdebug-2.7.2-7.0-vc14-x86_64.dll"
    "7.1" = "https://xdebug.org/files/php_xdebug-2.9.8-7.1-vc14-x86_64.dll"
    "7.2" = "https://xdebug.org/files/php_xdebug-3.1.6-7.2-vc15-x86_64.dll"
    "7.3" = "https://xdebug.org/files/php_xdebug-3.1.6-7.3-vc15-x86_64.dll"
    "7.4" = "https://xdebug.org/files/php_xdebug-3.1.6-7.4-vc15-x86_64.dll"
    "8.0" = "https://xdebug.org/files/php_xdebug-3.3.1-8.0-vs16-x86_64.dll"
    "8.1" = "https://xdebug.org/files/php_xdebug-3.3.1-8.1-vs16-x86_64.dll"
    "8.2" = "https://xdebug.org/files/php_xdebug-3.4.1-8.2-vs16-x86_64.dll"
    "8.3" = "https://xdebug.org/files/php_xdebug-3.5.1-8.3-vs16-x86_64.dll"
    "8.4" = "https://xdebug.org/files/php_xdebug-3.5.1-8.4-vs17-x86_64.dll"
    "8.5" = "https://xdebug.org/files/php_xdebug-3.5.1-8.5-vs17-x86_64.dll"
}

$phpFolders = Get-ChildItem -Path $phpDir -Directory -Filter "php*"

foreach ($folder in $phpFolders) {
    $version = $folder.Name.Replace("php", "")
    $majorMinor = $version.Substring(0, 3)
    
    if ($xdebugMap.ContainsKey($majorMinor)) {
        $url = $xdebugMap[$majorMinor]
        $dllName = "php_xdebug.dll"
        $extDir = Join-Path $folder.FullName "ext"
        $destPath = Join-Path $extDir $dllName
        $iniPath = Join-Path $folder.FullName "php.ini"
        
        Write-Host "Configuring Xdebug for PHP $version..." -ForegroundColor Cyan
        
        # Download DLL if not exists
        if (!(Test-Path $destPath)) {
            Write-Host "Downloading Xdebug DLL for $majorMinor..."
            try {
                Invoke-WebRequest -Uri $url -OutFile $destPath -ErrorAction Stop
            } catch {
                Write-Host "Failed to download for $($majorMinor): $($_.Exception.Message)" -ForegroundColor Yellow
                continue
            }
        }
        
        # Update php.ini
        $iniContent = Get-Content $iniPath -Raw
        
        # Remove old xdebug entries if any
        $iniContent = $iniContent -replace '(?ms)^\s*;?zend_extension\s*=.*?(xdebug).*?\r?\n', ""
        $iniContent = $iniContent -replace '(?ms)^\[xdebug\].*?(\[\w+\]|$)', '$1'
        $iniContent = $iniContent -replace '(?ms)^\s*;?xdebug\..*?\r?\n', ""
        
        $xdebugConfig = @"

[xdebug]
zend_extension="$($destPath.Replace('\', '/'))"
xdebug.mode=debug,develop,coverage
xdebug.client_port=9003
xdebug.start_with_request=yes
xdebug.log="D:/wamp64/logs/xdebug_$version.log"
"@
        
        if ($iniContent -notmatch "\[xdebug\]") {
            $iniContent += $xdebugConfig
            $iniContent | Set-Content $iniPath
            Write-Host "Xdebug config added to $iniPath" -ForegroundColor Green
        }
    } else {
        Write-Host "No Xdebug mapping for version $majorMinor (skipped)" -ForegroundColor Gray
    }
}
