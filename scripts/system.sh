#!/usr/bin/env bash
set -euo pipefail

echo "[+] Mengatur Timezone ke UTC / Asia/Jakarta..."
timedatectl set-timezone Asia/Jakarta

echo "[+] Mengatur Locale..."
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8

# echo "[+] Memastikan NTP / Systemd-timesyncd aktif..."
# timedatectl set-ntp on
# timedatectl status
