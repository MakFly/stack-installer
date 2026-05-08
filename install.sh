#!/usr/bin/env bash
# install.sh — Ansible + Docker + PHP (latest 8.x) installer
# Disables Apache2 / Nginx if present.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/<user>/<repo>/main/install.sh | sudo bash
#   # or
#   wget -qO- https://raw.githubusercontent.com/<user>/<repo>/main/install.sh | sudo bash
#
# Env overrides:
#   PHP_VERSION=8.3   # pin a specific PHP version (default: latest available)
#   SKIP_DOCKER=1     # skip Docker installation
#   SKIP_ANSIBLE=1    # skip Ansible installation
#   SKIP_PHP=1        # skip PHP installation
#   KEEP_WEBSERVERS=1 # do not disable apache2/nginx

set -euo pipefail

# ---------- helpers ----------
RED=$'\033[0;31m'; GRN=$'\033[0;32m'; YLW=$'\033[1;33m'; BLU=$'\033[0;34m'; NC=$'\033[0m'
log()  { printf '%s[+]%s %s\n' "$GRN" "$NC" "$*"; }
warn() { printf '%s[!]%s %s\n' "$YLW" "$NC" "$*"; }
err()  { printf '%s[x]%s %s\n' "$RED" "$NC" "$*" >&2; }
info() { printf '%s[i]%s %s\n' "$BLU" "$NC" "$*"; }

require_root() {
  if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root (use sudo)."
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
  OS_CODENAME="${VERSION_CODENAME:-}"
  case "$OS_ID" in
    ubuntu|debian) : ;;
    *)
      err "Unsupported OS: $OS_ID. This script targets Debian/Ubuntu."
      exit 1
      ;;
  esac
  log "Detected: $PRETTY_NAME"
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
  for p in "${pkgs[@]}"; do
    dpkg -s "$p" &>/dev/null || missing+=("$p")
  done
  if (( ${#missing[@]} )); then
    apt_update_once
    log "Installing: ${missing[*]}"
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${missing[@]}"
  fi
}

# ---------- web server disable ----------
disable_webserver() {
  local svc="$1"
  if systemctl list-unit-files --no-legend 2>/dev/null | awk '{print $1}' | grep -qx "${svc}.service"; then
    if systemctl is-active --quiet "$svc"; then
      log "Stopping ${svc}..."
      systemctl stop "$svc" || warn "Failed to stop ${svc}"
    fi
    if systemctl is-enabled --quiet "$svc" 2>/dev/null; then
      log "Disabling ${svc}..."
      systemctl disable "$svc" || warn "Failed to disable ${svc}"
    fi
    log "${svc} disabled."
  else
    info "${svc} not installed — nothing to disable."
  fi
}

handle_webservers() {
  if [[ -n "${KEEP_WEBSERVERS:-}" ]]; then
    info "KEEP_WEBSERVERS set — skipping apache2/nginx shutdown."
    return
  fi
  log "Checking for apache2 / nginx..."
  disable_webserver apache2
  disable_webserver nginx
}

# ---------- Ansible ----------
install_ansible() {
  if [[ -n "${SKIP_ANSIBLE:-}" ]]; then
    info "SKIP_ANSIBLE set — skipping Ansible."
    return
  fi
  if command -v ansible >/dev/null 2>&1; then
    log "Ansible already installed: $(ansible --version | head -n1)"
    return
  fi
  log "Installing Ansible..."
  ensure_pkg ca-certificates curl gnupg
  if [[ "$OS_ID" == "ubuntu" ]]; then
    ensure_pkg software-properties-common
    if ! grep -rq "ppa.launchpad.net/ansible/ansible" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
      add-apt-repository -y --update ppa:ansible/ansible
    fi
  fi
  apt_update_once
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ansible
  log "Ansible: $(ansible --version | head -n1)"
}

# ---------- Docker ----------
install_docker() {
  if [[ -n "${SKIP_DOCKER:-}" ]]; then
    info "SKIP_DOCKER set — skipping Docker."
    return
  fi
  if command -v docker >/dev/null 2>&1; then
    log "Docker already installed: $(docker --version)"
  else
    log "Installing Docker (official repo)..."
    ensure_pkg ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
      curl -fsSL "https://download.docker.com/linux/${OS_ID}/gpg" \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      chmod a+r /etc/apt/keyrings/docker.gpg
    fi
    local arch
    arch="$(dpkg --print-architecture)"
    echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${OS_ID} ${OS_CODENAME} stable" \
      > /etc/apt/sources.list.d/docker.list
    unset _APT_UPDATED
    apt_update_once
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  fi
  systemctl enable --now docker
  log "Docker: $(docker --version)"

  # Add invoking user to docker group (if running via sudo)
  local target_user="${SUDO_USER:-}"
  if [[ -n "$target_user" && "$target_user" != "root" ]]; then
    if ! id -nG "$target_user" | tr ' ' '\n' | grep -qx docker; then
      usermod -aG docker "$target_user"
      info "Added user '$target_user' to docker group (re-login required)."
    fi
  fi
}

# ---------- PHP ----------
detect_latest_php() {
  # Pull from Sury (Debian) or ondrej (Ubuntu) once repo is added
  apt-cache search --names-only '^php[0-9]+\.[0-9]+$' \
    | awk '{print $1}' | sed 's/^php//' \
    | sort -V | tail -n1
}

install_php() {
  if [[ -n "${SKIP_PHP:-}" ]]; then
    info "SKIP_PHP set — skipping PHP."
    return
  fi
  log "Installing PHP (latest 8.x)..."
  ensure_pkg ca-certificates curl gnupg lsb-release apt-transport-https

  install -m 0755 -d /etc/apt/keyrings

  if [[ "$OS_ID" == "debian" ]]; then
    # Sury repo
    if [[ ! -f /etc/apt/keyrings/sury-php.gpg ]]; then
      curl -fsSL https://packages.sury.org/php/apt.gpg \
        | gpg --dearmor -o /etc/apt/keyrings/sury-php.gpg
    fi
    echo "deb [signed-by=/etc/apt/keyrings/sury-php.gpg] https://packages.sury.org/php/ ${OS_CODENAME} main" \
      > /etc/apt/sources.list.d/sury-php.list
  else
    # Ubuntu: ondrej/php PPA
    ensure_pkg software-properties-common
    if ! grep -rq "ondrej/php" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
      add-apt-repository -y ppa:ondrej/php
    fi
  fi

  unset _APT_UPDATED
  apt_update_once

  local php_ver="${PHP_VERSION:-}"
  if [[ -z "$php_ver" ]]; then
    php_ver="$(detect_latest_php || true)"
  fi
  if [[ -z "$php_ver" ]]; then
    err "Could not detect a PHP 8.x version from the repository."
    exit 1
  fi
  if [[ ! "$php_ver" =~ ^8\. ]]; then
    warn "Latest detected PHP is ${php_ver} (not 8.x). Forcing 8.3 fallback."
    php_ver="8.3"
  fi
  log "Installing PHP ${php_ver}..."

  # Core packages (must exist)
  local php_core=(
    "php${php_ver}-cli"
    "php${php_ver}-common"
  )
  # Optional extensions — filter to what's actually available
  local php_ext_candidates=(
    "php${php_ver}-curl"
    "php${php_ver}-mbstring"
    "php${php_ver}-xml"
    "php${php_ver}-zip"
    "php${php_ver}-intl"
    "php${php_ver}-bcmath"
    "php${php_ver}-opcache"
    "php${php_ver}-readline"
    "php${php_ver}-gd"
  )
  local php_ext=()
  for pkg in "${php_ext_candidates[@]}"; do
    if apt-cache show "$pkg" >/dev/null 2>&1; then
      php_ext+=("$pkg")
    else
      info "Skipping ${pkg} (not in repo — likely bundled in core for this PHP version)"
    fi
  done
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${php_core[@]}" "${php_ext[@]}"

  # Install Composer
  if ! command -v composer >/dev/null 2>&1; then
    log "Installing Composer..."
    local tmp; tmp="$(mktemp -d)"
    curl -fsSL https://getcomposer.org/installer -o "$tmp/composer-setup.php"
    php "$tmp/composer-setup.php" --quiet --install-dir=/usr/local/bin --filename=composer
    rm -rf "$tmp"
  fi

  log "PHP: $(php -v | head -n1)"
  log "Composer: $(composer --version 2>/dev/null || echo 'n/a')"
}

# ---------- main ----------
main() {
  require_root
  detect_os
  apt_update_once
  ensure_pkg curl ca-certificates gnupg lsb-release

  handle_webservers
  install_ansible
  install_docker
  install_php

  print_summary
}

print_summary() {
  local target_user="${SUDO_USER:-$(whoami)}"
  local docker_in_group=0
  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]] \
     && id -nG "$SUDO_USER" 2>/dev/null | tr ' ' '\n' | grep -qx docker; then
    docker_in_group=1
  fi

  echo
  printf '%s' "$GRN"
  echo "============================================================"
  echo "                  INSTALLATION SUMMARY"
  echo "============================================================"
  printf '%s' "$NC"

  echo
  echo "  Installed components:"
  if command -v ansible >/dev/null 2>&1; then
    echo "    [OK] $(ansible --version | head -n1)"
  else
    echo "    [--] Ansible        (skipped or not installed)"
  fi
  if command -v docker >/dev/null 2>&1; then
    echo "    [OK] $(docker --version)"
    docker compose version >/dev/null 2>&1 \
      && echo "    [OK] $(docker compose version | head -n1)"
  else
    echo "    [--] Docker         (skipped or not installed)"
  fi
  if command -v php >/dev/null 2>&1; then
    echo "    [OK] $(php -v | head -n1)"
  else
    echo "    [--] PHP            (skipped or not installed)"
  fi
  if command -v composer >/dev/null 2>&1; then
    echo "    [OK] Composer $(composer --version --no-ansi 2>/dev/null | awk '{print $3}')"
  else
    echo "    [--] Composer       (skipped or not installed)"
  fi

  echo
  echo "  Web servers status:"
  for svc in apache2 nginx; do
    if systemctl list-unit-files --no-legend 2>/dev/null \
        | awk '{print $1}' | grep -qx "${svc}.service"; then
      if systemctl is-active --quiet "$svc" 2>/dev/null; then
        echo "    [!!] ${svc}: still active"
      else
        echo "    [OK] ${svc}: disabled"
      fi
    else
      echo "    [--] ${svc}: not installed"
    fi
  done

  printf '%s' "$GRN"
  echo
  echo "============================================================"
  printf '%s' "$NC"

  # ---- IMPORTANT: shell reload notice (English, intentional) ----
  if [[ $docker_in_group -eq 1 ]]; then
    printf '%s' "$YLW"
    echo
    echo "  >>> ACTION REQUIRED — DOCKER GROUP MEMBERSHIP <<<"
    printf '%s' "$NC"
    echo
    echo "  User '${target_user}' has been added to the 'docker' group,"
    echo "  but the change is NOT active in your current shell session."
    echo
    echo "  To run docker WITHOUT sudo, choose one:"
    echo
    echo "    1) Reload your shell groups in this session:"
    echo "         newgrp docker"
    echo
    echo "    2) Or log out and log back in (recommended for SSH sessions):"
    echo "         exit          # then reconnect via SSH"
    echo
    echo "    3) Or apply for the current shell only:"
    echo "         exec sg docker newgrp \`id -gn\`"
    echo
    echo "  Verify with:    docker run --rm hello-world"
    echo
  fi

  log "Done. Stack ready."
}

main "$@"
