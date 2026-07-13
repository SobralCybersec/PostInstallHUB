---
title: "Roadmap"
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

# Roadmap

No fixed dates. Phases are sequenced by dependency, not calendar. Each phase has a concrete done condition.

## Phase 0 — Repo scaffold + common lib

**Goal:** A working repo that any agent or contributor can pick up, with shared helpers ready for distro scripts to source.

**Deliverables:**

- GitHub repo created: `matheusgomescosta/PostInstallHUB`
- `README.md`: project description, install command, supported platforms, what it does/doesn't do
- `LICENSE`: MIT
- `AGENTS.md`: universal agent operating rules (how Claude/Codex/Pi should work in this repo)
- `CLAUDE.md`: points to AGENTS.md, Claude-specific notes
- `lib/colors.sh`: ANSI color variables + `info`, `ok`, `warn`, `err` print functions
- `lib/lock.sh`: write `/tmp/postinstallhub.lock` on start; remove on clean exit; `trap` on crash/signal
- `lib/backup.sh`: copy `$1` to `$1.bak.$(date +%s)` before overwriting; print warning
- `install.sh` skeleton: reads `/etc/os-release` to detect distro; maps to script path; prints error and exits for unknown distros; delegates to distro script when found

**Done when:** Running `install.sh` on Ubuntu prints the detected distro name and `[INFO] Delegating to scripts/linux/ubuntu.sh` (even though the script doesn't exist yet) then exits with a clear error rather than a crash.

---

## Phase 1 — Linux scripts

**Goal:** All four Linux distros complete end-to-end.

**Deliverables:**

- `scripts/linux/ubuntu.sh`:
  - `apt-get update && apt-get upgrade -y`
  - `apt-get install -y git curl neovim zsh`
  - curl dotfiles from companion repo
  - system tweaks
  - `chsh -s $(which zsh)`
- `scripts/linux/arch.sh`: same flow via `pacman -Syu` and `pacman -S`
- `scripts/linux/fedora.sh`: same flow via `dnf update` and `dnf install`
- `scripts/linux/omarchy.sh`: Arch base (pacman) + Hyprland-specific config paths and tweaks

Each script:
- sources `lib/colors.sh`, `lib/lock.sh`, `lib/backup.sh`
- checks if each package is already installed before installing (idempotent)
- calls `backup.sh` before placing any dotfile

**Done when:** Each script runs cleanly in a fresh Docker container of the target distro. Running it twice produces no errors and no duplicate actions.

---

## Phase 2 — Windows scripts

**Goal:** Windows support via CMD entry point and PowerShell for config work.

**Deliverables:**

- `scripts/windows/setup.cmd`:
  - Check for winget; error and exit if missing
  - `winget install --id Git.Git -e --silent`
  - `winget install --id Neovim.Neovim -e --silent`
  - `winget install --id cURL.cURL -e --silent`
  - calls `setup.ps1` for dotfile placement and shell config
- `scripts/windows/setup.ps1`:
  - curl dotfiles from companion repo
  - PowerShell profile setup
  - system tweaks applicable to Windows

**Note:** `install.sh` is Linux/bash. On Windows the user runs `setup.cmd` directly. README documents both entry points.

**Done when:** `setup.cmd` runs cleanly in a Windows 10 and Windows 11 VM from CMD. Packages installed, dotfiles placed, no errors on second run.

---

## Phase 3 — Tests, documentation, release

**Goal:** Confidence the scripts work across all targets; README ready for public use; first release tagged.

**Deliverables:**

- Docker-based smoke tests for each Linux distro:
  - `FROM ubuntu:latest` / `FROM archlinux:latest` / `FROM fedora:latest`
  - Run `install.sh`, assert `git`, `curl`, `neovim`, `zsh` are present and on PATH
  - Run again, assert no errors (idempotency check)
- `tests/` directory with one `test-<distro>.sh` per distro that builds and runs the container
- README updated with:
  - curl one-liner (prominent, top of file)
  - supported platforms table
  - what it installs (exact package list)
  - what it doesn't do (no dev env)
  - manual Windows instructions
  - companion repo link
- GitHub Release `v1.0.0` with:
  - `install.sh` attached
  - SHA256 checksum in release notes

**Done when:** All Docker tests pass. `curl -fsSL .../install.sh | bash` works on a fresh Ubuntu container from the release tag.

---

## Future / not committed

These are ideas only. Not planned for v1.0.0.

| Idea | Why deferred |
|---|---|
| macOS support (brew) | Different toolchain; separate concern |
| Additional distros (NixOS, openSUSE, Alpine) | Unknown effort; test burden |
| Interactive mode (ask before each step) | Adds complexity; not needed for solo use |
| Automated update check | Maintenance concern, not post-install |
| GUI wrapper | No user need identified |
