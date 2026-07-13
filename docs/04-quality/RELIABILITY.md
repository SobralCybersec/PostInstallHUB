---
title: "Reliability Specification"
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

# Reliability specification

PostInstallHUB is a local one-shot script, not a running service. Web-service reliability concepts (availability percentage, error budgets, uptime SLAs, circuit breakers, distributed retries) are N/A here. Reliability means: the script does what it says, exits correctly, is safe to re-run, and fails loudly with a useful message when something goes wrong.

## Reliability goals

| Goal | Definition | Target |
|---|---|---|
| Correct exit on success | `install.sh` exits 0 on a fresh supported OS with internet + sudo | 100% of runs in Docker integration tests |
| Correct exit on failure | `install.sh` exits non-zero with an `[ERROR]` message on every detectable failure | 100% of failure cases |
| Idempotency | Re-running `install.sh` on an already-configured system exits 0 with no harmful side effects | 100% of re-run tests |
| OS detection accuracy | `detect_os` returns the correct distro string on every supported OS | 100% (unit tested) |

## Service level indicators and objectives

N/A in the web-service sense. See [SLO.md](SLO.md) for the script-specific SLOs (SLO-001 through SLO-003).

## Error budget

N/A — PostInstallHUB is not a continuously running service with a rolling error budget. Failures are discrete events fixed by patching the script and cutting a new release.

## Recovery objectives

| Scenario | Recovery method | User action |
|---|---|---|
| Script exits non-zero mid-run | Fix the reported error (missing dependency, no internet, wrong distro), remove stale lock if present, re-run | Manual; re-run is safe due to idempotency |
| Stale lock file after crash | Remove `/tmp/postinstallhub.lock` manually | `rm /tmp/postinstallhub.lock` |
| Dotfile conflict | Script prints `[WARNING]` and skips; user resolves conflict manually | Manual diff and merge |
| Package manager failure | Script exits non-zero; user fixes package manager (e.g., `apt --fix-broken install`) and re-runs | Manual |

RTO: time for user to re-run after fixing the issue — typically < 5 minutes.
RPO: N/A — the script applies configuration, it does not store data. Pre-existing files are warned about before modification.

## Failure-mode inventory

| Failure | Detection | Automatic response | Manual response |
|---|---|---|---|
| Unsupported OS detected | `detect_os` returns unknown | `[ERROR]` message + exit 1 | User runs on a supported distro |
| No internet access | Package manager fails | `[ERROR]` + exit 1 (via `set -e`) | User fixes network, re-runs |
| No sudo / insufficient permissions | `sudo` call fails | `[ERROR]` + exit 1 | User ensures sudo access, re-runs |
| Lock file already exists | `acquire_lock` finds existing lock | `[ERROR]` message explaining stale lock, exit 1 | `rm /tmp/postinstallhub.lock`, re-run |
| Individual package install fails | Package manager exits non-zero | `set -e` aborts script; `[ERROR]` logged | User investigates package manager, re-runs |
| Dotfile target already exists | Config modification blocked | `[WARNING]` printed; step skipped | User resolves conflict manually |
| Companion dotfile repo unreachable | `curl` fails | `[ERROR]` + exit 1 | User checks network / repo URL, re-runs |

## Resilience patterns

- Timeouts: N/A for a local script. Package manager has its own timeout logic. curl `--max-time` planned for v0.2.0.
- Retries: N/A — one-shot script. User re-runs manually after fixing the issue.
- Circuit breakers: N/A.
- Bulkheads: N/A.
- Backpressure: N/A.
- Graceful degradation: optional steps (tweaks, non-critical dotfiles) log `[WARNING]` and continue; required steps (OS detection, lock acquisition, core package installs) abort with exit 1.
- Data reconciliation: N/A — no database or distributed state.

## Idempotency (primary reliability feature)

Re-running `install.sh` on an already-configured system must be safe and must exit 0. Implementation:

- Check `command -v <pkg>` before installing; skip if already present.
- Use package manager flags that skip reinstalls (`pacman --needed`, `apt-get install` is idempotent by default).
- Check if dotfile symlink/config already exists before writing; skip with `[INFO]` if already correct.
- Lock file is removed by EXIT trap on both success and failure paths.

## Reliability tests

- [x] Fresh install exits 0 on all supported distros (Docker integration test per release)
- [x] Idempotent re-run exits 0 with no side effects (run twice in same Docker container)
- [x] `detect_os` returns correct value on all supported distros (unit test)
- [x] Script exits non-zero and prints `[ERROR]` when OS is unsupported (unit test)
- [x] Stale lock file causes immediate exit with informative message (unit test)
- [ ] No internet — package manager fails → script exits non-zero (integration test with network disabled)
- [ ] No sudo — apt/pacman call fails → script exits non-zero (integration test as non-sudo user)
