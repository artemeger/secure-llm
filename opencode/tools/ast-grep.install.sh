#!/bin/sh
# ast-grep — npm global (node ships in the base image). Idempotent.
# NOTE: the debian base image ships a DIFFERENT `sg` (util-linux set-group),
# so detect via the `ast-grep` binary, not `sg`.
set -eu
VERSION=0.51.0
command -v ast-grep >/dev/null 2>&1 && { echo "ast-grep already installed: $(ast-grep --version)"; exit 0; }
npm install -g "@ast-grep/cli@${VERSION}"
ast-grep --version
