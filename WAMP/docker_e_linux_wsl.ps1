# ============================================
# Configuração Base
# ============================================

$BasePath = "D:\Virtual-Machines"
$TempPath = "$BasePath\Temp"

# ============================================
# Preparação
# ============================================

Write-Host "Criando diretórios..." -ForegroundColor Cyan

New-Item -ItemType Directory -Force -Path $BasePath | Out-Null
New-Item -ItemType Directory -Force -Path $TempPath | Out-Null

# ============================================
# Detectar Ubuntu
# ============================================

Write-Host "Detectando distro Ubuntu..." -ForegroundColor Cyan

$UbuntuDistro = $null

try {
    $DistroList = wsl --list --quiet | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

    $UbuntuCandidates = $DistroList | Where-Object { $_ -match "Ubuntu" }

    if ($UbuntuCandidates.Count -eq 1) {
        $UbuntuDistro = $UbuntuCandidates[0]
    }
    elseif ($UbuntuCandidates.Count -gt 1) {
        Write-Host ""
        Write-Host "Foram encontradas múltiplas distros Ubuntu:" -ForegroundColor Yellow

        for ($i = 0; $i -lt $UbuntuCandidates.Count; $i++) {
            Write-Host "[$($i + 1)] $($UbuntuCandidates[$i])"
        }

        $Choice = Read-Host "Digite o número da distro que deseja migrar"

        if ($Choice -match '^\d+$' -and [int]$Choice -ge 1 -and [int]$Choice -le $UbuntuCandidates.Count) {
            $UbuntuDistro = $UbuntuCandidates[[int]$Choice - 1]
        }
    }
}
catch {
    Write-Host "Erro ao listar distros WSL." -ForegroundColor Red
}

# Caso não encontre automaticamente
if (-not $UbuntuDistro) {
    Write-Host ""
    Write-Host "Nenhuma distro Ubuntu foi detectada automaticamente." -ForegroundColor Yellow
    Write-Host "Exemplos válidos:" -ForegroundColor DarkGray
    Write-Host "Ubuntu"
    Write-Host "Ubuntu-22.04"
    Write-Host "Ubuntu-24.04"
    Write-Host "Ubuntu-Dev"
    Write-Host ""

    $UbuntuDistro = Read-Host "Digite manualmente o nome exato da distro Ubuntu"
}

Write-Host "Ubuntu selecionado: $UbuntuDistro" -ForegroundColor Green

# ============================================
# Detectar Docker Desktop
# ============================================

Write-Host "Localizando Docker Desktop..." -ForegroundColor Cyan

$DockerExe = $null

$RegistryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Docker Desktop.exe",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\Docker Desktop.exe"
)

foreach ($RegPath in $RegistryPaths) {
    if (Test-Path $RegPath) {
        $DockerExe = (Get-ItemProperty $RegPath).'(Default)'
        break
    }
}

if (-not $DockerExe) {
    $PossiblePaths = @(
        "$Env:ProgramFiles\Docker\Docker\Docker Desktop.exe",
        "$Env:ProgramFiles(x86)\Docker\Docker\Docker Desktop.exe",
        "$Env:LocalAppData\Programs\Docker\Docker\Docker Desktop.exe"
    )

    foreach ($Path in $PossiblePaths) {
        if (Test-Path $Path) {
            $DockerExe = $Path
            break
        }
    }
}

# Caso não encontre automaticamente
if (-not $DockerExe) {
    Write-Host ""
    Write-Host "Docker Desktop não foi encontrado automaticamente." -ForegroundColor Yellow
    Write-Host "Exemplos válidos:" -ForegroundColor DarkGray
    Write-Host "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    Write-Host "C:\Users\$Env:USERNAME\AppData\Local\Programs\Docker\Docker\Docker Desktop.exe"
    Write-Host ""

    $DockerExe = Read-Host "Digite manualmente o caminho completo do Docker Desktop.exe"
}

Write-Host "Docker encontrado em: $DockerExe" -ForegroundColor Green

# ============================================
# Distros Docker
# ============================================

$DockerDistros = @()

$WSLDistros = wsl --list --quiet | ForEach-Object { $_.Trim() }

if ($WSLDistros -contains "docker-desktop") {
    $DockerDistros += "docker-desktop"
}

if ($WSLDistros -contains "docker-desktop-data") {
    $DockerDistros += "docker-desktop-data"
}

# ============================================
# Encerrar Docker e WSL
# ============================================

Write-Host "Encerrando Docker Desktop..." -ForegroundColor Yellow

Get-Process | Where-Object {
    $_.ProcessName -like "*docker*"
} | Stop-Process -Force -ErrorAction SilentlyContinue

Write-Host "Encerrando WSL..." -ForegroundColor Yellow
wsl --shutdown

Start-Sleep -Seconds 5

# ============================================
# Migrar Ubuntu
# ============================================

Write-Host "Exportando distro $UbuntuDistro..." -ForegroundColor Green

$UbuntuTar = "$TempPath\$UbuntuDistro.tar"
$UbuntuTarget = "$BasePath\$UbuntuDistro"

wsl --export $UbuntuDistro $UbuntuTar

Write-Host "Removendo distro original..." -ForegroundColor Yellow
wsl --unregister $UbuntuDistro

Write-Host "Importando distro para novo local..." -ForegroundColor Green
New-Item -ItemType Directory -Force -Path $UbuntuTarget | Out-Null
wsl --import $UbuntuDistro $UbuntuTarget $UbuntuTar --version 2

# ============================================
# Migrar distros Docker
# ============================================

foreach ($Distro in $DockerDistros) {

    Write-Host "Exportando $Distro..." -ForegroundColor Green

    $TarPath = "$TempPath\$Distro.tar"
    $TargetPath = "$BasePath\$Distro"

    wsl --export $Distro $TarPath

    Write-Host "Removendo distro original $Distro..." -ForegroundColor Yellow
    wsl --unregister $Distro

    Write-Host "Importando $Distro para novo local..." -ForegroundColor Green
    New-Item -ItemType Directory -Force -Path $TargetPath | Out-Null
    wsl --import $Distro $TargetPath $TarPath --version 2
}

# ============================================
# Limpeza
# ============================================

Write-Host "Removendo arquivos TAR temporários..." -ForegroundColor Cyan
Remove-Item "$TempPath\*.tar" -Force -ErrorAction SilentlyContinue

# ============================================
# Reiniciar Docker
# ============================================

if ($DockerExe -and (Test-Path $DockerExe)) {
    Write-Host "Iniciando Docker Desktop..." -ForegroundColor Green
    Start-Process $DockerExe
} else {
    Write-Host "Docker Desktop não pôde ser iniciado automaticamente." -ForegroundColor Red
}

# ============================================
# Finalização
# ============================================

Write-Host ""
Write-Host "Migração concluída com sucesso." -ForegroundColor Green
Write-Host "Base utilizada: $BasePath" -ForegroundColor Cyan
Write-Host "Ubuntu migrado: $UbuntuDistro" -ForegroundColor Cyan

if ($DockerDistros.Count -gt 0) {
    Write-Host "Distros Docker migradas: $($DockerDistros -join ', ')" -ForegroundColor Cyan
}

# ============================================
# Instalar Redis no Ubuntu
# ============================================

Write-Host ""
Write-Host "Instalando Redis no Ubuntu..." -ForegroundColor Cyan

# Verificar se Redis já está instalado
$RedisCheck = wsl -d $UbuntuDistro -- bash -c "which redis-server" 2>$null

if ($RedisCheck -match "redis-server") {
    Write-Host "Redis já está instalado." -ForegroundColor Yellow
} else {
    Write-Host "Atualizando pacotes..." -ForegroundColor Gray
    wsl -d $UbuntuDistro -- bash -c "sudo apt-get update"
    
    Write-Host "Instalando Redis..." -ForegroundColor Gray
    wsl -d $UbuntuDistro -- bash -c "sudo apt-get install -y redis-server"
    
    Write-Host "Configurando Redis para aceitar conexões externas..." -ForegroundColor Gray
    # Backup do arquivo de configuração original
    wsl -d $UbuntuDistro -- bash -c "sudo cp /etc/redis/redis.conf /etc/redis/redis.conf.bak"
    
    # Modificar configuração para aceitar conexões externas e desabilitar protected mode
    wsl -d $UbuntuDistro -- bash -c "sudo sed -i 's/^bind 127.0.0.1 ::1/bind 0.0.0.0/' /etc/redis/redis.conf"
    wsl -d $UbuntuDistro -- bash -c "sudo sed -i 's/^protected-mode yes/protected-mode no/' /etc/redis/redis.conf"
    
    Write-Host "Redis instalado com sucesso!" -ForegroundColor Green
}

# ============================================
# Configurar Redis para iniciar com Windows
# ============================================

Write-Host ""
Write-Host "Configurando Redis para iniciar com o Windows..." -ForegroundColor Cyan

$TaskName = "WSL-Redis-AutoStart"
$TaskExists = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if ($TaskExists) {
    Write-Host "Tarefa '$TaskName' já existe. Atualizando..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# Criar script de inicialização do Redis
$RedisStartScript = @"
# Iniciar Redis
wsl -d $UbuntuDistro -- sudo service redis-server start
"@

$ScriptPath = "$BasePath\start-redis.ps1"
Set-Content -Path $ScriptPath -Value $RedisStartScript -Encoding UTF8

# Criar tarefa agendada para iniciar com o Windows
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-ExecutionPolicy Bypass -File `"$ScriptPath`"" `
    -WorkingDirectory "$BasePath"

$Trigger = New-ScheduledTaskTrigger -AtLogOn

$Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME `
    -LogonType Interactive `
    -RunLevel Highest

$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Hours 0 -Minutes 5)

Register-ScheduledTask -TaskName $TaskName `
    -Action $Action `
    -Trigger $Trigger `
    -Principal $Principal `
    -Settings $Settings `
    -Description "Inicia automaticamente o Redis no WSL ($UbuntuDistro) quando o usuário faz logon" | Out-Null

Write-Host "Tarefa agendada '$TaskName' criada com sucesso!" -ForegroundColor Green
Write-Host "O Redis será iniciado automaticamente quando você fizer logon no Windows." -ForegroundColor Cyan

# ============================================
# Iniciar Redis imediatamente
# ============================================

Write-Host ""
Write-Host "Iniciando Redis agora..." -ForegroundColor Cyan

try {
    wsl -d $UbuntuDistro -- sudo service redis-server start
    Write-Host "Redis iniciado com sucesso!" -ForegroundColor Green
    
    # Verificar status do Redis
    $RedisStatus = wsl -d $UbuntuDistro -- bash -c "service redis-server status" 2>$null
    if ($RedisStatus -match "active \(running\)") {
        Write-Host "Status: Redis está rodando." -ForegroundColor Green
    }
} catch {
    Write-Host "Erro ao iniciar Redis: $_" -ForegroundColor Red
}

# ============================================
# Resumo Final
# ============================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "RESUMO DA CONFIGURAÇÃO" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "✅ Migração WSL concluída" -ForegroundColor Green
Write-Host "✅ Redis instalado e configurado" -ForegroundColor Green
Write-Host "✅ Redis configurado para iniciar com Windows" -ForegroundColor Green
Write-Host "✅ Redis iniciado agora" -ForegroundColor Green
Write-Host ""
Write-Host "Base: $BasePath" -ForegroundColor Cyan
Write-Host "Distro: $UbuntuDistro" -ForegroundColor Cyan
Write-Host "Tarefa agendada: $TaskName" -ForegroundColor Cyan
Write-Host ""
Write-Host "Para conectar ao Redis do Windows:" -ForegroundColor Yellow
Write-Host "  redis-cli -h localhost -p 6379 (via WSL)" -ForegroundColor DarkGray
Write-Host "  Ou use clients Redis no Windows apontando para localhost:6379" -ForegroundColor DarkGray
Write-Host ""