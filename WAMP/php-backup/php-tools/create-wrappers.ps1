$toolsDir = "D:\wamp64\bin\php\php-tools"
$tools = @("phpstan", "psalm", "phpcs", "phpcbf", "phpmd", "rector", "php-cs-fixer")

foreach ($toolName in $tools) {
    $batPath = Join-Path $toolsDir "$toolName.bat"
    $pharName = "$toolName.phar"
    
    $content = "@echo off`r`nphp `"%~dp0$pharName`" %*"
    $content | Set-Content $batPath
}

# Create snyk.bat separately as it's an exe
$snykBat = Join-Path $toolsDir "snyk.bat"
$snykContent = "@echo off`r`n`"%~dp0snyk.exe`" %*"
$snykContent | Set-Content $snykBat

