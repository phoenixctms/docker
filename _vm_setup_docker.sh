#!/bin/bash
set -euo pipefail

echo "=== system ==="
free -h
df -h /
nproc

if ! command -v docker >/dev/null 2>&1; then
  echo "=== installing Docker Engine ==="
  apt-get update -qq
  apt-get install -y -qq ca-certificates curl
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  . /etc/os-release
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian ${VERSION_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi

usermod -aG docker phoenix || true
docker version
docker compose version

echo "=== stopping host phoenix stack to free RAM/ports (disposable VM) ==="
systemctl stop tomcat10 2>/dev/null || true
systemctl stop apache2 2>/dev/null || true
systemctl stop redis-server 2>/dev/null || true

echo "=== ready ==="
free -h
df -h /
