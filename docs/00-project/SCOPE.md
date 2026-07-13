---
title: "Scope and Non-Goals"
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

# Scope

## Problem boundary

PostInstallHUB owns the post-install configuration of a fresh OS installation. It covers package installation, dotfile setup, and system tweaks on supported Linux distros and Windows. It does not own ongoing system maintenance, package updates after initial setup, or anything requiring a running user session beyond initial shell configuration.

## In scope

| ID | Capability | Release | Notes |
|---|---|---|---|
| SCP-001 | OS and distro auto-detection | 0.1.0 | Reads `/etc/os-release` on Linux; `ver` on Windows |
| SCP-002 | Package installation: git, curl, neovim, zsh | 0.1.0 | Via apt / pacman / dnf / winget |
| SCP-003 | Dotfile setup via curl from companion GitHub repo | 0.1.0 | Pulls preset configs, no local dotfile management |
| SCP-004 | System tweaks (set zsh as default shell, distro-specific settings) | 0.1.0 | |
| SCP-005 | Lock file preventing concurrent runs | 0.1.0 | `/tmp/postinstallhub.lock` |
| SCP-006 | Backup warning + `.bak` file before overwriting any config | 0.1.0 | |
| SCP-007 | Idempotent execution (safe to run twice) | 0.1.0 | |
| SCP-008 | Ubuntu / Debian support | 0.1.0 | apt |
| SCP-009 | Arch Linux support | 0.1.0 | pacman |
| SCP-010 | Fedora support | 0.1.0 | dnf |
| SCP-011 | Omarchy support (DHH's Arch + Hyprland) | 0.1.0 | Arch base + Hyprland-specific config paths |
| SCP-012 | Windows support (CMD/batch + PowerShell) | 0.1.0 | winget |
| SCP-013 | Colored terminal output with step-level status | 0.1.0 | info / ok / warn / err helpers in lib/colors.sh |
| SCP-014 | Unknown distro exits cleanly with an error | 0.1.0 | No side effects on unsupported OS |

## Out of scope

| ID | Excluded capability | Reason | Reconsider when |
|---|---|---|---|
| OOS-001 | Dev environment setup (Node, Docker, Python, Ruby, Go runtimes) | Out of problem boundary; separate concern | Never for this project |
| OOS-002 | Mobile OS (Android, iOS) | Different toolchain and install model entirely | Separate project if ever |
| OOS-003 | GUI installer | CLI is sufficient; adds complexity for no user benefit | Never for MVP |
| OOS-004 | Cloud sync of configs | Out of scope; user manages their own sync/dotfile repo | Never |
| OOS-005 | Multi-user or team features | Solo tool; no auth model | Never |
| OOS-006 | Automatic updates after initial install | Maintenance concern, not post-install | Separate script if needed |
| OOS-007 | Package manager setup (installing apt/pacman/dnf itself) | Assumed present on supported distros | Never |
| OOS-008 | NixOS, openSUSE, Gentoo, Alpine | Not in target set; unknown test burden | Add per distro if requested |
| OOS-009 | macOS | Different toolchain (brew); separate concern | Separate repo if ever |

## Non-goals

- The system will not manage packages after the initial install run.
- The system will not act as a general dotfile manager (no versioning, no conflict resolution).
- The system will not set up a development environment (no language runtimes, no containers).
- The initial release is not intended to be a replacement for tools like Ansible, LARBS, or Nix.

## Assumptions

| ID | Assumption | Validation method | Owner | Due |
|---|---|---|---|---|
| ASM-001 | User has internet access during install | Required to download packages and dotfiles; stated in README | Matheus | Pre-release |
| ASM-002 | User has sudo rights (Linux) or admin rights (Windows) | Script will fail visibly at first privileged op if not | Matheus | Phase 1 |
| ASM-003 | Target OS is a fresh install or at minimum has the package manager available | Tested in clean Docker containers per distro | Matheus | Phase 1 |
| ASM-004 | Companion dotfile repo is public and accessible via curl | Verified before release | Matheus | Phase 3 |
| ASM-005 | winget is available on the Windows target | Requires Windows 10 1709+ or Windows 11; stated in README | Matheus | Phase 2 |

## Constraints

- Budget: none (personal project, all free tooling)
- Schedule: ASAP — MVP target, no fixed date
- Supported platforms: Ubuntu/Debian, Arch, Fedora, Omarchy, Windows 10/11
- Regulatory: none
- Team capacity: 1 person (Matheus)
- Required integrations: companion dotfile repo (public GitHub); no APIs, no auth

## Scope-change process

1. Submit the proposed change with user value, cost, risks, and affected requirements.
2. Update this document and relevant specs.
3. Create an ADR for architectural changes.
4. Obtain approval from Matheus.
