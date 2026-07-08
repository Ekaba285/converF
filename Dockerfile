# syntax=docker/dockerfile:1
# wrapper：复用官方镜像的二进制，前面加一层把 short-id 改成单引号（'0e69'），
# clash-verge 和 OpenClash 都认。
FROM metacubex/subconverter:latest

RUN apk add --no-cache python3

COPY <<'PY' /sid_fix.py
import re, urllib.request, urllib.error
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

UPSTREAM = "http://127.0.0.1:25500"
LISTEN   = 25501

SID_RE = re.compile(rb"(short-id:[ \t]*)([0-9A-Fa-f]+)([ \t]*[,}\r\n])")
HOP = {"content-length", "transfer-encoding", "connection", "keep-alive"}

class H(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    def go(self):
        req = urllib.request.Request(UPSTREAM + self.path, method="GET")
        for k, v in self.headers.items():
            if k.lower() not in ("host", "content-length", "connection", "accept-encoding"):
                req.add_header(k, v)
        try:
            r = urllib.request.urlopen(req, timeout=120)
            status, headers, body = r.status, r.headers, r.read()
        except urllib.error.HTTPError as e:
            status, headers, body = e.code, e.headers, e.read()
        except Exception as e:
            self.send_response(502); self.end_headers(); self.wfile.write(str(e).encode()); return
        body = SID_RE.sub(rb"\1'\2'\3", body)
        self.send_response(status)
        for k, v in headers.items():
            if k.lower() not in HOP:
                self.send_header(k, v)
        self.send_header("Content-Length", str(len(body))); self.end_headers()
        self.wfile.write(body)
    do_GET = do_HEAD = go
    def log_message(self, *a): pass

print(f"[sid-fix] :{LISTEN} -> {UPSTREAM}", flush=True)
ThreadingHTTPServer(("0.0.0.0", LISTEN), H).serve_forever()
PY

COPY <<'SH' /entrypoint.sh
#!/bin/sh
cd /base
subconverter &
exec python3 /sid_fix.py
SH
RUN chmod +x /entrypoint.sh

EXPOSE 25501
ENTRYPOINT ["/entrypoint.sh"]
