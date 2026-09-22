# WacliChatBridge

Een eenvoudige Windows-bridge tussen je eigen WhatsApp-account en ChatGPT.

De bridge gebruikt:

- [wacli](https://github.com/openclaw/wacli) als lokale WhatsApp-client;
- de officiële MCP Python SDK voor een lokale Streamable HTTP MCP-server;
- de officiële OpenAI `tunnel-client` om die lokale MCP veilig beschikbaar te maken voor ChatGPT.

WhatsApp-data blijft lokaal op de laptop. De MCP-server luistert alleen op `127.0.0.1`.

## Installeren

1. Clone of download deze repository.
2. Dubbelklik `INSTALL.cmd`.
3. De installer downloadt automatisch de actuele Windows x64-versies van WACLI, OpenAI `tunnel-client` en `uv`.
4. Scan de WhatsApp-QR-code.
5. Vul je OpenAI **Tunnel ID** (`tunnel_...`) in.
6. Vul je **Runtime API key** in met minimaal **Tunnels Read + Use**. De invoer is verborgen.
7. Klaar. De bridge start direct en voortaan automatisch bij Windows-login.

De runtime key wordt niet in Git opgeslagen. Windows versleutelt hem lokaal met DPAPI voor de huidige gebruiker.

## Controleren

Dubbelklik `STATUS.cmd`.

Daarmee controleer je:

- WACLI;
- de lokale MCP;
- de OpenAI tunnel;
- of de tunnel voor ChatGPT `ready` is.

## Verwijderen

Dubbelklik `UNINSTALL.cmd`.

De lokale runtime-map wordt niet hard verwijderd, maar als backup onder `%LOCALAPPDATA%` bewaard.

## Wat draait er lokaal?

Na installatie staat alles onder:

```text
%LOCALAPPDATA%\WacliChatBridge\
```

De installer start één verborgen supervisor die automatisch deze drie processen bewaakt en opnieuw start wanneer nodig:

- `wacli sync --follow --presence-mode quiet`;
- de MCP-server op `http://127.0.0.1:8787/mcp`;
- OpenAI `tunnel-client`.

Autostart gebeurt via Windows Task Scheduler. Als dat op de laptop niet is toegestaan, valt de installer terug op de Windows Startup-folder.

## MCP-tools

- `wacli_doctor`
- `wacli_chats_list`
- `wacli_messages_list`
- `wacli_messages_search`
- `wacli_sync_once`
- `wacli_history_backfill`
- `wacli_send_text`

De leesfuncties draaien in WACLI read-only mode. `wacli_send_text` is een expliciete externe write-actie.

## Security

- MCP bindt uitsluitend aan loopback (`127.0.0.1`).
- Alleen de OpenAI Secure MCP Tunnel maakt de lokale MCP bereikbaar voor ChatGPT.
- De runtime key wordt DPAPI-versleuteld opgeslagen.
- WhatsApp-store, tokens en secrets worden niet gecommit.
- WACLI gebruikt het WhatsApp Web-protocol en is geen officieel Meta-product.

## Eerste praktijktest

De Python-code is syntactisch gecontroleerd en de implementatie volgt de actuele MCP v2- en OpenAI tunnel-client interfaces. De echte Windows-installatie moet nog één keer op een schone Windows-machine worden gesmoked, omdat deze werkomgeving geen Windows/PowerShell-runtime heeft.
