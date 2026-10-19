# Provisioning Script

One-shot bash provisioning for a fresh Linux server (Ubuntu/Debian, or anything with
`apt-get`/`dnf`). Run the installer as root and it will:

1. Create a non-root `deploy` user
2. Give that user passwordless sudo (validated with `visudo` before installing)
3. Inject your SSH public key into `~deploy/.ssh/authorized_keys` (700 / 600)
4. Install Python 3 + `python3-pip`
5. Set the hostname (and update the `127.0.1.1` line in `/etc/hosts`)

Both scripts are idempotent: re-running them skips whatever is already in place.

## Usage

### 1. Fork this repo

Use the Fork button on GitHub so you get your own copy to edit — the config lives in
the repo, and the installer always clones from it.

### 2. Turn `.env.example` into `.env` and fill in your values

```bash
git clone https://github.com/YOUR_USERNAME/provisioning-script.git
cd provisioning-script
cp .env.example .env
nano .env
```

| Variable         | What it is                                             | Example                                        |
| ---------------- | ------------------------------------------------------ | ---------------------------------------------- |
| `DEPLOY_USER`    | Non-root user to create (default: `deploy`)             | `deploy`                                       |
| `SSH_PUBLIC_KEY` | Public key that gets SSH access to that user            | `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... me@laptop` |
| `NEW_HOSTNAME`   | Hostname for the server                                 | `web-01`                                       |

Values may contain spaces without quotes — that matters for the SSH key, so paste the
whole `ssh-ed25519 ...` line as-is. `.env` is gitignored; never commit your keys.

### 3. Run the installer on the server

On a fresh shell on the target box, fetch the installer and the config template into the
same directory, fill in `.env`, and run it (the installer picks up the `.env` sitting
beside it):

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/provisioning-script/main/install.sh   -o /tmp/install.sh
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/provisioning-script/main/.env.example -o /tmp/.env
nano /tmp/.env
sudo bash /tmp/install.sh
```

Or, if you already cloned the repo on the box (`.env` sits beside `install.sh`):

```bash
sudo bash install.sh
```

The installer clones your fork to `/opt/provisioning-script` and runs
`bootstrap-server.sh` from there. Point it at a different fork or branch with
`REPO_URL` / `REPO_BRANCH` / `INSTALL_DIR`, e.g.:

```bash
sudo REPO_URL=https://github.com/YOUR_USERNAME/provisioning-script.git bash /tmp/install.sh
```

Environment variables win over `.env`, so you can also skip the file entirely:

```bash
sudo SSH_PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)" NEW_HOSTNAME=web-01 bash install.sh
```

### 4. Log in

When the run finishes it prints the server's IP. Connect with:

```bash
ssh deploy@<server-ip>
```

## Requirements

- Root access on the target machine (`sudo bash ...`)
- `git` on the target (needed by the installer: `sudo apt-get install -y git`)
- `systemd` on the target (`hostnamectl` is used to set the hostname)

## Files

| File                  | Role                                                      |
| --------------------- | --------------------------------------------------------- |
| `install.sh`          | Entry point: clones the repo, loads `.env`, runs bootstrap |
| `bootstrap-server.sh` | Does the actual provisioning                               |
| `.env.example`        | Config template — copy to `.env` and fill in               |
