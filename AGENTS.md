# AGENTS.md

This repository uses `LTS` behavior by default.

## Version policy (mandatory)

1. Use LTS versions by default for runtime stacks.
2. Never pin a fixed non-LTS version in code or playbooks unless explicitly requested.
3. Do not add fixed latest-version shortcuts that can drift away from support policy.
4. If an explicit version is needed, use environment override variables and document it.

## Stack defaults

- Node.js:
  - Default channel must remain `LTS`.
  - `NODE_MAJOR` is an explicit override only.
  - `nodejs` task should remain idempotent and continue to install `nodejs` + bundled `npm` from LTS source.

- PHP:
  - Use an LTS-compatible package baseline and keep major `8.x`.
  - `PHP_VERSION` is an override only.
  - Never force Apache/Nginx installation.

- Core flow:
  - `install.sh` is a bootstrap only (Ansible + project sync + CLI install/launch).
  - Component installation must remain in Ansible playbooks (`ansible/site.yml` + `ansible/tasks/*.yml`).

## Delivery rules

- When updating stack tasks, preserve behavior for Debian/Ubuntu compatibility.
- Keep existing cleanup behavior that repairs known broken apt sources (Docker / legacy PPAs) as part of bootstrap stability.
- Keep user prompt text and component tree aligned with currently supported stack components:
  - `docker`
  - `php`
  - `composer`
  - `nodejs`
  - `zsh`
  - `zsh_plugins`

## Testing rules

1. Keep changes minimal and scoped.
2. Do not force extra non-LTS defaults without explicit user request.
3. Record changes and keep behavior backward-compatible where possible.
