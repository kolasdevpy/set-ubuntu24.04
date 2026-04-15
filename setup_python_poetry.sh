#!/bin/bash
set -euo pipefail

# ============================================================
# PYTHON + POETRY SETUP FOR UBUNTU 24.04
# Installs: pyenv, Python 3.12.13, Poetry
# Usage: ./setup_python_poetry.sh [python_version]


# wget https://raw.githubusercontent.com/kolasdevpy/set-ubuntu22.04/main/setup_python_poetry.sh
# chmod +x setup_python_poetry.sh
# ./setup_python_poetry.sh 3.12.13
# ============================================================
sudo apt-get update -y

# PYTHON
# install Python dependencies
sudo apt-get install -y build-essential zlib1g-dev libncurses5-dev libgdbm-dev \
libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev wget libbz2-dev liblzma-dev

# install pyenv
curl -fsSL https://pyenv.run | bash

# Add pyenv to PATH
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(pyenv init -)"' >> ~/.bashrc

# Update pyenv and instaal Python
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

pyenv update
pyenv install 3.12.13
pyenv global 3.12.13

# Creating simlinks for python3
sudo ln -sf "$PYENV_ROOT/versions/3.12.13/bin/python3" /usr/local/bin/python
sudo ln -sf "$PYENV_ROOT/versions/3.12.13/bin/python3" /usr/local/bin/python3

python --version
python3 --version


# POETRY
# Install Poetry
curl -sSL https://install.python-poetry.org | python3 -
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
export PATH="$HOME/.local/bin:$PATH"

poetry --version
