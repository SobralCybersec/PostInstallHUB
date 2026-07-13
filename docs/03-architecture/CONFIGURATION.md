---
title: "Configuration and Secrets"
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

# Configuration

> PostInstallHUB requires no configuration file. Scripts run with sensible defaults out of the box. All knobs are optional environment variables, set by the caller before invoking `install.sh`.

## Precedence

1. Built-in safe defaults (hardcoded in `install.sh` and distro scripts)
2. Environment variables exported by the caller before running the script

There is no config file, no secret manager, no deployment-time config layer. The script reads only what is in the environment at invocation time.

## Configuration registry

| Key | Type | Default | Secret | Purpose |
|---|---|---|---:|---|
| `POSTINSTALL_YES` | `0` or `1` | `0` | No | Skip the backup warning prompt. Set to `1` for automation, CI, or unattended runs. |
| `POSTINSTALL_SKIP_DOTFILES` | `0` or `1` | `0` | No | Skip the dotfile curl step entirely. Useful when managing dotfiles separately. |
| `POSTINSTALL_DOTFILES_URL` | URL string | built-in companion repo URL | No | Override the companion dotfile repo URL. Must be a valid `curl`-fetchable URL. |
| `POSTINSTALL_SKIP_TWEAKS` | `0` or `1` | `0` | No | Skip system tweaks (locale, fonts, keymaps, etc.). Packages still install. |

## Rules

- All env vars are checked at script start, before any install step runs.
- Invalid or unrecognised values print a yellow warning to stderr and fall back to the default — the script never exits due to a bad env var value.
- No config is written to disk. The only files written are the installed packages and the dotfiles themselves (which belong to the dotfile repo, not to PostInstallHUB).
- There are no secrets. No API keys, tokens, passwords, or credentials are accepted, stored, or transmitted by PostInstallHUB.
- `POSTINSTALL_DOTFILES_URL` is the only value that accepts free-form user input. The script validates it is non-empty and begins with `http://` or `https://` before use.

## Secrets

None. PostInstallHUB does not handle secrets in any form. Package managers authenticate to their own mirrors using the OS's built-in keyring (apt GPG keys, pacman keyring, etc.) — PostInstallHUB does not touch those.

If the companion dotfile repo is private, the user must configure SSH or a token in their environment before running the script. PostInstallHUB will not prompt for credentials.

## Example: unattended CI run

```bash
export POSTINSTALL_YES=1
export POSTINSTALL_SKIP_DOTFILES=1
curl -fsSL https://raw.githubusercontent.com/.../install.sh | bash
```

## Example: custom dotfile repo

```bash
export POSTINSTALL_DOTFILES_URL="https://raw.githubusercontent.com/myuser/mydots/main/install.sh"
curl -fsSL https://raw.githubusercontent.com/.../install.sh | bash
```
