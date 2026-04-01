$toolsDir = "D:\wamp64\bin\php\php-tools"
if (!(Test-Path $toolsDir)) { New-Item -ItemType Directory -Path $toolsDir }

$tools = @{
    "phpunit-5.7.phar" = "https://phar.phpunit.de/phpunit-5.7.phar"
    "phpunit-9.6.phar" = "https://phar.phpunit.de/phpunit-9.6.phar"
    "phpunit-11.phar"  = "https://phar.phpunit.de/phpunit-11.phar"
    "phpstan.phar"     = "https://github.com/phpstan/phpstan/releases/latest/download/phpstan.phar"
    "psalm.phar"       = "https://github.com/vimeo/psalm/releases/latest/download/psalm.phar"
    "phpcs.phar"       = "https://github.com/squizlabs/PHP_CodeSniffer/releases/latest/download/phpcs.phar"
    "phpcbf.phar"      = "https://github.com/squizlabs/PHP_CodeSniffer/releases/latest/download/phpcbf.phar"
    "rector.phar"      = "https://github.com/rectorphp/rector/releases/latest/download/rector.phar"
    "phpmd.phar"       = "https://phpmd.org/static/latest/phpmd.phar"
    "snyk.exe"         = "https://static.snyk.io/cli/latest/snyk-win.exe"
    "phpcompatibility.zip" = "https://github.com/PHPCompatibility/PHPCompatibility/archive/master.zip"
}

foreach ($tool in $tools.GetEnumerator()) {
    $dest = Join-Path $toolsDir $tool.Key
    Write-Host "Downloading $($tool.Key)..."
    try {
        Invoke-WebRequest -Uri $tool.Value -OutFile $dest -ErrorAction Stop
        Write-Host "Success: $($tool.Key)" -ForegroundColor Green
    } catch {
        Write-Host "Error downloading $($tool.Key): $_" -ForegroundColor Red
    }
}
