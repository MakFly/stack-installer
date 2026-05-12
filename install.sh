#!/usr/bin/env bash
# install.sh - bootstrap stack-installer CLI, then run it.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/MakFly/stack-installer/main/install.sh | sudo bash
#   wget -qO- https://raw.githubusercontent.com/MakFly/stack-installer/main/install.sh | sudo bash
#
# Env overrides:
#   STACK_INSTALLER_REPO=https://github.com/MakFly/stack-installer.git
#   STACK_INSTALLER_REF=main
#   STACK_INSTALLER_DIR=/opt/stack-installer
#   STACK_INSTALLER_NO_RUN=1  # install the CLI without launching it

set -euo pipefail

RED=$'\033[0;31m'; GRN=$'\033[0;32m'; YLW=$'\033[1;33m'; BLU=$'\033[0;34m'; NC=$'\033[0m'
log()  { printf '%s[+]%s %s\n' "$GRN" "$NC" "$*"; }
warn() { printf '%s[!]%s %s\n' "$YLW" "$NC" "$*"; }
err()  { printf '%s[x]%s %s\n' "$RED" "$NC" "$*" >&2; }
info() { printf '%s[i]%s %s\n' "$BLU" "$NC" "$*"; }

require_root() {
  if [[ $EUID -ne 0 ]]; then
    err "This bootstrap must be run as root (use sudo)."
    exit 1
  fi
}

detect_os() {
  if [[ ! -f /etc/os-release ]]; then
    err "Cannot detect OS: /etc/os-release missing."
    exit 1
  fi
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID="${ID:-unknown}"
  case "$OS_ID" in
    debian|ubuntu) log "Detected: ${PRETTY_NAME:-$OS_ID}" ;;
    *)
      err "Unsupported OS: $OS_ID. This project targets Debian/Ubuntu."
      exit 1
      ;;
  esac
}

apt_update_once() {
  if [[ -z "${_APT_UPDATED:-}" ]]; then
    log "Updating apt cache..."
    apt-get update -y
    _APT_UPDATED=1
  fi
}

ensure_pkg() {
  local pkgs=("$@")
  local missing=()
  local pkg
  for pkg in "${pkgs[@]}"; do
    dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
  done
  if (( ${#missing[@]} )); then
    apt_update_once
    log "Installing bootstrap packages: ${missing[*]}"
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${missing[@]}"
  fi
}

install_ansible_first() {
  log "Installing/updating Ansible first..."
  ensure_pkg ca-certificates curl git gnupg lsb-release
  if [[ "$OS_ID" == "ubuntu" ]]; then
    ensure_pkg software-properties-common
    if ! grep -rq "ppa.launchpad.net/ansible/ansible" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
      add-apt-repository -y --update ppa:ansible/ansible
    fi
  fi
  apt_update_once
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ansible
  log "$(ansible --version | head -n1)"
}

sync_project() {
  local install_dir="${STACK_INSTALLER_DIR:-/opt/stack-installer}"
  local repo_url="${STACK_INSTALLER_REPO:-https://github.com/MakFly/stack-installer.git}"
  local ref="${STACK_INSTALLER_REF:-main}"
  local script_dir
  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"

  if [[ -f "${script_dir}/ansible/site.yml" && -f "${script_dir}/bin/stack-installer" ]]; then
    log "Installing project from local checkout..."
    install -d -m 0755 "$install_dir"
    rsync -a --delete \
      --exclude '.git' \
      --exclude '.gitignore' \
      "${script_dir}/" "$install_dir/"
  else
    log "Installing project from ${repo_url} (${ref})..."
    if [[ -d "${install_dir}/.git" ]]; then
      git -c safe.directory="$install_dir" -C "$install_dir" fetch --quiet origin "$ref"
      git -c safe.directory="$install_dir" -C "$install_dir" checkout --quiet "$ref"
      git -c safe.directory="$install_dir" -C "$install_dir" pull --ff-only --quiet origin "$ref"
    elif [[ -e "$install_dir" ]]; then
      warn "${install_dir} exists but is not a git checkout; replacing it."
      rm -rf "$install_dir"
      git clone --branch "$ref" --depth=1 --quiet "$repo_url" "$install_dir"
    else
      git clone --branch "$ref" --depth=1 --quiet "$repo_url" "$install_dir"
    fi
  fi

  install -m 0755 "${install_dir}/bin/stack-installer" /usr/local/bin/stack-installer
  log "CLI installed: /usr/local/bin/stack-installer"
}

main() {
  require_root
  detect_os
  install_ansible_first
  ensure_pkg rsync
  sync_project

  if [[ -z "${STACK_INSTALLER_NO_RUN:-}" ]]; then
    log "Launching stack-installer..."
    if [[ -r /dev/tty && -w /dev/tty ]]; then
      exec /usr/local/bin/stack-installer </dev/tty >/dev/tty
    fi
    warn "No interactive TTY available; CLI installed but not launched."
    info "Run: sudo stack-installer"
    exit 0
  fi

  info "STACK_INSTALLER_NO_RUN set - run 'sudo stack-installer' when ready."
}

main "$@"
