#!/bin/bash
set -e

# rm -f secure_setup.sh
# wget https://raw.githubusercontent.com/kolasdevpy/set-ubuntu22.04/main/inst-tools-py31213-docker.sh
# chmod +x inst-tools-py31213-docker.sh
# ./inst-tools-py31213-docker.sh

# Determine the real user (even if run via sudo)
CURRENT_USER=$(whoami)
if [ "$CURRENT_USER" = "root" ]; then
    if [ -n "$SUDO_USER" ]; then
        CURRENT_USER="$SUDO_USER"
    else
        echo "❌ Running as root is not recommended. Run the script as a regular user with sudo privileges."
        exit 1
    fi
fi

HOME_DIR=$(eval echo ~$CURRENT_USER)
echo "✅ Installing for user: $CURRENT_USER, home directory: $HOME_DIR"

# 1. Basic system packages
sudo apt-get update -y
sudo apt-get install -y git htop tree zip unzip gzip

# 2. Dependencies for building Python
sudo apt-get install -y build-essential zlib1g-dev libncurses5-dev libgdbm-dev \
libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev wget libbz2-dev liblzma-dev

# 3. Install pyenv (for current user, without sudo)
curl -fsSL https://pyenv.run | bash

# Add pyenv to .bashrc if not already present
grep -q 'PYENV_ROOT="$HOME/.pyenv"' ~/.bashrc || {
    echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
    echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
    echo 'eval "$(pyenv init -)"' >> ~/.bashrc
}

# Activate pyenv in the current session
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# Install Python 3.12.13 via pyenv
pyenv update
pyenv install 3.12.13
pyenv global 3.12.13

# Create global symlinks (using sudo) for convenience
sudo ln -sf "$PYENV_ROOT/versions/3.12.13/bin/python3" /usr/local/bin/python
sudo ln -sf "$PYENV_ROOT/versions/3.12.13/bin/python3" /usr/local/bin/python3

# Verification
echo "🐍 Python version for user:"
python --version
python3 --version

# 4. Install Poetry (for current user)
curl -sSL https://install.python-poetry.org | python3 -

# Add Poetry to PATH in .bashrc
grep -q '$HOME/.local/bin' ~/.bashrc || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
export PATH="$HOME/.local/bin:$PATH"

poetry --version

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

docker --version
docker compose version

echo "------------------------------"
echo "⚠️  run: sudo usermod -aG docker admin"
echo "⚠️  run: newgrp docker"
echo "⚠️  Reload the terminal"
