from __future__ import annotations

import json
import os
import shutil
import subprocess
import time
from pathlib import Path
from typing import Any

from mcp.server.mcpserver import MCPServer

SERVER_NAME = "WacliChatBridge"
SERVER_VERSION = "0.1.0"
HOST = "127.0.0.1"
PORT = int(os.getenv("WACLI_MCP_PORT", "8787"))
STORE = os.path.expandvars(os.path.expanduser(os.getenv("WACLI_STORE_DIR", str(Path.home() / ".wacli"))))
WACLI_BIN = os.getenv("WACLI_BIN") or shutil.which("wacli") or "wacli"

mcp = MCPServer(
    SERVER_NAME,
    instructions=(
        "Use the read tools freely to inspect the local WhatsApp mirror. "
        "Sending a WhatsApp message is an external side effect and should only be called when the user clearly asked to send it."
    ),
)

def run_wacli(args: list[str], timeout_seconds: int = 60, read_only: bool = False) -> Any:
    cmd = [WACLI_BIN, "--json", "--store", STORE, *args]
    env = os.environ.copy()
    if read_only:
        env["WACLI_READONLY"] = "1"

    last_error = ""
    for attempt in range(2):
        try:
            proc = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=False,
                env=env,
                timeout=timeout_seconds,
                creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
            )
        except subprocess.TimeoutExpired as exc:
            raise RuntimeError(f"wacli timed out after {timeout_seconds}s") from exc

        stdout = (proc.stdout or "").strip()
        stderr = (proc.stderr or "").strip()
        if proc.returncode == 0:
            if not stdout:
                return {"ok": True}
            try:
                return json.loads(stdout)
            except json.JSONDecodeError:
                return {"ok": True, "output": stdout}

        last_error = stderr or stdout or f"wacli exited with code {proc.returncode}"
        if "store is locked" in last_error.lower() and attempt == 0:
            time.sleep(2)
            continue
        break
    raise RuntimeError(last_error or "wacli failed")

@mcp.tool()
def wacli_doctor() -> Any:
    """READ ONLY: Check WACLI authentication and local WhatsApp store health."""
    return run_wacli(["doctor"], read_only=True)

@mcp.tool()
def wacli_chats_list(limit: int = 30, query: str | None = None) -> Any:
    """READ ONLY: List locally synced WhatsApp chats, optionally filtered by text."""
    limit = max(1, min(int(limit), 500))
    cmd = ["chats", "list", "--limit", str(limit)]
    if query:
        cmd += ["--query", query]
    return run_wacli(cmd, read_only=True)

@mcp.tool()
def wacli_messages_list(
    chat: str | None = None,
    limit: int = 50,
    after: str | None = None,
    before: str | None = None,
) -> Any:
    """READ ONLY: List locally synced WhatsApp messages, optionally scoped to one chat and date range."""
    limit = max(1, min(int(limit), 500))
    cmd = ["messages", "list", "--limit", str(limit)]
    if chat:
        cmd += ["--chat", chat]
    if after:
        cmd += ["--after", after]
    if before:
        cmd += ["--before", before]
    return run_wacli(cmd, read_only=True)

@mcp.tool()
def wacli_messages_search(
    query: str,
    chat: str | None = None,
    from_jid: str | None = None,
    limit: int = 50,
    after: str | None = None,
    before: str | None = None,
    media_type: str | None = None,
) -> Any:
    """READ ONLY: Search the local WhatsApp message index with optional filters."""
    limit = max(1, min(int(limit), 500))
    cmd = ["messages", "search", query, "--limit", str(limit)]
    if chat:
        cmd += ["--chat", chat]
    if from_jid:
        cmd += ["--from", from_jid]
    if after:
        cmd += ["--after", after]
    if before:
        cmd += ["--before", before]
    if media_type:
        allowed = {"image", "video", "audio", "document"}
        if media_type not in allowed:
            raise ValueError(f"media_type must be one of: {', '.join(sorted(allowed))}")
        cmd += ["--type", media_type]
    return run_wacli(cmd, read_only=True)

@mcp.tool()
def wacli_sync_once(
    download_media: bool = False,
    refresh_contacts: bool = False,
    refresh_groups: bool = False,
) -> Any:
    """Sync WhatsApp once and update the local mirror. Does not send a message."""
    cmd = ["sync", "--once"]
    if download_media:
        cmd.append("--download-media")
    if refresh_contacts:
        cmd.append("--refresh-contacts")
    if refresh_groups:
        cmd.append("--refresh-groups")
    return run_wacli(cmd, timeout_seconds=900)

@mcp.tool()
def wacli_history_backfill(chat: str, requests: int = 1, count: int = 50) -> Any:
    """Request older WhatsApp history for one chat and store it locally."""
    requests = max(1, min(int(requests), 20))
    count = max(1, min(int(count), 500))
    return run_wacli(
        ["history", "backfill", "--chat", chat, "--requests", str(requests), "--count", str(count)],
        timeout_seconds=1200,
    )

@mcp.tool()
def wacli_send_text(to: str, message: str) -> Any:
    """WRITE / EXTERNAL SIDE EFFECT: Send a WhatsApp text message."""
    if not to.strip():
        raise ValueError("to is required")
    if not message.strip():
        raise ValueError("message is required")
    return run_wacli(["send", "text", "--to", to, "--message", message], timeout_seconds=90)

if __name__ == "__main__":
    mcp.run(
        transport="streamable-http",
        host=HOST,
        port=PORT,
        streamable_http_path="/mcp",
        json_response=True,
        stateless_http=True,
    )
