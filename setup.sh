#!/usr/bin/env bash
set -euo pipefail

# Pastikan script dijalankan sebagai root
if [ "$EUID" -ne 0 ]; then
  echo "[-] Jalankan script ini sebagai root (sudo)."
  exit 1
fi

echo "=========================================="
echo " MEMULAI AUTOMATED SERVER PROVISIONING"
echo "=========================================="

bash scripts/hardening.sh
bash scripts/firewall.sh
bash scripts/packages.sh
bash scripts/system.sh
bash scripts/autoupdate.sh

echo "=========================================="
echo " PROVISIONING SELESAI!"
echo "======================================="

echo "======================================="
echo " MELAKUKAN RESTART"
echo "======================================="
needrestart -r a
