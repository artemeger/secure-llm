#!/usr/bin/env python3
"""Minimal OpenAI-compatible stub used to test the full chain WITHOUT vLLM/GPU.

Serves on :8000 (vLLM's port, so a-vllm/nginx.conf works unmodified):
  GET  /health                -> 200 ok
  GET  /v1/models             -> canned list containing the real model id
  POST /v1/chat/completions   -> canned completion; supports stream:true (SSE)

Stdlib only. Run as a throwaway container on the A-side backend network with
the alias `vllm` — see README.md ("Testing without a GPU").
"""
import json
from http.server import BaseHTTPRequestHandler, HTTPServer

MODEL_ID = "bottlecapai/ThinkingCap-Qwen3.8-27B-NVFP4"


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):  # keep test output quiet
        print("[mock-vllm]", fmt % args, flush=True)

    def _send(self, code, body, ctype="application/json"):
        data = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path.startswith("/health"):
            self._send(200, "ok", "text/plain")
        elif self.path.startswith("/v1/models"):
            body = json.dumps(
                {
                    "object": "list",
                    "data": [
                        {"id": MODEL_ID, "object": "model", "owned_by": "local"}
                    ],
                }
            )
            self._send(200, body)
        else:
            self._send(404, json.dumps({"error": {"message": "not found"}}))

    def do_POST(self):
        if not self.path.startswith("/v1/chat/completions"):
            self._send(404, json.dumps({"error": {"message": "not found"}}))
            return
        n = int(self.headers.get("Content-Length", 0))
        try:
            req = json.loads(self.rfile.read(n) or b"{}")
        except json.JSONDecodeError:
            self._send(400, json.dumps({"error": {"message": "bad json"}}))
            return
        if req.get("stream"):
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.end_headers()
            for tok in ("mock", "-", "ok"):
                chunk = {
                    "id": "mock-1",
                    "object": "chat.completion.chunk",
                    "model": MODEL_ID,
                    "choices": [
                        {"index": 0, "delta": {"content": tok}, "finish_reason": None}
                    ],
                }
                self.wfile.write(f"data: {json.dumps(chunk)}\n\n".encode())
            self.wfile.write(b"data: [DONE]\n\n")
        else:
            body = json.dumps(
                {
                    "id": "mock-1",
                    "object": "chat.completion",
                    "model": MODEL_ID,
                    "choices": [
                        {
                            "index": 0,
                            "message": {"role": "assistant", "content": "mock-ok"},
                            "finish_reason": "stop",
                        }
                    ],
                }
            )
            self._send(200, body)


if __name__ == "__main__":
    print(f"mock vllm listening on :8000 (model={MODEL_ID})", flush=True)
    HTTPServer(("0.0.0.0", 8000), Handler).serve_forever()
