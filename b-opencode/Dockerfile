# Minimal OpenCode image for the secure offline workflow.
#
# - Internet is used ONLY at build time. The running container is air-gapped:
#   internal-only docker network, no published ports, and its only route out
#   is the nginx gateway (fixed upstream = Machine A).
# - Toolchain: tools/*.install.sh run at build time, selected by the TOOLS
#   build arg (fed from .env via compose.yaml). See tools/README.md.
# - Non-root `coder` user (uid 1000), pattern from glennvdv/opencode-dockerized.
#   We deliberately do NOT use that repo's wrapper: its docker-socket + host-
#   network defaults are security-hostile for this setup.

FROM node:22-bookworm-slim

# Pin when updating the image (npm view @opencode/cli version)
ARG OPENCODE_VERSION=2.2.1
# Space-separated list of tools/<name>.install.sh to run at build time.
# JVM toolchain example: TOOLS="git ripgrep fd jq java gradle maven"
ARG TOOLS="git ripgrep fd ast-grep jq"
# Expose the pin to tool scripts (node.install.sh reinstalls OpenCode on upgrade)
ENV OPENCODE_VERSION=${OPENCODE_VERSION}

# Base utilities only; tool scripts install the rest themselves.
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl tini unzip \
 && rm -rf /var/lib/apt/lists/*

# OpenCode V2 CLI (pinned)
RUN npm install -g "@opencode/cli@${OPENCODE_VERSION}" \
 && npm cache clean --force

# Build-time toolchain (each script follows tools/README.md conventions)
COPY tools/ /opt/tools/
RUN for t in ${TOOLS}; do echo ">> installing tool: $t"; sh "/opt/tools/${t}.install.sh"; done
# /opt/tools stays in the image: inert text, auditable.

# Non-root user. The node base image ships a uid-1000 `node` user and WSL2
# maps the Windows user to uid 1000, so rename that account to `coder`
# (uid/gid stay 1000) and files in the mounted workspace stay host-owned.
# If your host user has a different uid/gid, change them here.
RUN groupmod -n coder node \
 && usermod -l coder node \
 && usermod -d /home/coder -m -s /bin/bash coder \
 && mkdir -p /home/coder/.config/opencode \
             /home/coder/.local/share/opencode \
             /home/coder/.local/state/opencode \
             /home/coder/.cache/opencode \
             /workspace \
 && chown -R coder:coder /home/coder /workspace

USER coder
WORKDIR /workspace
ENTRYPOINT ["tini", "-g", "--"]
CMD ["opencode"]
