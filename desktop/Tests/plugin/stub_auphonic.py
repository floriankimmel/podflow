"""Minimal Auphonic API stub for script tests. Usage: stub_auphonic.py <port> <log-file>"""
import json
import sys
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT, LOG = int(sys.argv[1]), sys.argv[2]
state = {"status": 0, "polls": 0, "metadata": {}, "published": False}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _send(self, code, payload, raw=False):
        body = payload.encode() if raw else json.dumps({"data": payload}).encode()
        self.send_response(code)
        self.end_headers()
        self.wfile.write(body)

    def _record(self, body):
        with open(LOG, "a") as fh:
            fh.write(json.dumps({"method": self.command, "path": self.path,
                                 "auth": self.headers.get("Authorization", ""),
                                 "key": self.headers.get("X-Workspace-Key", ""), "body": body}) + "\n")

    def _details(self):
        files = [{"format": "mp3", "ending": "mp3", "download_url": f"http://127.0.0.1:{PORT}/dl/a.mp3"},
                 {"format": "transcript", "ending": "txt", "download_url": f"http://127.0.0.1:{PORT}/dl/t.txt"}]
        services = [{"type": "youtube", "result_urls": ["https://www.youtube.com/watch?v=abc123"]}] if state["published"] else []
        return {"uuid": "UUID1", "status": state["status"],
                "status_string": {0: "File Upload", 3: "Done", 4: "Audio Processing"}.get(state["status"], "?"),
                "error_message": "", "output_files": files, "outgoing_services": services,
                "metadata": state["metadata"]}

    def do_GET(self):
        self._record("")
        if self.path.startswith("/dl/t.txt"):
            return self._send(200, "Hallo und willkommen zur Folge.\n", raw=True)
        if self.path == "/api/production/UUID1.json":
            if state["status"] == 4:
                state["polls"] += 1
                if state["polls"] >= 2:
                    state["status"] = 3
            return self._send(200, self._details())
        self._send(404, {})

    def do_POST(self):
        raw = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        is_json = "json" in self.headers.get("Content-Type", "")
        body = json.loads(raw) if is_json and raw else f"<{len(raw)} bytes>"
        self._record(body)
        if self.headers.get("Authorization", "") == "bearer bad":
            return self._send(401, {})
        if self.path == "/api/productions.json":
            return self._send(200, {"uuid": "UUID1"})
        if self.path == "/api/production/UUID1/upload.json":
            if b"slow" in raw:
                time.sleep(3)
            return self._send(200, {"uuid": "UUID1"})
        if self.path == "/api/production/UUID1/start.json":
            state["status"], state["polls"] = 4, 0
            return self._send(200, self._details())
        if self.path == "/api/production/UUID1.json":
            state["metadata"] = body.get("metadata", {})
            return self._send(200, self._details())
        if self.path == "/api/production/UUID1/publish.json":
            state["published"] = True
            return self._send(200, self._details())
        self._send(404, {})


HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
