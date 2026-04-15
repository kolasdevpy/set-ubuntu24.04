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

# 📝 Defaults
PYTHON_VERSION="${1:-3.12.13}"
TARGET_USER="${SUDO_USER:-${USERNAME:-$(logname 2>/dev/null || echo "$USER")}}"
HOME_DIR="/home/$TARGET_USER"
BASHRC="$HOME_DIR/.bashrc"

# 🔒 Check if running as root (required for system packages)
if [[ $EUID -ne 0 ]]; then
   warn "This script installs system packages. Retrying with sudo..."
   exec sudo bash "$0" "$@"
fi

export DEBIAN_FRONTEND=noninteractive

# ─────────────────────────────────────────────────────────────
# 1. Install build dependencies for Python compilation
# ─────────────────────────────────────────────────────────────
step "Installing build dependencies..."
apt-get update -y
apt-get install -y \
    git curl wget build-essential zlib1g-dev libncurses5-dev \
    libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev \
    libsqlite3-dev libbz2-dev liblzma-dev

# ─────────────────────────────────────────────────────────────
# 2. Install pyenv
# ─────────────────────────────────────────────────────────────
step "Installing pyenv..."
if [[ -d "$HOME_DIR/.pyenv" ]]; then
    warn "pyenv already exists. Skipping installation."
else
    # Run pyenv installer as target user
    su - "$TARGET_USER" -c 'curl -fsSL https://pyenv.run | bash'
fi

# ─────────────────────────────────────────────────────────────
# 3. Configure PATH for pyenv (avoid duplicates)
# ─────────────────────────────────────────────────────────────
step "Configuring shell for pyenv..."
PYENV_INIT_BLOCK='# >>> pyenv init >>>
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
# <<< pyenv init <<<'

if ! grep -q "pyenv init" "$BASHRC" 2>/dev/null; then
    echo "$PYENV_INIT_BLOCK" >> "$BASHRC"
    info "pyenv configuration added to $BASHRC"
else
    warn "pyenv already configured in $BASHRC"
fi

# ─────────────────────────────────────────────────────────────
# 4. Install Python via pyenv
# ─────────────────────────────────────────────────────────────
step "Installing Python $PYTHON_VERSION via pyenv..."
su - "$TARGET_USER" -c "
    export PYENV_ROOT=\"\$HOME/.pyenv\"
    export PATH=\"\$PYENV_ROOT/bin:\$PATH\"
    eval \"\$(pyenv init -)\"
    pyenv update --quiet
    pyenv install -s $PYTHON_VERSION
    pyenv global $PYTHON_VERSION
"

# ─────────────────────────────────────────────────────────────
# 5. Verify Python installation
# ─────────────────────────────────────────────────────────────
step "Verifying Python installation..."
PYTHON_BIN="$HOME_DIR/.pyenv/versions/$PYTHON_VERSION/bin/python3"
if [[ -x "$PYTHON_BIN" ]]; then
    su - "$TARGET_USER" -c "$PYTHON_BIN --version"
    info "✅ Python $PYTHON_VERSION installed successfully"
else
    error "Python binary not found at $PYTHON_BIN"
fi

# ─────────────────────────────────────────────────────────────
# 6. Install Poetry
# ─────────────────────────────────────────────────────────────
step "Installing Poetry..."
su - "$TARGET_USER" -c "
    export PYENV_ROOT=\"\$HOME/.pyenv\"
    export PATH=\"\$PYENV_ROOT/versions/$PYTHON_VERSION/bin:\$PATH\"
    curl -sSL https://install.python-poetry.org | python3 -
"

# Configure PATH for Poetry (~/.local/bin)
POETRY_PATH_BLOCK='# >>> poetry PATH >>>
export PATH="\$HOME/.local/bin:\$PATH"
# <<< poetry PATH <<<'

if ! grep -q "poetry PATH" "$BASHRC" 2>/dev/null; then
    echo "$POETRY_PATH_BLOCK" >> "$BASHRC"
    info "Poetry PATH added to $BASHRC"
else
    warn "Poetry PATH already configured in $BASHRC"
fi

# ─────────────────────────────────────────────────────────────
# 7. Verify Poetry installation
# ─────────────────────────────────────────────────────────────
step "Verifying Poetry installation..."
su - "$TARGET_USER" -c "
    export PATH=\"\$HOME/.local/bin:\$PATH\"
    poetry --version
"

# ─────────────────────────────────────────────────────────────
# ✅ Final summary
# ─────────────────────────────────────────────────────────────
echo -e "\n${GREEN}🎉 Python + Poetry setup complete!${NC}"
echo "🔹 Python: $(su - "$TARGET_USER" -c "export PYENV_ROOT=\"\$HOME/.pyenv\" && export PATH=\"\$PYENV_ROOT/bin:\$PATH\" && eval \"\$(pyenv init -)\" && python --version")"
echo "🔹 Poetry: $(su - "$TARGET_USER" -c "export PATH=\"\$HOME/.local/bin:\$PATH\" && poetry --version 2>/dev/null || echo 'Re-login required')"
echo -e "💡 ${YELLOW}IMPORTANT: Re-login or run 'source ~/.bashrc' to apply PATH changes${NC}"
echo -e "💡 Create a project: ${YELLOW}poetry new mybot && cd mybot && poetry add python-telegram-bot${NC}"
