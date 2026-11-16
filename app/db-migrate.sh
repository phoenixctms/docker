#!/bin/bash
set -euo pipefail

: "${DBSERVER:=db}"
: "${DBPORT:=5432}"
: "${DBUSER:=ctsms}"
: "${DBNAME:=ctsms}"
: "${DBPASS:=ctsms}"

export PGPASSWORD="$DBPASS"

echo "Waiting for PostgreSQL at ${DBSERVER}:${DBPORT}..."
for i in $(seq 1 60); do
  if pg_isready -h "$DBSERVER" -p "$DBPORT" -U "$DBUSER" -d "$DBNAME" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
pg_isready -h "$DBSERVER" -p "$DBPORT" -U "$DBUSER" -d "$DBNAME"

echo "Checking whether schema is already present..."
EXISTS="$(psql -h "$DBSERVER" -p "$DBPORT" -U "$DBUSER" -d "$DBNAME" -Atc \
  "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name='users';")"

if [ "$EXISTS" != "0" ]; then
  echo "Schema already present (users table found); skipping migrate."
  exit 0
fi

echo "Applying schema-create.sql..."
psql -h "$DBSERVER" -p "$DBPORT" -U "$DBUSER" -d "$DBNAME" -v ON_ERROR_STOP=1 -f /ctsms/db/schema-create.sql
echo "Applying index-create.sql..."
psql -h "$DBSERVER" -p "$DBPORT" -U "$DBUSER" -d "$DBNAME" -v ON_ERROR_STOP=1 -f /ctsms/db/index-create.sql
echo "Applying schema-set-version.sql..."
psql -h "$DBSERVER" -p "$DBPORT" -U "$DBUSER" -d "$DBNAME" -v ON_ERROR_STOP=1 -f /ctsms/db/schema-set-version.sql

# Optional SQL from config-default install/sql
if [ -d /ctsms/install/sql ]; then
  for sql in /ctsms/install/sql/*.sql; do
    if [ -f "$sql" ]; then
      echo "Applying $sql ..."
      psql -h "$DBSERVER" -p "$DBPORT" -U "$DBUSER" -d "$DBNAME" -v ON_ERROR_STOP=1 -f "$sql"
    fi
  done
fi

echo "Database schema migration finished."
