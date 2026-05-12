#!/usr/bin/env bash
# install.sh - bootstrap stack-installer CLI, then run it.
#
# Usage:
#   curl -fsSL https://github.com/MakFly/stack-installer/raw/refs/heads/main/install.sh | sudo bash
#   wget -qO- https://github.com/MakFly/stack-installer/raw/refs/heads/main/install.sh | sudo bash
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

remove_ansible_ppa_sources() {
  local files=()
  local f

  while IFS= read -r -d '' f; do
    if grep -qE 'ppa\.launchpad(content)?\.net/(~)?ansible/ansible|ppa:ansible/ansible' "$f" 2>/dev/null; then
      files+=("$f")
    fi
  done < <(find /etc/apt/sources.list.d -maxdepth 1 -type f \( -name '*.list' -o -name '*.sources' \) -print0 2>/dev/null)

  if grep -qE 'ppa\.launchpad(content)?\.net/(~)?ansible/ansible|ppa:ansible/ansible' /etc/apt/sources.list 2>/dev/null; then
    warn "Ansible PPA entry found in /etc/apt/sources.list; disabling matching lines."
    cp /etc/apt/sources.list "/etc/apt/sources.list.stack-installer-backup.$(date +%Y%m%d%H%M%S)"
    sed -i -E '/ppa\.launchpad(content)?\.net\/(~)?ansible\/ansible|ppa:ansible\/ansible/s/^/# disabled by stack-installer: /' /etc/apt/sources.list
  fi

  if (( ${#files[@]} )); then
    warn "Removing Ansible PPA apt source(s): ${files[*]}"
    for f in "${files[@]}"; do
      rm -f "$f"
    done
  fi
}

remove_conflicting_docker_sources() {
  local files=()
  local f

  while IFS= read -r -d '' f; do
    if grep -q 'download.docker.com/linux' "$f" 2>/dev/null; then
      files+=("$f")
    fi
  done < <(find /etc/apt/sources.list.d -maxdepth 1 -type f \( -name '*.list' -o -name '*.sources' \) -print0 2>/dev/null)

  if grep -q 'download.docker.com/linux' /etc/apt/sources.list 2>/dev/null; then
    warn "Docker apt entry found in /etc/apt/sources.list; disabling matching lines."
    cp /etc/apt/sources.list "/etc/apt/sources.list.stack-installer-backup.$(date +%Y%m%d%H%M%S)"
    sed -i -E '/download\.docker\.com\/linux/s/^/# disabled by stack-installer: /' /etc/apt/sources.list
  fi

  if (( ${#files[@]} )); then
    warn "Removing Docker apt source(s) to clear signed-by conflicts: ${files[*]}"
    for f in "${files[@]}"; do
      rm -f "$f"
    done
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
  remove_ansible_ppa_sources
  ensure_pkg ca-certificates curl git gnupg lsb-release
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
  remove_conflicting_docker_sources
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
