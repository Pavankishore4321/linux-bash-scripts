#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Script:   initial-server-setup.sh
# Purpose:  Bootstrap and harden a fresh Ubuntu/CentOS server
# Project:  On-Premises Server Maintenance, IDigiPro (Incresol)
# Usage:    sudo bash initial-server-setup.sh
# ─────────────────────────────────────────────────────────────────────────────

# ── CONFIG ────────────────────────────────────────────────────────────────────
NEW_USER="devops"
SSH_PUB_KEY="ssh-rsa YOUR-PUBLIC-KEY-HERE"   # replace with your actual key
TIMEZONE="Asia/Kolkata"
LOG_FILE="/var/log/server-setup.log"

# ── FUNCTIONS ─────────────────────────────────────────────────────────────────
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "ERROR: Please run as root: sudo bash $0"
        exit 1
    fi
}

# ── MAIN ──────────────────────────────────────────────────────────────────────
check_root
log "===== Initial Server Setup Started ====="
log "Hostname: $(hostname)"

# Step 1 — Update system
log "Step 1: Updating system packages..."
apt update -y && apt upgrade -y
log "System updated."

# Step 2 — Create devops user
log "Step 2: Creating user: ${NEW_USER}"
if id "$NEW_USER" &>/dev/null; then
    log "User ${NEW_USER} already exists. Skipping."
else
    adduser --disabled-password --gecos "" "$NEW_USER"
    usermod -aG sudo "$NEW_USER"
    log "User ${NEW_USER} created and added to sudo group."
fi

# Step 3 — Setup SSH key for devops user
log "Step 3: Setting up SSH key..."
mkdir -p /home/${NEW_USER}/.ssh
echo "$SSH_PUB_KEY" >> /home/${NEW_USER}/.ssh/authorized_keys
chmod 700 /home/${NEW_USER}/.ssh
chmod 600 /home/${NEW_USER}/.ssh/authorized_keys
chown -R ${NEW_USER}:${NEW_USER} /home/${NEW_USER}/.ssh
log "SSH key configured."

# Step 4 — Allow passwordless sudo
log "Step 4: Configuring passwordless sudo..."
echo "${NEW_USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
log "Sudo configured."

# Step 5 — SSH hardening
log "Step 5: Hardening SSH..."
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/'          /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/'   /etc/ssh/sshd_config
systemctl restart sshd
log "SSH hardened — root login and password auth disabled."

# Step 6 — UFW Firewall
log "Step 6: Configuring UFW firewall..."
apt install -y ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
log "UFW firewall enabled. Allowed: SSH, HTTP, HTTPS."

# Step 7 — Set timezone
log "Step 7: Setting timezone to ${TIMEZONE}..."
timedatectl set-timezone "$TIMEZONE"
log "Timezone set to: $(timedatectl | grep 'Time zone')"

# Step 8 — Install essential tools
log "Step 8: Installing essential packages..."
apt install -y \
    curl wget git vim htop \
    net-tools unzip tar \
    logrotate fail2ban \
    ntp gnupg
log "Essential packages installed."

# Step 9 — Enable fail2ban
log "Step 9: Starting fail2ban..."
systemctl start fail2ban
systemctl enable fail2ban
log "fail2ban started."

# Step 10 — Log rotation config
log "Step 10: Configuring log rotation..."
cat > /etc/logrotate.d/app-logs << 'EOF'
/var/log/app/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 www-data adm
}
EOF
log "Log rotation configured."

log "===== Server Setup Complete ====="
log "Next steps:"
log "  1. Test SSH login as ${NEW_USER} before closing this session"
log "  2. Verify sudo works: sudo -l"
log "  3. Check UFW status: ufw status"
