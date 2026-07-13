# PostInstallHUB — Universal agent contract

This file is authoritative for Claude Code, OpenAI Codex CLI, Pi Coding Agent, and any
other AI coding assistant working on this repository.
Claude also reads `CLAUDE.md` for additional context.

## What this project is

PostInstallHUB is a **shell script collection** for post-install OS setup.

```
curl -fsSL https://raw.githubusercontent.com/matheusgomescosta/PostInstallHUB/main/install.sh | bash
```

One command auto-detects the OS and runs the correct distro script: installs packages,
configures dotfiles, applies tweaks, sets zsh as default shell.

- Type: Bash (Linux) + CMD/PowerShell (Windows)
- **No Node.js. No database. No HTTP API. No web framework. No Obsidian.**
- Zero runtime dependencies beyond bash and standard OS tools.

## Rules — always follow

1. Read `docs/00-project/PROJECT-INDEX.md` and the owning spec before editing any file.
2. Run `shellcheck scripts/linux/*.sh lib/*.sh install.sh` after bash changes.
3. Run `bash -n <file>` (syntax check) before committing any script.
4. Every bash file must start with `#!/usr/bin/env bash` and `set -euo pipefail`.
5. Quote every variable: `"$VAR"` — never bare `$VAR` in non-trivial context.
6. Use `log_info` / `log_success` / `log_warning` / `log_error` from `lib/common.sh`.
   Never use raw `echo` for status messages.
7. All install operations must be **idempotent** — check before acting.
8. Destructive/modifying actions require a backup warning via `lib/backup.sh`.
9. Lock file logic lives only in `lib/lock.sh`. Do not duplicate it.
10. Do not add npm, package.json, Node.js, databases, APIs, or any web framework.
11. Do not reference Obsidian, Apple Calendar, Soul Drive, or Bleach — wrong project.
12. Persist non-trivial decisions as ADRs in `docs/03-architecture/decisions/`.
13. Update the owning spec doc when architecture or behavior changes.

## Forbidden patterns

```bash
# Never: || true on critical steps
apt-get install -y git || true   # ← WRONG

# Never: unquoted variables
rm -f $FILE                      # ← WRONG — use "$FILE"

# Never: eval of external input
eval "$USER_INPUT"               # ← WRONG

# Never: run whole script as root
sudo bash install.sh             # ← WRONG — use targeted sudo only
```

## Project structure

```
install.sh              ← entry point; OS detection; routing
scripts/linux/
  common.sh             ← sourced by all distro scripts
  ubuntu.sh             ← Ubuntu/Debian (apt)
  arch.sh               ← Arch Linux (pacman)
  fedora.sh             ← Fedora (dnf)
  omarchy.sh            ← Omarchy/Arch+Hyprland (pacman)
scripts/windows/
  setup.cmd             ← Windows CMD
  setup.ps1             ← PowerShell
lib/
  colors.sh             ← ANSI constants: RED GREEN YELLOW BLUE NC
  lock.sh               ← acquire_lock / release_lock
  backup.sh             ← backup_warning
tests/
  test_ubuntu.sh
  test_arch.sh
  test_fedora.sh
  test_omarchy.sh
docs/                   ← all spec documents
```

## Read order

1. This file (`AGENTS.md`)
2. `CLAUDE.md` (Claude-specific context)
3. `docs/00-project/PROJECT-INDEX.md`
4. `docs/01-product/REQUIREMENTS.md`
5. `docs/03-architecture/BACKEND.md`
6. `docs/05-delivery/IMPLEMENTATION-PHASES.md`
