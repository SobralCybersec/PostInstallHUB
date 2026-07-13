---
title: "Error Handling"
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

# Error handling

## Philosophy

Fail fast on anything critical. Warn and continue on anything optional.

A package manager failure is critical — the machine ends up in an unknown state if we silently skip it. A dotfile curl failure is not — the machine is usable without custom dotfiles, and the user gets a clear manual recovery instruction.

`set -e` is active throughout all scripts. Unexpected non-zero exits surface immediately rather than silently propagating into later steps. Exceptions to `set -e` (non-critical steps wrapped in `|| true`) are marked with a `# ponytail:` comment naming the justification.

## Error categories

| Category | Meaning | Retryable | Logged level | User message |
|---|---|---:|---|---|
| Unsupported OS | `/etc/os-release` didn't match any known distro | No | Error (red) | Explicit list of supported OSes; how to open an issue |
| Package failure | `apt`/`pacman`/`dnf`/`winget` exited non-zero | No (auto) | Error (red) | Package name + "check your network and package manager, then re-run" |
| Lock conflict | Lock file already exists at script start | No | Error (red) | Lock file path + instruction to delete if stale |
| Missing sudo | `sudo` not found and a step requires it | No | Error (red) | "Run as root or install sudo" |
| Dotfile failure | `curl` to dotfile repo returned non-zero | Non-fatal | Warn (yellow) | URL tried + "run dotfile installer manually" |
| Shell change failure | `chsh` exited non-zero | Non-fatal | Warn (yellow) | `chsh -s $(which zsh)` command to run manually |

## Rules

- All errors print to **stderr** using the `log_error` or `log_warn` functions from `common.sh`, which prepend a colored prefix (`[ERROR]` in red, `[WARN]` in yellow).
- Error messages name the **exact thing that failed** — package name, file path, URL — not just "something went wrong."
- Non-fatal steps (dotfiles, `chsh`) always end with a one-line manual recovery command the user can copy-paste.
- No stack traces are exposed. Internal detail stays internal.
- Exit codes are consistent across all distro scripts (see registry below).
- `trap 'rm -f "$LOCK_FILE"' EXIT` is set immediately after lock acquisition so the lock is always cleaned up, even on unexpected exits.

## Exit code registry

| Code | Meaning | Recovery |
|---|---|---|
| `0` | Success — all steps completed | — |
| `1` | General / package install failure | Fix the reported package manager error, then re-run |
| `2` | Unsupported OS | Check supported distros in README; open an issue if yours should be supported |
| `3` | Lock conflict — another instance may be running | If no other instance is running: `rm /tmp/postinstallhub.lock`, then re-run |
| `4` | `sudo` unavailable | Run the script as root, or install sudo first |

## Error code registry (E-codes for internal reference)

| Code | Meaning | Exit code | Fatal | External docs |
|---|---|---|---:|---|
| E001 | Unsupported OS | 2 | Yes | README § Supported Platforms |
| E002 | Package install failure | 1 | Yes | README § Troubleshooting |
| E003 | Lock file exists | 3 | Yes | README § Troubleshooting |
| E004 | `sudo` unavailable | 4 | Yes | README § Troubleshooting |
| E005 | Dotfile curl failure | — (warn, continue) | No | README § Dotfiles |
| E006 | `chsh` failure | — (warn, continue) | No | README § Shell Setup |

## Logging

All output goes to stdout (informational) or stderr (warnings and errors) in the user's live terminal session. No log file is written by default. The user can capture everything with:

```bash
curl -fsSL .../install.sh | bash 2>&1 | tee ~/postinstall.log
```

Log line format (produced by `log_info` / `log_warn` / `log_error` in `common.sh`):

```
[INFO]  Updating package lists...
[WARN]  Could not fetch dotfiles from https://... — run installer manually.
[ERROR] Failed to install neovim. Check apt output above and re-run.
```

Colors are emitted only when stdout/stderr is a TTY (`[ -t 1 ]`); plain text otherwise (for log file redirect and CI).

## Lock cleanup on unexpected exit

```bash
# set immediately after lock acquisition in install.sh
trap 'rm -f "$LOCK_FILE"' EXIT
```

SIGTERM and SIGINT trigger the trap. SIGKILL does not — if the script is hard-killed, `/tmp/postinstallhub.lock` may remain. E003 message tells the user exactly what to delete.

If the script is killed mid-`apt`/`pacman`/`dnf`, the package manager's own lock may also remain. Standard recovery:

- apt: `sudo dpkg --configure -a`
- pacman: `sudo rm /var/lib/pacman/db.lck`
- dnf: `sudo rm /var/cache/dnf/*.pid`
