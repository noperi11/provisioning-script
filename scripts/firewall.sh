#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Firewall (UFW)
# Default deny incoming, izinkan SSH/HTTP/HTTPS saja
# ============================================================

SSH_PORT=2222

echo "[+] Mengkonfigurasi UFW..."

# ufw seharusnya sudah terinstall oleh packages.sh; install hanya jika belum ada
if ! command -v ufw >/dev/null 2>&1; then
    apt-get update && apt-get install -y ufw
fi

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
