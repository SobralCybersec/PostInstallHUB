---
title: "Implementation Phases"
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

# Implementation phases

PostInstallHUB ships in four phases: scaffold, Linux scripts, Windows scripts,
then tests + docs + first release.

---

## Phase 0 — Repository scaffold

**Goal:** Stand up the repo with the right directory structure and shared
library so all subsequent scripts have a consistent foundation.

**Tasks:**

1. Create directory structure:
   ```
   PostInstallHUB/
   ├── install.sh            # OS detection + dispatch
   ├── scripts/
   │   ├── linux/
   │   │   ├── ubuntu.sh
   │   │   ├── arch.sh
   │   │   ├── fedora.sh
   │   │   └── omarchy.sh
   │   └── windows/
   │       ├── setup.cmd
   │       └── setup.ps1
   ├── lib/
   │   ├── colors.sh         # ANSI color helpers (info/warn/error/ok)
   │   ├── lock.sh           # Lock file: prevent concurrent runs
   │   └── backup.sh         # Pre-run config backup helper
   ├── tests/
   │   ├── test_ubuntu.sh
   │   ├── test_arch.sh
   │   ├── test_fedora.sh
   │   └── test_omarchy.sh
   ├── docs/
   ├── AGENTS.md
   ├── CLAUDE.md
   ├── CHANGELOG.md
   └── README.md             # Includes curl one-liner (placeholder tag URL)
   ```
2. Write `lib/colors.sh` — `info`, `warn`, `error`, `ok` functions using ANSI codes.
3. Write `lib/lock.sh` — create `/tmp/postinstallhub.lock` on start, remove on exit/trap.
4. Write `lib/backup.sh` — backs up `~/.bashrc`, `~/.zshrc`, `~/.config` before changes.
5. Write skeleton `install.sh` — detects OS via `/etc/os-release` and `uname`, dispatches to the right script, shows backup warning before proceeding.
6. Write `AGENTS.md` + `CLAUDE.md` with project rules.
7. Write `README.md` with project description and placeholder curl URL.

**Verify:**

- `bash -n install.sh` exits 0.
- `shellcheck install.sh lib/*.sh` exits 0.
- Directory structure matches the tree above.
- `install.sh` prints "Unsupported OS" and exits 1 on an unrecognized system.

---

## Phase 1 — Linux scripts (Ubuntu, Arch, Fedora, Omarchy)

**Goal:** All four Linux distros fully supported.

**Tasks:**

1. **`scripts/linux/ubuntu.sh`** — `apt-get update`; install `git curl neovim zsh fzf ripgrep wget unzip`; curl dotfiles from Matheus's dotfiles repo; `chsh -s $(which zsh)`; apply terminal tweaks.
2. **`scripts/linux/arch.sh`** — equivalent with `pacman -Syu`; include `yay` AUR helper install if not present.
3. **`scripts/linux/fedora.sh`** — equivalent with `dnf upgrade`; enable RPM Fusion repos if needed.
4. **`scripts/linux/omarchy.sh`** — Arch base + Omarchy-specific additions: Hyprland, `waybar`, `kitty`, `rofi-wayland`, and any Omarchy dotfile layer.
5. Each script: source `lib/colors.sh`, `lib/lock.sh`, `lib/backup.sh` at top; print progress with color helpers; handle errors with `set -euo pipefail`.
6. Docker test each script in its container; verify idempotent re-run.

**Verify (per distro):**

- Docker container runs the script and exits 0.
- All target packages are installed (`command -v git neovim zsh` etc.).
- `zsh` is set as default shell (`getent passwd $USER | cut -d: -f7`).
- Dotfiles are present in `~`.
- Re-running the script exits 0 and produces no errors (idempotent).

---

## Phase 2 — Windows support

**Goal:** Windows 10 and 11 covered.

**Tasks:**

1. **`scripts/windows/setup.cmd`** — `winget install` for `Git.Git`, `Neovim.Neovim`, `Microsoft.WindowsTerminal`, `junegunn.fzf`; set `EDITOR` in user environment; create `%USERPROFILE%\.config` dir.
2. **`scripts/windows/setup.ps1`** — same installs via `winget`; adds PowerShell profile tweaks; installs `oh-my-posh` if desired; sets execution policy for the user scope only.
3. `install.sh` already dispatches Linux; `install.bat` (or README note) covers the Windows entry point.
4. Test in a Windows 10 and Windows 11 VM — clean snapshot before each run.

**Verify:**

- `setup.cmd` runs without errors on a clean Windows 10 VM.
- `setup.ps1` runs without errors on a clean Windows 11 VM.
- `git --version`, `nvim --version` return successfully after install.
- Re-running either script does not error (winget handles already-installed packages).

---

## Phase 3 — Tests, docs, and v0.1.0 release

**Goal:** Ship `v0.1.0` — the first public release.

**Tasks:**

1. Write bash test scripts (`tests/test_ubuntu.sh`, etc.) — each spins up the relevant Docker container, runs the distro script, and asserts packages are present. Exit 0 = pass, exit 1 = fail with details.
2. Write `README.md` with:
   - Project description and supported distros/OS.
   - Curl one-liner using the `v0.1.0` tag URL.
   - Manual fallback instructions (clone + run).
   - Backup warning.
3. Write `CHANGELOG.md` — `## [v0.1.0] - 2026-MM-DD` section.
4. Run full pre-release checklist (see `DEPLOYMENT.md`).
5. Tag `v0.1.0` and create GitHub Release.
6. Verify curl one-liner works on a fresh `ubuntu:22.04` container.

**Verify:**

- `bash tests/test_ubuntu.sh` exits 0.
- `bash tests/test_arch.sh` exits 0.
- `bash tests/test_fedora.sh` exits 0.
- Fresh `docker run --rm ubuntu:22.04` → curl one-liner → all packages present.
- GitHub Release page shows `v0.1.0` tag and CHANGELOG body.
- README curl URL resolves to `v0.1.0` raw content.

---

## Version milestones

| Version | Scope |
|---|---|
| `v0.1.0` | Linux (Ubuntu, Arch, Fedora) + skeleton Windows + tests + README |
| `v0.2.0` | Omarchy script complete + Windows fully tested |
| `v1.0.0` | All distros solid, idempotent, Docker tests green, README complete |
