#!/usr/bin/env bash
set -euo pipefail

SSH_PORT=2222

echo "[+] Menginstall dan mengkonfigurasi UFW..."
apt-get update && apt-get install -y ufw

# Set default policy
ufw default deny incoming
ufw default allow outgoing

# Izinkan SSH port baru, HTTP, dan HTTPS
ufw allow "$SSH_PORT"/tcp
ufw allow 80/tcp
ufw allow 443/tcp

echo "[+] Mengaktifkan UFW..."
ufw --force enable
ufw status verbose
