#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# Access Provisioning (lapis 1)
# Menyiapkan jalan masuk untuk orkestrator lapis 2: user +
# public key + sudo NOPASSWD. TIDAK menyentuh sshd_config,
# TIDAK memindah port, TIDAK mengaktifkan firewall — semua
# kebijakan SSH (port 2222, PasswordAuthentication, ufw,
# fail2ban) adalah milik role Ansible (ssh-hardening,
# firewall). Satu file config = satu pemilik.
# ============================================================

info() { echo "[+] $1"; }
fail() { echo "[-] $1" >&2; exit 1; }

# --- 1. Validasi ---
[[ "${EUID:-$(id -u)}" -eq 0 ]] || fail "Jalankan script sebagai root."

# shellcheck disable=SC1091
source "$(dirname "$(readlink -f "$0")")/../vars.sh"

if [[ -z "$PUBLIC_KEY" || "$PUBLIC_KEY" == "<PUBLIC_KEY_KAMU>" ]]; then
    fail "PUBLIC_KEY belum diisi. Suplai lewat environment (installer.sh / user data)."
fi

# Terima algoritma standar + kunci keamanan FIDO2/YubiKey
# (sk-...@openssh.com). Validasi di sini murah; kunci typo yang
# baru ketahuan setelah Ansible jalan = lockout.
if [[ ! "$PUBLIC_KEY" =~ ^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521)|sk-(ed25519|ecdsa-sha2-nistp(256|384|521))@openssh\.com)[[:space:]]+[A-Za-z0-9+/]+={0,3}([[:space:]:].*)?$ ]]; then
    fail "Format public key tidak valid."
fi

command -v sshd >/dev/null 2>&1 || fail "OpenSSH Server belum terinstal. Jalankan packages.sh terlebih dahulu."

SUDOERS_DROPIN="/etc/sudoers.d/90-${NEW_USER}"

echo "=================================================="
echo "[*] ACCESS PROVISIONING DIMULAI"
echo "=================================================="

# --- 2. Buat user + pasang public key ---
info "Menyiapkan user: $NEW_USER"

if ! id "$NEW_USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash -G sudo "$NEW_USER"
fi

# Password di-lock + dikosongkan: tidak ada password hardcode
# (fix audit item 2 — dulu NEW_PASS="admin" yang tetap berlaku
# untuk sudo dan console VPS provider). Login = key-only.
passwd -l -d "$NEW_USER" >/dev/null

SSH_DIR="/home/$NEW_USER/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"

info "Memasang public key..."
install -d -m 700 -o "$NEW_USER" -g "$NEW_USER" "$SSH_DIR"
touch "$AUTH_KEYS"
chown "$NEW_USER:$NEW_USER" "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"

if ! grep -qxF "$PUBLIC_KEY" "$AUTH_KEYS"; then
    printf '%s\n' "$PUBLIC_KEY" >> "$AUTH_KEYS"
fi

# Sudo NOPASSWD: Ansible pakai become:true dari user ini.
# (Alternatifnya suplai password sudo via vault — lebih ribet,
# dan password di repo publik = bencana.)
install -d -m 0755 /etc/sudoers.d
printf '%s ALL=(ALL:ALL) NOPASSWD:ALL\n' "$NEW_USER" > "$SUDOERS_DROPIN"
chmod 0440 "$SUDOERS_DROPIN"
visudo -cf "$SUDOERS_DROPIN" || fail "Sudoers drop-in tidak valid."

# --- 3. Ringkasan ---
echo "=================================================="
echo "[+] ACCESS PROVISIONING SELESAI"
echo "[+] User        : $NEW_USER (password locked, key-only)"
echo "[+] SSH         : port 22, konfigurasi default distro"
echo "[+] Sudo        : NOPASSWD via /etc/sudoers.d/90-$NEW_USER"
echo "=================================================="
echo
echo "[!] Sengaja TIDAK ada hardening sshd / ufw di lapis 1."
echo "[!] Lanjut: jalankan infra-ansible (role ssh-hardening +"
echo "    firewall) dari laptop — jangan biarkan VM terbuka lama."
echo
echo "Uji akses dari laptop:"
echo "ssh -i ~/.ssh/id_ed25519 $NEW_USER@IP_VM"
