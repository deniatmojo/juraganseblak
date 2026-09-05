#!/usr/bin/env python3
"""Viewer graph Graphify realtime.

Usage:
  python tools/graph_live.py            # build awal + watch + buka http://127.0.0.1:8791/live
  python tools/graph_live.py --no-watch # hanya serve graph.html yang ada

Yang dilakukan:
  1. (opsional) menjalankan `graphify . --watch` di background -> graph.json
     dan graph.html otomatis di-build ulang setiap file berubah (AST, 0 API).
  2. Menjalankan HTTP server kecil yang menyajikan graphify-out/ plus halaman
     /live: iframe graph.html yang me-reload otomatis tiap beberapa detik,
     jadi graph di layar ikut ter-update tanpa refresh manual.

Stop: Ctrl+C (watcher graphify ikut berhenti).
"""
import argparse
import subprocess
import sys
import threading
import time
import webbrowser
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "graphify-out"
PORT = 8791

LIVE_PAGE = """<!doctype html>
<html><head><meta charset="utf-8"><title>Graphify Live</title>
<style>
  html,body{margin:0;height:100%;background:#111;color:#eee;font-family:monospace}
  #bar{padding:6px 10px;font-size:13px;display:flex;gap:16px;align-items:center}
  #dot{width:9px;height:9px;border-radius:50%;background:#2ecc71;display:inline-block}
  iframe{border:0;width:100%;height:calc(100% - 30px)}
</style></head>
<body>
<div id="bar"><span id="dot"></span><span>graphify live</span>
<span id="stamp"></span><span style="margin-left:auto">reload tiap 5s</span></div>
<iframe id="f" src="/graph.html"></iframe>
<script>
  const stamp = document.getElementById('stamp');
  function refresh(){
    const f = document.getElementById('f');
    f.src = '/graph.html?' + Date.now();
    stamp.textContent = new Date().toLocaleTimeString();
    setTimeout(refresh, 5000);
  }
  stamp.textContent = new Date().toLocaleTimeString();
  setTimeout(refresh, 5000);
</script>
</body></html>
"""


NO_GRAPH_PAGE = """<!doctype html>
<html><head><meta charset="utf-8"><title>Belum ada graph</title>
<style>body{margin:0;height:100%;display:grid;place-items:center;background:#111;
color:#eee;font-family:monospace;text-align:center;line-height:1.7}</style></head>
<body>
<div>
<h2>graph.html belum ada</h2>
Graph knowledge-base belum pernah dibangun di project ini.<br>
Jalankan dari root project:<br><br>
<code>graphify .</code><br><br>
Halaman ini otomatis berganti ke graph begitu file tersedia.
</div>
</body></html>
"""


class Handler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith("/graph.html") and not (OUT / "graph.html").exists():
            body = NO_GRAPH_PAGE.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        elif self.path.startswith("/live"):
            body = LIVE_PAGE.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            super().do_GET()

    def log_message(self, *a):
        pass


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--no-watch", action="store_true")
    ap.add_argument("--no-open", action="store_true")
    args = ap.parse_args()

    watcher = None
    if not args.no_watch:
        watcher = subprocess.Popen(
            ["graphify", ".", "--watch"],
            cwd=ROOT,
            shell=False,
        )
        print("[live] graphify --watch berjalan di background (rebuild otomatis).")

    srv = ThreadingHTTPServer(("127.0.0.1", PORT), partial(Handler, directory=str(OUT)))
    url = f"http://127.0.0.1:{PORT}/live"
    print(f"[live] viewer: {url}  (Ctrl+C untuk berhenti)")

    def open_browser():
        time.sleep(1.0)
        try:
            webbrowser.open(url)
        except Exception:
            pass

    if not args.no_open:
        threading.Thread(target=open_browser, daemon=True).start()

    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print("\n[live] berhenti.")
    finally:
        srv.server_close()
        if watcher:
            watcher.terminate()
            try:
                watcher.wait(timeout=5)
            except subprocess.TimeoutExpired:
                watcher.kill()


if __name__ == "__main__":
    main()
