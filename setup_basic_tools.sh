#!/bin/bash
set -euo pipefail

# ============================================================
# BASIC TOOLS SETUP FOR UBUNTU 24.04
# Installs: git, htop, tree, zip, unzip, gzip

# wget https://raw.githubusercontent.com/kolasdevpy/set-ubuntu22.04/setup_basic_tools.sh
# chmod +x setup_basic_tools.sh
# sudo setup_basic_tools.sh
# ============================================================

# 🎨 Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
step()  { echo -e "\n${BLUE}➤ $1${NC}"; }

# 🔒 Root check
[[ $EUID -ne 0 ]] && error "This script must be run as root."

# 📦 Packages to install
PACKAGES=(
    git
    htop
    tree
    zip
    unzip
    gzip
)

export DEBIAN_FRONTEND=noninteractive

# ─────────────────────────────────────────────────────────────
# 1. Update package index
# ─────────────────────────────────────────────────────────────
step "Updating package index..."
apt-get update -y

# ─────────────────────────────────────────────────────────────
# 2. Install packages
# ─────────────────────────────────────────────────────────────
step "Installing: ${PACKAGES[*]}..."
apt-get install -y "${PACKAGES[@]}"

# ─────────────────────────────────────────────────────────────
# 3. Verify installations
# ─────────────────────────────────────────────────────────────
step "Verifying installations..."
for pkg in "${PACKAGES[@]}"; do
    if command -v "$pkg" &>/dev/null; then
        # Special handling for version flags
        case "$pkg" in
            gzip|zip|unzip)
                version=$($pkg 2>&1 | head -n1 || echo "installed")
                ;;
            tree)
                version=$($pkg --version 2>/dev/null | head -n1 || echo "installed")
                ;;
            *)
                version=$($pkg --version 2>/dev/null | head -n1 || echo "installed")
                ;;
        esac
        info "✅ $pkg: $version"
    else
        warn "⚠️  $pkg installed but not in PATH"
    fi
done

# ─────────────────────────────────────────────────────────────
# ✅ Final summary
# ─────────────────────────────────────────────────────────────
echo -e "\n${GREEN}🎉 Basic tools setup complete!${NC}"
echo -e "🔹 Quick usage:"
echo -e "   • Clone repo:  ${YELLOW}git clone <url>${NC}"
echo -e "   • Monitor:     ${YELLOW}htop${NC}"
echo -e "   • View tree:   ${YELLOW}tree -L 2${NC}"
echo -e "   • Archive:     ${YELLOW}zip -r backup.zip /path${NC}"
echo -e "   • Extract:     ${YELLOW}unzip archive.zip${NC}"
