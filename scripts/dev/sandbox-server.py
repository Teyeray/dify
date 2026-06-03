#!/usr/bin/env python3
"""
Minimal dev sandbox — NOT for production use.

Implements the dify-sandbox HTTP API so the Dify API server can execute
workflow code nodes without Docker.  Code runs directly in the host Python /
Node.js interpreter with NO isolation or resource limits.

Compatible with:  POST /v1/sandbox/run  (dify-sandbox 0.2.x protocol)

Usage:
    python scripts/dev/sandbox-server.py

Environment:
    SANDBOX_PORT     Listening port  (default: 8194)
    SANDBOX_API_KEY  X-Api-Key value (default: dify-sandbox)
"""

import json
import logging
import os
import subprocess
import sys
import tempfile
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT = int(os.environ.get("SANDBOX_PORT", 8194))
API_KEY = os.environ.get("SANDBOX_API_KEY", "dify-sandbox")
TIMEOUT = 30  # seconds per execution

logging.basicConfig(level=logging.INFO, format="[sandbox] %(message)s")
log = logging.getLogger(__name__)


def _run(cmd: list[str], code: str) -> subprocess.CompletedProcess:
    with tempfile.NamedTemporaryFile(
        suffix=cmd[-1] if cmd[-1] in (".py", ".js") else ".py",
        mode="w",
        delete=False,
        encoding="utf-8",
    ) as f:
        f.write(code)
        tmp = f.name
    try:
        return subprocess.run(
            cmd[:-1] + [tmp],
            capture_output=True,
            text=True,
            timeout=TIMEOUT,
        )
    finally:
        os.unlink(tmp)


def _execute(language: str, preload: str, code: str) -> dict:
    """Run code and return a dify-sandbox-compatible response body."""
    full = (preload or "") + "\n" + (code or "")

    try:
        if language == "python3":
            result = _run([sys.executable, ".py"], full)
        elif language == "nodejs":
            result = _run(["node", ".js"], full)
        else:
            return {
                "code": 1,
                "message": f"unsupported language: {language}",
                "data": {"stdout": None, "error": None},
            }
    except subprocess.TimeoutExpired:
        return {
            "code": 0,
            "message": "success",
            "data": {"stdout": None, "error": f"execution timed out after {TIMEOUT}s"},
        }
    except FileNotFoundError as exc:
        return {
            "code": 0,
            "message": "success",
            "data": {"stdout": None, "error": f"runtime not found: {exc}"},
        }

    if result.returncode != 0:
        return {
            "code": 0,
            "message": "success",
            "data": {"stdout": result.stdout or None, "error": result.stderr or "non-zero exit"},
        }
    return {
        "code": 0,
        "message": "success",
        "data": {"stdout": result.stdout, "error": None},
    }


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass  # silence default per-request logging

    def _send_json(self, status: int, body: dict):
        payload = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):
        if self.path in ("/health", "/"):
            self._send_json(200, {"code": 0, "message": "ok"})
        else:
            self._send_json(404, {"code": 404, "message": "not found"})

    def do_POST(self):
        if self.path != "/v1/sandbox/run":
            self._send_json(404, {"code": 404, "message": "not found", "data": {}})
            return

        if self.headers.get("X-Api-Key") != API_KEY:
            self._send_json(403, {"code": 403, "message": "forbidden", "data": {}})
            return

        length = int(self.headers.get("Content-Length", 0))
        try:
            body = json.loads(self.rfile.read(length))
        except Exception:
            self._send_json(400, {"code": 400, "message": "bad request", "data": {}})
            return

        language = body.get("language", "python3")
        preload = body.get("preload", "")
        code = body.get("code", "")

        log.info("run  language=%s  code_len=%d", language, len(code or ""))
        response = _execute(language, preload, code)
        log.info(
            "done error=%s",
            bool(response.get("data", {}).get("error")),
        )
        self._send_json(200, response)


if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", PORT), Handler)
    log.info("listening on :%d  key=%s  ⚠️  no isolation — dev only", PORT, API_KEY)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        log.info("stopped")
