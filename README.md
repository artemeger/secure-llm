# secure-llm — two-machine offline LLM workflow

- **Machine A (GPU box, Linux)** — vLLM serving
  `bottlecapai/ThinkingCap-Qwen3.8-27B-NVFP4` behind an nginx gateway.
  The vLLM container has **no network at all** (internal-only Docker network,
  no published ports, no NAT, `HF_HUB_OFFLINE=1`).
- **Machine B (Windows 11 + WSL2, Docker Engine in the distro)** — OpenCode in
  a container that sees exactly **one host directory** (`workspace/`) plus a
  read-only `opencode.json`. Air-gapped at runtime; reaches the model only via
  its own hardened nginx gateway whose single fixed destination is Machine A.

```
Machine A (A_IP)                                  Machine B (WSL2)
┌────────────────────────────────────┐            ┌──────────────────────────────────────┐
│  vllm  (vllm/vllm-openai:v0.29.0) │            │  opencode (custom minimal image)     │
│   • net: backend (internal only)   │            │   • net: agent (internal only)       │
│   • command from ./vllm-cmd.sh     │  LAN       │   • mounts: ./workspace (rw),       │
│   • gpus all, ipc host, shm 32g   │◄──────────►│     ./opencode.json (ro)            │
│  nginx :1234 → vllm:8000           │            │  gateway (nginx, hardened, ro-root) │
│   published on A_IP:1234 only      │            │   • fixed upstream A_IP:1234        │
└────────────────────────────────────┘            └──────────────────────────────────────┘
```

Request path: `opencode → http://gateway:8080/v1` (internal L2) → gateway nginx
→ `A_IP:1234` → A's nginx → `vllm:8000` (internal L2).

## Security properties

| Property | Enforced by |
|---|---|
| vLLM has zero egress | kernel: `internal: true` network (no default route, no NAT) |
| vLLM never contacts HuggingFace | `HF_HUB_OFFLINE=1` |
| OpenCode cannot reach LAN/internet/host | kernel: internal network, no published ports |
| OpenCode sees no host files except `workspace/` + `opencode.json` (ro) | compose volume list |
| Gateway only ever connects to `A_IP:1234` | reverse proxy with a single fixed `proxy_pass` |
| Compromised gateway degrades to a useless process | non-root, `cap_drop ALL`, `no-new-privileges`, read-only rootfs, `nginx:alpine` |
| Other apps on both machines unaffected | **no host firewall rules, no host services, no global NAT/routing changes anywhere** |

Accepted residuals (documented, not mitigated in this setup):

- A *compromised gateway process* could still open outbound sockets (its
  netns has a default route). Stronger option: run the B-side stack in a small
  Hyper-V Linux VM with its own firewall.
- `A_IP:1234` is LAN-reachable — no API key by design (LAN trust). Optional:
  `ufw allow from <your-subnet> to any port 1234` on Machine A.
- `workspace/` is fully read-write by definition — mount only the project.
- Docker isolation is not a sandbox against kernel/container-escape 0-days.

## Repository layout

```
vllm/        Machine A stack (compose, vllm-cmd.sh, nginx.conf, .env.example)
opencode/    Machine B stack (Dockerfile, compose, gateway.conf, opencode.json,
               tools/ build-time toolchain, workspace/)
test/          mock-vllm.py — OpenAI stub for no-GPU testing
```

## Setup — Machine A

1. Prereqs: docker compose v2, nvidia-container-toolkit. Smoke test:
   `docker run --rm --gpus all nvidia/cuda:12.8.0-base-ubuntu22.04 nvidia-smi`
2. **Pre-download the model** (the container is offline and can never fetch it):
   ```sh
   hf download bottlecapai/ThinkingCap-Qwen3.8-27B-NVFP4
   # lands in ~/.cache/huggingface — the directory compose mounts
   ```
3. `cd vllm && cp .env.example .env` → set `A_LAN_IP` (and `HF_TOKEN` only
   if the repo is gated).
4. `docker compose up -d` → wait for `vllm` to become `healthy`
   (minutes; MTP warmup). `docker compose ps`

The full vLLM command lives in **`vllm/vllm-cmd.sh` only**. Swap model or
flags: edit that file, `docker compose restart vllm`. Swap the image:
`VLLM_IMAGE=` in `.env`.

## Setup — Machine B

1. `cd opencode && cp .env.example .env` → set `A_LAN_IP` and `TOOLS`,
   then **sync the literal IP in `gateway.conf`**.
2. Put your project files in `workspace/`.
3. `docker compose up -d --build` (internet once, for the build).
4. Use it: `docker compose exec opencode opencode` → model picker →
   `local-vllm / ThinkingCap Qwen3.8 27B (NVFP4)`.

Toolchain: `TOOLS` in `.env` selects which `tools/*.install.sh` run at build
time (conventions in `tools/README.md`). JVM preset:
`TOOLS=git ripgrep fd jq java gradle maven`. Change it → `docker compose build`.

## GPU bring-up checklist (on the real GPU box)

Not testable without a GPU. Once the box is up:

1. `docker compose up -d` in `vllm/`; `docker compose logs -f vllm` —
   expect engine init, `Uvicorn running on http://0.0.0.0:8000`, then
   `healthy` in `docker compose ps`.
2. `curl -s http://<A_IP>:1234/v1/models` → lists the model.
3. On B: `docker compose exec opencode opencode` → real chat streams tokens
   (exercises the MTP speculative config + qwen3 parsers).

Troubleshooting:

| symptom | fix |
|---|---|
| OOM at engine init | lower `--gpu-memory-utilization` / `--max-num-seqs` in `vllm-cmd.sh` |
| MTP / speculative error | drop the `--speculative-config` line in `vllm-cmd.sh` |
| model not found | id must equal the `--model` string in `vllm-cmd.sh` AND the key in `opencode/opencode.json` |
| 502 from B's gateway | A down / model not loaded yet (`docker compose ps` on A) |

## Testing without a GPU (mock upstream)

Proves the entire chain minus the model, on a machine with docker (no GPU).
The A-side steps build the compose topology by hand so the multi-GB vLLM
image is never pulled (`docker compose up` would pull it even with
`--no-start`).

```sh
# 1. A side: project networks + mock upstream (alias nginx expects) + nginx
docker network create --internal secure-llm-vllm-backend
docker network create secure-llm-vllm-frontend
docker run -d --name vllm-mock --network secure-llm-vllm-backend \
  --network-alias vllm -v "$PWD/test/mock-vllm.py":/mock.py:ro \
  python:3.12-slim python /mock.py
docker run -d --name secure-llm-vllm-nginx --network secure-llm-vllm-frontend \
  --network secure-llm-vllm-backend -p 127.0.0.1:1234:1234 \
  -v "$PWD/vllm/nginx.conf:/etc/nginx/conf.d/default.conf:ro" nginx:stable

curl -s http://127.0.0.1:1234/v1/models    # canned model list
curl -sN -X POST http://127.0.0.1:1234/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"bottlecapai/ThinkingCap-Qwen3.8-27B-NVFP4","stream":true,"messages":[{"role":"user","content":"hi"}]}'
# → SSE chunks + [DONE]

# 2. B side: for the cross-container chain the gateway reaches A via the
#    docker host's bridge IP — 127.0.0.1 inside the gateway is its own
#    loopback. Find it:
#      docker network inspect bridge --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}'
#    (typically 172.17.0.1). Test-only: publish A's nginx on 0.0.0.0.
BRIDGE_IP=172.17.0.1
docker rm -f secure-llm-vllm-nginx
docker run -d --name secure-llm-vllm-nginx --network secure-llm-vllm-frontend \
  --network secure-llm-vllm-backend -p 0.0.0.0:1234:1234 \
  -v "$PWD/vllm/nginx.conf:/etc/nginx/conf.d/default.conf:ro" nginx:stable
sed -i "s|proxy_pass http://192.168.1.10:1234;|proxy_pass http://${BRIDGE_IP}:1234;|" opencode/gateway.conf
cd opencode && docker compose up -d --build
docker compose up -d --force-recreate gateway    # pick up the edited conf
docker compose exec opencode curl -s http://gateway:8080/v1/models    # canned list (full chain)
docker compose exec opencode curl -m 3 http://1.1.1.1 || echo "air-gapped: ok"
docker compose exec opencode getent hosts example.com || echo "air-gapped: ok (no DNS)"

# 3. cleanup (restores the shipped gateway.conf)
cd .. && docker rm -f vllm-mock secure-llm-vllm-nginx
docker network rm secure-llm-vllm-backend secure-llm-vllm-frontend
(cd opencode && docker compose down && git checkout -- gateway.conf)
```

Also verify statically at any time: `docker compose config` (both projects),
`sh -n` on all `tools/*.install.sh`, and `nginx -t` for both configs in a
one-off `nginx` container (A's conf needs `--add-host vllm:127.0.0.1` to
satisfy config-time name resolution).

## Host-impact statement

- **Machine A:** one published port (`A_IP:1234`), GPU occupied while running,
  model files in `~/.cache/huggingface` (one-time), docker objects removed by
  `docker compose down`. No firewall rules added.
- **Machine B:** nothing exposed (TUI via `docker exec` only), disk files and
  the built image. One-time build needs internet. No firewall rules added.
