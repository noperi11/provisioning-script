#!/usr/bin/env bash

#===============================================================================
# Bootstrap Server Provisioning
# Melakukan:
#   1. Validasi root & konfigurasi
#   2. Buat user deploy non-root
#   3. Sudo passwordless untuk user deploy
#   4. Injeksi SSH public key ke ~/.ssh/authorized_keys
#   5. Instalasi Python 3 + python3-pip
#   6. Set hostname sistem
#
#===============================================================================
set -euo pipefail

# --- Konfigurasi ---
DEPLOY_USER="deploy"
SSH_PUBLIC_KEY="<YOUR_KEY>"
NEW_HOSTNAME="<NEW_HOSTNAME>"
SUDOERS_FILE="/etc/sudoers.d/90-${DEPLOY_USER}-nopasswd"
SUDOERS_RULE="${DEPLOY_USER} ALL=(ALL) NOPASSWD:ALL"

# --- Helper ---
info() { printf '[bootstrap] %s\n' "$*"; }
fail() { printf '[bootstrap] GAGAL: %s\n' "$*" >&2; exit 1; }
tmpfile=""
trap 'rm -f "${tmpfile:-}"' EXIT

is_placeholder() {
    case "$1" in
        ""|"<"*) return 0 ;;
        *)       return 1 ;;
    esac
}

# apt-get update cukup sekali walau dipanggil dari beberapa tahap
PKG_INDEX_UPDATED=0

ensure_pkg_index() {
    if [ "$PKG_INDEX_UPDATED" -eq 0 ]; then
        info "Memperbarui index paket..."
        apt-get update -qq
        PKG_INDEX_UPDATED=1
    fi
}

# Instal paket lewat manajer paket yang tersedia (Debian/Ubuntu atau RHEL/Fedora)
pkg_install() {
    if command -v apt-get >/dev/null 2>&1; then
        ensure_pkg_index
        DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y "$@"
    else
        fail "tidak ada manajer paket yang didukung (apt-get/dnf)."
    fi
}

# --- 1. Validasi awal: root & placeholder ---
[ "$(id -u)" -eq 0 ] || fail "skrip harus dijalankan sebagai root (sudo $0)"

is_placeholder "$SSH_PUBLIC_KEY" && fail "SSH_PUBLIC_KEY belum diisi di blok Konfigurasi."
is_placeholder "$NEW_HOSTNAME"  && fail "NEW_HOSTNAME belum diisi di blok Konfigurasi."

info "Validasi awal OK (root, konfigurasi lengkap)."

# --- 2. Buat user deploy (non-root) ---
if getent passwd "$DEPLOY_USER" >/dev/null 2>&1; then
    info "User '${DEPLOY_USER}' sudah ada — melewati pembuatan."
else
    useradd --create-home --shell /bin/bash "$DEPLOY_USER"
    info "User '${DEPLOY_USER}' dibuat."
fi

USER_HOME=$(getent passwd "$DEPLOY_USER" | cut -d: -f6)
USER_GROUP=$(id -gn "$DEPLOY_USER")
[ -n "$USER_HOME" ] || fail "home directory untuk '${DEPLOY_USER}' tidak ditemukan."

# --- 3. Sudo passwordless untuk user deploy, pakai visudo biar ngga lockout ---
command -v visudo >/dev/null 2>&1 || pkg_install sudo

if [ -f "$SUDOERS_FILE" ] && grep -qxF "$SUDOERS_RULE" "$SUDOERS_FILE"; then
    info "Aturan sudo passwordless sudah ada — melewati."
else
    info "Menulis aturan sudo passwordless (${SUDOERS_FILE})..."
    tmpfile=$(mktemp)
    printf '%s\n' "$SUDOERS_RULE" > "$tmpfile"
    chmod 0440 "$tmpfile"
    visudo -cf "$tmpfile" >/dev/null || fail "aturan sudoers tidak valid; tidak dipasang."
    mv "$tmpfile" "$SUDOERS_FILE"
    info "Aturan sudo terpasang dan tervalidasi."
fi

# --- 4. Injeksi SSH public key ke authorized_keys ---
info "Memasang SSH public key untuk '${DEPLOY_USER}'..."
SSH_DIR="${USER_HOME}/.ssh"
AUTH_KEYS_FILE="${SSH_DIR}/authorized_keys"
install -d -m 0700 -o "$DEPLOY_USER" -g "$USER_GROUP" "$SSH_DIR"
[ -f "$AUTH_KEYS_FILE" ] || install -m 0600 -o "$DEPLOY_USER" -g "$USER_GROUP" /dev/null "$AUTH_KEYS_FILE"
if grep -qxF "$SSH_PUBLIC_KEY" "$AUTH_KEYS_FILE"; then
    info "Key sudah ada di authorized_keys — melewati."
else
    printf '%s\n' "$SSH_PUBLIC_KEY" >> "$AUTH_KEYS_FILE"
    info "Key ditambahkan."
fi
chown "$DEPLOY_USER:$USER_GROUP" "$AUTH_KEYS_FILE"
chmod 0700 "$SSH_DIR"
chmod 0600 "$AUTH_KEYS_FILE"
info "Permission SSH (700 / 600)."

# --- 5. Instalasi Python 3 + pip ---
if command -v python3 >/dev/null 2>&1 && command -v pip3 >/dev/null 2>&1; then
    info "Python 3 dan pip sudah terpasang — melewati ($(python3 --version))."
else
    info "Menginstal Python 3 + python3-pip..."
    pkg_install python3 python3-pip
    command -v python3 >/dev/null 2>&1 || fail "python3 tidak ditemukan setelah instalasi."
    command -v pip3    >/dev/null 2>&1 || fail "pip3 tidak ditemukan setelah instalasi."
    info "Python terpasang: $(python3 --version)."
fi

# --- 6. Set hostname sistem ---
command -v hostnamectl >/dev/null 2>&1 || fail "hostnamectl tidak tersedia (butuh systemd)."
OLD_HOSTNAME=$(hostnamectl --static)
if [ "$OLD_HOSTNAME" = "$NEW_HOSTNAME" ]; then
    info "Hostname sudah '${NEW_HOSTNAME}' — melewati."
else
    info "Mengganti hostname '${OLD_HOSTNAME}' -> '${NEW_HOSTNAME}'..."
    hostnamectl set-hostname "$NEW_HOSTNAME"
    # Perbarui baris 127.0.1.1 di /etc/hosts bila ada
    if grep -q '^127\.0\.1\.1' /etc/hosts; then
        sed -i "/^127\.0\.1\.1/s/${OLD_HOSTNAME}/${NEW_HOSTNAME}/g" /etc/hosts || true
        info "/etc/hosts diperbarui."
    fi
    info "Hostname baru aktif: $(hostnamectl --static)."
fi


info "==== Bootstrap selesai ===="
echo "Silahkan SSH ke $(hostname -I | awk '{print $1}')"
echo "Public IP: $(curl -s ifconfig.me)")"
