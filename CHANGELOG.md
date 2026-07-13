---
title: "Changelog"
status: "active"
owner: "Matheus"
version: "0.1.0"
last_reviewed: "2026-07-13"
---

# Changelog

All notable changes to PostInstallHUB are recorded here.

Format: [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/)
Versioning: [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html)

---

## [Unreleased]

### Added

#### CLI flag overrides
- `install.sh` — `_parse_cli_flags()` parses `--KEY=VALUE` / `--KEY` args **before** the TUI
  - Any env var the distro scripts read can be passed as a CLI flag
  - `--help` prints usage and exits 0; unknown `-*` flags warn and continue
  - Examples: `bash install.sh --UBUNTU_NVIDIA=1 --POSTINSTALL_DOTFILES=jakoolit`
  - `--POSTINSTALL_YES=1` is equivalent to the env-var form

#### New distros
- `scripts/linux/opensuse.sh` — openSUSE Leap / Tumbleweed post-install
  - zypper helpers: `zypper_install`, `zypper_addrepo`, `flatpak_remote_add`, `flatpak_install`
  - Steps: update · Packman repo · essential packages · Flatpak+Flathub · NVIDIA · Gaming · zsh
  - Flags: `OPENSUSE_NVIDIA` · `OPENSUSE_GAMING` · `OPENSUSE_PACKMAN`
- `scripts/linux/nixos.sh` — NixOS post-install / Home Manager setup
  - Declarative approach: idempotent appends to `/etc/nixos/configuration.nix`
  - Helpers: `nix_config_has` / `nix_config_append` with `backup_warning`
  - Steps: channels · flakes · unfree · Home Manager · essential packages advisory · rebuild
  - Flags: `NIXOS_FLAKES` · `NIXOS_UNFREE` · `NIXOS_HOME_MANAGER`
- `install.sh` + `lib/tui.sh` — both updated with `opensuse-*` and `nixos` cases

#### Shell setup library
- `lib/shells.sh` — Fish and Nushell setup helpers
  - `setup_fish()`: install → `/etc/shells` → `chsh` → fisher → plugins (nvm, fzf, tide) → `~/.config/fish/conf.d/postinstallhub.fish`
  - `setup_nushell()`: install → `env.nu` + `config.nu` config → optional default-shell
  - `_shells_detect_pm()`: auto-detects apt / pacman / dnf / zypper
  - Fully idempotent, honours `POSTINSTALL_YES=1`, uses `backup_warning` on existing files
- `scripts/linux/endeavour.sh` — `_step_fish` now delegates to `setup_fish` from `lib/shells.sh`

#### GUI dotfiles picker
- `lib/picker.sh` — rofi/fzf GUI picker for dotfiles and bool flags
  - `pick_dotfiles_gui DISTRO` — rofi dmenu > fzf fallback > empty (text TUI fallback)
  - `pick_flags_gui DISTRO` — multi-select flag picker (rofi `-multi-select` or `fzf --multi`)
  - Auto-detects `$DISPLAY` / `$WAYLAND_DISPLAY` before attempting GUI
- `lib/tui.sh` — sources `picker.sh`; calls `pick_dotfiles_gui` at start of `run_config_tui`
  - New `POSTINSTALL_PICKER` env: `auto` (default) · `tui` (force text) · `gui` (force GUI)

#### Web dashboard
- `tools/dashboard.sh` — streams install progress to a browser via Server-Sent Events
  - Self-contained HTML (no CDN), dark theme, ANSI stripping, auto-scroll, elapsed timer
  - SSE endpoint `/events` tails `/tmp/postinstallhub.log` in real-time
  - `--run` flag launches `install.sh` and pipes output to the log automatically
  - Works over SSH tunnel: `ssh -L 8080:localhost:8080 user@server`
  - Requires Python 3 (standard library only, no pip dependencies)

#### Ansible playbook export
- `tools/ansible-export.sh` — generates an idempotent Ansible playbook from selected flags
  - Auto-detects distro from `/etc/os-release` (or `--distro=X` override)
  - Reads already-exported env vars set by the TUI
  - Generates YAML with per-distro tasks (apt/dnf/pacman/zypper modules), tags, vars block
  - Distro coverage: ubuntu · fedora · arch · opensuse · debian · nixos · kali
  - Validates output with `python3 -c "import yaml; yaml.safe_load(...)"` if available
  - Usage: `bash tools/ansible-export.sh --output=my-workstation.yml`

#### TUI
- `lib/tui.sh` — interactive flag-configuration TUI (`run_config_tui`)
  - Pure-bash numbered checkbox `[x]` + radio `[●]` menu; no external deps
  - Distro-aware flag arrays: Ubuntu · Arch · Endeavour/CachyOS · Fedora · Debian · Kali · OpenSUSE · NixOS
  - Dotfiles radio: jakoolit · caelestia · zerodaygym (kali) · none (default)
  - `POSTINSTALL_YES=1` skips TUI entirely (CI / batch mode)
  - Exports selected env vars; shows 3-second summary before launch
- `install.sh` — wired `run_config_tui "$distro"` before the distro `case` block

#### Tests
- `tests/test_opensuse.sh` — 8 test sections; stubs zypper, flatpak, curl, chsh
- `tests/test_nixos.sh` — 41 cases across 9 sections; full mock harness (no root, no real NixOS)

#### Docs / misc
- `scripts/linux/dotfiles.sh` — jakoolit comment updated: NixOS added to supported distros list
- Complete spec documentation for all 60+ doc files
- `CLAUDE.md` and `AGENTS.md` for AI coding assistant context
- `docs/00-project/COCKPIT-BRIEF.md` rewritten for PostInstallHUB
- All placeholder `{{TOKENS}}` resolved across spec docs
- N/A markers for inapplicable template sections (API, database, Obsidian, AI, etc.)

---

## [0.1.0] - TBD

### Added

- `install.sh` — single entry point with OS auto-detection
- `lib/colors.sh` — ANSI color constants
- `lib/lock.sh` — lock file management
- `lib/backup.sh` — backup warning helper
- `scripts/linux/common.sh` — shared bash functions
- `scripts/linux/ubuntu.sh` — Ubuntu/Debian setup (apt)
- `scripts/linux/arch.sh` — Arch Linux setup (pacman)
- `scripts/linux/fedora.sh` — Fedora setup (dnf)
- `scripts/linux/omarchy.sh` — Omarchy setup (pacman + Hyprland)
- `scripts/windows/setup.cmd` — Windows CMD setup
- `scripts/windows/setup.ps1` — PowerShell setup
- `tests/test_ubuntu.sh`, `test_arch.sh`, `test_fedora.sh`, `test_omarchy.sh`

<!--
[Unreleased]: https://github.com/SobralCybersec/PostInstallHUB/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/SobralCybersec/PostInstallHUB/releases/tag/v0.1.0
-->
