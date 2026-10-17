#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# SSH Hardening
# User baru + public key + port kustom + lockdown autentikasi
# ============================================================

# --- Konfigurasi ---
NEW_USER="user-admin"
NEW_PASS="admin"
SSH_PORT=2222

SSH_CONFIG="/etc/ssh/sshd_config"
SSH_DIR="/home/$NEW_USER/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"

# Public key dari installer.sh (bootstrap). Jika setup.sh dijalankan
# langsung, ganti placeholder di bawah dengan isi ~/.ssh/id_ed25519.pub.
PUBLIC_KEY="${PUBLIC_KEY:-<PUBLIC_KEY_KAMU>}"

# --- Helper ---
info() { echo "[+] $1"; }
fail() { echo "[-] $1"; exit 1; }

restore_config() {
    cp -a "$CURRENT_CONFIG" "$SSH_CONFIG"
    rm -f "$CURRENT_CONFIG"
}

# --- 1. Validasi ---
[[ "$EUID" -eq 0 ]] || fail "Jalankan script sebagai root."

if [[ -z "$PUBLIC_KEY" || "$PUBLIC_KEY" == "<PUBLIC_KEY_KAMU>" ]]; then
    fail "PUBLIC_KEY belum diisi. Ganti <PUBLIC_KEY_KAMU> di installer.sh dengan isi ~/.ssh/id_ed25519.pub."
fi

if [[ ! "$PUBLIC_KEY" =~ ^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521)[[:space:]]+[A-Za-z0-9+/]+={0,3}([[:space:]].*)?$ ]]; then
    fail "Format public key tidak valid."
fi

command -v sshd >/dev/null 2>&1 || fail "OpenSSH Server belum terinstal. Jalankan packages.sh terlebih dahulu."

echo "=================================================="
echo "[*] SSH HARDENING DIMULAI"
echo "=================================================="

# --- 2. Buat user dan pasang public key ---
info "Menyiapkan user: $NEW_USER"

if ! id "$NEW_USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash -G sudo "$NEW_USER"
fi

usermod -aG sudo "$NEW_USER"
echo "$NEW_USER:$NEW_PASS" | chpasswd

info "Memasang public key..."

install -d -m 700 -o "$NEW_USER" -g "$NEW_USER" "$SSH_DIR"
touch "$AUTH_KEYS"
chown "$NEW_USER:$NEW_USER" "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"

if ! grep -qxF "$PUBLIC_KEY" "$AUTH_KEYS"; then
    printf '%s\n' "$PUBLIC_KEY" >> "$AUTH_KEYS"
fi

# --- 3. Backup konfigurasi asli ---
BACKUP="${SSH_CONFIG}.bak"

if [[ ! -f "$BACKUP" ]]; then
    cp -a "$SSH_CONFIG" "$BACKUP"
fi

# Simpan konfigurasi saat ini untuk pemulihan jika validasi gagal
CURRENT_CONFIG="$(mktemp)"
cp -a "$SSH_CONFIG" "$CURRENT_CONFIG"

# --- 4. Terapkan hardening ---
info "Mengatur SSH port $SSH_PORT..."

# Hapus setting lama agar tidak dobel dengan blok baru di bawah
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

# --- 5. Validasi sebelum restart ---
info "Memvalidasi konfigurasi SSH..."

# /run/sshd hilang jika service SSH belum pernah jalan di sesi ini;
# tanpa direktori ini, sshd -t gagal walau konfigurasinya benar.
install -d -m 0755 -o root -g root /run/sshd

# Pastikan host key tersedia (aman dijalankan berulang)
ssh-keygen -A >/dev/null

if ! /usr/sbin/sshd -t; then
    echo "[-] Konfigurasi tidak valid. Memulihkan konfigurasi sebelumnya."
    restore_config
    exit 1
fi

/usr/sbin/sshd -T > /tmp/sshd-effective.conf

if ! grep -qx "port $SSH_PORT" /tmp/sshd-effective.conf ||
   ! grep -qx 'permitrootlogin no' /tmp/sshd-effective.conf ||
   ! grep -qx 'passwordauthentication no' /tmp/sshd-effective.conf ||
   ! grep -qx 'pubkeyauthentication yes' /tmp/sshd-effective.conf; then

    echo "[-] Konfigurasi efektif tidak sesuai:"
    grep -E '^(port|permitrootlogin|passwordauthentication|pubkeyauthentication) ' \
        /tmp/sshd-effective.conf

    restore_config
    exit 1
fi

rm -f "$CURRENT_CONFIG"

# --- 6. Buka port SSH baru di firewall SEBELUM restart ---
#    (menghindari lock-out jika ufw sudah aktif dari run sebelumnya)
if command -v ufw >/dev/null 2>&1; then
    info "Mengizinkan port $SSH_PORT di UFW..."
    ufw allow "$SSH_PORT"/tcp
fi

# --- 7. Restart SSH ---
info "Merestart SSH..."

systemctl enable ssh >/dev/null 2>&1 || systemctl enable sshd >/dev/null 2>&1 || true

if ! systemctl restart ssh.service; then
    systemctl restart sshd.service
fi

if ! systemctl is-active --quiet ssh.service &&
   ! systemctl is-active --quiet sshd.service; then
    fail "SSH gagal aktif. Periksa systemctl status ssh."
fi

# --- 8. Ringkasan ---
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
