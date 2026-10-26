Provision a fresh Ubuntu/Debian server: set the hostname, create a sudo-less
non-root user with an SSH key, move SSH to a custom port, disable root login,
enable UFW, install a package list, and set the timezone.

Two entry points, same payload:

- `bootstrap-server.sh` â€” the provisioning script. Run it directly.
- `install.yaml` â€” a cloud-config for cloud-init (Hetzner, DigitalOcean, Proxmox,
  QEMU, etc.) that downloads `bootstrap-server.sh` from your own private repo and
  runs it on first boot.

## What it does

In order:

1. Refuses to run unless it is root and a `.env` file is in the **current
   directory**.
2. Appends everything it prints to `/var/log/server-bootstrap.log`.
3. Sets the hostname with `hostnamectl set-hostname`.
4. Creates the user (`useradd -m -s /bin/bash`) and sets its password with
   `chpasswd`.
5. Installs `pub_key` into `/home/<username>/.ssh/authorized_keys`
   (`700` on `.ssh`, `600` on `authorized_keys`).
6. Sets `PermitRootLogin no` in `/etc/ssh/sshd_config`, by rewriting the
   commented-out template line (`s/#PermitRootLogin.*/PermitRootLogin no/`).
7. Opens the new SSH port in UFW, *then* rewrites `Port`, validates the config
   with `sshd -t`, and restarts `ssh.service` (disabling `ssh.socket` first, for
   socket-activated Debian).
8. Prints the listening socket so you can confirm the port took.
9. UFW: deny incoming, allow outgoing, `--force enable`.
10. `apt-get install -y` each entry in `packages`
    (`DEBIAN_FRONTEND=noninteractive`).
11. Sets the timezone with `timedatectl set-timezone`.

## Requirements

- Ubuntu or Debian. The script uses `apt-get`, `ufw`, `hostnamectl`,
  `timedatectl`, and the Debian unit name `ssh.service` â€” it will not work on
  RHEL-family distros, where the unit is `sshd.service`.
- Root on the target.
- `curl` on the target, only for the cloud-init path.

## Configuration

Copy `.env.example` to `.env` and fill it in. The script validates none of these:
an unset one expands to an empty string and the corresponding command quietly
does the wrong thing (`hostnamectl set-hostname ""`, `useradd ""`,
`Port ` with no number). Only `timezone` ships with a usable value
(`Asia/Jakarta`).

| Variable       | Meaning                                                        | Example                    |
| -------------- | -------------------------------------------------------------- | -------------------------- |
| `new_hostname` | Hostname to set                                                | `web-01`                   |
| `username`     | Non-root user to create                                        | `admin`                    |
| `password`     | Password for that user (`chpasswd`)                            | `correct-horse-battery`    |
| `pub_key`      | Full public key line, quoted                                   | `"ssh-ed25519 AAAA... me"` |
| `new_ssh_port` | SSH port to move to                                            | `2222`                     |
| `packages`     | Space-separated package list                                   | `"git htop curl"`          |
| `timezone`     | `timedatectl` timezone                                         | `Asia/Jakarta`             |

Rules for `.env`, since it is sourced by bash rather than parsed:

- **No space before `=`.** Write `new_ssh_port="2222"`, not
  `new_ssh_port= "2222"`. With a space, bash treats the value as a command,
  fails with `command not found`, and leaves the variable **empty** â€” which
  breaks the SSH port and the package list. `.env.example` ships with this
  mistake on those two lines; fix it before running.
- Quote values containing spaces (`pub_key`, `packages`).
- Keep it out of version control. It holds a plaintext password and your key;
  this repo has no `.gitignore`, so add one to your fork.

## Usage

### Directly

```bash
git clone https://github.com/noperi11/provisioning-script.git
cd provisioning-script
cp .env.example .env
nano .env                       # fill in, and remove the space before `=`
sudo bash bootstrap-server.sh
```

The `.env` lookup is relative to the current directory, so `cd` into the
directory holding it before running.

### Via cloud-init

Edit `install.yaml`: replace `<Your Github Personal Access Token>` and
`<Your_Username>/<Your_Repo>`, and make sure your repo has a real `.env` at
`main` â€” the cloud-config downloads `.env`, not `.env.example`. Feed the result
to your provider as user-data / cloud-config. On first boot it pulls
`bootstrap-server.sh` and `.env` into `/tmp` and runs the script from there.

A PAT in cloud-config is written to the instance and is typically readable from
its metadata. Treat it as a secret scoped to this job: a fine-grained token with
read-only access to the single repo, and rotate it after provisioning. If your
provider can put a private repo's file straight into user-data, that is the
safer route.

## After the run

```bash
ssh -p <new_ssh_port> <username>@<server-ip>
```

The new user is **not** in the sudo group â€” the script never grants it. Either
keep administering as root over the key, or add sudo deliberately:

```bash
usermod -aG sudo <username>
```

## Files

| File                  | Role                                                     |
| --------------------- | -------------------------------------------------------- |
| `bootstrap-server.sh` | The provisioning script. Runs as root, reads `./.env`.   |
| `.env.example`        | Template. Copy to `.env`, fill in, fix the spacing.      |
| `install.yaml`        | cloud-config that fetches and runs the script on boot.   |
