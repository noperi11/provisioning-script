#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Sumber konfigurasi tunggal — di-source oleh setup.sh,
# installer.sh (via env), dan stage di scripts/.
#
# LAPIS 1 = bootstrap + access SAJA. Kebijakan server (port
# SSH, sshd_config, ufw, fail2ban, timezone, NTP, auto-update,
# Docker, aplikasi) adalah milik LAPIS 2 (repo Ansible).
# Jangan tambahkan variabel kebijakan ke file ini.
# ============================================================

# --- Identitas akses ---
NEW_USER="${NEW_USER:-user-admin}"

# --- Kunci SSH ---
# Suplai lewat environment (installer.sh / user data), JANGAN
# hardcode. Placeholder di bawah sengaja gagal cepat kalau lupa.
PUBLIC_KEY="${PUBLIC_KEY:-<PUBLIC_KEY_KAMU>}"

# --- Repository (installer.sh) ---
REPO_URL="${REPO_URL:-https://github.com/noperi11/provisioning-script.git}"
REPO_REF="${REPO_REF:-main}"
INSTALL_DIR="${INSTALL_DIR:-/opt/server-provisioning}"

# --- Sentinel untuk orkestrator berikutnya (Ansible) ---
SENTINEL_FILE="${SENTINEL_FILE:-/var/lib/server-provisioning.done}"

# --- Daftar paket bootstrap ---
# Hanya ALAT yang dibutuhkan agar lapis 2 bisa masuk dan
# bekerja. Kebijakan paket aplikasi (vim, htop, fail2ban,
# docker, ufw, unattended-upgrades, ...) BUKAN milik repo ini.
# shellcheck disable=SC2034  # dipakai oleh scripts/packages.sh
PACKAGES=(
    curl
    wget
    git
    ca-certificates
    gnupg
)
