---
title: "Backend Architecture"
status: "draft"
owner: "Matheus"
reviewers:
  - "Matheus"
version: "0.1.0"
last_reviewed: "2026-07-13"
review_cycle: "quarterly"
applies_to: "0.1.0"
source_of_truth: true
related: []
supersedes: null
---

# Script execution architecture

> "Backend" for PostInstallHUB means the script execution model — how scripts are structured, sourced, and run. There is no server, no framework, no daemon.

## Runtime

- Language/runtime: Bash 5+ (Linux); CMD/batch + PowerShell 5+ (Windows)
- Framework: none — raw shell only. Zero runtime dependencies beyond what ships with the OS.
- Process model: single-process, sequential execution. One instance at a time, enforced by a lock file (`/tmp/postinstallhub.lock`). The lock is acquired at entry and released at exit via `trap`.
- Deployment unit: a single shell script file (`install.sh`) downloaded on demand via `curl`. No installation step. No package. No binary.

## Modules and dependency rules

| Module | Responsibility | Owns | May source |
|---|---|---|---|
| `install.sh` | Entry point; OS detection; routing to distro script | Lock lifecycle | `lib/lock.sh`, `lib/colors.sh` |
| `scripts/linux/common.sh` | Shared functions: `log_info`, `log_error`, `backup_warning`, `check_command` | Logging conventions | `lib/colors.sh` |
| `scripts/linux/ubuntu.sh` | Ubuntu/Debian install logic (apt) | Ubuntu package list | `common.sh` |
| `scripts/linux/arch.sh` | Arch Linux install logic (pacman) | Arch package list | `common.sh` |
| `scripts/linux/fedora.sh` | Fedora install logic (dnf) | Fedora package list | `common.sh` |
| `scripts/linux/omarchy.sh` | Omarchy install logic; reuses Arch package install | Omarchy tweaks | `common.sh`, `arch.sh` |
| `lib/lock.sh` | Acquire and release lock file; exit on conflict | Lock file path | nothing |
| `lib/backup.sh` | Display backup warning; prompt user acknowledgment | Warning text | nothing |
| `lib/colors.sh` | ANSI color constants (`RED`, `GREEN`, `YELLOW`, `RESET`, etc.) | Color values | nothing |
| `scripts/windows/setup.cmd` | Windows CMD entry; winget installs; basic tweaks | Windows package list | nothing (CMD, not bash) |
| `scripts/windows/setup.ps1` | PowerShell companion; advanced Windows config | PS-specific config | nothing |

**Dependency direction rule:** lib/ modules have no dependencies. `common.sh` depends only on lib/. Distro scripts depend only on `common.sh`. `install.sh` depends on lib/ only — never directly on distro scripts (it sources them at runtime after OS detection). No circular sourcing.

## Script execution lifecycle

The "request lifecycle" equivalent for a shell script project:

1. **Entry** — user runs `curl -fsSL <url>/install.sh | bash` (or clones and runs directly)
2. **Lock acquisition** — `lib/lock.sh` writes `/tmp/postinstallhub.lock`; exits with E003 if lock already exists
3. **OS detection** — `install.sh` reads `/etc/os-release` (Linux) or `%OS%` (Windows) to select the correct distro script
4. **Backup warning** — `lib/backup.sh` prints warning and waits for user confirmation (skipped if `POSTINSTALL_YES=1`)
5. **Package install** — distro script calls `apt`/`pacman`/`dnf`/`winget` to install git, curl, neovim, zsh, and companions
6. **Dotfile setup** — curl fetches dotfiles from companion repo and places them in `$HOME` (skipped if `POSTINSTALL_SKIP_DOTFILES=1`)
7. **System tweaks** — distro-specific tweaks applied (locale, fonts, keymaps, etc.) (skipped if `POSTINSTALL_SKIP_TWEAKS=1`)
8. **Shell change** — `chsh -s $(which zsh)` sets zsh as default login shell
9. **Lock release** — `trap 'rm -f $LOCK_FILE' EXIT` fires; lock file removed
10. **Exit** — exit 0 on success; non-zero on any critical failure

## Transactions and consistency

No database. No distributed state. Atomicity is approximated by **idempotent checks**: every install step tests whether the target is already present before acting (`command -v neovim` before installing neovim, for example). Running the script twice on the same machine produces the same end state.

Cross-step consistency: if a step fails, the script exits (via `set -e`) and subsequent steps do not run. The system is left in a partially-configured state; re-running after fixing the root cause is safe because all steps are idempotent.

## Background jobs

None. PostInstallHUB is a foreground, interactive script. Everything runs synchronously in the user's terminal session. No cron jobs, no daemons, no deferred work.

## Authentication and authorization

None in the traditional sense. The script runs as the invoking user. Steps that require elevated privileges call `sudo` inline and prompt the user. The script never stores credentials. It never accepts or transmits tokens. `sudo` availability is checked at startup (E004 if absent and required).

## Error taxonomy

| Code | Category | Retryable | Exit code | User-safe message |
|---|---|---:|---|---|
| E001 | Unsupported OS | No | 2 | "Unsupported OS. Supported: Ubuntu/Debian, Arch, Fedora, Omarchy, Windows." |
| E002 | Package install failure | No (auto) | 1 | "Failed to install <package>. Check your network and package manager, then re-run." |
| E003 | Lock file exists | No | 3 | "Another instance may be running. If not, delete /tmp/postinstallhub.lock and re-run." |
| E004 | sudo unavailable | No | 4 | "sudo is required but not available. Run as root or install sudo." |
| E005 | Dotfile curl failure | Non-fatal | — (warn, continue) | "Could not fetch dotfiles. Run the dotfile installer manually after setup." |
| E006 | chsh failure | Non-fatal | — (warn, continue) | "Could not set zsh as default shell. Run: chsh -s $(which zsh)" |

## Resource limits

- Request body: N/A — no network server, no request body
- File upload: N/A
- Timeout: no script-level timeout; `apt`/`pacman`/`dnf` manage their own network timeouts
- Concurrency: 1 (enforced by lock file; second invocation exits immediately with E003)
- Rate limit: N/A

## Graceful shutdown

`trap 'rm -f "$LOCK_FILE"' EXIT` is set immediately after lock acquisition. If the process is killed (SIGTERM, SIGKILL, Ctrl-C), the EXIT trap fires and removes the lock. **Exception:** SIGKILL bypasses traps — if the script is hard-killed, the lock file may remain. The E003 message instructs the user to remove it manually.

The script does not drain in-flight work on shutdown because there is no queue or async work. A killed apt/pacman invocation may leave the package manager in a locked state; standard package manager recovery applies (`dpkg --configure -a` for apt, `rm /var/lib/pacman/db.lck` for pacman).

## Forbidden patterns

- `curl <url> | bash` of untrusted or unverified URLs inside the script itself.
- `rm -rf` on any path without explicit user confirmation printed immediately before.
- Suppressing exit codes on critical steps with `|| true` — non-critical steps may use `|| true` only when accompanied by a `ponytail:` comment naming the justification.
- Ignoring the return value of `sudo` calls.
- Hardcoding absolute paths that differ across distros (use `command -v` or `which`).
- Writing secrets, tokens, or passwords anywhere in script output or log redirects.
