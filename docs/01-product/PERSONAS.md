---
title: "Personas and Roles"
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

# Personas and roles

## Persona: The Fresh Installer

- Role: End user and developer (Matheus himself, plus similar power users)
- Context: Terminal on a freshly installed Linux distro or Windows machine; has sudo rights and internet access; no personal tooling set up yet
- Goals: Get a configured, comfortable shell environment in one command; avoid opening 20 browser tabs of setup tutorials; have consistent results across machines and reinstalls
- Pain points: Repeating the same setup process after every reinstall; forgetting which packages or tweaks to apply; inconsistency between machines when steps are done manually; spending 30–60 minutes on boring bookkeeping before any real work can happen
- Technical proficiency: Intermediate to advanced — knows what bash is, comfortable in a terminal, understands package managers and shell configuration
- Accessibility considerations: Standard terminal output; ANSI color is helpful for readability but the script must remain usable without it (plain-text fallback for color-blind or minimal terminals)
- Typical environment: Desktop Linux (Ubuntu/Debian, Arch, Fedora, or Omarchy) or Windows desktop; local machine, not a server; always has a working internet connection at the time of setup
- Success condition: After running one curl command, zsh is installed and set as the default shell, neovim is ready, dotfiles are configured via the companion repo, and system tweaks are applied — total elapsed time under 5 minutes, no manual steps required

## System roles

| Role | Description | Can access | Cannot access |
|---|---|---|---|
| Local user (sudo) | The person running the install script on their own machine | All script operations; sudo-gated package installs and shell changes | N/A — this is a local CLI tool with no remote access control |

## Permission matrix

N/A — PostInstallHUB is a local shell script. There are no user accounts, sessions, or role-based access controls. The script runs as the invoking user with sudo for package installation; no other permission model exists.

## Role lifecycle

N/A — the script has no concept of user accounts or persistent roles. It runs once (or idempotently on re-run) and exits. There is nothing to provision, suspend, or delete.
