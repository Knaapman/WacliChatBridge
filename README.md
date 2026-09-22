# WacliChatBridge

**Voor Windows. Geen technische installatie nodig.**

WacliChatBridge koppelt je eigen WhatsApp aan ChatGPT. Je WhatsApp-database blijft lokaal op je laptop.

## Start hier

### 1. Download deze repository

Gebruik **Code > Download ZIP** en pak het ZIP-bestand uit.

### 2. Dubbelklik op `START-HERE.cmd`

Daarna begeleidt de installer je stap voor stap.

Je hoeft alleen:

1. een WhatsApp QR-code te scannen;
2. je OpenAI Tunnel ID in te voeren;
3. je OpenAI Runtime API key in te voeren.

Heb je de Tunnel ID of API key nog niet? Druk tijdens de installatie gewoon op **ENTER**. De installer opent dan automatisch de juiste OpenAI-pagina.

### 3. Klaar

De installer controleert zelf:

- of WhatsApp gekoppeld is;
- of de lokale ChatGPT-bridge draait;
- of de OpenAI-tunnel draait;
- of de verbinding klaar is voor ChatGPT.

Als alles goed staat, kan hij meteen de ChatGPT Connector-instellingen voor je openen.

## Daarna hoef je niets meer te doen

WacliChatBridge start voortaan automatisch wanneer je inlogt op Windows.

Op je bureaublad komt een snelkoppeling **WacliChatBridge status** waarmee je altijd kunt controleren of alles werkt.

Bij opnieuw uitvoeren van `START-HERE.cmd` worden bestaande WhatsApp- en tunnelinstellingen herkend en kun je die gewoon behouden.

## Wat wordt automatisch geïnstalleerd?

De installer haalt zelf de actuele Windows-versies op van:

- WACLI;
- OpenAI `tunnel-client`;
- `uv` en een lokale Python-runtime;
- de MCP-dependencies.

Je hoeft deze onderdelen niet zelf te installeren.

## Als iets niet werkt

Voer eerst opnieuw `START-HERE.cmd` uit. Bestaande gegevens blijven behouden.

Je kunt ook:

- dubbelklikken op `STATUS.cmd`;
- de snelkoppeling **WacliChatBridge status** op je bureaublad gebruiken;
- logs bekijken in `%LOCALAPPDATA%\WacliChatBridge\logs`.

## Verwijderen

Dubbelklik op `UNINSTALL.cmd`.

De lokale gegevens worden niet direct weggegooid. De installer bewaart eerst een backup onder `%LOCALAPPDATA%`.

## Voor beheerders

WacliChatBridge gebruikt:

- WACLI voor de lokale WhatsApp-mirror;
- de officiële MCP Python SDK voor Streamable HTTP op `127.0.0.1:8787/mcp`;
- OpenAI Secure MCP Tunnel voor de verbinding met ChatGPT;
- een OpenAI Runtime API key met uitsluitend **Tunnels Read + Use**;
- Windows DPAPI voor lokale versleuteling van die runtime key.

De MCP-server bindt alleen op loopback. WhatsApp-data, tokens en secrets worden niet naar Git gecommit.

WACLI gebruikt het WhatsApp Web-protocol en is geen officieel Meta-product.

## Beschikbare MCP-tools

- `wacli_doctor`
- `wacli_chats_list`
- `wacli_messages_list`
- `wacli_messages_search`
- `wacli_sync_once`
- `wacli_history_backfill`
- `wacli_send_text`

De leesfuncties draaien read-only. `wacli_send_text` is een expliciete externe write-actie.

> De installer is ontworpen voor Windows x64. De eerste echte end-to-end smoke test moet nog op een schone Windows-laptop worden uitgevoerd.
