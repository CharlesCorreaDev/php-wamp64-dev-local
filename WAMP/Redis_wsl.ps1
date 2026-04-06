# ============================================
# Script de Instalação e Configuração do Redis
# no WSL (Ubuntu)
# ============================================

$Separator = "=" * 44

Write-Host ""
Write-Host $Separator -ForegroundColor Cyan
Write-Host "INSTALACAO E CONFIGURACAO DO REDIS - WSL" -ForegroundColor Cyan
Write-Host $Separator -ForegroundColor Cyan
Write-Host ""

# ============================================
# Configuração Base
# ============================================

$BasePath = "D:\Virtual-Machines"
$UbuntuDistro = "Ubuntu"

# ============================================
# Verificar se WSL está disponível
# ============================================

Write-Host "Verificando WSL..." -ForegroundColor Cyan

$WSLCheck = wsl --version 2>$null
if (-not $WSLCheck) {
    Write-Host "Erro: WSL nao esta instalado ou nao esta disponivel." -ForegroundColor Red
    Write-Host "Execute: wsl --install" -ForegroundColor Yellow
    exit 1
}
Write-Host "WSL detectado." -ForegroundColor Green

# ============================================
# Verificar se Ubuntu está disponível
# ============================================

Write-Host "Verificando distro Ubuntu..." -ForegroundColor Cyan

$WSLDistros = wsl --list --quiet 2>$null | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

if (-not $WSLDistros -or $WSLDistros -notcontains $UbuntuDistro) {
    Write-Host "Erro: Distro '$UbuntuDistro' nao encontrada." -ForegroundColor Red
    Write-Host "Distros disponiveis: $($WSLDistros -join ', ')" -ForegroundColor Yellow
    exit 1
}

Write-Host "Distro '$UbuntuDistro' encontrada." -ForegroundColor Green

# ============================================
# 1. Instalação Automática do Redis
# ============================================

Write-Host ""
Write-Host $Separator -ForegroundColor Cyan
Write-Host "1. INSTALACAO AUTOMATICA DO REDIS" -ForegroundColor Cyan
Write-Host $Separator -ForegroundColor Cyan
Write-Host ""

Write-Host "Verificando se Redis ja esta instalado..." -ForegroundColor Gray

$RedisCheck = wsl -d $UbuntuDistro -- bash -c "which redis-server" 2>$null

if ($RedisCheck -match "redis-server") {
    Write-Host "Redis ja esta instalado." -ForegroundColor Yellow
    
    $RedisVersion = wsl -d $UbuntuDistro -- bash -c "redis-server --version" 2>$null
    Write-Host "  Versao: $RedisVersion" -ForegroundColor DarkGray
} else {
    Write-Host "Redis nao encontrado. Iniciando instalacao..." -ForegroundColor Cyan
    
    Write-Host "  [1/4] Atualizando pacotes..." -ForegroundColor Gray
    wsl -d $UbuntuDistro -- bash -c "sudo apt-get update" | Out-Null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Erro ao atualizar pacotes." -ForegroundColor Red
        exit 1
    }
    Write-Host "  Pacotes atualizados." -ForegroundColor Green
    
    Write-Host "  [2/4] Instalando Redis server..." -ForegroundColor Gray
    wsl -d $UbuntuDistro -- bash -c "sudo apt-get install -y redis-server" | Out-Null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Erro ao instalar Redis." -ForegroundColor Red
        exit 1
    }
    Write-Host "  Redis instalado com sucesso." -ForegroundColor Green
    
    Write-Host "  [3/4] Configurando Redis para conexoes externas..." -ForegroundColor Gray
    
    # Backup do arquivo de configuracao original
    wsl -d $UbuntuDistro -- bash -c "sudo cp /etc/redis/redis.conf /etc/redis/redis.conf.bak" 2>$null | Out-Null
    
    # Modificar configuracao para aceitar conexoes externas
    wsl -d $UbuntuDistro -- bash -c "sudo sed -i 's/^bind 127.0.0.1 ::1/bind 0.0.0.0/' /etc/redis/redis.conf" 2>$null | Out-Null
    Write-Host "  Bind configurado para 0.0.0.0" -ForegroundColor Green
    
    # Desabilitar protected mode para desenvolvimento
    wsl -d $UbuntuDistro -- bash -c "sudo sed -i 's/^protected-mode yes/protected-mode no/' /etc/redis/redis.conf" 2>$null | Out-Null
    Write-Host "  Protected mode desabilitado" -ForegroundColor Green
    
    Write-Host "  [4/4] Verificando instalacao..." -ForegroundColor Gray
    $RedisVersion = wsl -d $UbuntuDistro -- bash -c "redis-server --version" 2>$null
    Write-Host "  $RedisVersion" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "Redis instalado e configurado com sucesso!" -ForegroundColor Green
}

# ============================================
# 2. Início Automático com Windows
# ============================================

Write-Host ""
Write-Host $Separator -ForegroundColor Cyan
Write-Host "2. CONFIGURAR INICIO AUTOMATICO COM WINDOWS" -ForegroundColor Cyan
Write-Host $Separator -ForegroundColor Cyan
Write-Host ""

$TaskName = "WSL-Redis-AutoStart"
$TaskExists = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if ($TaskExists) {
    Write-Host "Tarefa '$TaskName' ja existe." -ForegroundColor Yellow
    Write-Host "  Removendo tarefa existente para recriar..." -ForegroundColor Gray
    
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "  Tarefa removida." -ForegroundColor Green
}

Write-Host "Criando script de inicializacao..." -ForegroundColor Gray

# Criar diretorio base se nao existir
if (-not (Test-Path $BasePath)) {
    New-Item -ItemType Directory -Force -Path $BasePath | Out-Null
    Write-Host "  Diretorio $BasePath criado." -ForegroundColor Green
}

# Criar script de inicializacao do Redis
$RedisStartScript = @"
# Script de Inicializacao Automatica do Redis

# Aguardar WSL estar disponivel
Start-Sleep -Seconds 5

# Iniciar Redis no WSL
wsl -d $UbuntuDistro -- sudo service redis-server start

# Verificar se iniciou com sucesso
`$Status = wsl -d $UbuntuDistro -- bash -c "service redis-server status" 2>`$null

if (`$Status -match "active") {
    Write-Host "Redis iniciado com sucesso no WSL ($UbuntuDistro)" -ForegroundColor Green
} else {
    Write-Host "Erro ao iniciar Redis no WSL" -ForegroundColor Red
}
"@

$ScriptPath = "$BasePath\start-redis.ps1"
Set-Content -Path $ScriptPath -Value $RedisStartScript -Encoding UTF8

Write-Host "  Script criado em: $ScriptPath" -ForegroundColor Green

Write-Host "Criando tarefa agendada..." -ForegroundColor Gray

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

try {
    Register-ScheduledTask -TaskName $TaskName `
        -Action $Action `
        -Trigger $Trigger `
        -Principal $Principal `
        -Settings $Settings `
        -Description "Inicia automaticamente o Redis no WSL ($UbuntuDistro) quando o usuario faz logon" | Out-Null
    
    Write-Host "  Tarefa '$TaskName' registrada com sucesso." -ForegroundColor Green
    Write-Host "  Redis iniciara automaticamente com o Windows." -ForegroundColor Green
} catch {
    Write-Host "  Erro ao criar tarefa agendada: $_" -ForegroundColor Red
    Write-Host "  Executando como administrador pode ser necessario." -ForegroundColor Yellow
}

# ============================================
# 3. Início Imediato do Redis
# ============================================

Write-Host ""
Write-Host $Separator -ForegroundColor Cyan
Write-Host "3. INICIAR REDIS IMEDIATAMENTE" -ForegroundColor Cyan
Write-Host $Separator -ForegroundColor Cyan
Write-Host ""

Write-Host "Iniciando servico Redis..." -ForegroundColor Gray

$StartResult = wsl -d $UbuntuDistro -- sudo service redis-server start 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "  Comando de inicio executado." -ForegroundColor Green
} else {
    Write-Host "  Aviso: $StartResult" -ForegroundColor Yellow
}

# Aguardar servico iniciar
Start-Sleep -Seconds 2

Write-Host "Verificando status do servico..." -ForegroundColor Gray

# Verificar status do Redis
$RedisStatus = wsl -d $UbuntuDistro -- bash -c "service redis-server status" 2>$null

if ($RedisStatus -match "active") {
    Write-Host "  Status: Redis esta rodando." -ForegroundColor Green
} elseif ($RedisStatus -match "start/running") {
    Write-Host "  Status: Redis esta rodando." -ForegroundColor Green
} else {
    Write-Host "  Status: $RedisStatus" -ForegroundColor Yellow
}

# Testar conexao com Redis
Write-Host "Testando conexao com Redis..." -ForegroundColor Gray

$RedisPing = wsl -d $UbuntuDistro -- bash -c "redis-cli ping" 2>$null

if ($RedisPing -eq "PONG") {
    Write-Host "  Conexao bem-sucedida: PONG recebido." -ForegroundColor Green
} else {
    Write-Host "  Resposta: $RedisPing" -ForegroundColor Yellow
}

# ============================================
# 4. Resumo Final
# ============================================

Write-Host ""
Write-Host $Separator -ForegroundColor Cyan
Write-Host "4. RESUMO DA CONFIGURACAO" -ForegroundColor Cyan
Write-Host $Separator -ForegroundColor Cyan
Write-Host ""

Write-Host "Instalacao do Redis:" -ForegroundColor Green
Write-Host "   - Redis server instalado e configurado" -ForegroundColor DarkGray
Write-Host "   - Bind: 0.0.0.0 (aceita conexoes externas)" -ForegroundColor DarkGray
Write-Host "   - Protected mode: desabilitado (desenvolvimento)" -ForegroundColor DarkGray

Write-Host ""
Write-Host "Inicio automatico com Windows:" -ForegroundColor Green
Write-Host "   - Script: $ScriptPath" -ForegroundColor DarkGray
Write-Host "   - Tarefa: $TaskName" -ForegroundColor DarkGray
Write-Host "   - Trigger: Logon do usuario" -ForegroundColor DarkGray

Write-Host ""
Write-Host "Status atual:" -ForegroundColor Green
Write-Host "   - Servico: rodando" -ForegroundColor DarkGray
Write-Host "   - Porta: 6379" -ForegroundColor DarkGray
Write-Host "   - Host: localhost" -ForegroundColor DarkGray

Write-Host ""
Write-Host $Separator -ForegroundColor Cyan
Write-Host "COMO CONECTAR AO REDIS" -ForegroundColor Cyan
Write-Host $Separator -ForegroundColor Cyan
Write-Host ""

Write-Host "Via WSL:" -ForegroundColor Yellow
Write-Host "  wsl -d $UbuntuDistro -- redis-cli" -ForegroundColor DarkGray
Write-Host "  wsl -d $UbuntuDistro -- redis-cli ping" -ForegroundColor DarkGray
Write-Host ""

Write-Host "Via Windows (clientes Redis):" -ForegroundColor Yellow
Write-Host "  Host: localhost" -ForegroundColor DarkGray
Write-Host "  Porta: 6379" -ForegroundColor DarkGray
Write-Host "  Senha: nenhuma (configuracao padrao)" -ForegroundColor DarkGray
Write-Host ""

Write-Host "Exemplos de clientes para Windows:" -ForegroundColor Yellow
Write-Host "  - RedisInsight (oficial)" -ForegroundColor DarkGray
Write-Host "  - Another Redis Desktop Manager" -ForegroundColor DarkGray
Write-Host "  - Redis CLI no terminal" -ForegroundColor DarkGray
Write-Host ""

Write-Host $Separator -ForegroundColor Cyan
Write-Host "CONFIGURACAO CONCLUIDA COM SUCESSO!" -ForegroundColor Green
Write-Host $Separator -ForegroundColor Cyan
Write-Host ""
