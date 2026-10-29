#!/bin/sh
# java — Adoptium (Temurin) JDK via its apt repo. Idempotent.
# Override the LTS line with JAVA_VERSION (17/21/25).
set -eu
JAVA_VERSION="${JAVA_VERSION:-21}"
if command -v java >/dev/null 2>&1 && java -version 2>&1 | grep -q "version \"${JAVA_VERSION}\."; then
  echo "java ${JAVA_VERSION} already installed: $(java -version 2>&1 | head -1)"
  exit 0
fi
CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL "https://packages.adoptium.net/artifactory/api/gpg/key/public" -o /etc/apt/keyrings/adoptium.asc
echo "deb [signed-by=/etc/apt/keyrings/adoptium.asc] https://packages.adoptium.net/artifactory/deb ${CODENAME} main" \
  > /etc/apt/sources.list.d/adoptium.list
apt-get update
apt-get install -y --no-install-recommends "temurin-${JAVA_VERSION}-jdk"
rm -rf /var/lib/apt/lists/*
# Stable JAVA_HOME for subsequent build steps
JAVA_HOME_DIR="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
echo "export JAVA_HOME=${JAVA_HOME_DIR}" > /etc/profile.d/java.sh
java -version 2>&1 | head -1
