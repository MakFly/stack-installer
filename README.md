# stack-installer

> One-shot bash installer to bootstrap a fresh Debian/Ubuntu server with **curl**, **git**, **Ansible**, **Docker CE**, **PHP 8.x**, **Node.js LTS**, **npm**, and a productive **Zsh** setup — automatically disables conflicting **Apache2 / Nginx** services so ports 80/443 stay free for your containers.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell](https://img.shields.io/badge/shell-bash-1f425f.svg)](https://www.gnu.org/software/bash/)
[![Debian](https://img.shields.io/badge/Debian-11%20%7C%2012%20%7C%2013-A81D33?logo=debian&logoColor=white)](https://www.debian.org/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%20%7C%2022.04%20%7C%2024.04-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![Ansible](https://img.shields.io/badge/Ansible-latest-EE0000?logo=ansible&logoColor=white)](https://www.ansible.com/)
[![Docker](https://img.shields.io/badge/Docker-CE-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![PHP](https://img.shields.io/badge/PHP-8.5-777BB4?logo=php&logoColor=white)](https://www.php.net/)
[![Node.js](https://img.shields.io/badge/Node.js-LTS%2024-5FA04E?logo=nodedotjs&logoColor=white)](https://nodejs.org/)
[![Zsh](https://img.shields.io/badge/Zsh-Oh%20My%20Zsh-F15A24?logo=gnubash&logoColor=white)](https://ohmyz.sh/)
[![Tested](https://img.shields.io/badge/tested-debian%2013%20%7C%20ubuntu%2024.04-success)](#tested-environments)

---

## ⚡ Quick install (one-liner)

```bash
curl -fsSL https://raw.githubusercontent.com/MakFly/stack-installer/main/install.sh | sudo bash
```

or with `wget`:

```bash
wget -qO- https://raw.githubusercontent.com/MakFly/stack-installer/main/install.sh | sudo bash
```

That's it. ~2 minutes later you have a clean Ansible + Docker + PHP + Node.js + Zsh stack ready to use.

---

## 🎯 What it installs

| Component   | Source                                                                          | Why                                              |
| ----------- | ------------------------------------------------------------------------------- | ------------------------------------------------ |
| **curl** | Debian / Ubuntu repositories | Baseline HTTP client used by installers and scripts |
| **git** | Debian / Ubuntu repositories | Baseline VCS and plugin installer dependency |
| **Ansible** | [`ansible/ansible` PPA](https://launchpad.net/~ansible/+archive/ubuntu/ansible) (Ubuntu) / Debian main | Latest stable, official upstream                 |
| **Docker CE** | [Official Docker repo](https://docs.docker.com/engine/install/)               | CE + Compose plugin + Buildx + containerd        |
| **PHP 8.x** | [Sury](https://packages.sury.org/php/) (Debian) / [ondrej/php](https://launchpad.net/~ondrej/+archive/ubuntu/php) (Ubuntu) | Auto-detect latest (8.5 today), with extensions  |
| **Composer** | [getcomposer.org](https://getcomposer.org/)                                    | Latest stable                                    |
| **Node.js LTS** | [NodeSource](https://deb.nodesource.com/) | Node.js 24 LTS by default, override with `NODE_MAJOR` |
| **npm** | Bundled with Node.js | LTS-compatible npm version shipped with Node.js |
| **Zsh** | Debian / Ubuntu repositories + [Oh My Zsh](https://ohmyz.sh/) | Productive default shell for the invoking user |
| **Zsh autosuggestions** | [`zsh-users/zsh-autosuggestions`](https://github.com/zsh-users/zsh-autosuggestions) | Fish-like command suggestions from history/completion |
| **Zsh syntax highlighting** | [`zsh-users/zsh-syntax-highlighting`](https://github.com/zsh-users/zsh-syntax-highlighting) | Real-time command syntax highlighting |

**PHP extensions installed**: `cli`, `common`, `curl`, `mbstring`, `xml`, `zip`, `intl`, `bcmath`, `opcache`, `readline`, `gd` (each is filtered to what's actually packaged for the chosen version — newer PHP releases that bundle extensions in core are handled automatically).

**Zsh setup**: installs Oh My Zsh for the invoking sudo user, clones the official autosuggestions and syntax-highlighting plugins from GitHub, backs up any unmanaged `~/.zshrc`, writes a managed config, and switches the user's default shell to `zsh` when possible. Open a new login shell or reconnect via SSH after install.

## 🚫 What it disables

If detected, the script stops and disables (`systemctl disable --now`):

- **Apache2** (`apache2.service`)
- **Nginx** (`nginx.service`)

This frees up ports 80/443 for your Docker reverse proxy (Traefik, nginx-proxy, Caddy, etc.). Skip this with `KEEP_WEBSERVERS=1`.

---

## 🔧 Configuration (env vars)

| Variable            | Default | Effect                                          |
| ------------------- | ------- | ----------------------------------------------- |
| `PHP_VERSION`       | latest  | Pin a specific PHP version (e.g. `8.3`, `8.4`)  |
| `SKIP_DOCKER`       | unset   | Skip Docker installation                        |
| `SKIP_ANSIBLE`      | unset   | Skip Ansible installation                       |
| `SKIP_PHP`          | unset   | Skip PHP / Composer installation                |
| `SKIP_NODE`         | unset   | Skip Node.js / npm installation                 |
| `NODE_MAJOR`        | `24`    | Pin a Node.js major version from NodeSource     |
| `SKIP_AI_CLIS`      | unset   | Skip Claude Code / Codex / opencode            |
| `SKIP_ZSH`          | unset   | Skip Zsh / Oh My Zsh setup                      |
| `KEEP_WEBSERVERS`   | unset   | Do not disable apache2 / nginx                  |

Examples:

```bash
# Keep PHP 8.3 LTS instead of latest
curl -fsSL https://raw.githubusercontent.com/MakFly/stack-installer/main/install.sh \
  | sudo PHP_VERSION=8.3 bash

# Only install Docker, leave web servers alone
curl -fsSL https://raw.githubusercontent.com/MakFly/stack-installer/main/install.sh \
  | sudo SKIP_ANSIBLE=1 SKIP_PHP=1 SKIP_NODE=1 SKIP_AI_CLIS=1 SKIP_ZSH=1 KEEP_WEBSERVERS=1 bash

# Use another NodeSource major line
curl -fsSL https://raw.githubusercontent.com/MakFly/stack-installer/main/install.sh \
  | sudo NODE_MAJOR=22 bash
```

---

## ✅ Tested environments

Validated end-to-end in clean Docker containers:

- ✅ **Debian 13** (trixie) — Ansible 2.19+, Docker CE 29.x, PHP 8.5
- ✅ **Ubuntu 24.04** (noble) — Ansible 2.20+, Docker CE 29.x, PHP 8.5
- ✅ Debian 11 / 12, Ubuntu 20.04 / 22.04 (same code paths)

Other distros (RHEL, Fedora, Arch, Alpine) are **not supported** — the script aborts cleanly with a message.

---

## 🛡️ Safety

- `set -euo pipefail` — fails fast on any error
- Idempotent — safe to run multiple times (skips already-installed components)
- Only adds upstream-signed APT repositories (Docker, Sury, ondrej, Ansible PPA)
- No piped curl-as-root unless you choose the one-liner (always available as a clone+inspect+run alternative below)
- Adds the invoking user to the `docker` group automatically (re-login required)
- Backs up unmanaged `~/.zshrc` before writing the managed Zsh config

### Inspect before running (recommended)

```bash
git clone https://github.com/MakFly/stack-installer.git
cd stack-installer
less install.sh    # read it
sudo bash install.sh
```

---

## 🧪 Local development

Run shellcheck:

```bash
docker run --rm -v "$PWD:/mnt" koalaman/shellcheck:stable /mnt/install.sh
```

Test in a clean container:

```bash
docker run --rm -it -v "$PWD:/mnt:ro" debian:13 bash
# inside:
apt-get update && apt-get install -y curl ca-certificates gnupg
bash /mnt/install.sh
```

Node.js LTS is tracked from the official Node.js release schedule: <https://github.com/nodejs/Release> and <https://nodejs.org/en/about/releases/>.

---

## 📋 Post-install checks

```bash
ansible --version
docker --version && docker compose version
php -v
composer --version
curl --version
git --version
node --version && npm --version
zsh --version
```

If you ran with `sudo`, log out and back in for the `docker` group to take effect, then:

```bash
docker run --rm hello-world
```

If Zsh was installed, open a new login shell or reconnect via SSH before expecting it to be your default shell.

---

## 🤝 Contributing

Issues and PRs welcome. Keep the script POSIX-bash compatible, idempotent, and shellcheck-clean.

## 📄 License

[MIT](LICENSE) — © 2026 MakFly

---

## 🔍 Keywords

`ansible installer` · `docker install script` · `php 8.5 install` · `nodejs lts install` · `npm install debian` · `zsh installer` · `oh my zsh installer` · `zsh autosuggestions` · `zsh syntax highlighting` · `php install ubuntu` · `php install debian` · `lemp stack` · `lamp stack` · `vps bootstrap` · `server provisioning` · `devops bash script` · `one-liner install` · `disable apache nginx` · `composer install` · `debian 13 trixie` · `ubuntu 24.04 noble` · `homelab setup` · `docker compose installer` · `php sury` · `ondrej php` · `bash bootstrap` · `quick server setup`
