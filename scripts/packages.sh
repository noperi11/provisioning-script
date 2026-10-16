#!/usr/bin/env bash
set -euo pipefail

echo "[+] Mengupdate sistem & menginstall paket dasar..."
apt-get update && apt-get upgrade -y

PACKAGES=(
    curl
    wget
    git
    htop
    vim
    ufw
    fail2ban
    unzip
    net-tools
    ca-certificates
    gnupg
)

apt-get install -y "${PACKAGES[@]}"
echo "[+] Paket dasar berhasil diinstall."
