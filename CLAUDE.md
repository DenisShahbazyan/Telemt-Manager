# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`Telemt-Manager` is a Bash script for automating the installation, update, and removal of [Telemt](https://github.com/telemt/telemt) — a Telegram proxy — via systemd on Debian-based Linux distributions (Ubuntu, Mint, Kali, etc.).

Entry point for end users:
```bash
bash <(wget -qO - https://raw.githubusercontent.com/DenisShahbazyan/Telemt-Manager/master/telemt-manager.sh)
```

## Development

This is a pure Bash project with no build step, linter, or test suite. Development is editing `.sh` files directly. The script is designed to run on remote Debian-based Linux servers, not locally on macOS.

Validate syntax without running:
```bash
bash -n telemt-manager.sh
# or check all files at once:
for f in telemt-manager.sh scripts/*.sh scripts/i18n/*.sh; do bash -n "$f" || echo "FAIL: $f"; done
```

Shell options: `set -uo pipefail` (no `set -e`) — the script does **not** exit on every error; failures are handled explicitly with `|| return`/`|| exit` patterns. Do not add `set -e`.

All comments in the codebase are in Russian. Keep new comments in Russian to stay consistent.

## Architecture

### Module Loading Strategy

`telemt-manager.sh` (entry point) downloads all modules from GitHub Raw (`REPO_BASE_URL`) into a temp directory (`/tmp/telemt-manager-XXXXX/`) at startup and sources them. The temp directory is cleaned up on exit via a `trap`. This means the script is **self-updating** — users always get the latest `master` code.

### Module Dependency Graph

All modules are `source`d into a single flat namespace — there are no imports between modules. Order matters:

1. `scripts/i18n/{lang}.sh` — loaded first (via `_load_i18n`, separate from `SCRIPT_MODULES` array), defines `MSG_*` variables
2. `scripts/common.sh` — colors, logging (`log_info`, `log_error`, etc.), systemd helpers, version functions, UI utilities (`press_enter_to_continue`, `confirm_action`), path constants (`TELEMT_BIN`, `TELEMT_CONFIG_FILE`, etc.)
3. `scripts/install.sh` — install logic, but also defines shared functions used by other modules: `_download_and_place_binary` (used by `update.sh`), `_generate_secret` and `_validate_secret` (used by `users.sh`), `_set_config_ownership` (used by `users.sh`). Also defines `PROMPT_RESULT` (global return variable) and default constants (`DEFAULT_PORT`, `DEFAULT_DOMAIN`, `DEFAULT_USERNAME`).
4. `scripts/update.sh`, `scripts/uninstall.sh`, `scripts/users.sh`, `scripts/edit_config.sh` — depend on functions from `common.sh` and `install.sh`

The load order is defined by the `SCRIPT_MODULES` array in `telemt-manager.sh` — changing the order can break cross-module function calls.

**When moving or renaming functions, check all modules** — grep the entire `scripts/` directory since cross-module calls are implicit.

### i18n System

Language strings live in `scripts/i18n/{ru,en}.sh` as `MSG_*` shell variables, loaded before any other module. All user-facing output must use `MSG_*` variables — never hardcode strings. When adding new messages, add to **both** locale files. Some messages use `printf` format specifiers (`%s`) — the caller wraps them in `printf "$MSG_*" "$arg"`. Variables are organized by section comments (`# ── Header ──`, `# ── Install ──`, etc.) — place new variables in the correct section.

### TOML Config Manipulation

The config file (`/etc/telemt/telemt.toml`) is manipulated via `sed`, not a proper TOML parser. Users are stored under `[access.users]` as `username = "secret"` lines. Adding a user inserts a line after `[access.users]`; removing deletes the matching line. This is fragile — any changes to config format must account for the sed patterns in `install.sh` and `users.sh`.

### Function Naming Convention

- `run_*` — public entry points called from the main menu (e.g., `run_install`, `run_reinstall`, `run_update`, `run_users`)
- `_underscore_prefixed` — private/internal functions within a module
- `PROMPT_RESULT` — global variable used as return value from `_prompt_*` functions (Bash can't return strings). Set by the callee, read by the caller immediately after the call.
- `LANG_CODE` — global set during language selection, used to load the correct i18n file.

### Key Design Principles

- **Single Responsibility**: every function does exactly one thing — no "super-functions"
- **SOLID**: separate concerns across files and functions
- **No root required**: all privileged commands use `sudo`; script is intended for non-technical users
- **Bilingual**: Russian and English via i18n modules

## Behavior by State

### Header (always shown)
- systemd service status (running / stopped / not installed)
- Installed binary version (`telemt --version`) — green if matches latest, red if outdated
- Latest version fetched from GitHub Releases API

### Menu Items
| State | Menu |
|---|---|
| Not installed | `1) Install` |
| Installed | `1) Reinstall` |
| Always | `2) Update`, `3) Uninstall`, `4) Users`, `5) Edit config`, `Enter) Exit` |

## Installation Flow

**Auto mode defaults:** port `443`, TLS domain `github.com`, username `user1`, secret auto-generated via `openssl rand -hex 16`.

**Manual mode prompts:** port (validated as free via `ss` or `netstat`), domain, username, secret (auto-generate or enter manually; validated as exactly 32 hex characters `/^[0-9a-f]{32}$/`).

If an existing config (`/etc/telemt/telemt.toml`) is found, both modes offer to reuse it instead of overwriting.

**Post-install:** shows proxy link(s) fetched from the local API (`127.0.0.1:9091`) with a retry loop (up to 30 attempts) waiting for the service to become ready.

## Users Management

Submenu: list users (with proxy links from API), add user (auto or manual secret), remove user (cannot remove last user). Users are stored in the `[access.users]` section of the TOML config, manipulated via `sed`. After any change: `systemctl restart telemt`.

## System Paths

- Binary: `/bin/telemt`
- Config dir: `/etc/telemt/` — config file: `/etc/telemt/telemt.toml`
- Service: `/etc/systemd/system/telemt.service`
- Working dir: `/opt/telemt` (owned by system user `telemt`)
- Logs: `/var/log/telemt/telemt-manager-<timestamp>.log`
- API: `127.0.0.1:9091` (never exposed externally)

Path constants are defined in `scripts/common.sh` (`TELEMT_BIN`, `TELEMT_CONFIG_FILE`, etc.) — always use the variables, not hardcoded paths.

## Dependencies

Auto-installed at startup via `apt-get`: `jq`, `openssl`, `curl` (list in `REQUIRED_DEPS` array in `common.sh`). Also requires `wget` (bootstrapped separately before module download), `systemctl` (hard requirement, exits if missing), and `nano` (used by `edit_config.sh` for manual config editing).

## Planned Features

- RealiTLScanner integration for TLS domain selection
- Multiple Linux distro support beyond Debian-based
