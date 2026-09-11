# Instruksi Project — Juragan Seblak

## MySQL (WAJIB — baca sebelum apa pun yang berhubungan dengan database)

Mesin ini menjalankan DUA instance MySQL milik project BERBEDA. Sebelum menjalankan/mematikan
server database, meng-inisialisasi, atau menghapus apa pun terkait MySQL: **baca dan patuhi
`PROMPT-1-aturan-project-seblak.md`** (instance ini hanya boleh mengelola port 3306 via
`D:/mysql-data` + `D:/mysql-conf/my.ini`; port 3307 / `D:/mysql-data-mulia` adalah milik
project lain — JANGAN disentuh). Perintah yang berpotensi menghapus data WAJIB ditanyakan
dulu ke user.

## Graphify (wajib — penghemat token)

Project ini punya knowledge graph via MCP `graphify` (data di `graphify-out/graph.json`).

1. **Sebelum membaca file codebase secara langsung**, query graphify dulu untuk mencari konteks:
   - `mcp__graphify__query_graph` untuk pertanyaan/kata kunci umum
   - `mcp__graphify__get_node` / `get_neighbors` untuk detail satu konsep
   - `mcp__graphify__shortest_path` untuk relasi antar dua konsep
2. Baca file penuh **hanya** jika graph tidak menjawab, atau saat akan mengedit file tersebut.
3. Di awal session baru, panggil `mcp__graphify__graph_stats` sekali untuk memastikan MCP aktif.
4. Setelah perubahan code besar, ingatkan user untuk rebuild graph (lihat `GRAPHIFY_SETUP.md` / `graphify-report.bat`) agar graph tetap sinkron.
