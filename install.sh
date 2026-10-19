#!/usr/bin/env bash

#   =========================================
#   You can also install with the lines below:
#   curl -fsSL https://raw.githubusercontent.com/noperi11/provisioning-script/main/install.sh -o /tmp/install.sh
#   sudo bash /tmp/install.sh
#   =========================================

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/noperi11/provisioning-script.git}"
REPO_BRANCH="${REPO_BRANCH:-main}"
INSTALL_DIR="${INSTALL_DIR:-/opt/provisioning-script}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info() { printf '[installer] %s\n' "$*"; }
fail() { printf '[installer] FAILED: %s\n' "$*" >&2; exit 1; }

# Read the .env file line by line (instead of `source`) so that values containing
# spaces — like an SSH public key — do not need to be quoted.
load_env() {
    local line key value
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"                                  # CRLF-safe
        case "$line" in ''|'#'*) continue ;; esac             # blank / comment
        [ "${line#*=}" != "$line" ] || continue               # line without '='
        key="${line%%=*}"; value="${line#*=}"
        [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue  # valid variable name
        value="${value#"${value%%[![:space:]]*}"}"            # trim leading spaces
        case "$value" in \"*\"|\'*\') value="${value:1:${#value}-2}" ;; esac
        if [ -n "${!key:-}" ]; then continue; fi              # environment wins over .env
        export "$key=$value"
    done < "$1"
}

[ "$(id -u)" -eq 0 ] || fail "this script must be run as root (sudo bash $0)"
command -v git >/dev/null 2>&1 || fail "git not found (sudo apt-get install -y git)"

# --- 1. Download the repo (always a fresh clone) ---
if [ -d "$INSTALL_DIR" ]; then
    info "Removing the old clone at ${INSTALL_DIR}..."
    rm -rf "${INSTALL_DIR:?}"
fi

info "Cloning the repo into ${INSTALL_DIR}..."
git clone --branch "$REPO_BRANCH" "$REPO_URL" "$INSTALL_DIR"

# --- 2. Load configuration from .env (next to the installer, or inside the repo) ---
if [ -z "${ENV_FILE:-}" ]; then
    for cand in "${SCRIPT_DIR}/.env" "${INSTALL_DIR}/.env"; do
        if [ -f "$cand" ]; then ENV_FILE="$cand"; break; fi
    done
fi
if [ -n "${ENV_FILE:-}" ]; then
    info "Loading configuration from ${ENV_FILE}"
    load_env "$ENV_FILE"
else
    info "No .env found — expecting SSH_PUBLIC_KEY/NEW_HOSTNAME from the environment."
fi

# --- 3. Run provisioning ---
SCRIPT_PATH="${INSTALL_DIR}/bootstrap-server.sh"
[ -f "$SCRIPT_PATH" ] || fail "${SCRIPT_PATH} is missing from the repo."
info "Running bootstrap-server.sh..."
exec bash "$SCRIPT_PATH"
