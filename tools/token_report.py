#!/usr/bin/env python3
"""Laporan pemakaian & penghematan token Graphify.

Usage:
  python tools/token_report.py            # ringkasan per sesi saklar ON
  python tools/token_report.py --reset    # kosongkan penanda sesi (mulai pengukuran baru)

Sumber data: graphify-out/query-log.jsonl (diisi otomatis oleh MCP server dan
CLI graphify karena GRAPHIFY_QUERY_LOG di-set). Setiap query/path/explain
mencatat result_chars -> estimasi token (chars/4, kasar untuk campuran
kode+inggris; angka indikatif, bukan tokenizer resmi).

Pembanding:
  - "graph"       : token yang dikirim ke model dari hasil graphify (result_chars/4)
  - "per-file"    : perkiraan kalau assistant membaca file sumber dari node yang
                    dikembalikan (rata-rata ukuran file kode project x jumlah node)
  - "whole-repo"  : kalau assistant membaca seluruh kode project

Saat saklar OFF, tidak ada baris log baru -> itulah cara membandingkan:
jalankan tugas serupa saat ON dan OFF, bandingkan pemakaian token client
(meterai token di UI ZCode) dengan laporan ini sebagai pembanding granular.
"""
import argparse
import datetime as dt
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOG = ROOT / "graphify-out" / "query-log.jsonl"
MARKER = ROOT / "graphify-out" / ".report_marker"

CODE_EXTS = {
    ".py", ".js", ".ts", ".jsx", ".tsx", ".mjs", ".go", ".rs", ".java", ".rb",
    ".cs", ".kt", ".php", ".swift", ".lua", ".vue", ".svelte", ".sql", ".sh",
    ".html", ".css", ".md",
}
SKIP_DIRS = {"graphify", "graphify-out", ".git", ".zcode", "node_modules",
             ".venv", "__pycache__", "tools"}


def corpus_stats():
    n_files, total_chars = 0, 0
    for p in ROOT.rglob("*"):
        if not p.is_file():
            continue
        if p.suffix.lower() not in CODE_EXTS:
            continue
        rel = p.relative_to(ROOT)
        if rel.parts and rel.parts[0] in SKIP_DIRS:
            continue
        try:
            total_chars += len(p.read_text(encoding="utf-8", errors="ignore"))
            n_files += 1
        except OSError:
            pass
    return n_files, total_chars


def read_log_since(marker_ts):
    rows = []
    if not LOG.exists():
        return rows
    with LOG.open(encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            if marker_ts and rec.get("ts", "") <= marker_ts:
                continue
            rows.append(rec)
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--reset", action="store_true")
    args = ap.parse_args()

    marker_ts = None
    if MARKER.exists():
        marker_ts = MARKER.read_text(encoding="utf-8").strip() or None
    if args.reset:
        marker_ts = dt.datetime.now(dt.timezone.utc).isoformat()
        MARKER.parent.mkdir(parents=True, exist_ok=True)
        MARKER.write_text(marker_ts, encoding="utf-8")
        print(f"Penanda sesi di-set ke {marker_ts}. Mulai pengukuran baru.")
        return

    rows = read_log_since(marker_ts)
    n_files, corpus_chars = corpus_stats()
    avg_file_chars = (corpus_chars / n_files) if n_files else 0

    if not rows:
        print("Belum ada query graphify sejak penanda terakhir.")
        print("Jalankan tugas lewat assistant (saklar ON) lalu panggil laporan ini lagi.")
        return

    total_graph_chars = sum(r.get("result_chars") or 0 for r in rows)
    total_nodes = sum(r.get("nodes_returned") or 0 for r in rows)
    graph_tok = total_graph_chars / 4
    perfile_tok = (total_nodes * avg_file_chars) / 4
    whole_tok = corpus_chars / 4

    print("=" * 62)
    print("LAPORAN TOKEN GRAPHIFY (sejak penanda sesi terakhir)")
    print("=" * 62)
    print(f"Query dicatat        : {len(rows)} (query/path/explain)")
    print(f"Node dikembalikan    : {total_nodes}")
    print(f"Estimasi via graph   : {graph_tok:,.0f} token (result_chars/4)")
    if avg_file_chars:
        print(f"Estimasi baca file   : {perfile_tok:,.0f} token "
              f"({total_nodes} node x rata2 {avg_file_chars/4:,.0f} tok/file)")
        print(f"Estimasi baca repo   : {whole_tok:,.0f} token ({n_files} file kode)")
        if perfile_tok > 0:
            print(f"Hemat vs baca file   : {100*(1-graph_tok/perfile_tok):.1f}%")
        if whole_tok > 0:
            print(f"Hemat vs baca repo   : {100*(1-graph_tok/whole_tok):.1f}%")
    print("-" * 62)
    print(f"{'waktu':<21}{'kind':<8}{'node':>5}{'~tok':>9}  pertanyaan")
    for r in rows[-25:]:
        tok = (r.get("result_chars") or 0) / 4
        q = (r.get("question") or "")[:44]
        ts = (r.get("ts") or "")[:19].replace("T", " ")
        print(f"{ts:<21}{r.get('kind','?'):<8}{r.get('nodes_returned') or 0:>5}{tok:>9,.0f}  {q}")
    print("=" * 62)
    print("Saat saklar OFF log tidak bertambah; bandingkan meterai token")
    print("di UI ZCode untuk tugas serupa guna melihat selisihnya.")


if __name__ == "__main__":
    main()
