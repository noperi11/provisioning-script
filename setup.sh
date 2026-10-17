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

export DEBIAN_FRONTEND=noninteractive

# Bersihkan dpkg.cfg lama yang salah tulis (penyebab error dpkg "unknown option 'options'")
rm -f /etc/dpkg/dpkg.cfg.d/ssh

# --force-confold / --force-confdef adalah opsi apt (bukan dpkg.cfg),
# jadi disimpan di apt.conf.d agar semua pemanggilan apt/dpkg memakainya.
cat > /etc/apt/apt.conf.d/99force-conf <<'EOF'
Dpkg::Options {
    "--force-confold";
    "--force-confdef";
};
EOF

bash scripts/packages.sh
bash scripts/hardening.sh
bash scripts/firewall.sh
bash scripts/system.sh
bash scripts/autoupdate.sh

echo "=========================================="
echo " PROVISIONING SELESAI!"
echo "=========================================="

echo "======================================="
echo " MELAKUKAN RESTART"
echo "======================================="
needrestart -r a
