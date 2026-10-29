#!/bin/sh
# node — the base image ships Node 22 (required by OpenCode), so this script
# is a no-op by default. Set NODE_VERSION (a major, e.g. 20) to install a
# different major via nodesource; OpenCode's npm global is reinstalled
# against the new node.
set -eu
if [ -z "${NODE_VERSION:-}" ]; then
  echo "node already provided by base image: $(node --version)"
  exit 0
fi
CUR="$(node -p 'process.versions.node.split(".")[0]')"
if [ "$CUR" = "$NODE_VERSION" ]; then
  echo "node major ${NODE_VERSION} already installed: $(node --version)"
  exit 0
fi
curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | bash -
apt-get install -y --no-install-recommends nodejs
rm -rf /var/lib/apt/lists/*
# Reinstall the pinned OpenCode CLI against the new node
npm install -g "@opencode/cli@${OPENCODE_VERSION:-latest}"
node --version
