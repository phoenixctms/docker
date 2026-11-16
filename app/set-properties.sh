#!/bin/bash
set -euo pipefail

: "${DEFAULT_LOCALE:=en}"
: "${DBSERVER:=db}"
: "${DBPORT:=5432}"
: "${DBUSER:=ctsms}"
: "${DBNAME:=ctsms}"
: "${DBPASS:=ctsms}"

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
  upsert_prop "$prop" "database_username" "$DBUSER"
  upsert_prop "$prop" "database_password" "$DBPASS"
  upsert_prop "$prop" "database_connection_url" "jdbc:postgresql://${DBSERVER}:${DBPORT}/${DBNAME}"
  upsert_prop "$prop" "default_locale" "$DEFAULT_LOCALE"
done
