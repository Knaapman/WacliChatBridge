# WacliChatBridge

WacliChatBridge koppelt een lokale WACLI/WhatsApp-store aan ChatGPT via OpenAI Secure MCP Tunnel.

## Belangrijk: source-only repository

Deze repository is bewust **source-only** gemaakt.

Er staan dus geen:

- gedownloade executables;
- `.cmd` installers;
- PowerShell downloaders;
- proces-kill scripts;
- verborgen autostartprocessen;
- API-keys of WhatsApp-data

in de repository.

Dat maakt de GitHub-download transparanter en verkleint de kans dat browser- of endpointbeveiliging de ZIP als verdacht markeert.

## Installeren

Volg [SETUP.md](SETUP.md).

De setup gebruikt alleen officiële downloads van:

- WACLI;
- OpenAI `tunnel-client`;
- Astral `uv`.

## MCP-tools

- `wacli_doctor`
- `wacli_chats_list`
- `wacli_messages_list`
- `wacli_messages_search`
- `wacli_sync_once`
- `wacli_history_backfill`
- `wacli_send_text`

Leesacties gebruiken de lokale WACLI-store. `wacli_send_text` is een externe write-actie.

## Architectuur

```text
ChatGPT
   |
OpenAI Secure MCP Tunnel
   |
tunnel-client op de laptop
   |
127.0.0.1:8787/mcp
   |
WacliChatBridge
   |
lokale WACLI-store
   |
WhatsApp Web
```

De lokale MCP bindt alleen op loopback. Secrets en WhatsApp-data horen nooit in Git.

## Antivirus

Als een eerdere ZIP-download als verdacht werd geblokkeerd, gebruik dan de actuele `main` branch. De eerdere automatische installer is verwijderd uit de huidige repository.
