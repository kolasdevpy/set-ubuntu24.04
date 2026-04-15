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



if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root: sudo bash $0"
   exit 1
fi

SSH_PORT=${SSH_PORT:-22}

echo "🔐 Initializing Ubuntu 24.04 basic hardening..."
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
apt-get autoremove -y
apt-get clean

echo -e "\n[2/2] Hardening SSH configuration..."
SSH_DROPIN="/etc/ssh/sshd_config.d/99-hardening.conf"

cat > "$SSH_DROPIN" <<EOF
Port ${SSH_PORT}
PermitRootLogin prohibit-password
PasswordAuthentication no
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
EOF

# Отключаем конфликтующие настройки в cloud-init
CLOUD_INIT_SSH="/etc/ssh/sshd_config.d/50-cloud-init.conf"
if [[ -f "$CLOUD_INIT_SSH" ]]; then
    echo "⚠️ Fixing cloud-init SSH config..."
    sed -i 's/^PasswordAuthentication yes/# PasswordAuthentication yes/' "$CLOUD_INIT_SSH"
    sed -i 's/^PermitRootLogin yes/# PermitRootLogin yes/' "$CLOUD_INIT_SSH"
    sed -i 's/^PermitRootLogin prohibit-password/# PermitRootLogin prohibit-password/' "$CLOUD_INIT_SSH"
fi

mkdir -p /run/sshd
chmod 755 /run/sshd

if ! sshd -t; then
    echo "❌ SSH configuration test failed. Rolling back..."
    rm -f "$SSH_DROPIN"
    exit 1
fi

systemctl restart ssh
echo "✅ SSH reconfigured."
