#!/usr/bin/env bash

#   =========================================
#   Bisa juga pakai dibawah ini untuk install
#   curl -fsSL https://raw.githubusercontent.com/noperi11/provisioning-script/main/install.sh -o /tmp/install.sh
#   sudo bash /tmp/install.sh
#   =========================================

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/noperi11/provisioning-script.git}"
REPO_BRANCH="${REPO_BRANCH:-main}"
INSTALL_DIR="${INSTALL_DIR:-/opt/provisioning-script}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info() { printf '[installer] %s\n' "$*"; }
fail() { printf '[installer] GAGAL: %s\n' "$*" >&2; exit 1; }

# Baca file .env baris per baris (bukan `source`) supaya nilai yang berisi
# spasi — seperti SSH public key — tidak perlu diberi kutip.
load_env() {
    local line key value
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"                                  # aman untuk CRLF
        case "$line" in ''|'#'*) continue ;; esac             # kosong / komentar
        [ "${line#*=}" != "$line" ] || continue               # baris tanpa '='
        key="${line%%=*}"; value="${line#*=}"
        [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue  # nama variabel valid
        value="${value#"${value%%[![:space:]]*}"}"            # trim spasi depan
        case "$value" in \"*\"|\'*\') value="${value:1:${#value}-2}" ;; esac
        if [ -n "${!key:-}" ]; then continue; fi              # env mengalahkan .env
        export "$key=$value"
    done < "$1"
}

[ "$(id -u)" -eq 0 ] || fail "skrip harus dijalankan sebagai root (sudo bash $0)"
command -v git >/dev/null 2>&1 || fail "git tidak ditemukan (sudo apt-get install -y git)"

# --- 1. Download repo (selalu clone baru) ---
if [ -d "$INSTALL_DIR" ]; then
    info "Menghapus clone lama di ${INSTALL_DIR}..."
    rm -rf "${INSTALL_DIR:?}"
fi

info "Mengclone repo ke ${INSTALL_DIR}..."
git clone --branch "$REPO_BRANCH" "$REPO_URL" "$INSTALL_DIR"

# --- 2. Muat konfigurasi dari .env (di samping installer, atau di dalam repo) ---
if [ -z "${ENV_FILE:-}" ]; then
    for cand in "${SCRIPT_DIR}/.env" "${INSTALL_DIR}/.env"; do
        if [ -f "$cand" ]; then ENV_FILE="$cand"; break; fi
    done
fi
if [ -n "${ENV_FILE:-}" ]; then
    info "Memuat konfigurasi dari ${ENV_FILE}"
    load_env "$ENV_FILE"
else
    info "Tidak ada .env — mengharapkan SSH_PUBLIC_KEY/NEW_HOSTNAME dari environment."
fi

# --- 3. Jalankan provisioning ---
SCRIPT_PATH="${INSTALL_DIR}/bootstrap-server.sh"
[ -f "$SCRIPT_PATH" ] || fail "${SCRIPT_PATH} tidak ada di repo."
info "Menjalankan bootstrap-server.sh..."
exec bash "$SCRIPT_PATH"
