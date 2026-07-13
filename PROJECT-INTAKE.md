---
title: "Project Intake Questionnaire"
status: "complete"
owner: "Matheus"
version: "0.1.0"
last_reviewed: "2026-07-13"
---

# Project intake questionnaire

Completed answers for PostInstallHUB.

## Identity

- **Project name:** PostInstallHUB
- **Repository:** github.com/matheusgomescosta/PostInstallHUB
- **Product owner:** Matheus
- **Technical owner:** Matheus
- **Target release:** ASAP (MVP)
- **Team size and roles:** 1 — Matheus (owner, developer, tester)

## Product

- **Who is the primary user?**
  Matheus (and others who reinstall Linux or Windows frequently).

- **What problem are they trying to solve?**
  After a fresh OS install, setting up the same tools and preferences is tedious,
  error-prone, and inconsistent across machines. Users spend 20–60 minutes doing
  it manually and still forget steps.

- **What outcome proves the product is useful?**
  One `curl | bash` command results in git, curl, neovim, and zsh installed;
  dotfiles configured; zsh set as default shell; system tweaks applied — in under
  10 minutes, with no manual steps.

- **What are the three must-have capabilities?**
  1. OS auto-detection routing to the correct distro script
  2. Package installation (git, curl, neovim, zsh) via native package manager
  3. Dotfile configuration via companion repo curl

- **What is explicitly out of scope?**
  Dev environment setup (Node, Docker, Python); GUI installer; mobile OS;
  cloud sync; team/multi-user features; automatic updates.

- **What are the measurable success and guardrail metrics?**
  - Success: script exits 0; all packages present; zsh is default shell
  - Guardrail: no existing config file overwritten without backup warning
  - Guardrail: re-running never breaks anything (idempotency)

## Behavior

- **What are the critical workflows?**
  Fresh install run; idempotent re-run; blocked concurrent run; unsupported OS detection.

- **Which actions are destructive or irreversible?**
  None (by design). Modifying existing config files triggers a backup warning
  and requires user acknowledgment.

- **What happens offline or when a dependency fails?**
  Package install: fails with non-zero exit and informative message.
  Dotfile curl: warns and continues (non-fatal).
  Unsupported OS: exits 2 immediately with clear message.

- **Which operations retry automatically?**
  None. User re-runs manually after resolving the issue.

- **Which actions require human approval?**
  Any modification of existing config files (backup warning + Enter to continue).

- **What are the main state machines?**
  InstallSession: Blocked (lock exists) → Running → Success | Failed | Aborted

## Technology

- **Target platforms:** Ubuntu/Debian, Arch, Fedora, Omarchy (Linux); Windows 10/11
- **Frontend/runtime:** Terminal output (no UI)
- **Backend/runtime:** Bash 5+ (Linux); CMD/PowerShell 5+ (Windows)
- **Database:** None
- **API/event protocols:** None — CLI only
- **External integrations:** OS package manager; companion dotfile repo (GitHub)
- **Deployment target:** User's local machine (distributed via GitHub raw URL)
- **Hard technical constraints:** Must work on a fresh OS with only bash+curl available

## Quality

- **Performance targets:** OS detection < 1s; full fresh install < 10 min; re-run < 2 min
- **Availability/SLO target:** N/A (not a service)
- **RTO and RPO:** N/A (not a service)
- **Accessibility target:** Color + symbol pairing; no color-only indicators
- **Security baseline:** HTTPS-only curl; shellcheck clean; no credential handling
- **Privacy/regulatory obligations:** None — no data collected
- **Expected scale:** Single user per machine; runs once (or rarely)

## Delivery

- **Environments:** Docker containers per distro (ubuntu:22.04, archlinux:latest, fedora:latest); Windows VM
- **CI/CD platform:** None (manual testing)
- **Release cadence:** When ready; semver tagging
- **Deployment strategy:** GitHub Release + raw URL curl
- **Rollback constraints:** Pin to previous version tag
- **Observability stack:** Colored terminal output + exit codes

## AI, if applicable

- **AI capabilities:** N/A — PostInstallHUB has no AI features
- **Providers/models:** N/A
- **Data allowed to leave the system:** N/A
- **Tool permissions:** N/A
- **Human approval boundaries:** N/A
- **Evaluation targets:** N/A
- **Cost limits:** N/A
