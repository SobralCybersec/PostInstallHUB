---
title: "Performance Specification"
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

# Performance specification

PostInstallHUB is a local shell script, not a web service. "Performance" here means wall-clock execution time on the user's machine and container. There are no latency percentiles, no concurrent users, no APM dashboards — those sections are marked N/A.

## Execution time targets

| Operation | Target | Maximum | Notes |
|---|---|---|---|
| OS detection (`detect_os`) | < 1 second | 2 seconds | Pure bash + `/etc/os-release` read; no network |
| Lock acquisition (`acquire_lock`) | < 0.1 second | 0.5 second | Single file write to `/tmp` |
| Total script (no network — packages already installed, idempotent re-run) | < 2 minutes | 5 minutes | `command -v` checks only; no downloads |
| Total script (fresh install, good internet) | < 10 minutes | 20 minutes | Dominated by package download + install time |
| Total script (non-package steps only: dotfiles, tweaks, config) | < 30 seconds | 60 seconds | Excludes package manager I/O entirely |

## Capacity assumptions

- Concurrent users: 1 (local script; runs once at a time per machine; lock file enforces this).
- Requests/events per second: N/A.
- Dataset size: N/A — no database.
- Daily growth: N/A.
- Payload distribution: N/A.
- Bottleneck: outbound package downloads. The script itself is negligible; the package manager is the wall clock.

## Test scenarios

| Scenario | Environment | Pass condition |
|---|---|---|
| Fresh install — Ubuntu | `ubuntu:22.04` Docker, internet access | Completes in < 10 min; exit 0 |
| Fresh install — Arch | `archlinux:latest` Docker, internet access | Completes in < 10 min; exit 0 |
| Fresh install — Fedora | `fedora:latest` Docker, internet access | Completes in < 10 min; exit 0 |
| Idempotent re-run | Same Docker container, packages already installed | Completes in < 2 min; exit 0; no reinstalls |
| Non-network steps only | Any container, `--dry-run` or network disabled | Completes in < 30 s; exit 0 |

Measurement method: `time bash install.sh` inside the Docker container. Record real time. Log to `tests/perf-DISTRO-DATE.txt` for comparison across releases.

## Profiling

- CPU: N/A — CPU is never the bottleneck for a shell script calling package managers.
- Memory: N/A — bash process memory is negligible (< 10 MB).
- Database: N/A.
- Client bundle/runtime: N/A — not a web application.
- Regression threshold: if a new version takes > 2× longer than the previous version on the same Docker image with the same package list, investigate before releasing.

## Performance best practices (coding guidelines)

- Use `command -v <pkg>` to skip already-installed packages rather than calling the package manager unconditionally.
- Use `pacman --needed` (Arch) and equivalent flags on other package managers to skip reinstalls natively.
- Don't spawn unnecessary subshells inside `lib/` functions — prefer `var=$(...)` over piping where a single command suffices.
- Don't `cat` files into variables when `read` or direct parameter expansion works.
- Batch package installs into a single `apt-get install -y pkg1 pkg2 pkg3` call rather than one call per package.

## Failure behavior under load

- Load shedding: N/A — not a server.
- Queue limits: N/A.
- Backpressure: N/A.
- Timeouts: `curl` calls should use `--max-time 30` (planned for v0.2.0; see THREAT-MODEL.md TMR-002). Package manager timeouts are controlled by the package manager itself.
- Degraded features: if a non-critical step fails (e.g., a dotfile symlink), the script logs `[WARNING]` and continues; it does not abort the entire run for optional tweaks.
