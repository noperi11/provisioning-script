#!/usr/bin/env bash
set -Eeuo pipefail

NEW_USER="user-admin"
NEW_PASS="admin"
SSH_PORT=2222

SSH_CONFIG="/etc/ssh/sshd_config"
SSH_DIR="/home/$NEW_USER/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"

# 1. Root check
if [[ "$EUID" -ne 0 ]]; then
    echo "[-] Jalankan script sebagai root."
    exit 1
fi

echo "=================================================="
echo "[*] SSH HARDENING DIMULAI"
echo "=================================================="

# 2. Input public key
echo "[+] Tempel public key dari laptop."
read -r -p "Public key: " PUBLIC_KEY

if [[ ! "$PUBLIC_KEY" =~ ^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521)[[:space:]]+[A-Za-z0-9+/]+={0,3}([[:space:]].*)?$ ]]; then
    echo "[-] Format public key tidak valid."
    exit 1
fi

# 3. Pastikan OpenSSH server tersedia
if ! command -v sshd >/dev/null 2>&1; then
    echo "[-] OpenSSH Server belum terinstal. Jalankan install.sh terlebih dahulu."
    exit 1
fi

# 4. Membuat user
echo "[+] Menyiapkan user: $NEW_USER"

if ! id "$NEW_USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash -G sudo "$NEW_USER"
fi

usermod -aG sudo "$NEW_USER"
echo "$NEW_USER:$NEW_PASS" | chpasswd

# 5. Memasang public key
echo "[+] Memasang public key..."

install -d -m 700 -o "$NEW_USER" -g "$NEW_USER" "$SSH_DIR"
touch "$AUTH_KEYS"
chown "$NEW_USER:$NEW_USER" "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"

if ! grep -qxF "$PUBLIC_KEY" "$AUTH_KEYS"; then
    printf '%s\n' "$PUBLIC_KEY" >> "$AUTH_KEYS"
fi

# 6. Backup konfigurasi asli
BACKUP="${SSH_CONFIG}.bak"

if [[ ! -f "$BACKUP" ]]; then
    cp -a "$SSH_CONFIG" "$BACKUP"
fi

# Simpan konfigurasi saat ini untuk pemulihan jika validasi gagal
CURRENT_CONFIG="$(mktemp)"
cp -a "$SSH_CONFIG" "$CURRENT_CONFIG"

# 7. Mengatur SSH hardening
echo "[+] Mengatur SSH port $SSH_PORT..."

sed -i -E \
'/^[[:space:]]*(Port|PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|KbdInteractiveAuthentication|ChallengeResponseAuthentication)[[:space:]]+/Id' \
"$SSH_CONFIG"

cat >> "$SSH_CONFIG" <<EOF

# --- Konfigurasi Custom Hardening ---
Port $SSH_PORT
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
KbdInteractiveAuthentication no
EOF

# 8. Validasi sebelum restart
echo "[+] Memvalidasi konfigurasi SSH..."

# /run/sshd hilang jika belum ada boot layak (atau tmpfs dibersihkan);
# tanpa direktori ini, sshd -t gagal walau konfigurasinya benar.
install -d -m 0755 -o root -g root /run/sshd

# Pastikan host key tersedia (aman dijalankan berulang; hanya membuat key yang belum ada)
ssh-keygen -A >/dev/null

if ! /usr/sbin/sshd -t; then
    echo "[-] Konfigurasi tidak valid. Memulihkan konfigurasi sebelumnya."
    cp -a "$CURRENT_CONFIG" "$SSH_CONFIG"
    rm -f "$CURRENT_CONFIG"
    exit 1
fi

/usr/sbin/sshd -T > /tmp/sshd-effective.conf

if ! grep -qx "port $SSH_PORT" /tmp/sshd-effective.conf ||
   ! grep -qx 'permitrootlogin no' /tmp/sshd-effective.conf ||
   ! grep -qx 'passwordauthentication no' /tmp/sshd-effective.conf ||
   ! grep -qx 'pubkeyauthentication yes' /tmp/sshd-effective.conf; then

    echo "[-] Konfigurasi efektif tidak sesuai."
    grep -E '^(port|permitrootlogin|passwordauthentication|pubkeyauthentication) ' \
        /tmp/sshd-effective.conf

    cp -a "$CURRENT_CONFIG" "$SSH_CONFIG"
    rm -f "$CURRENT_CONFIG"
    exit 1
fi

rm -f "$CURRENT_CONFIG"

# 9. Restart SSH
echo "[+] Merestart SSH..."

if ! systemctl restart ssh.service; then
    systemctl restart sshd.service
fi

if ! systemctl is-active --quiet ssh.service &&
   ! systemctl is-active --quiet sshd.service; then
    echo "[-] SSH gagal aktif. Periksa systemctl status ssh."
    exit 1
fi

echo "=================================================="
echo "[+] SSH HARDENING SELESAI"
echo "[+] User             : $NEW_USER"
echo "[+] Port             : $SSH_PORT"
echo "[+] Root login       : Disabled"
echo "[+] Password login   : Disabled"
echo "[+] SSH key          : Enabled"
echo "=================================================="

echo
echo "[!] Jangan tutup sesi SSH lama sebelum menguji koneksi baru."
echo "[!] Pastikan TCP port $SSH_PORT diizinkan oleh firewall."
echo
echo "Perintah koneksi dari laptop:"
echo "ssh -i ~/.ssh/id_ed25519 -p $SSH_PORT $NEW_USER@IP_VM"
