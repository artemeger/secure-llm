#!/bin/sh
# tmux — apt package. Idempotent.
set -eu
command -v tmux >/dev/null 2>&1 && { echo "tmux already installed: $(tmux -V)"; exit 0; }
apt-get update
apt-get install -y --no-install-recommends tmux
rm -rf /var/lib/apt/lists/*
tmux -V
