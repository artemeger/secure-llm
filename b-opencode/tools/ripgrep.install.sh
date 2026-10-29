#!/bin/sh
# ripgrep — static musl binary from GitHub releases. Idempotent, arch-aware.
set -eu
VERSION=15.2.0
command -v rg >/dev/null 2>&1 && { echo "ripgrep already installed: $(rg --version | head -1)"; exit 0; }
case "$(dpkg --print-architecture)" in
  amd64) ARCH=x86_64  ;;
  arm64) ARCH=aarch64 ;;
  *) echo "unsupported architecture: $(dpkg --print-architecture)" >&2; exit 1 ;;
esac
DIR="ripgrep-${VERSION}-${ARCH}-unknown-linux-musl"
TARBALL="${DIR}.tar.gz"
curl -fsSL "https://github.com/BurntSushi/ripgrep/releases/download/${VERSION}/${TARBALL}" -o "/tmp/${TARBALL}"
tar -xzf "/tmp/${TARBALL}" -C /tmp
install -m 0755 "/tmp/${DIR}/rg" /usr/local/bin/rg
rm -rf "/tmp/${DIR}" "/tmp/${TARBALL}"
rg --version | head -1
