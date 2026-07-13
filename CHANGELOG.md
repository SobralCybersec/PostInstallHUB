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
