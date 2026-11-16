#!/bin/bash
set -euo pipefail

systemctl stop docker docker.socket containerd || true

# Move containerd state to /home ( /var LV is only ~2G )
mkdir -p /home/containerd
if [ -d /var/lib/containerd ] && [ ! -L /var/lib/containerd ]; then
  rm -rf /var/lib/containerd
fi
ln -sfn /home/containerd /var/lib/containerd

# Also move buildkit if present
mkdir -p /home/buildkit
if [ -d /var/lib/buildkit ] && [ ! -L /var/lib/buildkit ]; then
  rm -rf /var/lib/buildkit
fi
ln -sfn /home/buildkit /var/lib/buildkit

systemctl start containerd
systemctl start docker
docker info | grep -E 'Root|Storage'
df -h /home /var /
ls -la /var/lib/containerd /var/lib/buildkit
