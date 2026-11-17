#!/bin/bash
set -euo pipefail

: "${PHOENIX_DBSERVER:=db}"
: "${PHOENIX_DBPORT:=5432}"
: "${PHOENIX_DBUSER:=ctsms}"
: "${PHOENIX_DBNAME:=ctsms}"
: "${PHOENIX_DBPASS:=ctsms}"

export PGPASSWORD="$PHOENIX_DBPASS"

echo "Waiting for PostgreSQL at ${PHOENIX_DBSERVER}:${PHOENIX_DBPORT}..."
for i in $(seq 1 60); do
  if pg_isready -h "$PHOENIX_DBSERVER" -p "$PHOENIX_DBPORT" -U "$PHOENIX_DBUSER" -d "$PHOENIX_DBNAME" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
pg_isready -h "$PHOENIX_DBSERVER" -p "$PHOENIX_DBPORT" -U "$PHOENIX_DBUSER" -d "$PHOENIX_DBNAME"

echo "Checking whether schema is already present..."
EXISTS="$(psql -h "$PHOENIX_DBSERVER" -p "$PHOENIX_DBPORT" -U "$PHOENIX_DBUSER" -d "$PHOENIX_DBNAME" -Atc \
  "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name='users';")"

if [ "$EXISTS" != "0" ]; then
  echo "Schema already present (users table found); skipping migrate."
  exit 0
fi

echo "Applying schema-create.sql, index-create.sql, schema-set-version.sql in one transaction..."
psql -h "$PHOENIX_DBSERVER" -p "$PHOENIX_DBPORT" -U "$PHOENIX_DBUSER" -d "$PHOENIX_DBNAME" \
  -v ON_ERROR_STOP=1 --single-transaction \
  -f /ctsms/db/schema-create.sql \
  -f /ctsms/db/index-create.sql \
  -f /ctsms/db/schema-set-version.sql

# Optional SQL from config-default install/sql
if [ -d /ctsms/install/sql ]; then
  for sql in /ctsms/install/sql/*.sql; do
    if [ -f "$sql" ]; then
      echo "Applying $sql ..."
      psql -h "$PHOENIX_DBSERVER" -p "$PHOENIX_DBPORT" -U "$PHOENIX_DBUSER" -d "$PHOENIX_DBNAME" -v ON_ERROR_STOP=1 -f "$sql"
    fi
  done
fi

echo "Database schema migration finished."
