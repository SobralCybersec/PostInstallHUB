---
title: "Acceptance Criteria"
status: "draft"
owner: "Matheus"
reviewers:
  - "Matheus"
version: "0.1.0"
last_reviewed: "2026-07-13"
review_cycle: "quarterly"
applies_to: "0.1.0"
source_of_truth: true
related:
  - REQUIREMENTS.md
  - USE-CASES.md
supersedes: null
---

# Acceptance criteria

## Release acceptance checklist

- [ ] All MUST requirements are verified (FR-001, FR-002, FR-006, FR-007, FR-008, FR-009, FR-010)
- [ ] Security requirements are verified (SEC-001, SEC-002, SEC-003)
- [ ] No known regressions on Ubuntu 22.04, Arch, and Fedora
- [ ] Migrations and rollback are tested (idempotency pass on a pre-configured VM)
- [ ] Negative scenarios pass (unsupported OS, stale lock, concurrent run, missing network)
- [ ] No forbidden side-effects (no credentials logged, no HTTP calls, no files outside `$HOME` and `/tmp`)
- [ ] Invalid or unauthorized context rejected (unsupported OS exits cleanly without touching packages)

---

## AC-001 — OS Detection (FR-001)

**Initial context:** Fresh Ubuntu 22.04 machine with internet access and `sudo` rights; no lock file present.

**Steps:**
1. Run `curl -fsSL https://raw.githubusercontent.com/matheusgomescosta/PostInstallHUB/main/install.sh | bash`

**Observable result:**
- `/etc/os-release` is read by the script
- `ID=ubuntu` is detected
- `scripts/linux/ubuntu.sh` (or equivalent Debian/Ubuntu path) is sourced or executed
- Script does not fall through to the unsupported-OS error branch

**Second result / additional context:**
- Repeat with an Arch ISO: `ID=arch` detected → `scripts/linux/arch.sh` executed
- Repeat with Fedora 38: `ID=fedora` detected → `scripts/linux/fedora.sh` executed

**Forbidden side-effect:** Script must not attempt any package installs before OS detection completes.

---

## AC-002 — Package Install (FR-002)

**Initial context:** Fresh Arch Linux machine; `git`, `neovim`, `zsh`, `curl` not yet installed.

**Steps:**
1. Run install script to completion

**Observable result:**
- `command -v git` exits `0`
- `command -v neovim` exits `0`
- `command -v zsh` exits `0`
- `command -v curl` exits `0`

**Additional context:** On Ubuntu, verify via `dpkg -l git neovim zsh curl` — all show `ii` status.

**Forbidden side-effect:** No packages outside the declared list installed without user consent.

---

## AC-003 — Dotfiles (FR-003)

**Initial context:** System with internet access; dotfile companion repo accessible at its GitHub URL.

**Steps:**
1. Run install script
2. Observe dotfile curl invocation in script output

**Observable result:**
- Dotfile curl command exits `0`
- Expected dotfile symlinks or config files exist in `$HOME` (e.g. `~/.zshrc`, `~/.config/nvim/init.vim` or equivalent per dotfile preset)

**Safe failure result (alternative):** If the dotfile repo is unreachable, the script prints a warning and continues — exits `0`; remaining steps complete.

---

## AC-004 — zsh Default Shell (FR-004)

**Initial context:** System where `bash` is the current default shell.

**Steps:**
1. Run install script to completion
2. Open a new login shell session

**Observable result:**
- `echo $SHELL` in the new session returns `/bin/zsh` or `/usr/bin/zsh`
- `/etc/passwd` entry for the current user shows the zsh path

**Forbidden side-effect:** `chsh` must not be called if `zsh` is already the default (idempotency).

---

## AC-005 — System Tweaks (FR-005)

**Initial context:** Clean `~/.zshrc` (or none).

**Steps:**
1. Run install script to completion
2. Inspect `~/.zshrc`

**Observable result:**
- Configured aliases declared by the script are present in `~/.zshrc`
- Shell config defaults (e.g. history size, prompt setup) are present
- No duplicate entries if run twice (idempotency guard)

---

## AC-006 — Backup Warning (FR-006)

**Initial context:** `~/.zshrc` already exists with user content.

**Steps:**
1. Run install script; do not press Enter at the warning prompt

**Observable result:**
- Script prints: `WARNING: This will modify ~/.zshrc. Press Enter to continue or Ctrl+C to abort.`
- Script pauses and waits for input before writing anything to the file
- Pressing Ctrl+C at this point leaves `~/.zshrc` unmodified

**Additional context:** Verify by checking `~/.zshrc` mtime before and after Ctrl+C abort — must be unchanged.

---

## AC-007 — Lock File (FR-007)

**Initial context:** `/tmp/postinstallhub.lock` already exists (simulating a running instance).

**Steps:**
1. Run install script

**Observable result:**
- Script prints an error referencing the lock file path
- Script exits with code `1`
- No packages are installed; no config files are modified
- Exit occurs within 2 seconds of invocation

**Safe failure result:** If the lock exists but no matching PID is alive (stale lock), script prints a stale-lock warning, removes the file, and proceeds normally.

---

## AC-008 — Idempotency (FR-008)

**Initial context:** System already fully configured by a previous successful run.

**Steps:**
1. Run install script a second time; allow it to complete

**Observable result:**
- Script exits `0`
- Package manager output contains "already installed" / "nothing to do" for every package — no packages re-downloaded
- No config file modification timestamps change (verify via `stat ~/.zshrc` before and after)
- `chsh` not invoked (zsh already default)

---

## AC-009 — Exit Codes (FR-009)

**Initial context:** Simulate package manager failure (e.g. break apt with a bad source, or run in a network-isolated container).

**Steps:**
1. Run install script; let it reach the package install step
2. Observe exit behaviour when package manager fails

**Observable result:**
- Script prints the failing command and its stderr output
- Script exits with the package manager's exit code (non-zero)
- Lock file is removed before exit (cleanup runs on all exit paths)

---

## AC-010 — Curl Bootstrap (FR-010)

**Initial context:** Minimal fresh OS image with only `curl` installed; no `git`, `make`, `python`, or other build tools present.

**Steps:**
1. Run `curl -fsSL https://raw.githubusercontent.com/matheusgomescosta/PostInstallHUB/main/install.sh | bash`

**Observable result:**
- `install.sh` downloads and begins execution without requiring any tool beyond `curl` / `bash`
- Script does not error with "command not found" for any bootstrapping dependency
- Full install flow proceeds normally from this entry point

---

## AC-011 — Windows Setup (FR-011)

**Initial context:** Windows 10 (build 1809+) or Windows 11 with `winget` available; Administrator rights.

**Steps:**
1. Run `setup.cmd` (or `setup.ps1`) from the repository

**Observable result:**
- `git --version` succeeds after script completion
- `nvim --version` succeeds after script completion
- Script exits `0`
- When `winget` is absent: script exits `1` with a link to the App Installer (`https://aka.ms/getwinget`)
