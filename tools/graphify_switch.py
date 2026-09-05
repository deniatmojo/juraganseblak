#!/usr/bin/env python3
"""Saklar ON/OFF Graphify untuk workspace ini.

Usage:
  python tools/graphify_switch.py on      # daftarkan MCP server graphify (mode hemat token)
  python tools/graphify_switch.py off     # lepas MCP server (mode baca file biasa)
  python tools/graphify_switch.py status  # lihat kondisi saat ini

ON  = MCP server "graphify" terdaftar di .zcode/config.json -> assistant
      menjawab pertanyaan kodebase via query_graph (subgraph kecil).
OFF = entry MCP dihapus (backup ke .zcode/config.graphify-backup.json)
      -> assistant balik membaca file mentah.

Catatan: perubahan terbaca saat session ZCode baru dimulai (MCP connect saat start).
Query log tetap aktif selama graphify-out/query-log.jsonl dipakai, tapi hanya
tertulis kalau server MCP/CLI graphify berjalan - itu juga cara membandingkan
pemakaian: saat OFF tidak ada baris log baru karena assistant tidak memakai graph.
"""
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / ".zcode" / "config.json"
BACKUP = ROOT / ".zcode" / "config.graphify-backup.json"

SERVER_ENTRY = {
    "command": r"C:\Users\Design-Eng\.local\bin\graphify-mcp.exe",
    "args": [str(ROOT / "graphify-out" / "graph.json")],
    "env": {
        "GRAPHIFY_QUERY_LOG": str(ROOT / "graphify-out" / "query-log.jsonl"),
        "GRAPHIFY_QUERY_LOG_RESPONSES": "1",
    },
}


def load_config():
    if CONFIG.exists():
        return json.loads(CONFIG.read_text(encoding="utf-8"))
    return {}


def save_config(cfg):
    CONFIG.parent.mkdir(parents=True, exist_ok=True)
    CONFIG.write_text(json.dumps(cfg, indent=2) + "\n", encoding="utf-8")


def is_on(cfg):
    return "graphify" in (cfg.get("mcp", {}).get("servers", {}) or {})


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    cfg = load_config()

    if cmd == "on":
        if is_on(cfg):
            print("Graphify sudah ON.")
            return
        if BACKUP.exists():
            shutil.copy(BACKUP, CONFIG)
            cfg = load_config()
            if not is_on(cfg):
                servers = cfg.setdefault("mcp", {}).setdefault("servers", {})
                servers["graphify"] = SERVER_ENTRY
                save_config(cfg)
        else:
            servers = cfg.setdefault("mcp", {}).setdefault("servers", {})
            servers["graphify"] = SERVER_ENTRY
            save_config(cfg)
        print("Graphify ON - MCP server terdaftar. Mulai session ZCode baru untuk aktif.")

    elif cmd == "off":
        if not is_on(cfg):
            print("Graphify sudah OFF.")
            return
        shutil.copy(CONFIG, BACKUP)
        del cfg["mcp"]["servers"]["graphify"]
        if not cfg["mcp"]["servers"]:
            del cfg["mcp"]["servers"]
        if not cfg["mcp"]:
            del cfg["mcp"]
        save_config(cfg)
        print("Graphify OFF - MCP server dilepas (backup: .zcode/config.graphify-backup.json).")

    elif cmd == "status":
        state = "ON" if is_on(cfg) else "OFF"
        log = ROOT / "graphify-out" / "query-log.jsonl"
        n = sum(1 for _ in log.open(encoding="utf-8")) if log.exists() else 0
        print(f"Graphify : {state}")
        print(f"Query log: {log} ({n} entri)")

    else:
        print(__doc__)


if __name__ == "__main__":
    main()
