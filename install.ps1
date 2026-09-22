$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

trap {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Red
    Write-Host "De installatie is gestopt." -ForegroundColor Red
    Write-Host "==================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Je WhatsApp-data is niet verwijderd. Je kunt START-HERE.cmd gewoon opnieuw uitvoeren."
    Write-Host ""
    exit 1
}

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Join-Path $env:LOCALAPPDATA "WacliChatBridge"
$Bin = Join-Path $Root "bin"
$Store = Join-Path $Root "wacli-store"
$Secrets = Join-Path $Root "secrets"
$Logs = Join-Path $Root "logs"
$ConfigPath = Join-Path $Root "config.json"
$SecretPath = Join-Path $Secrets "runtime-key.dpapi"

$TunnelPage = "https://platform.openai.com/settings/organization/tunnels"
$RuntimeKeyPage = "https://platform.openai.com/settings/organization/api-keys"
$ChatGPTConnectorsPage = "https://chatgpt.com/#settings/Connectors"

function Write-Step {
    param([int]$Number, [string]$Text)
    Write-Host ""
    Write-Host "[$Number/6] $Text" -ForegroundColor Cyan
}

function Read-YesNo {
    param([string]$Question, [bool]$DefaultYes = $true)
    $hint = if ($DefaultYes) { "[J/n]" } else { "[j/N]" }
    $answer = Read-Host "$Question $hint"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $DefaultYes }
    return $answer.Trim().ToLowerInvariant() -in @("j","ja","y","yes")
}

function Stop-ExistingBridge {
    if (Test-Path (Join-Path $Root "stop.ps1")) {
        try {
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "stop.ps1") | Out-Null
            Start-Sleep -Milliseconds 700
        } catch {}
    }
}

function Get-LatestAsset {
    param(
        [string]$Repository,
        [string]$Pattern,
        [string]$Destination,
        [string]$ExecutableName
    )

    $headers = @{
        "User-Agent" = "WacliChatBridge"
        "Accept" = "application/vnd.github+json"
    }

    $release = Invoke-RestMethod -Headers $headers -Uri "https://api.github.com/repos/$Repository/releases/latest"
    $asset = $release.assets | Where-Object { $_.name -match $Pattern } | Select-Object -First 1
    if (-not $asset) {
        throw "Kon geen geschikte Windows-download vinden voor $Repository."
    }

    $tmp = Join-Path $env:TEMP ("wacli-chat-bridge-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null

    try {
        $download = Join-Path $tmp $asset.name
        Write-Host "  Downloaden: $($asset.name)"
        Invoke-WebRequest -Headers $headers -Uri $asset.browser_download_url -OutFile $download

        if ($asset.name -notmatch "\.zip$") {
            throw "Onverwacht downloadformaat: $($asset.name)"
        }

        $unpack = Join-Path $tmp "unpack"
        Expand-Archive -Path $download -DestinationPath $unpack -Force
        $exe = Get-ChildItem $unpack -Recurse -File -Filter $ExecutableName | Select-Object -First 1
        if (-not $exe) {
            throw "$ExecutableName is niet gevonden in $($asset.name)."
        }

        Copy-Item $exe.FullName $Destination -Force
    }
    finally {
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Test-WacliLinked {
    param([string]$Wacli)
    try {
        & $Wacli --store $Store doctor *> $null
        return ($LASTEXITCODE -eq 0)
    }
    catch {
        return $false
    }
}

function Read-TunnelId {
    while ($true) {
        Write-Host ""
        Write-Host "Je hebt een OpenAI Tunnel ID nodig. Die begint met tunnel_." -ForegroundColor White
        Write-Host "Heb je die nog niet? Druk dan alleen op ENTER. Ik open de juiste OpenAI-pagina." -ForegroundColor DarkGray
        $value = Read-Host "Tunnel ID"
        if ([string]::IsNullOrWhiteSpace($value)) {
            Start-Process $TunnelPage
            Write-Host "De Tunnels-pagina is geopend. Maak of selecteer daar de tunnel die je wilt gebruiken."
            Read-Host "Druk op ENTER zodra je de Tunnel ID hebt"
            continue
        }
        $value = $value.Trim()
        if ($value -match "^tunnel_[0-9a-f]{32}$") {
            return $value
        }
        Write-Host "Dit lijkt geen geldige Tunnel ID. Voorbeeld: tunnel_0123456789abcdef0123456789abcdef" -ForegroundColor Yellow
    }
}

function Read-RuntimeKey {
    while ($true) {
        Write-Host ""
        Write-Host "Nu is een OpenAI Runtime API key nodig met Tunnels Read + Use." -ForegroundColor White
        Write-Host "Heb je die nog niet? Druk alleen op ENTER. Ik open de juiste OpenAI-pagina." -ForegroundColor DarkGray
        $key = Read-Host "Runtime API key" -AsSecureString
        if ($key.Length -gt 0) {
            return $key
        }
        Start-Process $RuntimeKeyPage
        Write-Host "De Runtime API Keys-pagina is geopend."
        Write-Host "Maak een Restricted key met alleen Tunnels Read + Use."
        Read-Host "Druk op ENTER zodra je de key hebt"
    }
}

function Test-LocalPort {
    param([int]$Port)
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $async = $client.BeginConnect("127.0.0.1", $Port, $null, $null)
        if (-not $async.AsyncWaitHandle.WaitOne(1500, $false)) { return $false }
        $client.EndConnect($async)
        return $true
    }
    catch {
        return $false
    }
    finally {
        $client.Close()
    }
}

function Test-Url200 {
    param([string]$Url)
    try {
        $response = Invoke-WebRequest -UseBasicParsing $Url -TimeoutSec 4
        return ($response.StatusCode -eq 200)
    }
    catch {
        return $false
    }
}

Clear-Host
Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "            WacliChatBridge setup" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Deze setup koppelt jouw eigen WhatsApp aan ChatGPT."
Write-Host "Je WhatsApp-data blijft lokaal op deze laptop."
Write-Host ""
Write-Host "Je hoeft alleen:"
Write-Host "  1. één QR-code te scannen;"
Write-Host "  2. je OpenAI Tunnel ID in te voeren;"
Write-Host "  3. je OpenAI Runtime API key in te voeren."
Write-Host ""
Write-Host "De rest gebeurt automatisch."
Write-Host ""

if (-not $IsWindows -and $PSVersionTable.PSEdition -eq "Core") {
    throw "Deze installer is bedoeld voor Windows."
}

New-Item -ItemType Directory -Force -Path $Root,$Bin,$Store,$Secrets,$Logs | Out-Null

$ExistingConfig = $null
if (Test-Path $ConfigPath) {
    try { $ExistingConfig = Get-Content $ConfigPath -Raw | ConvertFrom-Json } catch {}
}
$ReuseTunnel = $false
if ($ExistingConfig -and (Test-Path $SecretPath)) {
    Write-Host "Er is al een bestaande WacliChatBridge-installatie gevonden." -ForegroundColor Green
    $ReuseTunnel = Read-YesNo "Bestaande WhatsApp- en tunnelinstellingen behouden?" $true
}

Stop-ExistingBridge

Write-Step 1 "Benodigde onderdelen installeren"
Write-Host "Dit kan even downloaden. Je hoeft niets te kiezen."

$Wacli = Join-Path $Bin "wacli.exe"
$Tunnel = Join-Path $Bin "tunnel-client.exe"
$Uv = Join-Path $Bin "uv.exe"

Get-LatestAsset "openclaw/wacli" "(?i)windows[_-]amd64\.zip$" $Wacli "wacli.exe"
Get-LatestAsset "openai/tunnel-client" "^tunnel-client-v.*-windows-amd64\.zip$" $Tunnel "tunnel-client.exe"
Get-LatestAsset "astral-sh/uv" "^uv-x86_64-pc-windows-msvc\.zip$" $Uv "uv.exe"

Write-Host "  WACLI:         OK" -ForegroundColor Green
Write-Host "  OpenAI tunnel: OK" -ForegroundColor Green
Write-Host "  Python helper: OK" -ForegroundColor Green

Write-Step 2 "Lokale ChatGPT-bridge klaarmaken"
& $Uv python install 3.13 | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Python kon niet automatisch worden geïnstalleerd." }

Copy-Item (Join-Path $RepoRoot "bridge") $Root -Recurse -Force
Copy-Item (Join-Path $RepoRoot "pyproject.toml") $Root -Force
& $Uv sync --project $Root | Out-Null
if ($LASTEXITCODE -ne 0) { throw "De lokale MCP-omgeving kon niet worden klaargemaakt." }

Write-Host "  Lokale bridge: OK" -ForegroundColor Green

Write-Step 3 "WhatsApp koppelen"
if (Test-WacliLinked $Wacli) {
    Write-Host "WhatsApp is al gekoppeld. QR-code overslaan." -ForegroundColor Green
}
else {
    Write-Host "Pak je telefoon en ga naar:"
    Write-Host "WhatsApp > Instellingen > Gekoppelde apparaten > Apparaat koppelen" -ForegroundColor White
    Write-Host ""
    Write-Host "Er verschijnt zo een QR-code in dit venster."
    Write-Host ""
    & $Wacli --store $Store auth
    if ($LASTEXITCODE -ne 0) { throw "De WhatsApp-koppeling is niet afgerond." }

    if (-not (Test-WacliLinked $Wacli)) {
        throw "WhatsApp is gekoppeld, maar WACLI rapporteert nog geen gezonde verbinding."
    }
    Write-Host ""
    Write-Host "  WhatsApp: gekoppeld" -ForegroundColor Green
}

Write-Step 4 "OpenAI-tunnel koppelen"
if ($ReuseTunnel) {
    $TunnelId = [string]$ExistingConfig.tunnel_id
    Write-Host "Bestaande tunnel wordt opnieuw gebruikt: $TunnelId" -ForegroundColor Green
}
else {
    $TunnelId = Read-TunnelId
    $RuntimeKey = Read-RuntimeKey
    $RuntimeKey | ConvertFrom-SecureString | Set-Content $SecretPath
}

if (-not (Test-Path $SecretPath)) {
    $RuntimeKey = Read-RuntimeKey
    $RuntimeKey | ConvertFrom-SecureString | Set-Content $SecretPath
}

@{
    tunnel_id = $TunnelId
    mcp_port = 8787
    health_port = 8788
} | ConvertTo-Json | Set-Content $ConfigPath -Encoding UTF8

Write-Host "  Tunnelinstellingen: opgeslagen" -ForegroundColor Green
Write-Host "  De API key is lokaal versleuteld voor jouw Windows-account." -ForegroundColor DarkGray

Write-Step 5 "Automatisch starten met Windows"

$Supervisor = @'
$ErrorActionPreference = "Continue"
$Root = Join-Path $env:LOCALAPPDATA "WacliChatBridge"
$Config = Get-Content (Join-Path $Root "config.json") -Raw | ConvertFrom-Json
$Bin = Join-Path $Root "bin"
$Logs = Join-Path $Root "logs"
$Wacli = Join-Path $Bin "wacli.exe"
$Tunnel = Join-Path $Bin "tunnel-client.exe"
$Uv = Join-Path $Bin "uv.exe"
$Store = Join-Path $Root "wacli-store"

$secure = Get-Content (Join-Path $Root "secrets\runtime-key.dpapi") -Raw | ConvertTo-SecureString
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try { $RuntimeKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }

function Start-Child {
    param([string]$Name)

    if ($Name -eq "sync") {
        return Start-Process $Wacli -WindowStyle Hidden -PassThru -ArgumentList @(
            "--store", $Store,
            "sync", "--follow",
            "--presence-mode", "quiet",
            "--max-reconnect", "0"
        ) -RedirectStandardOutput (Join-Path $Logs "sync.out.log") -RedirectStandardError (Join-Path $Logs "sync.err.log")
    }

    if ($Name -eq "mcp") {
        $env:WACLI_BIN = $Wacli
        $env:WACLI_STORE_DIR = $Store
        $env:WACLI_MCP_PORT = [string]$Config.mcp_port

        return Start-Process $Uv -WindowStyle Hidden -PassThru -ArgumentList @(
            "run", "--project", $Root,
            "python", (Join-Path $Root "bridge\server.py")
        ) -RedirectStandardOutput (Join-Path $Logs "mcp.out.log") -RedirectStandardError (Join-Path $Logs "mcp.err.log")
    }

    if ($Name -eq "tunnel") {
        $env:CONTROL_PLANE_TUNNEL_ID = [string]$Config.tunnel_id
        $env:CONTROL_PLANE_API_KEY = $RuntimeKey
        $env:MCP_SERVER_URL = "http://127.0.0.1:$($Config.mcp_port)/mcp"

        return Start-Process $Tunnel -WindowStyle Hidden -PassThru -ArgumentList @(
            "run",
            "--health.listen-addr", "127.0.0.1:$($Config.health_port)",
            "--log.format", "json",
            "--log.file", (Join-Path $Logs "tunnel.jsonl")
        ) -RedirectStandardOutput (Join-Path $Logs "tunnel.out.log") -RedirectStandardError (Join-Path $Logs "tunnel.err.log")
    }
}

$children = @{}
foreach ($name in @("sync","mcp","tunnel")) {
    $children[$name] = Start-Child $name
}

while ($true) {
    Start-Sleep -Seconds 5
    foreach ($name in @("sync","mcp","tunnel")) {
        $process = $children[$name]
        if (-not $process -or $process.HasExited) {
            Start-Sleep -Seconds 2
            $children[$name] = Start-Child $name
        }
    }
}
'@
$SupervisorPath = Join-Path $Root "supervisor.ps1"
Set-Content $SupervisorPath $Supervisor -Encoding UTF8

$Status = @'
$Root = Join-Path $env:LOCALAPPDATA "WacliChatBridge"
if (-not (Test-Path (Join-Path $Root "config.json"))) {
    Write-Host "WacliChatBridge is nog niet geïnstalleerd." -ForegroundColor Yellow
    exit 1
}

$Config = Get-Content (Join-Path $Root "config.json") -Raw | ConvertFrom-Json
$Wacli = Join-Path $Root "bin\wacli.exe"
$Store = Join-Path $Root "wacli-store"

function Test-Port([int]$Port) {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $async = $client.BeginConnect("127.0.0.1", $Port, $null, $null)
        if (-not $async.AsyncWaitHandle.WaitOne(1500, $false)) { return $false }
        $client.EndConnect($async)
        return $true
    } catch { return $false }
    finally { $client.Close() }
}

function Test-Url([string]$Url) {
    try {
        $r = Invoke-WebRequest -UseBasicParsing $Url -TimeoutSec 4
        return ($r.StatusCode -eq 200)
    } catch { return $false }
}

Clear-Host
Write-Host ""
Write-Host "WacliChatBridge status" -ForegroundColor Cyan
Write-Host "======================" -ForegroundColor Cyan
Write-Host ""

try {
    & $Wacli --store $Store doctor *> $null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] WhatsApp gekoppeld" -ForegroundColor Green
    } else {
        Write-Host "[!]  WhatsApp heeft aandacht nodig" -ForegroundColor Yellow
    }
} catch {
    Write-Host "[!]  WhatsApp heeft aandacht nodig" -ForegroundColor Yellow
}

if (Test-Port ([int]$Config.mcp_port)) {
    Write-Host "[OK] Lokale ChatGPT-bridge draait" -ForegroundColor Green
} else {
    Write-Host "[!]  Lokale ChatGPT-bridge draait niet" -ForegroundColor Yellow
}

if (Test-Url "http://127.0.0.1:$($Config.health_port)/healthz") {
    Write-Host "[OK] OpenAI-tunnel draait" -ForegroundColor Green
} else {
    Write-Host "[!]  OpenAI-tunnel draait niet" -ForegroundColor Yellow
}

if (Test-Url "http://127.0.0.1:$($Config.health_port)/readyz") {
    Write-Host "[OK] Klaar voor ChatGPT" -ForegroundColor Green
} else {
    Write-Host "[...] Nog niet klaar voor ChatGPT" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Tunnel ID: $($Config.tunnel_id)"
Write-Host ""
'@
$StatusPath = Join-Path $Root "status.ps1"
Set-Content $StatusPath $Status -Encoding UTF8

$Stop = @'
Get-CimInstance Win32_Process | Where-Object {
    $_.CommandLine -like "*WacliChatBridge*" -and
    ($_.Name -in @("powershell.exe","wacli.exe","tunnel-client.exe","uv.exe","python.exe"))
} | ForEach-Object {
    if ($_.ProcessId -ne $PID) {
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }
}
'@
Set-Content (Join-Path $Root "stop.ps1") $Stop -Encoding UTF8

$TaskName = "WacliChatBridge"
$AutostartMethod = ""
try {
    $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$SupervisorPath`""
    $Trigger = New-ScheduledTaskTrigger -AtLogOn
    $Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Description "WACLI + MCP + OpenAI tunnel for ChatGPT" -Force | Out-Null
    $AutostartMethod = "Windows Taakplanner"
}
catch {
    $Startup = [Environment]::GetFolderPath("Startup")
    $Cmd = Join-Path $Startup "WacliChatBridge.cmd"
    "@echo off`r`nstart `"`" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$SupervisorPath`"`r`n" | Set-Content $Cmd -Encoding ASCII
    $AutostartMethod = "Windows Opstartmap"
}

try {
    $Desktop = [Environment]::GetFolderPath("Desktop")
    $ShortcutPath = Join-Path $Desktop "WacliChatBridge status.lnk"
    $Shell = New-Object -ComObject WScript.Shell
    $Shortcut = $Shell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = "powershell.exe"
    $Shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$StatusPath`""
    $Shortcut.WorkingDirectory = $Root
    $Shortcut.Description = "Controleer WacliChatBridge"
    $Shortcut.Save()
}
catch {}

Write-Host "  Automatisch starten: OK ($AutostartMethod)" -ForegroundColor Green

Get-CimInstance Win32_Process | Where-Object {
    $_.CommandLine -like "*WacliChatBridge*supervisor.ps1*" -and $_.ProcessId -ne $PID
} | ForEach-Object {
    Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
}

Start-Process powershell.exe -WindowStyle Hidden -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", "`"$SupervisorPath`""
) | Out-Null

Write-Step 6 "Controleren of alles werkt"
Write-Host "De tunnel kan bij een eerste koppeling ongeveer 30 seconden nodig hebben."
Write-Host -NoNewline "Controleren"

$Ready = $false
$McpReady = $false
$TunnelHealthy = $false
for ($i = 0; $i -lt 24; $i++) {
    Start-Sleep -Seconds 3
    $McpReady = Test-LocalPort 8787
    $TunnelHealthy = Test-Url200 "http://127.0.0.1:8788/healthz"
    $Ready = Test-Url200 "http://127.0.0.1:8788/readyz"
    if ($McpReady -and $TunnelHealthy -and $Ready) { break }
    Write-Host -NoNewline "."
}
Write-Host ""

Write-Host ""
if ($McpReady -and $TunnelHealthy -and $Ready) {
    Write-Host "==================================================" -ForegroundColor Green
    Write-Host "KLAAR. WacliChatBridge werkt." -ForegroundColor Green
    Write-Host "==================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "[OK] WhatsApp gekoppeld" -ForegroundColor Green
    Write-Host "[OK] Lokale ChatGPT-bridge draait" -ForegroundColor Green
    Write-Host "[OK] OpenAI-tunnel draait" -ForegroundColor Green
    Write-Host "[OK] Tunnel is klaar voor ChatGPT" -ForegroundColor Green
    Write-Host ""
    Write-Host "Tunnel ID:" -ForegroundColor White
    Write-Host "  $TunnelId" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Laatste stap in ChatGPT:"
    Write-Host "  Instellingen > Connectors > toevoegen via Tunnel"
    Write-Host "  Selecteer deze tunnel of plak bovenstaande Tunnel ID."
    Write-Host ""
    Write-Host "Daarna kun je bijvoorbeeld vragen:"
    Write-Host '  "Check mijn WhatsApp en toon mijn vijf meest recente chats."'
    Write-Host ""

    if (Read-YesNo "ChatGPT Connector-instellingen nu openen?" $true) {
        Start-Process $ChatGPTConnectorsPage
    }
}
else {
    Write-Host "==================================================" -ForegroundColor Yellow
    Write-Host "Installatie klaar, maar de verbinding is nog niet volledig ready." -ForegroundColor Yellow
    Write-Host "==================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Dit kan bij een nieuwe OpenAI-tunnel nog even duren."
    Write-Host "Dubbelklik straks op 'WacliChatBridge status' op je bureaublad."
    Write-Host ""
    Write-Host "Als hij na een minuut nog niet ready is, controleer dan:"
    Write-Host "  - of de Runtime API key Tunnels Read + Use heeft;"
    Write-Host "  - of Tunnel ID $TunnelId bij de juiste workspace hoort."
    Write-Host ""
    Write-Host "Logs staan hier:"
    Write-Host "  $Logs"
    Write-Host ""
}

exit 0
