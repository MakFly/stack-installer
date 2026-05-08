# stack-installer

> One-shot bash installer to bootstrap a fresh Debian/Ubuntu server with **Ansible**, **Docker CE**, and **PHP 8.x** (latest) — automatically disables conflicting **Apache2 / Nginx** services so ports 80/443 stay free for your containers.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell](https://img.shields.io/badge/shell-bash-1f425f.svg)](https://www.gnu.org/software/bash/)
[![Debian](https://img.shields.io/badge/Debian-11%20%7C%2012%20%7C%2013-A81D33?logo=debian&logoColor=white)](https://www.debian.org/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%20%7C%2022.04%20%7C%2024.04-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![Ansible](https://img.shields.io/badge/Ansible-latest-EE0000?logo=ansible&logoColor=white)](https://www.ansible.com/)
[![Docker](https://img.shields.io/badge/Docker-CE-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![PHP](https://img.shields.io/badge/PHP-8.5-777BB4?logo=php&logoColor=white)](https://www.php.net/)
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

That's it. ~2 minutes later you have a clean Ansible + Docker + PHP stack ready to use.

---

## 🎯 What it installs

| Component   | Source                                                                          | Why                                              |
| ----------- | ------------------------------------------------------------------------------- | ------------------------------------------------ |
| **Ansible** | [`ansible/ansible` PPA](https://launchpad.net/~ansible/+archive/ubuntu/ansible) (Ubuntu) / Debian main | Latest stable, official upstream                 |
| **Docker CE** | [Official Docker repo](https://docs.docker.com/engine/install/)               | CE + Compose plugin + Buildx + containerd        |
| **PHP 8.x** | [Sury](https://packages.sury.org/php/) (Debian) / [ondrej/php](https://launchpad.net/~ondrej/+archive/ubuntu/php) (Ubuntu) | Auto-detect latest (8.5 today), with extensions  |
| **Composer** | [getcomposer.org](https://getcomposer.org/)                                    | Latest stable                                    |

**PHP extensions installed**: `cli`, `common`, `curl`, `mbstring`, `xml`, `zip`, `intl`, `bcmath`, `opcache`, `readline`, `gd` (each is filtered to what's actually packaged for the chosen version — newer PHP releases that bundle extensions in core are handled automatically).

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
| `KEEP_WEBSERVERS`   | unset   | Do not disable apache2 / nginx                  |

Examples:

```bash
# Keep PHP 8.3 LTS instead of latest
curl -fsSL https://raw.githubusercontent.com/MakFly/stack-installer/main/install.sh \
  | sudo PHP_VERSION=8.3 bash

# Only install Docker, leave web servers alone
curl -fsSL https://raw.githubusercontent.com/MakFly/stack-installer/main/install.sh \
  | sudo SKIP_ANSIBLE=1 SKIP_PHP=1 KEEP_WEBSERVERS=1 bash
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

---

## 📋 Post-install checks

```bash
ansible --version
docker --version && docker compose version
php -v
composer --version
```

If you ran with `sudo`, log out and back in for the `docker` group to take effect, then:

```bash
docker run --rm hello-world
```

---

## 🤝 Contributing

Issues and PRs welcome. Keep the script POSIX-bash compatible, idempotent, and shellcheck-clean.

## 📄 License

[MIT](LICENSE) — © 2026 MakFly

---

## 🔍 Keywords

`ansible installer` · `docker install script` · `php 8.5 install` · `php install ubuntu` · `php install debian` · `lemp stack` · `lamp stack` · `vps bootstrap` · `server provisioning` · `devops bash script` · `one-liner install` · `disable apache nginx` · `composer install` · `debian 13 trixie` · `ubuntu 24.04 noble` · `homelab setup` · `docker compose installer` · `php sury` · `ondrej php` · `bash bootstrap` · `quick server setup`
