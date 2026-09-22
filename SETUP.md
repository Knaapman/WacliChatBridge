# Veilige Windows-setup

Deze repository bevat bewust alleen broncode en configuratievoorbeelden. Er staan geen binaries, downloaders, verborgen processen of autostart-installers in.

## Wat je nodig hebt

Installeer of download deze drie onderdelen uitsluitend van de officiële leverancier:

1. **uv**
   - Windows: `winget install --id=astral-sh.uv -e`
2. **WACLI**
   - Download de actuele Windows x64 release van:
     https://github.com/openclaw/wacli/releases/latest
3. **OpenAI tunnel-client**
   - Download de actuele Windows x64 release van:
     https://github.com/openai/tunnel-client/releases/latest

Pak `wacli.exe` en `tunnel-client.exe` uit naar bijvoorbeeld:

```text
C:\Tools\WacliChatBridge\bin
```

Voeg die map tijdelijk aan je PowerShell PATH toe:

```powershell
$env:Path = "C:\Tools\WacliChatBridge\bin;$env:Path"
```

## 1. Bridge voorbereiden

Open PowerShell in de uitgepakte/cloned repository en voer uit:

```powershell
uv sync
```

## 2. WhatsApp koppelen

Maak een lokale WACLI-store:

```powershell
$Store = "$env:LOCALAPPDATA\WacliChatBridge\wacli-store"
New-Item -ItemType Directory -Force -Path $Store | Out-Null
wacli --store $Store auth
```

Scan daarna de QR-code via:

**WhatsApp > Instellingen > Gekoppelde apparaten > Apparaat koppelen**

Controleer daarna:

```powershell
wacli --store $Store doctor
```

## 3. Lokale MCP starten

Open een PowerShell-venster in de repository:

```powershell
$env:WACLI_BIN = "C:\Tools\WacliChatBridge\bin\wacli.exe"
$env:WACLI_STORE_DIR = "$env:LOCALAPPDATA\WacliChatBridge\wacli-store"
uv run python bridge\server.py
```

Laat dit venster tijdens de eerste test open.

De MCP draait dan lokaal op:

```text
http://127.0.0.1:8787/mcp
```

## 4. OpenAI tunnel koppelen

Maak of selecteer een Tunnel ID via OpenAI Platform en maak een Restricted Runtime API key met alleen:

- **Tunnels Read**
- **Tunnels Use**

Open daarna een tweede PowerShell-venster:

```powershell
$env:CONTROL_PLANE_TUNNEL_ID = "tunnel_..."
$env:CONTROL_PLANE_API_KEY = "plak-hier-de-runtime-key"
$env:MCP_SERVER_URL = "http://127.0.0.1:8787/mcp"

tunnel-client doctor --explain
tunnel-client run --health.listen-addr 127.0.0.1:8788
```

Controleer:

```powershell
Invoke-WebRequest http://127.0.0.1:8788/healthz
Invoke-WebRequest http://127.0.0.1:8788/readyz
```

Beide horen HTTP 200 te geven voordat je in ChatGPT gaat testen.

## 5. ChatGPT koppelen

Open ChatGPT:

**Settings > Connectors > Connection: Tunnel**

Selecteer de tunnel of plak de Tunnel ID.

Test bijvoorbeeld:

> Check mijn WhatsApp en toon mijn vijf meest recente chats.

## Autostart

Zet autostart pas aan nadat de handmatige flow volledig werkt. Dat doen we op de betreffende laptop met de native Windows- en tunnel-client-functionaliteit, in plaats van met een generieke downloader of verborgen PowerShell-processen in deze repository.

Dat voorkomt onnodige antiviruswaarschuwingen en maakt de installatie beter controleerbaar.

## Security

- De repository bevat geen API-keys, WhatsApp-store of binaries.
- De MCP luistert alleen op `127.0.0.1`.
- Gebruik voor de runtime key alleen **Tunnels Read + Use**.
- Gebruik geen admin key voor de langlopende tunnel-runtime.
- Download WACLI en tunnel-client alleen uit hun officiële repositories.
