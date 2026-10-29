#!/bin/sh
# maven — binary tarball from archive.apache.org. Idempotent.
# Stable 3.9.x line pinned (Maven 4 is still RC upstream). Requires a JDK:
# bootstraps java.install.sh if missing (TOOLS order irrelevant).
set -eu
MAVEN_VERSION="${MAVEN_VERSION:-3.9.16}"
command -v mvn >/dev/null 2>&1 && { echo "maven already installed: $(mvn --version 2>/dev/null | head -1)"; exit 0; }
command -v java >/dev/null 2>&1 || sh /opt/tools/java.install.sh
if [ ! -d "/opt/apache-maven-${MAVEN_VERSION}" ]; then
  curl -fsSL "https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" -o /tmp/maven.tar.gz
  tar -xzf /tmp/maven.tar.gz -C /opt
  rm -f /tmp/maven.tar.gz
fi
ln -sfn "/opt/apache-maven-${MAVEN_VERSION}/bin/mvn" /usr/local/bin/mvn
mvn --version 2>/dev/null | head -1
