#!/usr/bin/env bash
set -euo pipefail

NEW_USER="user-admin"
NEW_PASS="admin"
SSH_PORT=2222

echo "[+] Membuat user baru: $NEW_USER..."
id "$NEW_USER" &>/dev/null || useradd -m -s /bin/bash -G sudo "$NEW_USER"
echo "$NEW_USER:$NEW_PASS" | chpasswd

echo "[+] Mengonfigurasi SSH Hardening..."
SSH_CONFIG="/etc/ssh/sshd_config"

# Backup config asli
cp "$SSH_CONFIG" "${SSH_CONFIG}.bak"

# 1. Pastikan baris-baris penting di-comment dulu atau dibersihkan agar tidak duplikat
# Menggunakan sed untuk menonaktifkan konfigurasi lama yang aktif
sed -i -E 's/^[[:space:]]*Port[[:space:]]+/#Port /g' "$SSH_CONFIG"
sed -i -E 's/^[[:space:]]*PermitRootLogin[[:space:]]+/#PermitRootLogin /g' "$SSH_CONFIG"
sed -i -E 's/^[[:space:]]*PasswordAuthentication[[:space:]]+/#PasswordAuthentication /g' "$SSH_CONFIG"

# 2. Append (tambahkan) konfigurasi baru yang bersih di akhir baris file sshd_config
cat << EOF >> "$SSH_CONFIG"

# --- Konfigurasi Custom Hardening ---
Port $SSH_PORT
PermitRootLogin no
PasswordAuthentication yes
EOF

# 3. WAJIB: Validasi sintaks sebelum restart service
echo "[+] Memvalidasi konfigurasi SSH..."
if ! sshd -t; then
    echo "[-] Error: Konfigurasi SSH tidak valid! Mengembalikan konfigurasi awal..."
    cp "${SSH_CONFIG}.bak" "$SSH_CONFIG"
    exit 1
fi

echo "[+] Merestart service SSH..."
systemctl restart ssh || systemctl restart sshd
echo "[+] Hardening SSH selesai. Port baru: $SSH_PORT, Root login: Disabled."
