# Setup Graphify — Juragan Seblak

Infrastruktur hemat token berbasis knowledge graph (Graphify) untuk project ini.

## Yang sudah terpasang

| Komponen | Lokasi / perintah | Fungsi |
|---|---|---|
| Graphify CLI + MCP | `graphify` (via `uv tool install "graphifyy[mcp]"`, v0.9.53) | build graph & MCP server |
| MCP server (workspace) | `.zcode/config.json` → `mcp.servers.graphify` | tool `query_graph`, `get_node`, `get_neighbors`, `shortest_path`, dll untuk assistant |
| Saklar ON/OFF | `python tools/graphify_switch.py on|off|status` | daftar/lepas MCP server untuk perbandingan token |
| Laporan token | `python tools/token_report.py` (`--reset` mulai pengukuran baru) | rekap query + estimasi hemat vs baca file |
| Viewer realtime | `python tools/graph_live.py` | `graphify --watch` + halaman live di http://127.0.0.1:8791/live |
| Query log | `graphify-out/query-log.jsonl` (diaktifkan via `GRAPHIFY_QUERY_LOG`) | catatan tiap query (JSONL) |

## File .bat (double-click saja)

| File | Fungsi |
|---|---|
| `graphify-on.bat` | saklar ON (mode hemat token) |
| `graphify-off.bat` | saklar OFF (baca file biasa) |
| `graphify-status.bat` | cek kondisi saklar + jumlah query tercatat |
| `graphify-report.bat` | laporan token (jalankan dari cmd dengan `graphify-report.bat --reset` untuk mulai pengukuran baru) |

Setelah ON/OFF, mulai session ZCode baru agar perubahannya terbaca.

## Alur harian

1. **Menambah/ubah kode** — tidak perlu apa pun kalau `graph_live.py` jalan
   (watcher rebuild otomatis, AST saja, 0 API). Manual: `graphify . --update`.
2. **Build penuh pertama kali / besar**: `graphify .` (dari root project).
   Output: `graphify-out/graph.json`, `graph.html`, `GRAPH_REPORT.md`.
3. **Melihat graph**: buka http://127.0.0.1:8791/live (auto reload tiap 5 s).

## Eksperimen perbandingan token (saklar)

1. `python tools/token_report.py --reset` — mulai pengukuran.
2. Pastikan saklar di kondisi yang diuji:
   - ON : `python tools/graphify_switch.py on` → mulai session ZCode baru.
   - OFF: `python tools/graphify_switch.py off` → mulai session ZCode baru.
3. Kerjakan tugas yang sama di kedua kondisi (mis. "jelaskan alur X", "apa yang
   memanggil Y").
4. Bandingkan:
   - meterai token di UI ZCode (pemakaian nyata model), dan
   - `python tools/token_report.py` (granular: node dikembalikan, estimasi
     token graph vs baca file).

Catatan: perubahan saklar baru terbaca saat session baru dimulai, karena MCP
server di-connect saat session start.

## Batasan / catatan

- **Build graph pakai**: `graphify extract . --code-only` (AST lokal, 0 API, 0 biaya)
  lalu `graphify cluster-only .` untuk regenerasi report + graph.html.
  Update cepat setelah edit kode: `graphify update .` (tanpa LLM).
- `.graphifyignore` mengecualikan folder `graphify/` (clone repo referensi)
  agar tidak ikut ter-index dan tidak memicu semantic pass LLM.
- Estimasi token memakai chars/4 — indikatif, bukan tokenizer resmi.
- Folder `graphify/` di root adalah clone repo upstream untuk referensi;
- Safe di-commit: `graphify-out/` (kecuali `query-log.jsonl` kalau dianggap
  privat) dan `tools/`, `.zcode/config.json`.
