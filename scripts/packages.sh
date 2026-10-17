#!/usr/bin/env bash
set -euo pipefail

echo "[+] Mengupdate sistem..."
apt-get update && apt-get upgrade -y

echo "[+] Menginstall OpenSSH Server..."
apt-get install -y openssh-server

echo "[+] Menginstall paket dasar..."
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
