#!/bin/bash
set -euo pipefail

# ============================================================
# ABOUT
# Secure Ubuntu 24.04 Server Setup Script

# SETUP
# wget https://raw.githubusercontent.com/kolasdevpy/set-ubuntu22.04/main/secure_setup.sh
# chmod +x secure_setup.sh
# sudo ./secure_setup.sh
# ============================================================

# 🔒 Privilege check
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root: sudo bash $0"
   exit 1
fi

# ⚙️ Configuration (change if SSH uses a non-standard port)
SSH_PORT=${SSH_PORT:-22}

echo "🔐 Initializing Ubuntu 24.04 basic hardening..."
echo "⚠️  IMPORTANT: Do not close your current SSH session until you verify the new connection!"
echo "💡 Tip: Open a second SSH session and test login before exiting this one."

export DEBIAN_FRONTEND=noninteractive

# ─────────────────────────────────────────────────────────────
# 1. System Update
# ─────────────────────────────────────────────────────────────
echo -e "\n[1/2] Updating system packages..."
apt-get update -y
apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
apt-get autoremove -y
apt-get clean

# ─────────────────────────────────────────────────────────────
# 2. SSH Hardening: Keys only, disable root
# ─────────────────────────────────────────────────────────────
echo -e "\n[2/2] Hardening SSH configuration..."
SSH_DROPIN="/etc/ssh/sshd_config.d/99-hardening.conf"

cat > "$SSH_DROPIN" <<EOF
# SSH Port (modify if needed)
Port ${SSH_PORT}

# Disable root login and password authentication
PermitRootLogin no
PasswordAuthentication no
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no

# Explicitly allow public key authentication
PubkeyAuthentication yes
EOF

# 🔧 Ubuntu 24.04 fix: ensure privilege separation directory exists
mkdir -p /run/sshd
chmod 755 /run/sshd

# Validate configuration syntax before applying
if ! sshd -t; then
    echo "❌ SSH configuration test failed. Rolling back changes..."
    rm -f "$SSH_DROPIN"
    exit 1
fi

# Reload or restart SSH to apply changes (works whether service is running or not)
systemctl reload-or-restart ssh
echo "✅ SSH reconfigured successfully. Drop-in file: $SSH_DROPIN"
