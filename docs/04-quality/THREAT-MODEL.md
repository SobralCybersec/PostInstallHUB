---
title: "Threat Model"
status: "draft"
owner: "Matheus"
reviewers:
  - "Matheus"
version: "0.1.0"
last_reviewed: "2026-07-10"
review_cycle: "quarterly"
applies_to: "0.1.0"
source_of_truth: true
related: []
supersedes: null
---

# Threat model

This document enumerates threats using STRIDE per trust boundary and maps each
to a mitigating control. Controls themselves live in
[SECURITY.md](SECURITY.md) under `SEC-` IDs — this document is the source of
truth for the threats and their mapping, not for the controls.

## Scope

- System under analysis: PostInstallHUB — a set of bash/CMD shell scripts that a user downloads via `curl` and runs locally to set up a fresh OS install.
- In scope: the `curl` download step; script execution on the local machine; interaction with package managers (apt, pacman, dnf, winget); dotfile application; lock file handling.
- Out of scope: OS-level security hardening (PostInstallHUB does not configure firewalls, SELinux, or AppArmor — `N/A — not in project scope`). Runtime network services — PostInstallHUB is not a daemon (`N/A — local one-shot script`).
- Assumptions: The user's machine is trusted (the attacker is external). GitHub is semi-trusted (public, versioned, Matheus controls with 2FA). The user copies the install URL from the official README verbatim.

## Data-flow trust boundaries

```
TB-1: Public internet → user terminal (curl download)
TB-2: User terminal → local OS (script execution, sudo escalation)
TB-3: User terminal → package manager (apt/pacman/dnf outbound)
TB-4: User terminal → companion dotfile repo (curl download)
```

```mermaid
flowchart LR
    subgraph Untrusted
        Internet[Public Internet / GitHub Raw]
    end
    subgraph User_Machine
        Terminal[User Terminal: bash install.sh]
        PackageMgr[Package Manager: apt/pacman/dnf]
        Dotfiles[Companion Dotfile Repo: curl HTTPS]
        LockFile[/tmp/postinstallhub.lock]
    end
    Internet -->|TB-1: curl -fsSL HTTPS| Terminal
    Terminal -->|TB-2: sudo for specific cmds| PackageMgr
    Terminal -->|TB-3: curl -fsSL HTTPS| Dotfiles
    Terminal -->|TB-4: local write| LockFile
```

| Boundary ID | Crossing | From → To | Trust change |
|---|---|---|---|
| TB-1 | curl download of install.sh | Public internet → User terminal | Untrusted bytes enter the execution environment |
| TB-2 | sudo escalation for package installs and chsh | User session → root | Privilege elevated for specific, visible commands |
| TB-3 | curl download of companion dotfiles | Public internet (Matheus-controlled repo) → User home | Semi-trusted content written to user home directory |
| TB-4 | Lock file creation | User session → /tmp | Local only; no trust change |

## STRIDE per boundary

| Threat ID | Boundary | STRIDE | Threat | Affected asset | Mitigation | Status |
|---|---|---|---|---|---|---|
| THR-001 | TB-1 | Spoofing | Attacker hosts malicious `install.sh` at a look-alike URL; user is tricked into running it | User OS configuration | HTTPS enforced (`curl -fsSL`); README links verbatim GitHub raw URL; public repo is auditable before running | mitigated |
| THR-002 | TB-1 | Tampering | GitHub repo is compromised; script is modified between the user reading the README and running the curl command | GitHub repo / user OS | 2FA on GitHub account; release tags pinned in docs; users can verify the script before piping to bash (save to file first) | mitigated |
| THR-003 | TB-1 | Repudiation | Unclear what the script did to the system; no record of actions taken | User OS | Script prints every action with colored log lines (`[INFO]`, `[SUCCESS]`, `[WARNING]`, `[ERROR]`); user can capture with `2>&1 \| tee install.log` | mitigated |
| THR-004 | TB-1 | Information Disclosure | Script logs or transmits credentials, tokens, or sensitive env vars | User credentials | Script never asks for or handles credentials; sudo password is handled by the OS PAM layer, never seen by the script; no env var logging | mitigated |
| THR-005 | TB-1 | Denial of Service | Malformed or slow response from GitHub hangs the script indefinitely | Script execution | `curl -fsSL` fails fast on HTTP errors; consider adding `--max-time` to curl calls in future | accepted (low risk) |
| THR-006 | TB-2 | Elevation of Privilege | Script calls `sudo` on more commands than necessary, or wraps the entire execution in sudo | User OS | `sudo` used only for specific commands (package installs, `chsh`); script must not be run as root; each sudo call is printed before execution | mitigated |
| THR-007 | TB-2 | Denial of Service | Lock file left behind after a crash prevents re-running the script | Script usability | EXIT trap removes the lock file on clean exit; stale-lock recovery is documented; consider auto-expiry via PID check | accepted (see TMR-001) |
| THR-008 | TB-2 | Tampering | Script modifies existing config files without warning, overwriting user customizations | User dotfiles | Backup warning printed before any config modification; `set -e` stops execution on unexpected errors | mitigated |
| THR-009 | TB-3 | Tampering | Companion dotfile repo is compromised; malicious dotfiles applied | User home directory | Repo is Matheus-controlled; same 2FA protection; no `eval` of dotfile content by install.sh | mitigated |
| THR-010 | TB-3 | Information Disclosure | curl to dotfile repo leaks path or system info in User-Agent or headers | N/A | curl default User-Agent is generic; no custom headers added; not a meaningful risk for a local script | accepted (negligible) |

> `THR-` IDs are shared with the threat-model summary in SECURITY.md; keep the
> two tables consistent — this document owns the full enumeration.

## Attack trees

Goal-oriented decomposition. Root is the attacker objective; leaves are
concrete steps. Notation: `AND` = all children required, `OR` = any child.

```
AT-1: Attacker executes arbitrary code on user's machine via PostInstallHUB  (OR)
├── AT-1.1: Compromise the install.sh served from GitHub  (OR)
│   ├── AT-1.1.1: Compromise Matheus's GitHub account          → mitigated by 2FA (SECURITY.md)
│   └── AT-1.1.2: GitHub infrastructure breach                 → accepted (out of Matheus's control)
├── AT-1.2: Trick user into running a different URL  (OR)
│   ├── AT-1.2.1: Phishing / social engineering                → mitigated by README verbatim URL + HTTPS
│   └── AT-1.2.2: Typosquat GitHub username                    → mitigated by HTTPS (cert must match)
└── AT-1.3: Inject malicious content at runtime  (AND)
    ├── AT-1.3.1: Exploit unquoted variable in script          → mitigated by shellcheck + quoting policy
    └── AT-1.3.2: Inject via package manager output            → accepted (package manager is trusted)

AT-2: Attacker causes user data loss via PostInstallHUB  (OR)
├── AT-2.1: Script overwrites existing config without warning  → mitigated by backup_warning() + set -e
└── AT-2.2: Script removes files unnecessarily                 → mitigated by no-destructive-ops rule (never rm -rf user dirs)
```

| Attack tree ID | Objective | Highest-risk path | Residual risk |
|---|---|---|---|
| AT-1 | Arbitrary code execution on user's machine | AT-1.1.1 — GitHub account compromise | Low (2FA in place; solo project with small attack surface) |
| AT-2 | User data loss | AT-2.1 — silent config overwrite | Low (backup warning + set -e implemented) |

## Residual risks and follow-ups

| ID | Threat | Decision | Owner | Due |
|---|---|---|---|---|
| TMR-001 | THR-007: Stale lock file after crash | Accept for v0.1.0; mitigate in v0.2.0 by checking if the PID in the lock file is still alive before refusing to run | Matheus | v0.2.0 |
| TMR-002 | THR-005: No `--max-time` on curl | Accept for v0.1.0; add `--max-time 30` to all curl calls in v0.2.0 | Matheus | v0.2.0 |

## Review

- Re-run this model when: a new distro is added, a new `curl` download target is introduced, sudo scope changes, or the companion dotfile repo changes ownership.
- Cadence: per-release.
- Unresolved: `[ ]` TMR-001 (stale lock auto-expiry), `[ ]` TMR-002 (curl max-time).
