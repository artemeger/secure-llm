# Build-time toolchain for the OpenCode image

The tools here are installed **at image build time only** (internet available
then). The running container is air-gapped — nothing installed here can phone
home, and the container has no other route out than the model gateway.

## How it works

- The Dockerfile copies this directory to `/opt/tools/` inside the image.
- The `TOOLS` build arg (set from `opencode/.env`) is a space-separated
  list of tool names; the Dockerfile runs `tools/<name>.install.sh` for each.
- To change the toolset: edit `TOOLS` in `.env`, then `docker compose build`.

Default: `git ripgrep fd ast-grep jq`
JVM preset: `TOOLS=git ripgrep fd jq java gradle maven`

## Script convention (follow this when adding your own tool)

Each `<name>.install.sh`:

1. POSIX `sh`, `set -eu`.
2. Declares a **pinned version** variable at the top (`VERSION=…` or
   `JAVA_VERSION=…` etc.) — never "latest".
3. **Idempotent**: `exit 0` (with a message) when the tool is already present.
4. **Arch-aware** where relevant: `dpkg --print-architecture`
   (`amd64` → `x86_64`, `arm64` → `aarch64`).
5. Installs into standard prefixes on `PATH` (`/usr/local/bin`, npm globals,
   `/opt/…` + symlink). Installs run as root at build time.
6. No daemons, no post-install network use, no runtime state.
7. apt-based scripts do their own `apt-get update … && rm -rf /var/lib/apt/lists/*`.

`gradle`/`maven` depend on a JDK and bootstrap `java.install.sh` themselves,
so tool order in `TOOLS` does not matter.

## Available

| script          | method                                              |
|-----------------|-----------------------------------------------------|
| git             | apt                                                 |
| ripgrep         | static musl binary (GitHub releases, 15.2.0)        |
| fd              | static musl binary (GitHub releases, 10.5.0)        |
| ast-grep        | `npm i -g @ast-grep/cli@0.51.0`                     |
| jq              | apt                                                 |
| uv              | static musl binary (GitHub releases, 0.13.6)        |
| tmux            | apt                                                 |
| node            | base image ships Node 22; no-op unless `NODE_VERSION` major is set (then nodesource install + OpenCode reinstall) |
| java            | Adoptium (Temurin) apt repo, `temurin-21-jdk` default (`JAVA_VERSION`) |
| gradle          | dist zip from services.gradle.org (9.8.2) → `/opt/gradle` |
| maven           | binary tarball from archive.apache.org (3.9.16) → `/opt/maven` |

## Adding a tool

1. Create `tools/foo.install.sh` following the convention (make it `chmod +x`,
   though the Dockerfile invokes it via `sh` so the bit is not required).
2. Append `foo` to `TOOLS` in `.env`.
3. `docker compose build` (in `opencode/`).

An unknown name in `TOOLS` fails the build on purpose — fix the list or add
the script.
