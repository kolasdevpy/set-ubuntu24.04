#!/bin/bash
set -euo pipefail

# ============================================================
# ABOUT
# Secure Ubuntu 24.04 Server Setup Script

# SETUP
# wget https://raw.githubusercontent.com/kolasdevpy/set-ubuntu24.04/main/secure_setup.sh
# chmod +x secure_setup.sh
# Usage: sudo ./secure_setup.sh <NEW_SSH_PORT>
# Example: sudo ./secure_setup.sh 2222
# ============================================================

# --- Проверка аргументов и прав ---
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root: sudo $0 <PORT>"
   exit 1
fi

if [[ $# -ne 1 ]]; then
    echo "❌ Usage: $0 <NEW_SSH_PORT>"
    echo "   Example: $0 2222"
    exit 1
fi

NEW_SSH_PORT="$1"

# port validation
if ! [[ "$NEW_SSH_PORT" =~ ^[0-9]+$ ]] || [[ "$NEW_SSH_PORT" -lt 1 ]] || [[ "$NEW_SSH_PORT" -gt 65535 ]]; then
    echo "❌ Invalid port number. Must be between 1 and 65535."
    exit 1
fi


if [[ "$NEW_SSH_PORT" -eq 22 ]]; then
    echo "⚠️  You chose port 22. It's recommended to use a non-standard port for security."
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "🔐 Starting Ubuntu 24.04 hardening with SSH on port $NEW_SSH_PORT..."
export DEBIAN_FRONTEND=noninteractive



# ===== update =====
apt-get update -y
apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
apt-get autoremove -y
apt-get clean

apt-get install -y ufw fail2ban

# ===== sshd_config =====
echo -e "\n[1/4] Configuring SSH on port $NEW_SSH_PORT (password auth disabled)..."
SSH_DROPIN="/etc/ssh/sshd_config.d/99-hardening.conf"

cat > "$SSH_DROPIN" <<EOF
Port $NEW_SSH_PORT
PermitRootLogin prohibit-password
PasswordAuthentication no
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
EOF

# ===== config of cloud-init =====
CLOUD_INIT_SSH="/etc/ssh/sshd_config.d/50-cloud-init.conf"
if [[ -f "$CLOUD_INIT_SSH" ]]; then
    echo "⚠️  Fixing cloud-init SSH config..."
    sed -i 's/^PasswordAuthentication yes/# PasswordAuthentication yes/' "$CLOUD_INIT_SSH"
    sed -i 's/^PermitRootLogin yes/# PermitRootLogin yes/' "$CLOUD_INIT_SSH"
    sed -i 's/^PermitRootLogin prohibit-password/# PermitRootLogin prohibit-password/' "$CLOUD_INIT_SSH"
fi

mkdir -p /run/sshd
chmod 755 /run/sshd

# ===== SSH config validation =====
if ! sshd -t; then
    echo "❌ SSH configuration test failed. Rolling back..."
    rm -f "$SSH_DROPIN"
    exit 1
fi



# ---  UFW allow SSH port) ---
echo -e "\n[2/4] Configuring UFW: allow only port $NEW_SSH_PORT/tcp..."
ufw default deny incoming
ufw default allow outgoing
ufw allow "$NEW_SSH_PORT"/tcp comment 'SSH'
echo "✅ If you want to allow other ports:"
echo "ufw allow 80/tcp"
echo "ufw allow 443/tcp"

# ===== UFW =====
echo "y" | ufw enable
ufw status verbose
echo "✅ UFW enabled. Only port $NEW_SSH_PORT/tcp is open."

# ===== ICMP =====
echo -e "\n[3/4] Configuring ICMP filtering (allow essential types, rate-limit ping)..."
BEFORE_RULES="/etc/ufw/before.rules"
MARKER="# ICMP_custom_rules_$(hostname)"

cp "$BEFORE_RULES" "${BEFORE_RULES}.bak.$(date +%Y%m%d_%H%M%S)"

if ! grep -qF "$MARKER" "$BEFORE_RULES"; then
    sed -i "/^*filter/a\\
$MARKER\n\
# Allow responses to pings and service messages (required for MTU discovery)\n\
-A ufw-before-input -p icmp --icmp-type echo-reply -j ACCEPT\n\
-A ufw-before-input -p icmp --icmp-type destination-unreachable -j ACCEPT\n\
-A ufw-before-input -p icmp --icmp-type time-exceeded -j ACCEPT\n\
-A ufw-before-input -p icmp --icmp-type parameter-problem -j ACCEPT\n\
\n\
# Limit incoming ping requests (1 packet per second)\n\
-A ufw-before-input -p icmp --icmp-type echo-request -m limit --limit 1/second -j ACCEPT\n\
\n\
# All other ICMP - prohibit\n\
-A ufw-before-input -p icmp -j DROP\n" "$BEFORE_RULES"

    ufw reload
    echo "✅ ICMP rules added (ping limited, essential types allowed)."
else
    echo "ℹ️ ICMP rules already present, skipping."
fi


# ===== Fail2Ban for SSH =====
echo -e "\n[4/4] Installing and configuring Fail2Ban for SSH on port $NEW_SSH_PORT..."
FAIL2BAN_JAIL_LOCAL="/etc/fail2ban/jail.local"

cat > "$FAIL2BAN_JAIL_LOCAL" <<EOF
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1
bantime  = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled   = true
port      = $NEW_SSH_PORT
filter    = sshd
logpath   = %(sshd_log)s
maxretry  = 3
EOF

systemctl enable fail2ban
systemctl restart fail2ban
echo "✅ Fail2Ban installed and protecting SSH on port $NEW_SSH_PORT."


# ===== FINAL RESTART SSH =====
ORIGINAL_USER=${SUDO_USER:-$(whoami)}
SERVER_IP=$(hostname -I | awk '{print $1}')

echo -e "\n✅ All configurations applied."
echo "⚠️  SSH service will now restart and switch to port $NEW_SSH_PORT."
echo "   Your current connection will be closed. Reconnect using:"
echo "   ssh -p $NEW_SSH_PORT $ORIGINAL_USER@$SERVER_IP"
echo "   Password authentication is disabled. Use your SSH key."
echo -e "   Restarting in 3 seconds...\n"
sleep 3

systemctl restart ssh
