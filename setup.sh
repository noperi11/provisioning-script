#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Setup Utama Provisioning
# Alur: packages -> hardening -> firewall -> system -> autoupdate
# ============================================================

# --- 1. Validasi Hak Akses Root ---
if [ "$EUID" -ne 0 ]; then
    echo "[-] Jalankan script ini sebagai root (sudo)."
    exit 1
fi

echo "=========================================="
echo " MEMULAI AUTOMATED SERVER PROVISIONING"
echo "=========================================="

# --- 2. Mode noninteractive untuk apt/dpkg ---
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

# --- 3. Jalankan tahapan provisioning ---
bash scripts/packages.sh      # update sistem + openssh-server + paket dasar
bash scripts/hardening.sh     # user, public key, port SSH, lockdown autentikasi
bash scripts/firewall.sh      # UFW: deny incoming, izin SSH/HTTP/HTTPS
bash scripts/system.sh        # timezone & locale
bash scripts/autoupdate.sh    # unattended-upgrades

echo "=========================================="
echo " PROVISIONING SELESAI!"
echo "=========================================="

# --- 4. Restart layanan jika perlu ---
echo "=========================================="
echo " MELAKUKAN RESTART"
echo "=========================================="

if command -v needrestart >/dev/null 2>&1; then
    needrestart -r a
else
    echo "[+] needrestart tidak tersedia, melewati restart otomatis."
fi
