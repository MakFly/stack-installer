# stack-installer

> Bootstrapper Debian/Ubuntu qui installe **Ansible en premier**, installe une CLI locale `stack-installer`, puis lance un panneau interactif pour installer ou mettre à jour les composants choisis sur la machine locale.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell](https://img.shields.io/badge/shell-bash-1f425f.svg)](https://www.gnu.org/software/bash/)
[![Debian](https://img.shields.io/badge/Debian-11%20%7C%2012%20%7C%2013-A81D33?logo=debian&logoColor=white)](https://www.debian.org/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%20%7C%2022.04%20%7C%2024.04-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![Ansible](https://img.shields.io/badge/Ansible-first-EE0000?logo=ansible&logoColor=white)](https://www.ansible.com/)
[![Node.js](https://img.shields.io/badge/Node.js-dynamic%20LTS-5FA04E?logo=nodedotjs&logoColor=white)](https://nodejs.org/)

---

## Quick install

```bash
curl -fsSL https://github.com/MakFly/stack-installer/raw/refs/heads/main/install.sh | sudo bash
```

or with `wget`:

```bash
wget -qO- https://github.com/MakFly/stack-installer/raw/refs/heads/main/install.sh | sudo bash
```

The bootstrap installs Ansible first, installs the real local command `/usr/local/bin/stack-installer`, then launches the CLI automatically. When installed through `curl ... | sudo bash`, the menu is attached back to `/dev/tty` so it remains interactive.

On Ubuntu releases where the Ansible PPA is not published yet, the bootstrap uses the distribution package and removes stale `ansible/ansible` PPA source files that would otherwise break `apt update`.

---

## What it does

`install.sh` is only the bootstrap layer:

1. Detect Debian/Ubuntu.
2. Install bootstrap dependencies.
3. Install Ansible first.
4. Install this project into `/opt/stack-installer`.
5. Install the local CLI at `/usr/local/bin/stack-installer`.
6. Launch the CLI.

`stack-installer` is the day-to-day command. The interactive menu shows a component tree and lets you choose groups or individual items by number instead of answering a long y/n wizard:

```bash
sudo stack-installer
```

Example selection:

```text
1,3          # Docker + Node.js
2.1,2.2,4.2 # PHP + Composer + Zsh syntax highlighting + autosuggest
all         # everything
```

It runs Ansible locally with:

```bash
ansible-playbook -i localhost, -c local /opt/stack-installer/ansible/site.yml
```

---

## Component Panel

The interactive panel can install/update everything or only selected components:

| Component | Behavior |
| --- | --- |
| `docker` | Installs Docker CE from Docker's official apt repo |
| `php` | Installs PHP 8.x CLI/extensions without nginx/apache2 |
| `composer` | Installs/updates Composer and pulls PHP when needed |
| `nodejs` | Installs/updates current NodeSource LTS and bundled npm |
| `zsh` | Installs Zsh + Oh My Zsh and manages `.zshrc` |
| `zsh_plugins` | Installs/updates autosuggestions and syntax highlighting |

Zsh setup uses `powerlevel10k` as default theme with a full path prompt configuration by default.

Zsh plugins come from the official GitHub repositories:

- <https://github.com/zsh-users/zsh-autosuggestions>
- <https://github.com/zsh-users/zsh-syntax-highlighting>

Apache2 and Nginx are never installed. If they already exist, the playbook stops/disables them unless `KEEP_WEBSERVERS=1` is set.

On Ubuntu, PHP is installed from the distribution repositories to avoid release-specific PPA failures. On Debian, the Sury PHP repository is used.

---

## Node.js LTS Policy

By default, Node.js follows the current LTS channel dynamically through NodeSource:

```text
https://deb.nodesource.com/setup_lts.x
```

That means rerunning the CLI later can move Node.js to the then-current LTS line. `NODE_MAJOR` is only an explicit override:

```bash
sudo NODE_MAJOR=22 stack-installer --components nodejs
```

npm is not upgraded with `npm@latest`; it remains the npm version bundled with Node.js LTS.

References:

- <https://github.com/nodejs/Release>
- <https://nodejs.org/en/about/releases/>
- <https://github.com/nodesource/distributions>

---

## CLI Usage

Interactive mode:

```bash
sudo stack-installer
```

Install/update everything:

```bash
sudo stack-installer --all
```

Install/update selected components:

```bash
sudo stack-installer --components php,nodejs,zsh,zsh_plugins
```

Show installed versions/status:

```bash
sudo stack-installer --status
```

Bootstrap without launching the CLI:

```bash
curl -fsSL https://github.com/MakFly/stack-installer/raw/refs/heads/main/install.sh \
  | sudo STACK_INSTALLER_NO_RUN=1 bash
```

---

## Configuration

| Variable | Default | Effect |
| --- | --- | --- |
| `STACK_INSTALLER_REPO` | `https://github.com/MakFly/stack-installer.git` | Git repo cloned by the bootstrap |
| `STACK_INSTALLER_REF` | `main` | Branch/tag cloned by the bootstrap |
| `STACK_INSTALLER_DIR` | `/opt/stack-installer` | Local project install directory |
| `STACK_INSTALLER_NO_RUN` | unset | Install the CLI without launching it |
| `PHP_VERSION` | latest detected 8.x | Pin PHP, for example `8.3` |
| `NODE_MAJOR` | unset | Override dynamic LTS with a major line |
| `KEEP_WEBSERVERS` | unset | Do not stop/disable existing apache2/nginx |

---

## Safety

- Ansible is installed before the component panel runs.
- The CLI is relaunchable for full updates or selective updates.
- Component tasks are idempotent.
- PHP is installed without Apache2/Nginx packages.
- Existing unmanaged `~/.zshrc` is backed up before writing the managed Zsh config.
- Docker group changes and default-shell changes require a new login shell or SSH reconnect.

---

## Local development

Syntax checks:

```bash
bash -n install.sh
bash -n bin/stack-installer
```

Ansible syntax check:

```bash
ansible-playbook -i localhost, -c local ansible/site.yml --syntax-check
```

ShellCheck, when Docker is available:

```bash
docker run --rm -v "$PWD:/mnt" koalaman/shellcheck:stable /mnt/install.sh /mnt/bin/stack-installer
```

---

## Post-install checks

```bash
stack-installer --status
ansible --version
docker --version && docker compose version
php -v
composer --version
node --version && npm --version
zsh --version
```

---

## License

[MIT](LICENSE) - © 2026 MakFly
