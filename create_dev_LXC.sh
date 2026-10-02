#!/usr/bin/env bash

set -euo pipefail

NAME="t3-dev"

incus launch images:ubuntu/24.04/cloud "$NAME"

incus config set "$NAME" limits.cpu=4
incus config set "$NAME" limits.memory=12GiB
incus config set "$NAME" security.privileged=false
incus config set "$NAME" security.idmap.isolated=true
incus config set "$NAME" security.nesting=true

incus exec "$NAME" -- bash -c '
apt update

apt install -y \
  git git-lfs curl wget unzip jq \
  build-essential cmake ninja-build \
  python3 python3-pip python3-venv pipx \
  nodejs npm openssh-server tmux neovim \
  ripgrep fzf htop shellcheck sqlite3

adduser --disabled-password --gecos "" dev

usermod -aG sudo dev

echo "dev ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/dev
chmod 440 /etc/sudoers.d/dev

mkdir -p /home/dev/projects
chown -R dev:dev /home/dev
'

echo
echo "Container ready."
echo "Enter with:"
echo "incus exec $NAME -- su - dev"
