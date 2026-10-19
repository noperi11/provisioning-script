#!/usr/bin/env bash

#===============================================================================
# Bootstrap Server Provisioning (run by install.sh from the repo)
# Performs:
#   1. Validate root & configuration
#   2. Create a non-root deploy user
#   3. Passwordless sudo for the deploy user
#   4. Inject the SSH public key into ~/.ssh/authorized_keys
#   5. Install Python 3 + python3-pip
#   6. Set the system hostname
#
#===============================================================================
set -euo pipefail

# --- Configuration ---
# Values can come from the environment (forwarded by install.sh) or from the defaults below.
DEPLOY_USER="${DEPLOY_USER:-deploy}"
SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY:-<YOUR_PUBLIC_KEY>}"
NEW_HOSTNAME="${NEW_HOSTNAME:-<NEW_HOSTNAME>}"
SUDOERS_FILE="/etc/sudoers.d/90-${DEPLOY_USER}-nopasswd"
SUDOERS_RULE="${DEPLOY_USER} ALL=(ALL) NOPASSWD:ALL"

# --- Helpers ---
info() { printf '[bootstrap] %s\n' "$*"; }
fail() { printf '[bootstrap] FAILED: %s\n' "$*" >&2; exit 1; }
tmpfile=""
trap 'rm -f "${tmpfile:-}"' EXIT

is_placeholder() {
    case "$1" in
        ""|"<"*) return 0 ;;
        *)       return 1 ;;
    esac
}

# apt-get update runs only once even if called from several stages
PKG_INDEX_UPDATED=0

ensure_pkg_index() {
    if [ "$PKG_INDEX_UPDATED" -eq 0 ]; then
        info "Updating the package index..."
        apt-get update -qq
        PKG_INDEX_UPDATED=1
    fi
}

# Install packages through whichever package manager is available (Debian/Ubuntu or RHEL/Fedora)
pkg_install() {
    if command -v apt-get >/dev/null 2>&1; then
        ensure_pkg_index
        DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y "$@"
    else
        fail "no supported package manager found (apt-get/dnf)."
    fi
}

# --- 1. Initial validation: root & placeholders ---
[ "$(id -u)" -eq 0 ] || fail "this script must be run as root (sudo $0)"

is_placeholder "$SSH_PUBLIC_KEY" && fail "SSH_PUBLIC_KEY is not set (pass it via the environment or the Configuration block)."
is_placeholder "$NEW_HOSTNAME"  && fail "NEW_HOSTNAME is not set (pass it via the environment or the Configuration block)."

info "Initial validation OK (root, configuration complete)."

# --- 2. Create the deploy user (non-root) ---
if getent passwd "$DEPLOY_USER" >/dev/null 2>&1; then
    info "User '${DEPLOY_USER}' already exists — skipping creation."
else
    useradd --create-home --shell /bin/bash "$DEPLOY_USER"
    info "User '${DEPLOY_USER}' created."
fi

USER_HOME=$(getent passwd "$DEPLOY_USER" | cut -d: -f6)
USER_GROUP=$(id -gn "$DEPLOY_USER")
[ -n "$USER_HOME" ] || fail "home directory for '${DEPLOY_USER}' not found."

# --- 3. Passwordless sudo for the deploy user, via visudo so we don't get locked out ---
command -v visudo >/dev/null 2>&1 || pkg_install sudo

if [ -f "$SUDOERS_FILE" ] && grep -qxF "$SUDOERS_RULE" "$SUDOERS_FILE"; then
    info "Passwordless sudo rule already present — skipping."
else
    info "Writing the passwordless sudo rule (${SUDOERS_FILE})..."
    tmpfile=$(mktemp)
    printf '%s\n' "$SUDOERS_RULE" > "$tmpfile"
    chmod 0440 "$tmpfile"
    visudo -cf "$tmpfile" >/dev/null || fail "invalid sudoers rule; not installed."
    mv "$tmpfile" "$SUDOERS_FILE"
    info "Sudo rule installed and validated."
fi

# --- 4. Inject the SSH public key into authorized_keys ---
info "Installing the SSH public key for '${DEPLOY_USER}'..."
SSH_DIR="${USER_HOME}/.ssh"
AUTH_KEYS_FILE="${SSH_DIR}/authorized_keys"
install -d -m 0700 -o "$DEPLOY_USER" -g "$USER_GROUP" "$SSH_DIR"
[ -f "$AUTH_KEYS_FILE" ] || install -m 0600 -o "$DEPLOY_USER" -g "$USER_GROUP" /dev/null "$AUTH_KEYS_FILE"
if grep -qxF "$SSH_PUBLIC_KEY" "$AUTH_KEYS_FILE"; then
    info "Key already present in authorized_keys — skipping."
else
    printf '%s\n' "$SSH_PUBLIC_KEY" >> "$AUTH_KEYS_FILE"
    info "Key added."
fi
chown "$DEPLOY_USER:$USER_GROUP" "$AUTH_KEYS_FILE"
chmod 0700 "$SSH_DIR"
chmod 0600 "$AUTH_KEYS_FILE"
info "SSH permissions set (700 / 600)."

# --- 5. Install Python 3 + pip ---
if command -v python3 >/dev/null 2>&1 && command -v pip3 >/dev/null 2>&1; then
    info "Python 3 and pip already installed — skipping ($(python3 --version))."
else
    info "Installing Python 3 + python3-pip..."
    pkg_install python3 python3-pip
    command -v python3 >/dev/null 2>&1 || fail "python3 not found after installation."
    command -v pip3    >/dev/null 2>&1 || fail "pip3 not found after installation."
    info "Python installed: $(python3 --version)."
fi

# --- 6. Set the system hostname ---
command -v hostnamectl >/dev/null 2>&1 || fail "hostnamectl is unavailable (systemd required)."
OLD_HOSTNAME=$(hostnamectl --static)
if [ "$OLD_HOSTNAME" = "$NEW_HOSTNAME" ]; then
    info "Hostname is already '${NEW_HOSTNAME}' — skipping."
else
    info "Changing hostname '${OLD_HOSTNAME}' -> '${NEW_HOSTNAME}'..."
    hostnamectl set-hostname "$NEW_HOSTNAME"
    # Update the 127.0.1.1 line in /etc/hosts if it exists
    if grep -q '^127\.0\.1\.1' /etc/hosts; then
        sed -i "/^127\.0\.1\.1/s/${OLD_HOSTNAME}/${NEW_HOSTNAME}/g" /etc/hosts || true
        info "/etc/hosts updated."
    fi
    info "New hostname active: $(hostnamectl --static)."
fi


info "==== Bootstrap complete ===="
echo "Please SSH to $(hostname -I | awk '{print $1}')"
echo "Public IP: $(curl -s ifconfig.me)"
