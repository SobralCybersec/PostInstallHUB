---
title: "Glossary"
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

# Glossary

| Term | Definition | Do not confuse with | Source |
|---|---|---|---|
| post-install | The configuration phase that runs after an OS is freshly installed but before the machine is in daily use. PostInstallHUB owns exactly this phase. | System updates / ongoing maintenance (out of scope) | Project definition |
| dotfile | A configuration file for a shell or tool, named with a leading dot (e.g. `.zshrc`, `.gitconfig`). PostInstallHUB pulls dotfile presets from the companion repo via curl. | A full dotfile manager (stow, chezmoi) — PostInstallHUB does not manage dotfiles after initial placement | Unix convention |
| companion repo | The separate GitHub repository that hosts Matheus's dotfile presets. PostInstallHUB fetches files from it via curl during install. Not bundled in this repo. | PostInstallHUB itself | Project definition |
| entry point | `install.sh` — the single script fetched and piped to bash by the curl one-liner. Responsible for OS/distro detection and delegating to the correct distro script. | Distro scripts (they are called by the entry point, not directly) | COCKPIT-BRIEF.md §4 |
| OS detection | The logic in `install.sh` that reads `/etc/os-release` (Linux) or `ver` (Windows) to determine which distro script to call. | Package manager detection (separate step inside distro scripts) | COCKPIT-BRIEF.md §4 |
| distro | A specific Linux distribution (Ubuntu, Arch, Fedora, Omarchy) or Windows. Each distro has its own script under `scripts/`. | Package manager — multiple distros can share a package manager (e.g. Arch and Omarchy both use pacman) | Common usage |
| idempotent | A script that produces the same end state whether run once or multiple times, without errors or duplicate side effects on subsequent runs. | Atomic — idempotent means safe to repeat, not that it completes as a single transaction | SCOPE.md SCP-007 |
| lock file | A file written to `/tmp/postinstallhub.lock` at the start of a run and removed on exit. Prevents two concurrent executions of the script. | A package manager lock file (e.g. `yarn.lock`) — unrelated concept | SCOPE.md SCP-005 |
| backup warning | A message printed to the terminal before any config file is overwritten, followed by the creation of a `.bak.<timestamp>` copy of the original. Implemented in `lib/backup.sh`. | A full backup system — this is file-level, single-step protection only | SCOPE.md SCP-006 |
| Omarchy | DHH's (David Heinemeier Hansson's) opinionated Arch + Hyprland setup. Uses pacman as package manager but has different config file paths than plain Arch. Handled by `scripts/linux/omarchy.sh`. | Plain Arch Linux — same package manager, different config layout | https://omarchy.org |
| apt | The package manager for Ubuntu and Debian-based distros. Used in `scripts/linux/ubuntu.sh`. | apt-get — older interface; apt is preferred | Debian project |
| pacman | The package manager for Arch Linux and Omarchy. Used in `scripts/linux/arch.sh` and `scripts/linux/omarchy.sh`. | apt, dnf — different distros entirely | Arch Linux |
| dnf | The package manager for Fedora. Replaced yum. Used in `scripts/linux/fedora.sh`. | yum — dnf is the current tool; yum is legacy | Fedora project |
| winget | The Windows Package Manager CLI. Used in `scripts/windows/setup.cmd` to install packages on Windows 10/11. | Chocolatey, Scoop — third-party alternatives; winget is the Microsoft-native tool | Microsoft |
| tweak | A system-level configuration change applied after package installation. Examples: setting zsh as the default shell (`chsh`), applying Hyprland-specific config on Omarchy. Not a package install. | Package installation — tweaks happen after packages are in place | Project definition |
| curl one-liner | The single command a user runs to start PostInstallHUB: `curl -fsSL https://raw.githubusercontent.com/matheusgomescosta/PostInstallHUB/main/install.sh \| bash` | A full installer with a GUI or interactive prompt | Project definition |

## Acronyms

| Acronym | Expansion | Meaning in this project |
|---|---|---|
| OS | Operating System | Linux (various distros) or Windows |
| CMD | Command Prompt | Windows CMD shell; entry point for Windows scripts |
| PS | PowerShell | Windows PowerShell; handles config work on Windows |
| MVP | Minimum Viable Product | The first working release: all 4 Linux distros + Windows supported |
| bak | backup | File extension suffix used by `lib/backup.sh` when preserving originals |

## Naming rules

- Script files: `kebab-case.sh` or `kebab-case.cmd` / `kebab-case.ps1`
- Library helpers: `lib/lowercase.sh`
- Distro scripts: `scripts/linux/<distroname>.sh`, `scripts/windows/setup.cmd`
- Backup files: `<original-filename>.bak.<unix-timestamp>`
- Lock file: `/tmp/postinstallhub.lock` (fixed path, not configurable)
