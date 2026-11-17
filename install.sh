#!/bin/bash
# Download Phoenix CTMS Compose and start it with the published images.
set -euo pipefail

REF="${PHOENIX_REF:-master}"
DEST="${PHOENIX_HOME:-$HOME/phoenixctms}"
URL="https://github.com/phoenixctms/docker/archive/refs/heads/${REF}.tar.gz"

if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
  echo "Install Docker Engine or Docker Desktop, then run this again." >&2
  exit 1
fi
if ! command -v curl >/dev/null 2>&1 || ! command -v tar >/dev/null 2>&1; then
  echo "curl and tar are required." >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "Downloading Phoenix CTMS Compose (${REF})..."
curl -fsSL "$URL" | tar -xz -C "$tmp"
src="$tmp/docker-${REF}"
if [ ! -f "$src/compose.yaml" ]; then
  echo "Download did not contain compose.yaml." >&2
  exit 1
fi

mkdir -p "$DEST"
find "$DEST" -mindepth 1 -maxdepth 1 ! -name '.env' -exec rm -rf {} +
cp -a "$src/." "$DEST/"

if [ ! -f "$DEST/.env" ]; then
  sed -e 's/^# \(PHOENIX_CTSMS_IMAGE=\)/\1/' \
      -e 's/^# \(PHOENIX_SIGNUP_IMAGE=\)/\1/' \
      "$DEST/.env.example" > "$DEST/.env"
fi

cd "$DEST"
echo "Starting in ${DEST}"
echo "db-init prints the UI URL and the phoenix password."
docker compose pull
docker compose up -d --no-build
docker compose logs -f db-init
