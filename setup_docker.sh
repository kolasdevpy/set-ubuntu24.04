#!/bin/bash
set -euo pipefail

# ============================================================
# DOCKER ENGINE SETUP FOR UBUNTU 24.04
# Installs: Docker CE, Buildx, Compose plugin
# Usage: sudo ./setup_docker.sh

# wget https://raw.githubusercontent.com/kolasdevpy/set-ubuntu22.04/main/setup_docker.sh
# chmod +x setup_docker.sh
# sudo ./setup_docker.sh
# ============================================================

# DOCKER
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

# Install the latest version
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker "$USER"

sudo systemctl restart docker

sudo docker --version
sudo docker compose version

echo "------------------------------"
echo "⚠️  Reload the terminal"
echo "⚠️  run: sudo usermod -aG docker admin"
echo "⚠️  run: newgrp docker"
