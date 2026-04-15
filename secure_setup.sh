#!/bin/bash
set -euo pipefail

# ============================================================
# ABOUT
# Secure Ubuntu 24.04 Server Setup Script
# Run: sudo bash secure_server_setup.sh [path_to_public_key]
# Default key path: /root/.ssh/authorized_keys

# SETUP
# wget https://github.com/kolasdevpy/set-ubuntu22.04/blob/main/secure_setup.sh
# chmod +x secure_setup.sh
# sudo ./secure_setup.sh
# ============================================================

# --- Settings ---
NEW_USER="admin"
SSH_PORT="22"
KEY_SOURCE="${1:-/root/.ssh/authorized_keys}"
LOG_FILE="/var/log/server_setup.log"

# Colors and logging
exec > >(tee -a "$LOG_FILE") 2>&1
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
    exit 1
}

# --- Root check ---
if [[ $EUID -ne 0 ]]; then
    error "Script must be run as root (use sudo)."
fi

log "Starting server setup (log written to $LOG_FILE)."

# --- Warning about passwordless sudo ---
warn "You requested passwordless sudo for $NEW_USER. This means the user can run any command as root without a password. Only enable this on a personal trusted server."

# --- 1. System update ---
log "Updating package lists and system..."
apt update && apt upgrade -y

# --- 2. Create new user ---
log "Creating user $NEW_USER..."
if id "$NEW_USER" &>/dev/null; then
    warn "User $NEW_USER already exists. Skipping creation."
else
    adduser --disabled-password --gecos "" "$NEW_USER"
    usermod -aG sudo "$NEW_USER"
    log "User $NEW_USER created and added to sudo group."
fi

# Copy SSH key from root to new user
if [[ -f "$KEY_SOURCE" ]]; then
    log "Copying SSH key from $KEY_SOURCE to $NEW_USER's home..."
    mkdir -p "/home/$NEW_USER/.ssh"
    cp "$KEY_SOURCE" "/home/$NEW_USER/.ssh/authorized_keys"
    chown -R "$NEW_USER:$NEW_USER" "/home/$NEW_USER/.ssh"
    chmod 700 "/home/$NEW_USER/.ssh"
    chmod 600 "/home/$NEW_USER/.ssh/authorized_keys"
    log "SSH key copied."
else
    error "Key file $KEY_SOURCE not found. Add your public key to /root/.ssh/authorized_keys or specify the path as a parameter."
fi

# --- 3. Configure passwordless sudo for the new user ---
log "Configuring passwordless sudo for $NEW_USER..."
echo "$NEW_USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/99-$NEW_USER-nopasswd
chmod 440 /etc/sudoers.d/99-$NEW_USER-nopasswd
log "Passwordless sudo enabled for $NEW_USER."

# --- 4. Safe SSH configuration (via drop-in file) ---
log "Creating drop-in file for secure SSH settings (does not overwrite main config)..."
DROPPIN_FILE="/etc/ssh/sshd_config.d/99-security.conf"
mkdir -p /etc/ssh/sshd_config.d
cat > "$DROPPIN_FILE" <<EOF
# Secure settings added by script $(date)
Port $SSH_PORT
LogLevel VERBOSE
LoginGraceTime 30s
MaxAuthTries 3
MaxSessions 5
MaxStartups 3:50:10
PermitRootLogin prohibit-password
PasswordAuthentication no
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no
X11Forwarding no
AllowTcpForwarding no
AllowAgentForwarding no
EOF

# Check SSH config validity
log "Checking SSH configuration..."
if sshd -t; then
    log "SSH configuration is valid."
else
    error "SSH configuration error. Removing drop-in file and exiting."
    rm -f "$DROPPIN_FILE"
    exit 1
fi

systemctl restart ssh

# --- 5. Test new connection before locking root and enabling UFW ---
log "Waiting 5 seconds for SSH to stabilize..."
sleep 5
log "Verifying that user $NEW_USER can log in via SSH key..."
if ssh -o ConnectTimeout=5 -o BatchMode=yes -o PasswordAuthentication=no -p "$SSH_PORT" "$NEW_USER@localhost" exit; then
    log "Login successful for $NEW_USER using SSH key."
else
    error "Failed to log in as $NEW_USER via SSH key. Rolling back SSH changes."
    rm -f "$DROPPIN_FILE"
    systemctl restart ssh
    exit 1
fi

# --- 6. Lock root password (console protection) ---
log "Locking root password..."
passwd -l root

# --- 7. Configure UFW ---
log "Configuring UFW firewall..."
apt install ufw -y
ufw default deny incoming
ufw default allow outgoing
ufw allow "$SSH_PORT"/tcp
# Check that the port is actually listening
if ss -tlnp | grep -q ":$SSH_PORT "; then
    ufw --force enable
    log "UFW enabled, only port $SSH_PORT is allowed."
else
    error "Port $SSH_PORT is not listening. UFW not enabled."
fi

# --- 8. Configure Fail2ban ---
log "Installing and configuring fail2ban..."
apt install fail2ban -y
cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = $SSH_PORT
logpath = %(sshd_log)s
backend = systemd
EOF
systemctl enable fail2ban --now
log "Fail2ban started and configured."

# --- 9. Automatic security updates (non-interactive) ---
log "Setting up automatic updates..."
apt install unattended-upgrades -y
debconf-set-selections <<EOF
unattended-upgrades unattended-upgrades/enable_auto_updates boolean true
EOF
dpkg-reconfigure --frontend=noninteractive unattended-upgrades
cat > /etc/apt/apt.conf.d/50unattended-upgrades <<EOF
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}";
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}ESMApps:\${distro_codename}-apps-security";
    "\${distro_id}ESM:\${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF
log "Automatic updates enabled."

# --- 10. Cleanup ---
log "Removing unnecessary packages..."
apt autoremove -y
apt autoclean

# --- Final messages ---
echo "====================================================="
echo -e "${GREEN}Server setup completed successfully!${NC}"
echo "====================================================="
echo "Important information:"
echo "- Password login disabled, only SSH key allowed."
echo "- Root can still log in via SSH using the same key as before."
echo "- Root password is locked (console login with password is blocked)."
echo "- Passwordless sudo configured for $NEW_USER."
echo "- SSH port: $SSH_PORT (change in $DROPPIN_FILE)."
echo "- UFW allows only port $SSH_PORT."
echo "- Fail2ban active, blocks IP after 3 failed attempts."
echo "- Automatic security updates enabled."
echo "====================================================="
echo "Before closing the current session, test a new connection:"
echo "ssh $NEW_USER@<IP-address> -p $SSH_PORT -i your_private_key"
echo "Also test root login (optional):"
echo "ssh root@<IP-address> -p $SSH_PORT -i your_private_key"
echo "====================================================="
echo "Setup log saved to $LOG_FILE"
