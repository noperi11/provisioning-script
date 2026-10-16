#!/usr/bin/env bash
set -euo pipefail

# Konfigurasi Variabel (Ganti sesuai kebutuhan)
NEW_USER="admin"
NEW_PASS="admin"
SSH_PORT=2222

echo "[+] Membuat user baru: $NEW_USER..."
id "$NEW_USER" &>/dev/null || useradd -m -s /bin/bash -G sudo "$NEW_USER"
echo "$NEW_USER:$NEW_PASS" | chpasswd

echo "[+] Mengonfigurasi SSH Hardening..."
SSH_CONFIG="/etc/ssh/sshd_config"

# Backup config asli
cp "$SSH_CONFIG" "${SSH_CONFIG}.bak"

# Ubah konfigurasi SSH
sed -i "s/#Port 22/Port $SSH_PORT/" "$SSH_CONFIG"
sed -i "s/^Port 22/Port $SSH_PORT/" "$SSH_CONFIG"
sed -i "s/#PermitRootLogin.*/PermitRootLogin no/" "$SSH_CONFIG"
sed -i "s/^PermitRootLogin.*/PermitRootLogin no/" "$SSH_CONFIG"
sed -i "s/#PasswordAuthentication yes/PasswordAuthentication yes/" "$SSH_CONFIG" # Ubah ke no jika pakai SSH Key

echo "[+] Merestart service SSH..."
systemctl restart ssh || systemctl restart sshd
echo "[+] Hardening SSH selesai. Port baru: $SSH_PORT, Root login: Disabled."
