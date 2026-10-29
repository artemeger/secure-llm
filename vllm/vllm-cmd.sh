#!/usr/bin/env bash
# Full vLLM launch command. This file is the ONLY place the command lives.
#
#   change model/flags  -> edit here, then:  docker compose restart vllm
#   change image tag    -> VLLM_IMAGE in .env (never edit compose)
set -euo pipefail
exec vllm serve \
  --model bottlecapai/ThinkingCap-Qwen3.8-27B-NVFP4 \
  --kv-cache-dtype fp8 \
  --max-model-len 180000 \
  --max-num-seqs 3 \
  --gpu-memory-utilization 0.94 \
  --reasoning-parser qwen3 \
  --enable-auto-tool-choice \
  --tool-call-parser qwen3_xml \
  --default-chat-template-kwargs '{"reasoning_effort": "xhigh"}' \
  --speculative-config '{"method": "mtp", "num_speculative_tokens": 3, "draft_sample_method": "probabilistic"}' \
  --host 0.0.0.0 \
  --port 8000
