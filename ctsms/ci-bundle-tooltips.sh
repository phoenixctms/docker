#!/bin/bash
# Publish-job helper: init a temporary stack, run Render/render.sh, pack the PNGs into ROOT.war.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

image="${PHOENIX_CTSMS_IMAGE:-phoenixctms-ctsms:ci}"
out="${PHOENIX_TOOLTIP_DIR:-/tmp/phoenix-tooltips}"
export PHOENIX_CTSMS_IMAGE="$image"

mkdir -p "$out"
find "$out" -name '*.png' -delete

cleanup() {
  docker compose down -v || true
}
trap cleanup EXIT

docker compose up -d db
docker compose up -d --no-build db-migrate
docker compose up -d --no-build ctsms
docker compose up -d --no-build db-init

initialized=0
for i in $(seq 1 120); do
  if docker compose logs db-init 2>/dev/null | grep -q 'Username: phoenix'; then
    initialized=1
    break
  fi
  echo "waiting for init... ($i)"
  sleep 10
done
docker compose logs db-init | tee /tmp/phoenix-db-init.log
if [ "$initialized" != "1" ]; then
  echo "db-init did not finish" >&2
  exit 1
fi

docker run --rm \
  --network phoenixctms_default \
  -v phoenixctms_credentials:/credentials:ro \
  -v "${out}:/ctsms/build/ctsms/web/src/main/webapp/resources/images/tooltips" \
  -v "${root}/ctsms/render-tooltips.sh:/render-tooltips.sh:ro" \
  -e PHOENIX_DBSERVER=db \
  -e PHOENIX_DBPORT=5432 \
  -e PHOENIX_DBUSER="${PHOENIX_POSTGRES_USER:-ctsms}" \
  -e PHOENIX_DBPASS="${PHOENIX_POSTGRES_PASSWORD:-ctsms}" \
  -e PHOENIX_DBNAME="${PHOENIX_POSTGRES_DB:-ctsms}" \
  --entrypoint bash \
  "$image" \
  /render-tooltips.sh

test -s "${out}/trial_states.png"
test -s "${out}/trial_states_de.png"

docker buildx build \
  --builder default \
  --load \
  -f ctsms/Dockerfile.tooltips \
  --build-arg "BASE_IMAGE=${image}" \
  -t phoenixctms-ctsms:bundled \
  "$out"
