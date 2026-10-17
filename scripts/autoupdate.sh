#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Auto Update
# unattended-upgrades untuk security update otomatis
# ============================================================

export NEEDRESTART_MODE=l

echo "[+] Menginstall unattended-upgrades..."
apt-get install -y unattended-upgrades apt-listchanges

echo "[+] Mengaktifkan unattended-upgrades secara otomatis..."
dpkg-reconfigure -f noninteractive unattended-upgrades

echo "[+] Konfigurasi selesai."
