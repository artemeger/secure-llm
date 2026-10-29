#!/bin/sh
# uv — static musl binary from GitHub releases. Idempotent, arch-aware.
# (The astral install.sh lands in $HOME/.local/bin and is not visible to the
# non-root runtime user, so we install the release binary directly instead.)
set -eu
VERSION=0.13.6
command -v uv >/dev/null 2>&1 && { echo "uv already installed: $(uv --version)"; exit 0; }
case "$(dpkg --print-architecture)" in
  amd64) ARCH=x86_64  ;;
  arm64) ARCH=aarch64 ;;
  *) echo "unsupported architecture: $(dpkg --print-architecture)" >&2; exit 1 ;;
esac
DIR="uv-${ARCH}-unknown-linux-musl"
TARBALL="${DIR}.tar.gz"
curl -fsSL "https://github.com/astral-sh/uv/releases/download/${VERSION}/${TARBALL}" -o "/tmp/${TARBALL}"
tar -xzf "/tmp/${TARBALL}" -C /tmp
install -m 0755 "/tmp/${DIR}/uv"  /usr/local/bin/uv
install -m 0755 "/tmp/${DIR}/uvx" /usr/local/bin/uvx
rm -rf "/tmp/${DIR}" "/tmp/${TARBALL}"
uv --version
