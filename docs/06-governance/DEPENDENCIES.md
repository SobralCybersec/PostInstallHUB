---
title: "Dependency Policy"
status: "active"
owner: "Matheus"
reviewers:
  - "Matheus"
version: "0.1.0"
last_reviewed: "2026-07-13"
review_cycle: "quarterly"
applies_to: "0.1.0"
source_of_truth: true
related: ["SUPPLY-CHAIN.md", "CODING-STANDARDS.md"]
supersedes: null
---

# Dependency policy

PostInstallHUB has **no external software dependencies** to install before running the scripts themselves. There is no `package.json`, no `Pipfile`, no `Gemfile`, no `go.mod`, no `pom.xml`. The scripts are plain bash and CMD.

---

## Runtime dependencies

These must already exist on the target machine (or be bootstrapped separately) when running the install script:

### Linux

| Dependency | Version | Purpose | How to get it |
|---|---|---|---|
| `bash` | 5+ | Script interpreter — required | System-provided on all supported distros |
| `curl` | any recent | Initial `curl \| bash` install invocation | Pre-installed on most distros; if not, `apt install curl` / `pacman -S curl` / `dnf install curl` |

Everything else (`git`, `neovim`, `zsh`) is installed **by** the scripts, not required before them.

### Windows

| Dependency | Version | Purpose | How to get it |
|---|---|---|---|
| PowerShell | 5+ | Script interpreter for `setup.ps1` | System-provided (Windows 10+) |
| `winget` | any | Package installation | System-provided (Windows 10 1709+); update via Microsoft Store if absent |
| CMD | any | `setup.cmd` interpreter | System-provided on all Windows versions |

---

## Dev dependencies

Used during development only — not needed to run the scripts on a target machine.

| Tool | Purpose | Install |
|---|---|---|
| `shellcheck` | Static analysis / linting for bash scripts | `apt install shellcheck` / `pacman -S shellcheck` / `brew install shellcheck` |
| `bats` (planned) | Bash unit test framework — see TECH-DEBT.md | `apt install bats` / `npm install -g bats` |
| Docker | Integration testing in clean containers | [docs.docker.com](https://docs.docker.com) |

---

## Packages installed by the scripts (not dependencies of the scripts)

These are what PostInstallHUB *installs on the user's machine* — they are targets, not dependencies:

- `git`
- `curl`
- `neovim`
- `zsh`
- Dotfiles from Matheus's companion dotfile repo (Matheus-controlled)

All packages come from **official distro repositories** — no third-party PPAs, no AUR helpers, no unofficial taps.

---

## Package manager lockfiles

**N/A.** No lockfiles exist or are needed. There is no npm, pip, bundler, cargo, or maven dependency tree in this project.

---

## npm dependencies

**N/A.** This is not a Node.js project.

---

## Python dependencies

**N/A.** This is not a Python project.

---

## Update policy

Runtime dependencies (`bash`, `curl`, `winget`, PowerShell) are system-provided and updated through normal OS maintenance, not by this project.

Dev tools (`shellcheck`, `bats`, Docker) are updated manually by Matheus as needed. No automated dependency update bot is configured.

---

## Prohibited

- Adding any npm, pip, gem, or other language ecosystem dependency to the main scripts.
- Sourcing scripts from third-party URLs without an explicit comment acknowledging the trust decision.
- Requiring a package manager (Homebrew, nix, etc.) to be pre-installed before running PostInstallHUB.
