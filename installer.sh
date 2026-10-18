#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Bootstrap Installer (lapis 0 -> lapis 1)
# Tugas: pastikan git ada, clone repo (ter-pin ref), serahkan
# ke setup.sh. Tidak ada logika provisioning di sini.
#
# Pemakaian di AWS user data / cloud-init:
#   export PUBLIC_KEY="ssh-ed25519 AAAA... kunci-laptop-anda"
#   export REPO_REF="v1.0"   # pin ke tag, jangan main
#   curl -fsSL <raw-url>/installer.sh -o /tmp/installer.sh
#   bash /tmp/installer.sh
# ============================================================

info() { echo "[*] $1"; }
ok()   { echo "[+] $1"; }
err()  { echo "[-] $1" >&2; }

# --- 1. Validasi Hak Akses Root ---
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    err "Installer ini harus dijalankan sebagai root (gunakan sudo)."
    exit 1
fi

# --- 2. Konfigurasi (bisa dioverride via environment) ---
REPO_URL="${REPO_URL:-https://github.com/noperi11/provisioning-script.git}"
REPO_REF="${REPO_REF:-main}"
INSTALL_DIR="${INSTALL_DIR:-/opt/server-provisioning}"

# --- 3. PUBLIC_KEY wajib disuplai dari lingkungan ---
# Gagal DI SINI, bukan setengah jalan setelah SSH berubah
# (fix: placeholder hardcode + set -e mati di tengah run).
if [[ -z "${PUBLIC_KEY:-}" || "${PUBLIC_KEY:-}" == "<PUBLIC_KEY_KAMU>" ]]; then
    err "Environment PUBLIC_KEY belum diisi."
    err "Contoh: export PUBLIC_KEY=\"\$(cat ~/.ssh/id_ed25519.pub)\""
    exit 1
fi
export PUBLIC_KEY

# --- 4. Pastikan git tersedia (fix item 3) ---
# Image Ubuntu cloud/minimal sering tidak punya git; dulu clone
# langsung mati diVM fresh.
if ! command -v git >/dev/null 2>&1; then
    info "git belum ada, memasang..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y git
fi

# --- 5. Clone repository (shallow + ref ter-pin, bisa diaudit) ---
if [ -d "$INSTALL_DIR" ]; then
    info "Direktori $INSTALL_DIR sudah ada, membersihkan..."
    rm -rf "$INSTALL_DIR"
fi

info "Mendownload $REPO_URL (ref: $REPO_REF)"
git clone --depth 1 --branch "$REPO_REF" "$REPO_URL" "$INSTALL_DIR"

COMMIT_HASH="$(git -C "$INSTALL_DIR" rev-parse HEAD)"
ok "Clone selesai. Commit: $COMMIT_HASH"

# --- 6. Atur hak akses eksekusi ---
cd "$INSTALL_DIR"

if [ ! -f "setup.sh" ]; then
    err "File setup.sh tidak ditemukan di dalam repository!"
    exit 1
fi

chmod +x setup.sh
if [ -d "scripts" ]; then
    chmod +x scripts/*.sh
fi

# --- 7. Eksekusi Skrip Utama ---
info "Bootstrap selesai! Menyerahkan kendali ke setup.sh..."
exec ./setup.sh
