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
3. De installer downloadt automatisch WACLI, OpenAI `tunnel-client` en `uv`.
4. Scan de WhatsApp-QR-code.
5. Vul je OpenAI **Tunnel ID** (`tunnel_...`) in.
6. Vul je **tunnel runtime key** in. De invoer is verborgen.
7. Klaar. De bridge start direct en voortaan automatisch bij Windows-login.

De runtime key wordt niet in Git opgeslagen. Windows versleutelt hem met DPAPI voor de huidige gebruiker.

## Controleren

Dubbelklik `STATUS.cmd`.

Je ziet afzonderlijk:

- WACLI;
- lokale MCP health;
- OpenAI tunnel health;
- OpenAI tunnel readiness.

## Updaten

Dubbelklik `UPDATE.cmd`. De bestaande WhatsApp-koppeling en tunnelcredentials blijven behouden.

## Verwijderen

Dubbelklik `UNINSTALL.cmd`.

De WhatsApp-store wordt standaard bewaard als backup onder `%LOCALAPPDATA%`.

## Wat draait er lokaal?

Na installatie staat alles onder:

```text
%LOCALAPPDATA%\WacliChatBridge\
```

De bridge houdt automatisch actief:

- `wacli sync --follow --presence-mode quiet`;
- de MCP-server op `http://127.0.0.1:8787/mcp`;
- OpenAI `tunnel-client`.

## MCP-tools

- `wacli_doctor`
- `wacli_chats_list`
- `wacli_messages_list`
- `wacli_messages_search`
- `wacli_sync_once`
- `wacli_history_backfill`
- `wacli_send_text`

De leesfuncties draaien in WACLI read-only mode. `wacli_send_text` is een externe write-actie.

## Security

- MCP bindt uitsluitend aan loopback (`127.0.0.1`).
- Alleen de OpenAI Secure MCP Tunnel maakt hem bereikbaar voor ChatGPT.
- Tunnelcredentials worden lokaal DPAPI-versleuteld opgeslagen.
- WhatsApp-store, tokens en secrets worden niet gecommit.
- WACLI gebruikt WhatsApp Web en is geen officieel Meta-product.
