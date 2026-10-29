#!/bin/sh
# fd (fd-find) — static musl binary from GitHub releases. Idempotent, arch-aware.
set -eu
VERSION=10.5.0
command -v fd >/dev/null 2>&1 && { echo "fd already installed: $(fd --version)"; exit 0; }
case "$(dpkg --print-architecture)" in
  amd64) ARCH=x86_64  ;;
  arm64) ARCH=aarch64 ;;
  *) echo "unsupported architecture: $(dpkg --print-architecture)" >&2; exit 1 ;;
esac
DIR="fd-v${VERSION}-${ARCH}-unknown-linux-musl"
TARBALL="${DIR}.tar.gz"
curl -fsSL "https://github.com/sharkdp/fd/releases/download/v${VERSION}/${TARBALL}" -o "/tmp/${TARBALL}"
tar -xzf "/tmp/${TARBALL}" -C /tmp
install -m 0755 "/tmp/${DIR}/fd" /usr/local/bin/fd
rm -rf "/tmp/${DIR}" "/tmp/${TARBALL}"
fd --version
