---
title: "Project Context"
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

# PostInstallHUB Context

## One-paragraph summary

PostInstallHUB is a shell script collection that configures a fresh OS installation with a single curl command. It auto-detects the running OS and distro, installs a baseline set of tools (git, curl, neovim, zsh), pulls dotfile presets from a companion GitHub repo, applies system tweaks, and sets zsh as the default shell. Supported targets are Ubuntu/Debian, Arch, Fedora, Omarchy (DHH's Arch + Hyprland setup), and Windows. The project is owned and maintained by one person (Matheus) and targets the personal-use case of reproducible machine setup across reinstalls and new hardware.

## What triggered this project

Every time a new machine or a fresh OS install comes up, the same sequence of steps follows: install the same packages, copy the same configs, change the default shell, tweak the same system settings. Done manually it takes 20–40 minutes and always drifts slightly from machine to machine. Done ad-hoc from memory it introduces inconsistencies. The goal was to reduce that to one command with consistent, repeatable output.

## Current state

- Phase: MVP — greenfield, nothing built yet
- Implemented: spec documents only
- In progress: spec completion, then install.sh scaffold
- Known gaps: none (greenfield)
- Next milestone: Phase 0 complete — repo scaffold + lib/ helpers + install.sh OS detection

## Alternatives considered

| Alternative | What it does | Why not chosen |
|---|---|---|
| Manual setup | Run commands by hand each time | Inconsistent, slow, error-prone across reinstalls |
| Dotfile-only repo | Repo of config files, user clones and symlinks manually | Solves dotfiles but not package install or system tweaks; still manual |
| Ansible playbook | Full provisioning tool, YAML-defined tasks, idempotent by design | Overkill for a personal solo tool; requires Ansible installed first; YAML overhead for simple package install |
| LARBS (Luke's Auto-Rice Bootstrapping Scripts) | Arch-specific post-install script by Luke Smith | Arch only; opinionated toward his specific rice; not easily adapted |
| ChrisTitusTech scripts | Shell scripts for post-install on various distros | Different scope (heavier, more opinionated); doesn't match Matheus's specific tool set and dotfiles |
| Nix / NixOS | Fully declarative system configuration | Steep learning curve; different mental model; overkill for the problem at hand |

## Why a bash script collection

- Zero dependencies to run (bash is available on every target)
- Easy to read and audit — plain shell, no abstraction layers
- Easy to extend per distro without touching other scripts
- Curl one-liner install works on any fresh system with internet access
- Matheus can maintain it alone without learning a new tool

The tradeoff is that bash scripts are less structured than Ansible or Nix. That's acceptable here because the scope is narrow (baseline packages + dotfiles + tweaks), the operator is the owner, and the project runs in controlled environments (fresh installs Matheus controls).

## Hard constraints

| ID | Constraint | Rationale | Consequence |
|---|---|---|---|
| CON-001 | No runtime dependencies beyond bash + curl | Must work on a fresh OS with nothing installed | All logic stays in shell; no Python/Node/Ruby helpers |
| CON-002 | No destructive operations without backup + warning | User trust and safety | `lib/backup.sh` must be called before any config overwrite |
| CON-003 | Lock file prevents concurrent runs | Avoid partial state from parallel execution | `lib/lock.sh` sets lock at start, clears on exit/crash |
| CON-004 | Scripts must be idempotent | Safe to re-run without side effects | Each install step checks if already done before acting |
| CON-005 | Scope limited to: packages + dotfiles + tweaks | No dev environment setup | Explicitly documented in SCOPE.md OOS-001 |

## Technology baseline

| Layer | Choice | Notes |
|---|---|---|
| Linux scripts | Bash | POSIX-compatible where possible |
| Windows scripts | CMD batch + PowerShell | CMD for entry; PS for config work |
| Package managers | apt / pacman / dnf / winget | One per distro, detected automatically |
| Dotfile delivery | curl from companion GitHub repo | No git clone needed on the target machine |
| Testing | Docker containers per distro | Clean-slate smoke tests |
| Distribution | GitHub Releases | Manual tagging, checksums in release notes |

## Stable decisions

- Entry point is `install.sh`, single file, fetched via curl and piped to bash.
- Distro scripts live under `scripts/linux/` and `scripts/windows/`.
- Shared helpers live under `lib/` and are sourced by distro scripts.
- Dotfiles come from a separate companion repo, not bundled in this repo.
- No package manager installation — assumes the package manager is already present on a supported distro.

## Rules for contributors and AI agents

1. Read `AGENTS.md` and this file before changing any script.
2. Do not contradict accepted specs; propose an ADR when a decision must change.
3. Do not invent missing requirements. Mark them `TBD` with owner and impact.
4. All scripts must remain idempotent — check before acting.
5. Prefer the smallest implementation satisfying accepted requirements.
6. Never add runtime dependencies (no Python, Node, Ruby helpers).
7. Test changes in a clean Docker container, not on a live machine.

## Frequently needed links

- Scope: [SCOPE.md](SCOPE.md)
- Roadmap: [ROADMAP.md](ROADMAP.md)
- Status: [PROJECT-STATUS.md](PROJECT-STATUS.md)
- Glossary: [GLOSSARY.md](GLOSSARY.md)
