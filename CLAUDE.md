# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`Telemt-Manager` is a Bash script for automating the installation, update, and removal of [Telemt](https://github.com/telemt/telemt) — a Telegram proxy — via systemd on Debian-based Linux distributions (Ubuntu, Mint, Kali, etc.).

Entry point for end users:
```bash
bash <(wget -O - https://raw.githubusercontent.com/DenisShahbazyan/Telemt-Manager/main/telemt-manager.sh)
```

## Architecture

### File Structure

```
Telemt-Manager/
├── telemt-manager.sh          # Main entry point — downloads modules, shows menu
└── scripts/
    ├── common.sh              # Colors, logging, root/sudo check, dependency check
    ├── install.sh             # Installation logic (auto + manual)
    ├── uninstall.sh           # Uninstall logic
    └── update.sh              # Binary update logic
```

### Module Loading Strategy

`telemt-manager.sh` downloads required modules from GitHub Raw into a temp directory (`/tmp/telemt-manager-XXXXX/`) at startup and sources them. The temp directory is cleaned up on exit via a `trap`.

### Key Design Principles

- **Single Responsibility**: every function does exactly one thing — no "super-functions"
- **SOLID**: separate concerns across files and functions
- **No root required**: all privileged commands use `sudo`; script is intended for non-technical users
- **Russian language**: all user-facing output is in Russian (English support planned as a future feature)

## Behavior by State

### Header (always shown)
- systemd service status (running / stopped / not installed)
- Installed binary version (`telemt --version`) — green if matches latest, red if outdated
- Latest version fetched from GitHub Releases API

### Menu Items
| State | Menu |
|---|---|
| Not installed | `1) Установить` |
| Installed | `1) Переустановить` |
| Always | `2) Обновить`, `3) Удалить`, `Enter) Выход` |

## Installation Flow

**Auto mode defaults:**
- Port: `443`
- TLS domain: `github.com`
- First username: `user1`
- Secret: auto-generated via `openssl rand -hex 16`

**Manual mode prompts:** port (validated as free via `netstat`), domain, username, secret (user choice: auto-generate or enter manually; validated as exactly 32 hex characters `/^[0-9a-f]{32}$/`)

**Post-install:** `systemctl enable telemt && systemctl start telemt` — no further output

**Config location:** `/etc/telemt/telemt.toml`

**API:** always bound to `127.0.0.1:9091` (never exposed externally)

## Users Management (planned feature)

Separate main-menu item. Covers: add user (auto or manual secret), remove user, list users. After any change: `systemctl restart telemt`.

## Uninstall

Always full (binary + config + systemd unit + system user `telemt`), but always asks whether to preserve `/etc/telemt/`.

## Update

Downloads the new binary only, replaces `/bin/telemt`, runs `systemctl restart telemt`.

## Logging

All actions are logged to `/var/log/telemt/telemt-manager-<YYYY-MM-DD_HH-MM-SS>.log`.

## Dependency Check

At startup, verify presence of: `wget`, `jq`, `openssl`, `systemctl`, `net-tools` (`netstat`). Missing packages are installed automatically via `apt-get`.

## Planned Features (not in MVP)

- RealiTLScanner integration for TLS domain selection
- `Edit config` menu item (opens `nano /etc/telemt/telemt.toml`)
- English language support
- Multiple Linux distro support beyond Debian-based
