@echo off
setlocal

:: Get PHP Version
for /f "tokens=2 delims= " %%v in ('php -v ^| findstr /i "PHP [0-9]"') do (
    set "PHP_VER=%%v"
    goto :found_ver
)

:found_ver
:: Extract major.minor (e.g., 8.2)
set "MAJ_MIN=%PHP_VER:~0,3%"

set "TOOLS_DIR=D:\wamp64\bin\php\php-tools"

if "%MAJ_MIN%"=="5.6" (
    php "%TOOLS_DIR%\phpunit-5.7.phar" %*
) else if "%MAJ_MIN%"=="7.0" (
    php "%TOOLS_DIR%\phpunit-9.6.phar" %*
) else if "%MAJ_MIN%"=="7.1" (
    php "%TOOLS_DIR%\phpunit-9.6.phar" %*
) else if "%MAJ_MIN%"=="7.2" (
    php "%TOOLS_DIR%\phpunit-9.6.phar" %*
) else if "%MAJ_MIN%"=="7.3" (
    php "%TOOLS_DIR%\phpunit-9.6.phar" %*
) else if "%MAJ_MIN%"=="7.4" (
    php "%TOOLS_DIR%\phpunit-9.6.phar" %*
) else if "%MAJ_MIN%"=="8.0" (
    php "%TOOLS_DIR%\phpunit-9.6.phar" %*
) else if "%MAJ_MIN%"=="8.1" (
    php "%TOOLS_DIR%\phpunit-9.6.phar" %*
) else if "%MAJ_MIN%"=="8.2" (
    php "%TOOLS_DIR%\phpunit-11.phar" %*
) else if "%MAJ_MIN%"=="8.3" (
    php "%TOOLS_DIR%\phpunit-11.phar" %*
) else if "%MAJ_MIN%"=="8.4" (
    php "%TOOLS_DIR%\phpunit-11.phar" %*
) else if "%MAJ_MIN%"=="8.5" (
    php "%TOOLS_DIR%\phpunit-11.phar" %*
) else (
    :: Default to latest
    php "%TOOLS_DIR%\phpunit-11.phar" %*
)

endlocal
