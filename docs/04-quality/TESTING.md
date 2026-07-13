---
title: "Testing Strategy"
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

# Testing strategy

## Goals

- Detect defects at the cheapest reliable layer.
- Verify requirements and contracts.
- Keep critical workflows deterministic and repeatable.
- Test failures, migrations, and recovery—not only happy paths.

## Test layers

| Layer | Scope | Uses real dependencies | Target | CI stage |
|---|---|---:|---|---|
| Unit | Individual bash functions (`detect_os`, `backup_warning`, `acquire_lock`, lib/ helpers) | No (pure bash, no network, no sudo) | All `lib/` functions + `detect_os` | PR (shellcheck + bash -n + bats) |
| Integration | Full script run inside Docker container per distro; verifies packages installed, dotfiles configured, tweaks applied | Yes (real apt/pacman/dnf in container) | ubuntu:22.04, archlinux:latest, fedora:latest, omarchy | Manual per release |
| E2E | `install.sh` on a fresh VM/container per supported distro; all acceptance criteria verified | Yes | All supported distros (Ubuntu, Arch, Fedora, Omarchy, Windows) | Manual before each release |
| Performance | Total script execution time per distro | Production-like (Docker with internet) | < 10 min fresh install; < 30 s dry run; < 2 min idempotent re-run | Manual |
| Security | Code review for curl\|bash safety, variable quoting, no credential logging | Mixed (static analysis) | 100% of scripts pass shellcheck; no eval of user input; no hardcoded secrets | Manual/release |

## Requirement traceability

| Requirement | Test type | Test ID/path | Environment |
|---|---|---|---|
| FR-001: OS detection | Unit | `tests/test_detect_os.sh` | Local bash / Docker |
| FR-002: Package install (apt) | Integration | `tests/test_ubuntu.sh` | `ubuntu:22.04` Docker |
| FR-003: Package install (pacman) | Integration | `tests/test_arch.sh` | `archlinux:latest` Docker |
| FR-004: Package install (dnf) | Integration | `tests/test_fedora.sh` | `fedora:latest` Docker |
| FR-005: Package install (Omarchy/pacman) | Integration | `tests/test_omarchy.sh` | `archlinux:latest` Docker |
| FR-006: Dotfiles configured | Integration | `tests/test_ubuntu.sh`, `tests/test_arch.sh` | Docker |
| FR-007: Lock file prevents concurrent runs | Unit | `tests/test_lock.sh` | Local bash |
| FR-008: Idempotent re-run exits 0 | E2E | Manual re-run in Docker | Docker |
| FR-009: Backup warning before config modification | Unit | `tests/test_backup_warning.sh` | Local bash |

## Test data

- Factories/fixtures: No fixtures needed. Docker images per distro serve as self-contained test environments (`ubuntu:22.04`, `archlinux:latest`, `fedora:latest`).
- PII policy: N/A — scripts handle no personal data. No synthetic data required.
- Deterministic clock/randomness: N/A — scripts do not use randomness or time-sensitive logic.
- Cleanup/isolation: Each Docker container is ephemeral and discarded after the test run. Lock file (`/tmp/postinstallhub.lock`) is cleaned up by the script's EXIT trap; manual removal documented for stale-lock recovery.

## Mocking policy

- Mock the OS package manager only for unit tests of non-install functions (e.g., stub `apt-get` to verify the script would call it with the right arguments, without actually installing).
- Integration tests use real package managers inside Docker — no mocking.
- Do not assert implementation details without a documented reason.
- Do not mock `detect_os` in integration tests; it must run against the real container OS.

## Quality gates

### Pull request

- [x] `shellcheck` passes on all `.sh` files (no errors, warnings treated as errors).
- [x] `bash -n` syntax check passes on all scripts.
- [x] Unit tests in `tests/` pass (`bats tests/` or equivalent bash runner).
- [x] No new hardcoded credentials, no `eval` of user-controlled input introduced.

### Release

- [x] All integration tests pass in Docker (`test_ubuntu.sh`, `test_arch.sh`, `test_fedora.sh`, `test_omarchy.sh`).
- [x] E2E test: `install.sh` runs to completion on a fresh container of each supported distro.
- [x] Idempotency verified: script run twice in the same container exits 0 both times with no harmful side effects.
- [x] README and docs verified against actual script behavior.

## Flaky tests

- Quarantine owner: Matheus
- Maximum quarantine: 1 week — a quarantined test must be fixed or deleted within 7 days.
- Flake rate threshold: 0% — shell scripts against fixed Docker images should be fully deterministic. Any flake is a real bug.
- Exception: tests that make outbound network calls (package downloads) must be tagged `# network-dependent` and are excluded from the determinism expectation. Run them separately and treat flakes as network issues, not test bugs.
- Quarantined tests do not count as passing coverage.
