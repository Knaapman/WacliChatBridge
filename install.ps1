$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Join-Path $env:LOCALAPPDATA "WacliChatBridge"
$Bin = Join-Path $Root "bin"
$Store = Join-Path $Root "wacli-store"
$Secrets = Join-Path $Root "secrets"
$Logs = Join-Path $Root "logs"

New-Item -ItemType Directory -Force -Path $Root,$Bin,$Store,$Secrets,$Logs | Out-Null

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
        throw "No suitable Windows x64 release found for $Repository."
    }

    $tmp = Join-Path $env:TEMP ("wacli-chat-bridge-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    try {
        $download = Join-Path $tmp $asset.name
        Write-Host "Downloading $($asset.name)..."
        Invoke-WebRequest -Headers $headers -Uri $asset.browser_download_url -OutFile $download

        if ($asset.name -match "\.zip$") {
            $unpack = Join-Path $tmp "unpack"
            Expand-Archive -Path $download -DestinationPath $unpack -Force
            $exe = Get-ChildItem $unpack -Recurse -File -Filter $ExecutableName | Select-Object -First 1
            if (-not $exe) { throw "$ExecutableName not found in $($asset.name)." }
            Copy-Item $exe.FullName $Destination -Force
        }
        elseif ($asset.name -match "\.exe$") {
            Copy-Item $download $Destination -Force
        }
        else {
            throw "Unsupported release asset: $($asset.name)"
        }
    }
    finally {
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "WacliChatBridge setup" -ForegroundColor Cyan
Write-Host "WhatsApp stays on this laptop. ChatGPT reaches only the local MCP through OpenAI Secure MCP Tunnel."
Write-Host ""

$Wacli = Join-Path $Bin "wacli.exe"
$Tunnel = Join-Path $Bin "tunnel-client.exe"
$Uv = Join-Path $Bin "uv.exe"

Get-LatestAsset "openclaw/wacli" "windows[_-]amd64.*\.zip$" $Wacli "wacli.exe"
Get-LatestAsset "openai/tunnel-client" "windows[_-]amd64.*\.zip$" $Tunnel "tunnel-client.exe"
Get-LatestAsset "astral-sh/uv" "uv-x86_64-pc-windows-msvc\.zip$" $Uv "uv.exe"

Write-Host "Installing Python and MCP runtime..."
& $Uv python install 3.13
if ($LASTEXITCODE -ne 0) { throw "Python installation through uv failed." }

Copy-Item (Join-Path $RepoRoot "bridge") $Root -Recurse -Force
Copy-Item (Join-Path $RepoRoot "pyproject.toml") $Root -Force
& $Uv sync --project $Root
if ($LASTEXITCODE -ne 0) { throw "MCP dependency installation failed." }

Write-Host ""
Write-Host "WhatsApp pairing" -ForegroundColor Yellow
Write-Host "Open WhatsApp on your phone > Linked devices > Link a device, then scan the QR code."
& $Wacli --store $Store auth
if ($LASTEXITCODE -ne 0) { throw "WhatsApp pairing failed." }

Write-Host ""
$TunnelId = Read-Host "OpenAI Tunnel ID (tunnel_...)"
if ($TunnelId -notmatch "^tunnel_[0-9a-f]{32}$") {
    throw "Tunnel ID must look like tunnel_ followed by 32 lowercase hexadecimal characters."
}
$RuntimeKey = Read-Host "OpenAI Runtime API key (Tunnels Read + Use)" -AsSecureString
if ($RuntimeKey.Length -eq 0) { throw "Runtime API key is required." }

$RuntimeKey | ConvertFrom-SecureString | Set-Content (Join-Path $Secrets "runtime-key.dpapi")
@{
    tunnel_id = $TunnelId
    mcp_port = 8787
    health_port = 8788
} | ConvertTo-Json | Set-Content (Join-Path $Root "config.json") -Encoding UTF8

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
            "--store", $Store, "sync", "--follow", "--presence-mode", "quiet", "--max-reconnect", "0"
        ) -RedirectStandardOutput (Join-Path $Logs "sync.out.log") -RedirectStandardError (Join-Path $Logs "sync.err.log")
    }
    if ($Name -eq "mcp") {
        $env:WACLI_BIN = $Wacli
        $env:WACLI_STORE_DIR = $Store
        $env:WACLI_MCP_PORT = [string]$Config.mcp_port
        return Start-Process $Uv -WindowStyle Hidden -PassThru -ArgumentList @(
            "run", "--project", $Root, "python", (Join-Path $Root "bridge\server.py")
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
foreach ($name in @("sync","mcp","tunnel")) { $children[$name] = Start-Child $name }

while ($true) {
    Start-Sleep -Seconds 5
    foreach ($name in @("sync","mcp","tunnel")) {
        $p = $children[$name]
        if (-not $p -or $p.HasExited) {
            Start-Sleep -Seconds 2
            $children[$name] = Start-Child $name
        }
    }
}
'@
Set-Content (Join-Path $Root "supervisor.ps1") $Supervisor -Encoding UTF8

$Status = @'
$Root = Join-Path $env:LOCALAPPDATA "WacliChatBridge"
$Config = Get-Content (Join-Path $Root "config.json") -Raw | ConvertFrom-Json
$Wacli = Join-Path $Root "bin\wacli.exe"
$Store = Join-Path $Root "wacli-store"

Write-Host ""
Write-Host "WacliChatBridge" -ForegroundColor Cyan
Write-Host "Tunnel: $($Config.tunnel_id)"
Write-Host ""

try {
    Invoke-WebRequest -UseBasicParsing "http://127.0.0.1:$($Config.mcp_port)/mcp" -Method POST -ContentType "application/json" -Body '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' -TimeoutSec 5 | Out-Null
    Write-Host "MCP:        OK" -ForegroundColor Green
} catch {
    Write-Host "MCP:        NOT READY" -ForegroundColor Yellow
}
try {
    Invoke-WebRequest -UseBasicParsing "http://127.0.0.1:$($Config.health_port)/healthz" -TimeoutSec 5 | Out-Null
    Write-Host "Tunnel:     HEALTHY" -ForegroundColor Green
} catch {
    Write-Host "Tunnel:     NOT HEALTHY" -ForegroundColor Yellow
}
try {
    Invoke-WebRequest -UseBasicParsing "http://127.0.0.1:$($Config.health_port)/readyz" -TimeoutSec 5 | Out-Null
    Write-Host "ChatGPT:    READY" -ForegroundColor Green
} catch {
    Write-Host "ChatGPT:    NOT READY" -ForegroundColor Yellow
}
Write-Host ""
& $Wacli --store $Store doctor
'@
Set-Content (Join-Path $Root "status.ps1") $Status -Encoding UTF8

$Stop = @'
Get-CimInstance Win32_Process | Where-Object {
    $_.CommandLine -like "*WacliChatBridge*" -and
    ($_.Name -in @("powershell.exe","wacli.exe","tunnel-client.exe","uv.exe","python.exe"))
} | ForEach-Object {
    if ($_.ProcessId -ne $PID) { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}
'@
Set-Content (Join-Path $Root "stop.ps1") $Stop -Encoding UTF8

$TaskName = "WacliChatBridge"
$SupervisorPath = Join-Path $Root "supervisor.ps1"
try {
    $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$SupervisorPath`""
    $Trigger = New-ScheduledTaskTrigger -AtLogOn
    $Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Description "WACLI + MCP + OpenAI tunnel for ChatGPT" -Force | Out-Null
    Write-Host "Autostart configured with Windows Task Scheduler."
}
catch {
    $Startup = [Environment]::GetFolderPath("Startup")
    $Cmd = Join-Path $Startup "WacliChatBridge.cmd"
    "@echo off`r`nstart `"`" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$SupervisorPath`"`r`n" | Set-Content $Cmd -Encoding ASCII
    Write-Host "Task Scheduler unavailable; autostart configured through the Startup folder."
}

Get-CimInstance Win32_Process | Where-Object {
    $_.CommandLine -like "*WacliChatBridge*supervisor.ps1*" -and $_.ProcessId -ne $PID
} | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

Start-Process powershell.exe -WindowStyle Hidden -ArgumentList @(
    "-NoProfile","-ExecutionPolicy","Bypass","-File","`"$SupervisorPath`""
) | Out-Null

Start-Sleep -Seconds 7

Write-Host ""
Write-Host "Installed." -ForegroundColor Green
Write-Host "Runtime folder: $Root"
Write-Host ""
Write-Host "To check it later:"
Write-Host "  powershell.exe -ExecutionPolicy Bypass -File `"$Root\status.ps1`""
Write-Host ""
Write-Host "When Tunnel ready = READY, the local bridge is ready for the ChatGPT connector."
