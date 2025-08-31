Param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Args
)

$Blue = "[INFO]"; $Green = "[SUCCESS]"; $Yellow = "[WARNING]"; $Red = "[ERROR]"; $NC = ""

function Write-Info { param([string]$Message) Write-Host "$Blue $Message" }
function Write-Success { param([string]$Message) Write-Host "$Green $Message" }
function Write-Warn { param([string]$Message) Write-Host "$Yellow $Message" }
function Write-Err { param([string]$Message) Write-Host "$Red $Message" }

function Test-DockerCompose {
    try { $null = docker --version; $null = docker compose version; return $true }
    catch { Write-Err "Docker or Docker Compose is not installed or not in PATH"; return $false }
}

function Get-ComposeCommand {
    if ((Test-Path "docker-compose.cpu.yml") -and $env:FORCE_CPU_MODE -eq "true") { return "docker compose -f docker-compose.cpu.yml" }
    elseif ((Test-Path ".env") -and (Get-Content ".env" | Select-String "FORCE_CPU_MODE=true")) {
        if (Test-Path "docker-compose.cpu.yml") { return "docker compose -f docker-compose.cpu.yml" }
    }
    return "docker compose"
}

function Start-BackendIfNeeded {
    Write-Info "Checking if backend is running..."
    $composeCmd = Get-ComposeCommand
    $backendStatus = Invoke-Expression "$composeCmd ps backend 2>`$null" | Select-String "Up"
    if (-not $backendStatus) { Write-Info "Starting backend service..."; Invoke-Expression "$composeCmd up -d backend"; Start-Sleep -Seconds 5 }
}

function Invoke-DirectCLI { param([string[]]$Arguments)
    if (-not (Test-DockerCompose)) { exit 1 }
    Start-BackendIfNeeded
    $composeCmd = Get-ComposeCommand
    $cmd = "$composeCmd --profile cli run --rm cli python cli_ingest.py"
    Invoke-Expression "$cmd $($Arguments -join ' ')"
}

function Show-Help {
@"
PROMTOK Direct CLI Helper Script for Windows PowerShell

This tool provides DIRECT document processing with live feedback, bypassing the background queue.

Usage: .\promtok-cli.ps1 <command> [options]

Commands:
  create-user <username> <password> [-FullName "Name"] [-Admin]
  create-group <username> <group_name> [-Description "Description"]
  list-groups [-Username <username>]
  ingest <username> <document_directory> [-Group <group_id>] [-ForceReembed] [-Device <device>] [-DeleteAfterSuccess] [-BatchSize <num>]
  status [-Username <username>] [-Group <group_id>]
  cleanup [-Username <username>] [-Status <status>] [-Group <group_id>] [-Confirm]
  search <username> <query> [-Limit <num>]
  reset-db [-Backup] [-Force] [-Stats] [-Check]

Examples:
  .\promtok-cli.ps1 create-user researcher mypass123 -FullName "Research User"
  .\promtok-cli.ps1 create-group researcher "AI Papers" -Description "Machine Learning Research"
  .\promtok-cli.ps1 ingest researcher .\documents
"@
}

if ($Args.Count -eq 0 -or $Args[0] -in @('help','--help','-h')) { Show-Help; exit 0 }

$Command = $Args[0]
$Remaining = $Args[1..($Args.Count-1)]

switch ($Command) {
  'create-user' { Invoke-DirectCLI $Args }
  'create-group' { Invoke-DirectCLI $Args }
  'list-groups' { Invoke-DirectCLI $Args }
  'ingest' { Invoke-DirectCLI $Args }
  'status' { Invoke-DirectCLI $Args }
  'cleanup' { Invoke-DirectCLI $Args }
  'cleanup-cli' { Invoke-DirectCLI $Args }
  'search' { Invoke-DirectCLI $Args }
  'reset-db' { Invoke-DirectCLI $Args }
  default { Write-Err "Unknown command: $Command"; Show-Help; exit 1 }
}

