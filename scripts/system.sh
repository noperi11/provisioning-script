#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# System
# Timezone dan locale server
# ============================================================

echo "[+] Mengatur Timezone ke Asia/Jakarta..."
timedatectl set-timezone Asia/Jakarta

echo "[+] Mengatur Locale..."
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8
