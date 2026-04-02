<#
.SYNOPSIS
    Cria um backup completo das versoes PHP e php-tools do WampServer.
.DESCRIPTION
    Copia para a pasta onde este script esta localizado:
      - Todas as pastas php* de D:\wamp64\bin\php\ (ou caminho informado)
      - A pasta php-tools (browscap, ferramentas customizadas, etc.)
      - Quaisquer DLLs/OCX soltas na pasta raiz de cada PHP

    O backup pode ser restaurado com o script restore-wamp.ps1.
.NOTES
    Execute como Administrador.
    O backup pode ocupar varios GB dependendo das versoes instaladas.
.EXAMPLE
    .\backup-wamp.ps1
    Executa o script e segue o assistente interativo.
#>

# ===============================================================================
# CONFIGURAÇÕES INICIAIS
# ===============================================================================

# Define que qualquer erro deve interromper a execução do script
$ErrorActionPreference = "Stop"

# Armazena o diretório onde este script está localizado
# Usado como referência para salvar o backup na mesma pasta
$ScriptDir = $PSScriptRoot

# ===============================================================================
# ETAPA 1: EXIBIR BANNER DE BOAS-VINDAS
# ===============================================================================
# Limpa a tela do terminal para uma visualização mais limpa
Clear-Host

# Exibe um banner formatado identificando o propósito do script
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         WAMP PHP BACKUP - Criacao de Backup              ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ===============================================================================
# ETAPA 2: OBTER CAMINHO DE INSTALAÇÃO DO WAMPSERVER
# ===============================================================================
# Solicita ao usuário o caminho onde o WampServer está instalado
Write-Host "  Informe o caminho de instalacao do WampServer:" -ForegroundColor Yellow
Write-Host "  Exemplos: D:\wamp64   C:\wamp64   E:\dev\wamp64" -ForegroundColor DarkGray
Write-Host ""

# Define D:\wamp64 como caminho padrão caso o usuário pressione Enter sem digitar
$wampDefault = "D:\wamp64"
$userInput   = Read-Host "  WampServer path [$wampDefault]"

# Se o usuário não digitou nada, usa o caminho padrão
if ([string]::IsNullOrWhiteSpace($userInput)) { $userInput = $wampDefault }

# Remove barras finais do caminho para evitar problemas de concatenação
$WampRoot = $userInput.TrimEnd('\', '/')

# Monta o caminho completo para a pasta bin\php onde estão as versões PHP
$WampPhpDir = Join-Path $WampRoot "bin\php"

# Valida se o caminho informado realmente existe
# Se não existir, exibe erro e encerra o script
if (-not (Test-Path $WampPhpDir)) {
    Write-Host ""
    Write-Host "  [ERRO] Pasta nao encontrada: $WampPhpDir" -ForegroundColor Red
    Write-Host "  Verifique o caminho e tente novamente." -ForegroundColor Red
    exit 1
}

# Confirma que o caminho foi validado com sucesso
Write-Host ""
Write-Host "  [OK] WampServer encontrado em: $WampRoot" -ForegroundColor Green

# ===============================================================================
# ETAPA 3: DEFINIR DIRETÓRIO DE DESTINO DO BACKUP
# ===============================================================================
# O backup será salvo na subpasta "php-backup" dentro do diretório do script
$BackupRoot = Join-Path $ScriptDir "php-backup"
Write-Host "  [OK] Destino do backup     : $BackupRoot" -ForegroundColor Green
Write-Host ""

# ===============================================================================
# ETAPA 4: MAPEAR VERSÕES PHP E FERRAMENTAS PARA BACKUP
# ===============================================================================

# Lista todas as pastas que começam com "php" seguido de dígito
# Exemplos: php5.6.40, php7.4.33, php8.1.33, php8.2.29, etc.
$phpFolders    = Get-ChildItem $WampPhpDir -Directory | Where-Object { $_.Name -match "^php\d" }

# Define o caminho da pasta php-tools (contém ferramentas customizadas)
$toolsFolder   = Join-Path $WampPhpDir "php-tools"

# Verifica se a pasta php-tools existe para incluir no backup
$hasTools      = Test-Path $toolsFolder

# Exibe para o usuário quais itens serão copiados
Write-Host "  Itens que serao copiados:" -ForegroundColor Cyan

# Para cada versão PHP, calcula e exibe o tamanho aproximado
foreach ($f in $phpFolders) {
    # Soma o tamanho de todos os arquivos recursivamente e converte para MB
    $sizeMB = [math]::Round((Get-ChildItem $f.FullName -Recurse -File | Measure-Object Length -Sum).Sum / 1MB, 1)
    Write-Host "    • $($f.Name)  (~$sizeMB MB)" -ForegroundColor White
}

# Se php-tools existir, também exibe seu tamanho
if ($hasTools) {
    $toolsMB = [math]::Round((Get-ChildItem $toolsFolder -Recurse -File | Measure-Object Length -Sum).Sum / 1MB, 1)
    Write-Host "    • php-tools  (~$toolsMB MB)" -ForegroundColor White
}

# Calcula e exibe o tamanho total estimado de todo o backup
Write-Host ""
$totalGB = [math]::Round((Get-ChildItem $WampPhpDir -Recurse -File |
    Where-Object { $_.FullName -notmatch "\\php-tools\\" -or $hasTools } |
    Measure-Object Length -Sum).Sum / 1GB, 2)
Write-Host "  Tamanho total estimado: ~$totalGB GB" -ForegroundColor Yellow
Write-Host ""

# Solicita confirmação do usuário antes de prosseguir
$confirm = Read-Host "  Deseja continuar? (S/N)"
if ($confirm -notmatch '^[Ss]') {
    Write-Host "  Backup cancelado." -ForegroundColor DarkGray
    exit 0
}

# ===============================================================================
# ETAPA 5: CRIAR ESTRUTURA DE DIRETÓRIOS DO BACKUP
# ===============================================================================

# Cria a pasta de backup se ainda não existir
# -Force garante que não haverá erro se a pasta já existir
if (-not (Test-Path $BackupRoot)) {
    New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
}

# Salva metadados em JSON para que o script de restore saiba:
# - Quando o backup foi feito
# - De qual caminho original os arquivos vieram
# - Quais versões PHP foram incluídas
$meta = @{
    BackupDate    = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    SourceWampRoot = $WampRoot
    SourcePhpDir  = $WampPhpDir
    Versions      = @($phpFolders | ForEach-Object { $_.Name })
}
$meta | ConvertTo-Json | Set-Content (Join-Path $BackupRoot "backup-meta.json") -Encoding UTF8

Write-Host ""

# ===============================================================================
# ETAPA 6: DEFINIR FUNÇÃO DE CÓPIA COM BARRA DE PROGRESSO
# ===============================================================================
# Função auxiliar para copiar pastas inteiras exibindo progresso
# Parâmetros:
#   - Source:      Caminho de origem da pasta
#   - Destination: Caminho de destino da pasta
#   - Label:       Nome descritivo para exibição no progresso
function Copy-FolderWithProgress {
    param($Source, $Destination, $Label)

    # Lista todos os arquivos da pasta de origem (recursivo)
    $files = Get-ChildItem $Source -Recurse -File
    $total = $files.Count
    $done  = 0

    Write-Host "  Copiando $Label ($total arquivos)..." -ForegroundColor DarkCyan

    # Itera sobre cada arquivo para copiar individualmente
    foreach ($file in $files) {
        # Calcula o caminho relativo do arquivo em relação à origem
        $relative = $file.FullName.Substring($Source.Length).TrimStart('\')
        
        # Monta o caminho completo de destino mantendo a estrutura de pastas
        $dest     = Join-Path $Destination $relative
        
        # Extrai o diretório de destino para criá-lo se não existir
        $destDir  = [System.IO.Path]::GetDirectoryName($dest)
        if (-not (Test-Path $destDir)) { 
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null 
        }
        
        # Copia o arquivo forçando sobrescrita se já existir
        Copy-Item $file.FullName -Destination $dest -Force
        
        # Incrementa contador de arquivos processados
        $done++
        
        # A cada 50 arquivos ou no último, atualiza a barra de progresso
        if ($done % 50 -eq 0 -or $done -eq $total) {
            $pct = [math]::Round($done / $total * 100)
            Write-Progress -Activity "Copiando $Label" -Status "$done/$total arquivos" -PercentComplete $pct
        }
    }
    
    # Finaliza a barra de progresso
    Write-Progress -Activity "Copiando $Label" -Completed
    
    # Exibe confirmação de conclusão desta pasta
    Write-Host "  [OK]   $Label" -ForegroundColor Green
}

# ===============================================================================
# ETAPA 7: COPIAR VERSÕES PHP PARA O BACKUP
# ===============================================================================
Write-Host "  ─── Copiando versoes PHP ─────────────────────────" -ForegroundColor Cyan

# Para cada versão PHP encontrada, copia para a pasta de backup
foreach ($phpDir in $phpFolders) {
    # Monta o caminho de destino mantendo o nome da versão
    $dest = Join-Path $BackupRoot $phpDir.Name
    
    # Chama a função de cópia com progresso
    Copy-FolderWithProgress -Source $phpDir.FullName -Destination $dest -Label $phpDir.Name
}

# ===============================================================================
# ETAPA 8: COPIAR PHP-TOOLS (SE EXISTIR)
# ===============================================================================
# Só copia php-tools se a pasta existir no WampServer de origem
if ($hasTools) {
    Write-Host ""
    Write-Host "  ─── Copiando php-tools ───────────────────────────" -ForegroundColor Cyan
    
    # Define o destino dentro da pasta de backup
    $dest = Join-Path $BackupRoot "php-tools"
    
    # Copia todo o conteúdo de php-tools
    Copy-FolderWithProgress -Source $toolsFolder -Destination $dest -Label "php-tools"
}

# ===============================================================================
# ETAPA 9: EXIBIR RESUMO FINAL DO BACKUP
# ===============================================================================

# Calcula o tamanho real ocupado pelo backup após a cópia
$backupSizeMB = [math]::Round((Get-ChildItem $BackupRoot -Recurse -File | Measure-Object Length -Sum).Sum / 1MB, 1)

# Prepara label indicando se php-tools foi incluído ou não
$toolsLabel   = if ($hasTools) { 'php-tools' } else { '(sem php-tools)' }

# Exibe mensagem de conclusão formatada
Write-Host ''
Write-Host 'Backup concluido!' -ForegroundColor Green
Write-Host '  ─────────────────────────────────────────────────────────' -ForegroundColor Green
Write-Host "  Local   : $BackupRoot" -ForegroundColor White
Write-Host "  Versoes : $($phpFolders.Count) versoes PHP + $toolsLabel" -ForegroundColor White
Write-Host "  Tamanho : $backupSizeMB MB no total" -ForegroundColor White
Write-Host ''
Write-Host '  Para restaurar em outro WampServer, execute:' -ForegroundColor Yellow
Write-Host '  .\restore-wamp.ps1' -ForegroundColor DarkCyan
Write-Host ''
