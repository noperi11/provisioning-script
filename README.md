# provisioning-script

Bootstrap bash satu-pakai untuk VPS/VM Ubuntu — **lapis 1 saja**:
siapkan sistem supaya *bisa di-SSH oleh orkestrator*. Repo ini
**sengaja tidak** lagi melakukan hardening SSH, firewall, timezone,
auto-update, apalagi Docker/aplikasi — semua kebijakan itu milik
lapis 2 (repo Ansible `infra-ansible`, lihat `plan-docker-ansible.txt`).

Prinsip: **satu file konfigurasi = satu pemilik.** Dua config
manager yang menyentuh `/etc/ssh`, ufw, dan daftar paket adalah
resep lockout. Maka repo ini dibekukan sebagai "image prep" minimal
dan bertag; Ansible yang hidup sehari-hari.

## Arsitektur tiga lapisan

| Lapis | Milik | Isi |
|-------|-------|-----|
| 0 | AWS user data (cloud-init) | ~15 baris: pasang git, clone tag, jalankan installer |
| 1 | **repo ini** | bootstrap: packages → access (+ sentinel) |
| 2 | `infra-ansible` (luar repo) | ssh-hardening, firewall, system, updates, docker-host, app-deploy |

## Cara pakai

Dari laptop, lewat bootstrap (disarankan — ini yang dipakai user data):

```bash
export PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)"   # WAJIB, tanpa ini gagal di awal
export REPO_REF="v1.0"                              # pin ke tag, jangan main
curl -fsSL https://raw.githubusercontent.com/noperi11/provisioning-script/${REPO_REF}/installer.sh -o /tmp/installer.sh
sudo bash /tmp/installer.sh
```

`installer.sh` memastikan git ada, clone repo (shallow, ter-pin ref,
commit hash dicatat di output) ke `/opt/server-provisioning`, lalu
menyerahkan kendali ke `setup.sh`. Bisa juga dijalankan langsung di
VM (mis. lewat console provider):

```bash
sudo PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)" bash setup.sh
```

## Konfigurasi tunggal

Semua nilai hidup di **`vars.sh`** dan di-source oleh semua stage.

| Variabel | Default | Keterangan |
|----------|---------|------------|
| `NEW_USER` | `user-admin` | user sudo, login key-only |
| `PUBLIC_KEY` | *(wajib via env)* | kunci SSH; tanpa ini run gagal **sebelum** ada perubahan apa pun |
| `REPO_URL` / `REPO_REF` | repo ini / `main` | pin ke tag release saat bootstrap |
| `INSTALL_DIR` | `/opt/server-provisioning` | lokasi clone |
| `SENTINEL_FILE` | `/var/lib/server-provisioning.done` | penanda base siap untuk lapis 2 |
| `PACKAGES` | curl, wget, git, ca-certificates, gnupg | alat bootstrap saja |

## Apa yang dilakukan tiap stage

1. **packages.sh** — `apt update/upgrade`, `openssh-server`, paket
   alat dari `vars.sh`; pastikan sshd aktif di **port default 22**
   dengan konfigurasi bawaan distro.
2. **access.sh** — buat `user-admin` (password **di-lock**, jadi
   key-only), pasang `PUBLIC_KEY` di `authorized_keys`, sudo
   `NOPASSWD` via `/etc/sudoers.d/90-user-admin` (validasi
   `visudo -cf`). Ini modal Ansible pakai `become: true`.

Log lengkap: `/var/log/provisioning.log`. Penanda selesai:
`/var/lib/server-provisioning.done` (berisi timestamp UTC + commit
hash dicatat di log).

## Yang TIDAK dilakukan repo ini (sengaja)

| Hal | Sekarang milik |
|-----|----------------|
| Port SSH 2222, sshd_config, `sshd -t/-T` | role `ssh-hardening` (Ansible) |
| ufw, fail2ban | role `firewall` (Ansible) |
| timezone, locale, NTP | role `system` (Ansible) |
| unattended-upgrades | role `updates` (Ansible) |
| Docker, Compose, deploy app | role `docker-host`, `app-deploy` (Ansible) |

**Status setelah bootstrap = masih terbuka**: port 22, config sshd
bawaan, ufw off. Ini jendela sementara — jalankan Ansible segera.
(Untuk demo VPS satu-dua hari di jaringan privat, dapat diterima;
untuk publik, jangan dibiarkan.)

## Recovery kalau terkunci (lockout)

Lockout nyata terjadi setelah lapis 2 berjalan (port 22 ditutup,
SSH pindah 2222 key-only). Prosedur:

1. Masuk lewat **console provider** (AWS EC2 Serial Console, mount
   EBS di instance lain, atau web console VPS).
2. `ufw allow 22/tcp && systemctl reload ssh`, cek
   `sshd -T | grep -E '^(port|permitrootlogin|passwordauth)'`.
3. Curiga sshd rusak: `rm /etc/ssh/sshd_config.d/50-hardening.conf`
   lalu `sshd -t && systemctl restart ssh` (drop-in adalah satu-satunya
   sumber perubahan dari Ansible; menghapusnya mengembalikan default).
4. Perbaiki di repo Ansible, re-run `--check --diff`, lalu apply.

## Docker & UFW (catatan untuk lapis 2)

Container yang mem-publish port (mis. `ports: "80:80"`) **melewati
UFW** — Docker menulis rule NAT langsung di chain iptables. Pilihan
saat lapis 2 dibangun: bind `127.0.0.1:PORT` di belakang reverse
proxy, atau kelola chain `DOCKER-USER`. Putuskan sebelum deploy
pertama.

## Batas repo ini

- Tidak memasang Docker/Compose/app, tidak menyentuh sshd_config/ufw.
- Tidak menyimpan secret apa pun. `PUBLIC_KEY` hanya lewat
  environment, tidak pernah di-commit.
- Perubahan harus di-commit + push + **di-tag** sebelum bootstrap VM
  memakai versi baru; `REPO_REF` menunjuk tag, bukan `main`.
- Uji end-to-end di 1 VM fresh + re-run sekali (bukti idempotensi)
  sebelum tag versi baru.
