#!/bin/bash
# Download Phoenix CTMS Compose and start it with the published images.
set -euo pipefail

REF="${PHOENIX_REF:-master}"
DEST="${PHOENIX_HOME:-$HOME/phoenixctms}"
URL="https://github.com/phoenixctms/docker/archive/refs/heads/${REF}.tar.gz"

if ! command -v docker >/dev/null 2>&1; then
  echo "Install Docker Engine or Docker Desktop, then run this again." >&2
  exit 1
fi
# docker.exe reads stdin. Under curl | bash that stdin is this script, so close it.
docker() { command docker "$@" </dev/null; }
if ! docker compose version >/dev/null 2>&1; then
  echo "Install Docker Engine or Docker Desktop, then run this again." >&2
  exit 1
fi

# The socket is root:docker. A regular user is not in that group until added,
# and an already-open shell does not pick the group up. Join it and continue.
if ! docker info >/dev/null 2>&1; then
  docker_err="$(docker info 2>&1 || true)"
  if [[ "$docker_err" == *"could not be found in this WSL 2 distro"* ]]; then
    echo "Enable this WSL distro in Docker Desktop: Settings, Resources, WSL integration." >&2
    exit 1
  fi
  if [[ "$docker_err" != *"permission denied"* ]]; then
    printf '%s\n' "$docker_err" >&2
    exit 1
  fi
  if [[ "${PHOENIX_DOCKER_GROUP_REEXEC:-}" == 1 ]]; then
    echo "User ${USER} still cannot open the Docker socket. Open a new WSL shell and run this again." >&2
    exit 1
  fi
  if ! id -nG | grep -qw docker; then
    echo "Adding ${USER} to the docker group..."
    if [[ "$(id -u)" -eq 0 ]]; then
      usermod -aG docker "$USER"
    else
      sudo usermod -aG docker "$USER"
    fi
  fi
  echo "Continuing as ${USER} with the docker group."
  exec sg docker -c "PHOENIX_DOCKER_GROUP_REEXEC=1 curl -fsSL https://raw.githubusercontent.com/phoenixctms/docker/master/install.sh | bash"
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
