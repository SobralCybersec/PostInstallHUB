---
title: "Product Specification"
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

# Product specification

## Vision

PostInstallHUB turns a bare OS install into a fully configured, personal environment with one command and no manual steps.

## Problem statement

- User: Developers and power users who reinstall Linux (or Windows) regularly — primarily Matheus
- Situation: Immediately after a fresh OS install, the machine has no personal tooling, no preferred shell, and none of the configuration that makes it usable
- Problem: Setting up the same packages, dotfiles, and tweaks after every reinstall is tedious, error-prone, and inconsistent — steps get forgotten, order matters, and the process can take 30–60 minutes of tab-switching
- Current alternative: Manual setup from memory or a personal notes file; ad-hoc shell commands run in whatever order they're remembered
- Cost of the problem: Time lost on mechanical bookkeeping instead of actual work; machines with subtly different configurations; frustration when a step is missed and surfaces later as a broken tool

## Value proposition

One curl command replaces 30–60 minutes of manual setup. The script auto-detects the OS, installs the right packages via the native package manager, pulls down dotfiles from the companion repo, applies system tweaks, and sets zsh as the default shell — all idempotently, so re-running it after a partial failure is safe. No tutorial tabs, no forgotten steps, no inconsistency between machines.

## Target users

| Segment | Primary need | Frequency | Priority |
|---|---|---:|---:|
| Matheus (owner) | Repeatable, opinionated setup for his own machines | Per OS reinstall (a few times per year) | P0 |
| Linux power users (similar profile) | Quick post-install setup matching their own preferences, or a fork base | Per OS reinstall | P1 |

## Product principles

1. One command is enough — the entry point is a single curl-pipe-bash; no prerequisites beyond what a fresh OS provides.
2. Idempotent by default — every operation checks before applying; re-running the script never breaks a working setup.
3. Fail loudly, not silently — package install failures abort with a clear message; the script never exits 0 when something critical went wrong.

## Core capabilities

| ID | Capability | User value | Priority |
|---|---|---|---|
| CAP-001 | OS auto-detection (Ubuntu/Debian, Arch, Fedora, Omarchy, Windows) | No manual configuration needed; correct script runs automatically | MUST |
| CAP-002 | Core package installation (git, curl, neovim, zsh) via native package manager | Essential tools present immediately after run | MUST |
| CAP-003 | Dotfile configuration via companion repo curl | Personal shell config applied automatically | MUST |
| CAP-004 | Set zsh as default shell (`chsh`) | Preferred shell active after next login without manual steps | MUST |
| CAP-005 | System tweaks (aliases, performance/privacy settings) | Machine behaves as expected from first use | SHOULD |
| CAP-006 | Lock file preventing concurrent runs | Safe to invoke without worrying about race conditions | MUST |
| CAP-007 | Backup warning before config-modifying operations | User is never surprised by overwritten config files | MUST |
| CAP-008 | Idempotent re-runs | Script can be re-run after partial failure without damage | MUST |

## Success metrics

| Metric | Baseline | Target | Window | Source |
|---|---:|---:|---|---|
| Script exit code on supported OS | N/A | 0 (all packages present, zsh default) | Per run | Script exit code |
| Time from curl invocation to completion | ~45 min manual | < 5 min | Per run | Elapsed time printed in summary |
| Packages verified present post-run | 0 | 4/4 (git, curl, neovim, zsh) | Per run | `which` / package manager query |
| Default shell after run | bash (distro default) | zsh | Per run | `echo $SHELL` or `getent passwd $USER` |

## Guardrail metrics

| Metric | Maximum/minimum | Why |
|---|---:|---|
| Script exit 0 with missing packages | 0 occurrences | Silent partial success is worse than an explicit failure |
| Config files overwritten without backup warning | 0 occurrences | Users must never lose config silently |
| Concurrent runs modifying the same machine | 0 occurrences | Lock file is the guarantee; violation means the lock logic is broken |

## Product risks

- Companion dotfile repo URL becomes unavailable or changes — dotfile step fails silently (already non-fatal, but leaves machine partially configured without notice).
- Package names diverge across distro versions (e.g., `neovim` not in default repos on older Ubuntu) — install step fails; user must resolve manually. Mitigation: document minimum supported distro versions.
- `chsh` requires a re-login to take effect — user may not realize zsh isn't active yet until they open a new terminal session. Mitigation: print a clear note in the success summary.
- Omarchy-specific scripts may drift from upstream DHH repo changes — OS detection routes to Omarchy path but packages or tweaks may no longer apply correctly.

## Open questions

| Question | Owner | Due | Blocking |
|---|---|---|---|
| What is the minimum supported version for each distro (Ubuntu 22.04? 24.04?)? | Matheus | 2026-08-01 | YES — affects package name assumptions |
| Should Windows support use winget, scoop, or choco for package installation? | Matheus | 2026-08-01 | YES — no Windows install logic exists yet |
| Should the `--yes` flag suppress all prompts including the backup warning, or only the Enter-to-continue gate? | Matheus | 2026-08-01 | NO |
