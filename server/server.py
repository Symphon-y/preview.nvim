#!/usr/bin/env python3
"""HTTP preview server for preview-md-nvim."""

import argparse
import os
import threading
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

_lock = threading.Lock()
_watched_file = ""
_last_modified = 0.0

_HTML_PAGE = """\
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Preview</title>
  <link rel="stylesheet"
    href="https://cdnjs.cloudflare.com/ajax/libs/github-markdown-css/5.5.1/github-markdown-dark.min.css">
  <style>
    * { box-sizing: border-box; }
    html, body { margin: 0; padding: 0; background: #0d1117; }
    .markdown-body {
      max-width: 980px;
      margin: 0 auto;
      padding: 45px;
    }
    @media (max-width: 767px) { .markdown-body { padding: 15px; } }
  </style>
</head>
<body>
  <article class="markdown-body" id="content"></article>
  <script src="https://cdn.jsdelivr.net/npm/marked@9/marked.min.js"></script>
  <script>
    marked.use({ gfm: true, breaks: false });

    async function load() {
      const res = await fetch('/content');
      if (!res.ok) return;
      const text = await res.text();
      const fileType = res.headers.get('X-File-Type');
      const fileName = res.headers.get('X-File-Name') || 'Preview';
      document.title = fileName;
      if (fileType === 'html') {
        document.getElementById('content').innerHTML = text;
      } else {
        document.getElementById('content').innerHTML = marked.parse(text);
      }
    }

    const es = new EventSource('/events');
    es.onmessage = (e) => { if (e.data === 'reload') load(); };
    es.onerror = () => {};

    load();
  </script>
</body>
</html>
"""


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)
        p = parsed.path

        if p == "/":
            self._send(200, _HTML_PAGE.encode(), "text/html; charset=utf-8")
        elif p == "/content":
            self._serve_content()
        elif p == "/events":
            self._serve_sse()
        elif p == "/switch":
            qs = parse_qs(parsed.query)
            new_file = qs.get("file", [""])[0]
            if new_file:
                _set_file(new_file)
            self._send(200, b"ok", "text/plain")
        else:
            self._send(404, b"not found", "text/plain")

    def _serve_content(self):
        with _lock:
            f = _watched_file
        if not f:
            self._send(404, b"no file set", "text/plain")
            return
        try:
            data = Path(f).read_bytes()
        except OSError as e:
            self._send(500, str(e).encode(), "text/plain")
            return

        ext = Path(f).suffix.lower()
        is_html = ext in (".html", ".htm")
        ct = "text/html; charset=utf-8" if is_html else "text/plain; charset=utf-8"

        self.send_response(200)
        self.send_header("Content-Type", ct)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("X-File-Type", "html" if is_html else "md")
        self.send_header("X-File-Name", Path(f).name)
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(data)

    def _serve_sse(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "keep-alive")
        self.end_headers()

        last = _last_modified
        try:
            self.wfile.write(b": ping\n\n")
            self.wfile.flush()
            while True:
                cur = _last_modified
                if cur != last:
                    last = cur
                    self.wfile.write(b"data: reload\n\n")
                    self.wfile.flush()
                time.sleep(0.15)
        except (BrokenPipeError, ConnectionResetError, OSError):
            pass

    def _send(self, code, body, ct):
        self.send_response(code)
        self.send_header("Content-Type", ct)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_):
        pass


def _set_file(path):
    global _watched_file, _last_modified
    with _lock:
        _watched_file = path
        _last_modified = time.time()


def _watch_loop():
    global _last_modified
    prev_mtime = 0.0
    prev_file = ""
    while True:
        with _lock:
            f = _watched_file
        if f:
            if f != prev_file:
                prev_file = f
                prev_mtime = 0.0
            try:
                m = os.path.getmtime(f)
                if m != prev_mtime:
                    prev_mtime = m
                    with _lock:
                        _last_modified = m
            except OSError:
                pass
        time.sleep(0.25)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--file", required=True)
    ap.add_argument("--port", type=int, default=0)
    args = ap.parse_args()

    _set_file(args.file)

    srv = HTTPServer(("127.0.0.1", args.port), Handler)
    port = srv.server_address[1]
    print(port, flush=True)  # Lua reads this to know the port

    threading.Thread(target=_watch_loop, daemon=True).start()
    srv.serve_forever()


if __name__ == "__main__":
    main()
