#!/bin/bash
set -euo pipefail

: "${PHOENIX_DEFAULT_LOCALE:=en}"
: "${PHOENIX_DBSERVER:=db}"
: "${PHOENIX_DBPORT:=5432}"
: "${PHOENIX_DBUSER:=ctsms}"
: "${PHOENIX_DBNAME:=ctsms}"
: "${PHOENIX_DBPASS:=ctsms}"

upsert_prop() {
  local file="$1" key="$2" value="$3"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  if grep -qE "^${key}=" "$file" 2>/dev/null; then
    sed -r -i "s|^${key}=.*|${key}=${value}|" "$file"
  else
    echo "${key}=${value}" >> "$file"
  fi
}

for prop in \
  /ctsms/properties/ctsms-applicationcontext.properties \
  /ctsms/properties/ctsms-dbtool.properties
do
  upsert_prop "$prop" "database_username" "$PHOENIX_DBUSER"
  upsert_prop "$prop" "database_password" "$PHOENIX_DBPASS"
  upsert_prop "$prop" "database_connection_url" "jdbc:postgresql://${PHOENIX_DBSERVER}:${PHOENIX_DBPORT}/${PHOENIX_DBNAME}"
  upsert_prop "$prop" "default_locale" "$PHOENIX_DEFAULT_LOCALE"
done
