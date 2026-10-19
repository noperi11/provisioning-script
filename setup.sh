#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Provisioning Script for VPS/VM
# ============================================================

STAGE=""
log() { echo "[*] $*"; }
ok()  { echo "[+] $*"; }
err() { echo "[-] $*" >&2; }

# --- 1. Validasi Hak Akses Root ---
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    err "Jalankan script ini sebagai root (sudo)."
    exit 1
fi

# cd ke direktori repo supaya tidak bergantung cwd pemanggil
# (fix item 7: `sudo bash /opt/.../setup.sh` dari mana pun dulu gagal).
cd "$(dirname "$(readlink -f "$0")")"

# --- 2. Log + gagal keras dengan penanda stage ---
# Run setengah jadi adalah failure mode normal proyek ini (fix item 8):
# tanpa log + nama stage, diagnosisnya tebak-tebakan.
exec > >(tee -a /var/log/provisioning.log) 2>&1
trap 'err "GAGAL di stage: ${STAGE:-init} (baris $LINENO)"' ERR

echo "=========================================="
echo " MEMULAI BOOTSTRAP PROVISIONING (lapis 1)"
echo "=========================================="

# --- 3. Konfigurasi tunggal + mode noninteractive apt/dpkg ---
# shellcheck disable=SC1091
source ./vars.sh
export DEBIAN_FRONTEND=noninteractive
# needrestart jangan pernah membangkitkan reboot diam-diam;
# reboot adalah keputusan operator (dijadwalkan eksplisit di
# Ansible), bukan efek samping apt.
export NEEDRESTART_MODE=a

# Bersihkan dpkg.cfg lama yang salah tulis (penyebab error dpkg
# "unknown option 'options'" — bug commit f23b4ad).
rm -f /etc/dpkg/dpkg.cfg.d/ssh

# --force-confold / --force-confdef adalah opsi apt (bukan
# dpkg.cfg), jadi disimpan di apt.conf.d agar semua pemanggilan
# apt/dpkg memakainya.
cat > /etc/apt/apt.conf.d/99force-conf <<'EOF'
Dpkg::Options {
    "--force-confold";
    "--force-confdef";
};
EOF

# --- 4. Jalankan tahapan bootstrap ---
for STAGE in packages access; do
    log "Stage: $STAGE"
    bash "scripts/${STAGE}.sh"
    ok "Stage: $STAGE selesai"
done
STAGE=""

# --- 5. Sentinel: base siap dipakai orkestrator berikutnya ---
# cloud-init jalan asinkron; tanpa penanda ini, orkestrator
# (Ansible) bisa connect ke mesin yang belum selesai diproses.
date -u '+%Y-%m-%dT%H:%M:%SZ' > "$SENTINEL_FILE"
commit_hash="$(git -C "$PWD" rev-parse HEAD 2>/dev/null || echo 'n/a')"
log "Sentinel ditulis: $SENTINEL_FILE (commit: $commit_hash)"

echo "=========================================="
echo " BOOTSTRAP SELESAI"
echo " Akses   : ${NEW_USER}@<ip>:22 (key-only, sudo NOPASSWD)"
echo " Log     : /var/log/provisioning.log"
echo " Lanjut  : jalankan infra-ansible (lapis 2):"
echo "           ssh-hardening -> firewall -> system ->"
echo "           updates -> docker-host -> app-deploy"
echo "=========================================="
echo
echo "[!] Status VM MASIH TERBUKA: port 22, konfigurasi sshd"
echo "[!] default distro, ufw belum aktif. Ini sengaja — semua"
echo "[!] kebijakan adalah milik lapis 2. Minimize the gap:"
echo "[!] jalankan Ansible segera setelah bootstrap ini."
echo
echo "Uji akses dari laptop:"
echo "ssh -i ~/.ssh/id_ed25519 ${NEW_USER}@<ip>"
