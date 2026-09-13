#!/usr/bin/env python3
"""LFD web chat — local UI talking to Ollama on :11434."""
from __future__ import annotations

import os
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.dirname(os.path.abspath(__file__))
OLLAMA = os.environ.get("OLLAMA_HOST", "http://127.0.0.1:11434").rstrip("/")
PORT = int(os.environ.get("LFD_WEB_PORT", "7681"))
HOST = os.environ.get("LFD_WEB_HOST", "127.0.0.1")


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args) -> None:
        return

    def do_GET(self) -> None:
        if self.path.startswith("/ollama/") or self.path.startswith("/api/"):
            self.proxy()
            return
        rel = "index.html" if self.path in ("/", "/index.html") else self.path.split("?", 1)[0].lstrip("/")
        fs = os.path.normpath(os.path.join(ROOT, rel))
        if not fs.startswith(ROOT) or not os.path.isfile(fs):
            self.send_error(404)
            return
        ctype = "text/html; charset=utf-8"
        if fs.endswith(".js"):
            ctype = "application/javascript"
        elif fs.endswith(".css"):
            ctype = "text/css"
        with open(fs, "rb") as f:
            body = f.read()
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self) -> None:
        self.proxy()

    def proxy(self) -> None:
        path = self.path
        if path.startswith("/ollama"):
            path = path[7:] or "/"
        url = OLLAMA + path
        length = int(self.headers.get("Content-Length") or 0)
        payload = self.rfile.read(length) if length else None
        req = urllib.request.Request(url, data=payload, method=self.command)
        for h in ("Content-Type", "Accept"):
            if h in self.headers:
                req.add_header(h, self.headers[h])
        try:
            with urllib.request.urlopen(req, timeout=600) as resp:
                data = resp.read()
                self.send_response(resp.status)
                self.send_header("Content-Type", resp.headers.get("Content-Type", "application/json"))
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
        except urllib.error.HTTPError as e:
            body = e.read()
            self.send_response(e.code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        except Exception as e:
            msg = ('{"error":%s}' % (repr(str(e)))).encode()
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(msg)))
            self.end_headers()
            self.wfile.write(msg)


def main() -> None:
    httpd = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"LFD web chat  http://{HOST}:{PORT}  → {OLLAMA}", flush=True)
    httpd.serve_forever()


if __name__ == "__main__":
    main()
