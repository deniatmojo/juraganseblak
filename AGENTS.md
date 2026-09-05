# Instruksi Project — Juragan Seblak

## Graphify (wajib — penghemat token)

Project ini punya knowledge graph via MCP `graphify` (data di `graphify-out/graph.json`).

1. **Sebelum membaca file codebase secara langsung**, query graphify dulu untuk mencari konteks:
   - `mcp__graphify__query_graph` untuk pertanyaan/kata kunci umum
   - `mcp__graphify__get_node` / `get_neighbors` untuk detail satu konsep
   - `mcp__graphify__shortest_path` untuk relasi antar dua konsep
2. Baca file penuh **hanya** jika graph tidak menjawab, atau saat akan mengedit file tersebut.
3. Di awal session baru, panggil `mcp__graphify__graph_stats` sekali untuk memastikan MCP aktif.
4. Setelah perubahan code besar, ingatkan user untuk rebuild graph (lihat `GRAPHIFY_SETUP.md` / `graphify-report.bat`) agar graph tetap sinkron.
