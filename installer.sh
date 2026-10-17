#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Bootstrap Installer
# Tugas: siapkan key, clone repo, lalu serahkan ke setup.sh
# ============================================================

# --- Konfigurasi ---
INSTALL_DIR="/opt/server-provisioning"
REPO_URL="https://github.com/noperi11/provisioning-script.git"

# Public key laptop kamu — ganti <PUBLIC_KEY_KAMU> dengan isi ~/.ssh/id_ed25519.pub
export PUBLIC_KEY="<PUBLIC_KEY_KAMU>"

# --- Konfigurasi Warna untuk Output Terminal ---
readonly COLOR_RESET="\033[0m"
readonly COLOR_INFO="\033[1;34m"    # Biru
readonly COLOR_SUCCESS="\033[1;32m" # Hijau
readonly COLOR_WARN="\033[1;33m"    # Kuning
readonly COLOR_ERROR="\033[1;31m"   # Merah

print_info()    { echo -e "${COLOR_INFO}[*] $1${COLOR_RESET}"; }
print_success() { echo -e "${COLOR_SUCCESS}[+] $1${COLOR_RESET}"; }
print_warn()    { echo -e "${COLOR_WARN}[!] $1${COLOR_RESET}"; }
print_error()   { echo -e "${COLOR_ERROR}[-] $1${COLOR_RESET}"; }

# --- 1. Validasi Hak Akses Root ---
if [ "$EUID" -ne 0 ]; then
    print_error "Installer ini harus dijalankan sebagai root (gunakan sudo)."
    exit 1
fi

echo "=================================================="
print_info "BOOTSTRAP INSTALLER DIMULAI..."
echo "=================================================="

# --- 2. Siapkan Direktori Kerja ---
if [ -d "$INSTALL_DIR" ]; then
    print_warn "Direktori $INSTALL_DIR sudah ada, membersihkan..."
    rm -rf "$INSTALL_DIR"
fi

# --- 3. Clone Repository ---
print_info "Mendownload skrip dari repository: $REPO_URL"
git clone "$REPO_URL" "$INSTALL_DIR"

# --- 4. Atur Hak Akses Eksekusi ---
cd "$INSTALL_DIR"

if [ ! -f "setup.sh" ]; then
    print_error "File setup.sh tidak ditemukan di dalam repository!"
    exit 1
fi

chmod +x setup.sh
[ -d "scripts" ] && chmod +x scripts/*.sh

echo "=================================================="
print_success "Bootstrap selesai! Menyerahkan kendali ke setup.sh..."
echo "=================================================="

# --- 5. Eksekusi Skrip Utama ---
exec ./setup.sh
