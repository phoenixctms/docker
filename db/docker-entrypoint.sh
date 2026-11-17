#!/bin/bash
# Compose only sets PHOENIX_POSTGRES_*. The stock Postgres image reads POSTGRES_*
# from this process, so copy them here and nowhere else.
set -euo pipefail

: "${PHOENIX_POSTGRES_DB:=ctsms}"
: "${PHOENIX_POSTGRES_USER:=ctsms}"
: "${PHOENIX_POSTGRES_PASSWORD:=ctsms}"

export POSTGRES_DB="$PHOENIX_POSTGRES_DB"
export POSTGRES_USER="$PHOENIX_POSTGRES_USER"
export POSTGRES_PASSWORD="$PHOENIX_POSTGRES_PASSWORD"

exec docker-entrypoint.sh "$@"
