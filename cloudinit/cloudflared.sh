#!/bin/bash
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive

# ==============================================================================
# CONFIGURATION - SET YOUR VALUES HERE
# ==============================================================================
NEW_USER="amin"
NEW_PASSWORD="YOUR_PASSWORD_HERE"
CF_TUNNEL_TOKEN="YOUR_CLOUDFLARE_TUNNEL_TOKEN_HERE"

# ==============================================================================
# 1. CREATE USER & CONFIGURE SUDO
# ==============================================================================
if ! id -u "$NEW_USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$NEW_USER"
fi

# Set the password for the user
echo "$NEW_USER:$NEW_PASSWORD" | chpasswd
usermod -aG sudo "$NEW_USER"

# Grant full passwordless sudo permissions
echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-$NEW_USER"
chmod 0440 "/etc/sudoers.d/90-$NEW_USER"

# ==============================================================================
# 2. CONFIGURE SSHD (FORCE ENABLE PASSWORD AUTHENTICATION)
# ==============================================================================
mkdir -p /etc/ssh/sshd_config.d

# Cloud images (Ubuntu/Debian) often disable password auth in /etc/ssh/sshd_config.d/*
if ls /etc/ssh/sshd_config.d/*.conf >/dev/null 2>&1; then
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config.d/*.conf
fi

# Create dedicated drop-in file for password authentication
cat <<'EOF' > /etc/ssh/sshd_config.d/01-password-auth.conf
PasswordAuthentication yes
KbdInteractiveAuthentication yes
EOF
chmod 0644 /etc/ssh/sshd_config.d/01-password-auth.conf

# Update main sshd_config as well
sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#\?KbdInteractiveAuthentication .*/KbdInteractiveAuthentication yes/' /etc/ssh/sshd_config

# Restart SSH (supports both systemd service and Ubuntu socket activation)
systemctl daemon-reload
systemctl restart ssh.socket ssh.service sshd.service 2>/dev/null || \
systemctl restart ssh 2>/dev/null || \
systemctl restart sshd 2>/dev/null

# ==============================================================================
# 3. INSTALL & CONFIGURE CLOUDFLARE TUNNEL
# ==============================================================================
apt-get update -y
apt-get install -y curl

# Add Cloudflare GPG key
mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-public-v2.gpg | tee /usr/share/keyrings/cloudflare-public-v2.gpg >/dev/null

# Add Cloudflare apt repository
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg] https://pkg.cloudflare.com/cloudflared any main' | tee /etc/apt/sources.list.d/cloudflared.list

# Install cloudflared
apt-get update -y
apt-get install -y cloudflared

# Register and start the Cloudflare Tunnel systemd service
cloudflared service install "$CF_TUNNEL_TOKEN"