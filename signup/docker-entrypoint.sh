#!/bin/bash
set -euo pipefail

: "${PHOENIX_REDIS_HOST:=redis}"
: "${PHOENIX_REDIS_PORT:=6379}"
: "${PHOENIX_APP_HTTP:=http://ctsms:8080}"
: "${PHOENIX_PUBLIC_URL:=http://localhost:8888}"

PHOENIX_APP_HTTP="${PHOENIX_APP_HTTP%/}"
SIGNUP_DIR=/ctsms/bulk_processor/CTSMS/BulkProcessor/Projects/WebApps/Signup
CFG="${SIGNUP_DIR}/config.cfg"
PROD="${SIGNUP_DIR}/production.yml"
SETTINGS="${SIGNUP_DIR}/settings.yml"
CRED=/credentials/login.txt

for f in "$CFG" "$PROD" "$SETTINGS"; do
  if [ ! -f "$f" ]; then
    echo "Missing Signup config: ${f}" >&2
    exit 1
  fi
done

set_cfg() {
  local key="$1" value="$2"
  KEY="$key" VALUE="$value" perl -i -pe '
    BEGIN { $k = $ENV{KEY}; $v = $ENV{VALUE}; $done = 0; }
    if (!$done && /^\Q$k\E\s*=/) {
      $_ = "$k = $v\n";
      $done = 1;
    }
  ' "$CFG"
  if ! grep -qE "^${key}[[:space:]]*=" "$CFG"; then
    echo "${key} = ${value}" >> "$CFG"
  fi
}

set_cfg ctsmsrestapi_uri "${PHOENIX_APP_HTTP}/rest"
set_cfg ctsmsrestapi_username "my_department_cron"
set_cfg ctsmsrestapi_realm "api"
set_cfg screenloglevel "INFO"

if [ ! -f "$CRED" ]; then
  echo "Missing ${CRED}. db-init must finish and write the cron password before Signup starts." >&2
  exit 1
fi

CRON_PASSWORD="$(sed -n 's/^Cron user password (my_department_cron): //p' "$CRED" | head -n 1 | tr -d '\r')"
if [ -z "$CRON_PASSWORD" ]; then
  echo "Cron user password (my_department_cron) not found in ${CRED}." >&2
  exit 1
fi
set_cfg ctsmsrestapi_password "$CRON_PASSWORD"

REDIS_SERVER="${PHOENIX_REDIS_HOST}:${PHOENIX_REDIS_PORT}" perl -i -pe '
  if (/^(\s*)sock:/) { $_ = "$1server: \"$ENV{REDIS_SERVER}\"\n"; }
  elsif (/^(\s*)server:/) { $_ = "$1server: \"$ENV{REDIS_SERVER}\"\n"; }
  elsif (/^logger:/) { $_ = "logger: \"console\"\n"; }
' "$PROD"

tmp="$(mktemp)"
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    ctsms_base_uri:*) printf "ctsms_base_uri: '%s'\n" "$PHOENIX_PUBLIC_URL" ;;
    *) printf '%s\n' "$line" ;;
  esac
done < "$SETTINGS" > "$tmp"
mv "$tmp" "$SETTINGS"

echo "Starting Signup (REST=${PHOENIX_APP_HTTP}/rest, Redis=${PHOENIX_REDIS_HOST}:${PHOENIX_REDIS_PORT})."
exec "$@"
