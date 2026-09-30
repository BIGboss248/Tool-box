#!/bin/bash
set -euo pipefail

# Ensure script is running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Run with sudo: sudo bash $0" >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

# ==============================================================================
# CONFIGURATION - SET YOUR VALUES HERE
# ==============================================================================
NEW_USER="amin"
NEW_PASSWORD="YOUR_PASSWORD_HERE"
CF_TUNNEL_TOKEN="YOUR_CLOUDFLARE_TUNNEL_TOKEN_HERE"

# Helper function to wait for apt / dpkg locks on boot
wait_for_apt_lock() {
    echo "Waiting for apt/dpkg locks to be released..."
    while fuser /var/lib/dpkg/lock >/dev/null 2>&1 || \
          fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || \
          fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
        sleep 2
    done
}

# ==============================================================================
# 1. CREATE USER & CONFIGURE SUDO
# ==============================================================================
if ! id -u "$NEW_USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$NEW_USER"
fi

# Set password and add to sudo group
echo "$NEW_USER:$NEW_PASSWORD" | chpasswd
usermod -aG sudo "$NEW_USER"

# Grant full passwordless sudo permissions
mkdir -p /etc/sudoers.d
echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-$NEW_USER"
chmod 0440 "/etc/sudoers.d/90-$NEW_USER"

# ==============================================================================
# 2. CONFIGURE SSHD (FORCE ENABLE PASSWORD AUTHENTICATION)
# ==============================================================================
mkdir -p /etc/ssh/sshd_config.d

# Override any cloud-init or cloud-image drop-in configs disabling password auth
if ls /etc/ssh/sshd_config.d/*.conf >/dev/null 2>&1; then
    sed -i 's/^[#]*PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config.d/*.conf
    sed -i 's/^[#]*KbdInteractiveAuthentication.*/KbdInteractiveAuthentication yes/g' /etc/ssh/sshd_config.d/*.conf
fi

# Create high-priority drop-in config for password authentication (Ubuntu 24.04 compatibility)
cat <<'EOF' > /etc/ssh/sshd_config.d/99-password-auth.conf
PasswordAuthentication yes
KbdInteractiveAuthentication yes
EOF
chmod 0644 /etc/ssh/sshd_config.d/99-password-auth.conf

# Update main sshd_config as fallback
sed -i 's/^[#]*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^[#]*KbdInteractiveAuthentication.*/KbdInteractiveAuthentication yes/' /etc/ssh/sshd_config

# Restart SSH service/socket (Ubuntu 24.04 uses ssh.socket)
systemctl daemon-reload
systemctl restart ssh.socket || true
systemctl restart ssh || true
systemctl restart sshd || true

# ==============================================================================
# 3. INSTALL & CONFIGURE CLOUDFLARE TUNNEL
# ==============================================================================
wait_for_apt_lock
apt-get update -y
wait_for_apt_lock
apt-get install -y curl

# Add Cloudflare GPG key
mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-public-v2.gpg | tee /usr/share/keyrings/cloudflare-public-v2.gpg >/dev/null

# Add Cloudflare apt repository
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg] https://pkg.cloudflare.com/cloudflared any main' | tee /etc/apt/sources.list.d/cloudflared.list

# Install cloudflared
wait_for_apt_lock
apt-get update -y
wait_for_apt_lock
apt-get install -y cloudflared

# Register and start Cloudflare Tunnel service
cloudflared service install "$CF_TUNNEL_TOKEN" || true
systemctl daemon-reload
systemctl enable --now cloudflared || true
systemctl restart cloudflared || true