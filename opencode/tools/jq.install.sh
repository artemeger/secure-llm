#!/bin/sh
# jq — apt package. Idempotent.
set -eu
command -v jq >/dev/null 2>&1 && { echo "jq already installed: $(jq --version)"; exit 0; }
apt-get update
apt-get install -y --no-install-recommends jq
rm -rf /var/lib/apt/lists/*
jq --version
