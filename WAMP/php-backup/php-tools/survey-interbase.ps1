$phpRootDir = "D:\wamp64\bin\php"
$results = @()

Get-ChildItem -Path $phpRootDir -Directory -Filter "php*" | ForEach-Object {
    $ver = $_.Name
    $extPath = Join-Path $_.FullName "ext\php_interbase.dll"
    $iniPath = Join-Path $_.FullName "php.ini"
    $apacheIniPath = Join-Path $_.FullName "phpForApache.ini"
    
    $dllExists = Test-Path $extPath
    $enabledCLI = $false
    $enabledApache = $false
    
    if (Test-Path $iniPath) {
        $enabledCLI = Select-String -Path $iniPath -Pattern '^\s*extension\s*=\s*(php_)?interbase(\.dll)?' -Quiet
    }
    if (Test-Path $apacheIniPath) {
        $enabledApache = Select-String -Path $apacheIniPath -Pattern '^\s*extension\s*=\s*(php_)?interbase(\.dll)?' -Quiet
    }
    
    $results += [PSCustomObject]@{
        PHPVersion = $ver
        DLL_Exists = $dllExists
        CLI_Enabled = $enabledCLI
        Apache_Enabled = $enabledApache
    }
}

$results | Format-Table -AutoSize
