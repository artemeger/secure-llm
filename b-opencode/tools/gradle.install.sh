#!/bin/sh
# gradle — distribution zip from services.gradle.org. Idempotent.
# Requires a JDK: bootstraps java.install.sh if missing (TOOLS order irrelevant).
set -eu
GRADLE_VERSION="${GRADLE_VERSION:-9.8.2}"
command -v gradle >/dev/null 2>&1 && { echo "gradle already installed: $(gradle --version 2>/dev/null | grep '^Gradle' | head -1)"; exit 0; }
command -v java >/dev/null 2>&1 || sh /opt/tools/java.install.sh
if [ ! -d "/opt/gradle/gradle-${GRADLE_VERSION}" ]; then
  curl -fsSL "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" -o /tmp/gradle.zip
  unzip -q /tmp/gradle.zip -d /opt/gradle
  rm -f /tmp/gradle.zip
fi
ln -sfn "/opt/gradle/gradle-${GRADLE_VERSION}/bin/gradle" /usr/local/bin/gradle
gradle --version 2>/dev/null | grep '^Gradle' | head -1
