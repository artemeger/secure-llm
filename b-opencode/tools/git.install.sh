#!/bin/sh
# git — apt package. Idempotent.
set -eu
command -v git >/dev/null 2>&1 && { echo "git already installed: $(git --version)"; exit 0; }
apt-get update
apt-get install -y --no-install-recommends git
rm -rf /var/lib/apt/lists/*
git --version
