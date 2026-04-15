#!/bin/bash
set -euo pipefail

# ============================================================
# BASIC TOOLS SETUP FOR UBUNTU 24.04
# Installs: git, htop, tree, zip, unzip, gzip

# wget https://raw.githubusercontent.com/kolasdevpy/set-ubuntu22.04/main/setup_basic_tools.sh
# chmod +x setup_basic_tools.sh
# sudo ./setup_basic_tools.sh
# ============================================================


sudo apt-get update -y

# install base tools
sudo apt-get install -y git htop tree zip unzip gzip
