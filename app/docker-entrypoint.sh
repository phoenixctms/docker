#!/bin/bash
set -euo pipefail

: "${JAVA_XMS:=512m}"
: "${JAVA_XMX:=1536m}"

/usr/local/bin/set-properties.sh

# Allow heap overrides without rewriting the whole JAVA_OPTS string
export JAVA_OPTS="${JAVA_OPTS:-} -Xms${JAVA_XMS} -Xmx${JAVA_XMX}"

VERSION="$(cat /ctsms/VERSION 2>/dev/null || echo unknown)"
COMMIT="$(cat /ctsms/COMMIT 2>/dev/null || echo unknown)"
echo "Starting Phoenix CTMS ${VERSION} [${COMMIT}]"

exec "$@"
