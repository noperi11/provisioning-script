# Provisioning Script

Provision a fresh Linux server in one command. `install.sh` fetches the repo, loads your config from `.env`, and runs `bootstrap-server.sh` as root. Works on Ubuntu/Debian and anything with `apt-get` or `dnf`.

## What it does

1. Creates a non-root `deploy` user
2. Gives that user passwordless sudo (the rule is validated with `visudo` before it is installed)
3. Installs your SSH public key into `~deploy/.ssh/authorized_keys` (permissions 700 / 600)
4. Installs Python 3 and `python3-pip`
5. Sets the hostname and updates the `127.0.1.1` line in `/etc/hosts`, if that line exists

Every step is idempotent: re-running skips whatever is already in place. The only thing refreshed on each run is the repo clone in `/opt/provisioning-script`.

## Requirements

- Root access on the target machine (`sudo bash ...`)
- `git` on the target (`sudo apt-get install -y git`)
- `systemd` on the target (the hostname is set with `hostnamectl`)

## Usage

### Quick run (no clone needed)

Fetch the installer and the config template into the same directory, fill in `.env`, and run. The installer picks up the `.env` sitting beside it:

```bash
curl -fsSL https://raw.githubusercontent.com/noperi11/provisioning-script/main/install.sh -o /tmp/install.sh
curl -fsSL https://raw.githubusercontent.com/noperi11/provisioning-script/main/.env.example -o /tmp/.env
nano /tmp/.env
sudo bash /tmp/install.sh
```

### From a clone

```bash
git clone https://github.com/noperi11/provisioning-script.git
cd provisioning-script
cp .env.example .env
nano .env
sudo bash install.sh
```

### Without a .env file

Environment variables win over `.env`, so you can skip the file entirely:

```bash
sudo SSH_PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)" NEW_HOSTNAME=web-01 bash install.sh
```

### From your own fork

`install.sh` clones `REPO_URL` (default: this repo) and runs `bootstrap-server.sh` from that clone. To provision from your own copy, point it at your fork:

```bash
sudo REPO_URL=https://github.com/YOUR_USERNAME/provisioning-script.git bash /tmp/install.sh
```

## Configuration

| Variable         | What it is                                              | Default                    |
| ---------------- | ------------------------------------------------------- | -------------------------- |
| `DEPLOY_USER`    | Non-root user to create                                  | `deploy`                   |
| `SSH_PUBLIC_KEY` | Public key that gets SSH access to that user             | required, no usable default |
| `NEW_HOSTNAME`   | Hostname for the server                                  | required, no usable default |
| `REPO_URL`       | Repo the installer clones to get `bootstrap-server.sh`   | `noperi11/provisioning-script` |
| `REPO_BRANCH`    | Branch to clone                                          | `main`                     |
| `INSTALL_DIR`    | Where the repo is cloned                                 | `/opt/provisioning-script` |
| `ENV_FILE`       | Explicit path to the config file                         | first `.env` found beside the installer, then in the clone |

`SSH_PUBLIC_KEY` and `NEW_HOSTNAME` fail fast: the run aborts if either is unset or still a `<PLACEHOLDER>` value from the template.

Values may contain spaces without quotes. That matters for the SSH key, so paste the whole `ssh-ed25519 ...` line as-is. `.env` is gitignored; never commit your keys.

## After the run

The script prints the server's local and public IP. Connect with:

```bash
ssh deploy@<server-ip>
```

## Files

| File                  | Role                                                        |
| --------------------- | ----------------------------------------------------------- |
| `install.sh`          | Entry point: clones the repo, loads `.env`, runs bootstrap   |
| `bootstrap-server.sh` | Does the actual provisioning                                 |
| `.env.example`        | Config template. Copy to `.env` and fill in                  |
