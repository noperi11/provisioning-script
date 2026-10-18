#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Paket Bootstrap
# Update sistem + OpenSSH server + alat dasar agar lapis 2
# (Ansible) bisa masuk dan bekerja.
# Daftar paket hidup di SATU tempat: vars.sh (PACKAGES).
# ============================================================

# shellcheck disable=SC1091
source "$(dirname "$(readlink -f "$0")")/../vars.sh"

echo "[+] Mengupdate sistem..."
apt-get update && apt-get upgrade -y

echo "[+] Menginstall OpenSSH server + paket bootstrap..."
apt-get install -y openssh-server "${PACKAGES[@]}"

# Pastikan sshd aktif di port default (22) — satu-satunya syarat
# agar Ansible bisa connect. TIDAK ada hardening di sini; sshd
# tetap pada konfigurasi bawaan distro, dikelola penuh oleh
# role ssh-hardening di lapis 2.
systemctl enable ssh >/dev/null 2>&1 || systemctl enable sshd >/dev/null 2>&1 || true
if ! systemctl is-active --quiet ssh.service &&
   ! systemctl is-active --quiet sshd.service; then
    systemctl restart ssh.service || systemctl restart sshd.service
fi

echo "[+] sshd aktif di port default. Hardening = ranah lapis 2."
