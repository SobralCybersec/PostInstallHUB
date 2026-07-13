---
title: "Requirements"
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

# Requirements

## Requirement format

Each requirement must be atomic, testable, unambiguous, and assigned a stable ID.

## Functional requirements

| ID | Requirement | Priority | Acceptance reference | Owner |
|---|---|---:|---|---|
| FR-001 | `install.sh` shall detect the running OS/distro by reading `/etc/os-release` (Linux) or equivalent and route execution to the correct platform script. | MUST | AC-001 | Matheus |
| FR-002 | The script shall install `git`, `curl`, `neovim`, and `zsh` using the distro's native package manager (`apt`, `pacman`, or `dnf`). | MUST | AC-002 | Matheus |
| FR-003 | The script shall invoke the dotfile preset install script via `curl` from the companion GitHub repository. | SHOULD | AC-003 | Matheus |
| FR-004 | The script shall set `zsh` as the default shell for the current user via `chsh`. | SHOULD | AC-004 | Matheus |
| FR-005 | The script shall apply system tweaks: aliases, shell config defaults, and convenience settings appended to `~/.zshrc` or equivalent. | SHOULD | AC-005 | Matheus |
| FR-006 | The script shall display a backup warning before modifying any existing configuration file and require explicit user acknowledgment (Enter to continue, Ctrl+C to abort). | MUST | AC-006 | Matheus |
| FR-007 | The script shall create a lock file at `/tmp/postinstallhub.lock` on startup and exit with a descriptive error if a lock already exists, preventing concurrent runs. | MUST | AC-007 | Matheus |
| FR-008 | All operations shall be idempotent: re-running the script on an already-configured system shall produce no destructive changes and shall exit 0. | MUST | AC-008 | Matheus |
| FR-009 | The script shall exit `0` on success and a non-zero code with a descriptive error message on any failure. | MUST | AC-009 | Matheus |
| FR-010 | `install.sh` shall be bootstrappable via a single `curl` one-liner on a fresh OS that has only `curl` or `wget` available. | MUST | AC-010 | Matheus |
| FR-011 | A Windows equivalent (`setup.cmd` or `setup.ps1`) shall install `git`, `curl`, `neovim`, and apply Windows-specific tweaks using `winget`. | SHOULD | AC-011 | Matheus |

## Quality requirements

Use measurable scenarios rather than adjectives such as "fast" or "secure."

| ID | Context and trigger | Expected response | Measure |
|---|---|---|---|
| QR-001 | When running on a fresh Ubuntu 22.04+ system with internet access | The complete install script shall finish successfully | Elapsed time ≤ 10 minutes |
| QR-002 | When the detected OS is not in the supported list | The script shall exit with a clear "Unsupported OS" error message | Exit within 2 seconds; message names the detected OS and lists supported distros |
| QR-003 | When re-run on an already-configured system | No package shall be reinstalled unnecessarily | `apt`/`pacman` output shows "already installed" / "nothing to do" for every package |

## Security requirements

| ID | Requirement | Threat/control source | Verification |
|---|---|---|---|
| SEC-001 | The install script shall not store, log, or transmit any user credentials or personal data. | THREAT_MODEL | Code review |
| SEC-002 | The `curl`-based install entry point shall use HTTPS only; no HTTP fallback is permitted. | POLICY | Code review |
| SEC-003 | The script shall not execute any downloaded content other than the companion dotfile preset and its own declared sub-scripts. | THREAT_MODEL | Code review + manual test |

## Data requirements

| ID | Requirement | Classification | Retention |
|---|---|---|---|
| DATA-001 | No user data is collected or persisted beyond the lock file (`/tmp/postinstallhub.lock`), which is deleted on clean exit. | N/A | Session only (deleted on exit) |

## Compliance requirements

| ID | Obligation | Applicability | Evidence |
|---|---|---|---|
| CMP-001 | The scripts shall be compatible with the open source licenses of all installed packages (`git`, `curl`, `neovim`, `zsh`, `winget`-sourced packages). | All supported distros and Windows | Package list review against SPDX license identifiers |

## Traceability

| Requirement | Design | Implementation | Verification | Release |
|---|---|---|---|---|
| FR-001 | [SCOPE.md](../SCOPE.md) | `scripts/linux/install.sh` | `tests/test_os_detection.sh` | v0.1.0 |
| FR-002 | [SCOPE.md](../SCOPE.md) | `scripts/linux/install.sh` | `tests/test_packages.sh` | v0.1.0 |
| FR-003 | [SCOPE.md](../SCOPE.md) | `scripts/linux/install.sh` | `tests/test_dotfiles.sh` | v0.1.0 |
| FR-004 | [SCOPE.md](../SCOPE.md) | `scripts/linux/install.sh` | `tests/test_shell_default.sh` | v0.1.0 |
| FR-005 | [SCOPE.md](../SCOPE.md) | `scripts/linux/install.sh` | `tests/test_tweaks.sh` | v0.1.0 |
| FR-006 | [SCOPE.md](../SCOPE.md) | `scripts/linux/install.sh` | `tests/test_backup_warning.sh` | v0.1.0 |
| FR-007 | [SCOPE.md](../SCOPE.md) | `scripts/linux/install.sh` | `tests/test_lock.sh` | v0.1.0 |
| FR-008 | [SCOPE.md](../SCOPE.md) | `scripts/linux/install.sh` | `tests/test_idempotency.sh` | v0.1.0 |
| FR-009 | [SCOPE.md](../SCOPE.md) | `scripts/linux/install.sh` | `tests/test_exit_codes.sh` | v0.1.0 |
| FR-010 | [SCOPE.md](../SCOPE.md) | `install.sh` | `tests/test_curl_bootstrap.sh` | v0.1.0 |
| FR-011 | [SCOPE.md](../SCOPE.md) | `scripts/windows/setup.cmd` | `tests/test_windows_setup.ps1` | v0.1.0 |
