---
title: "Service Level Objectives"
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

# Service level objectives

PostInstallHUB is not a running service — there is no uptime, no rolling error budget, no burn-rate alerting. The SLO concept is adapted here to describe pass/fail acceptance criteria for the script, measured during manual integration tests before each release.

This document is the single authoritative home for SLO targets. [RELIABILITY.md](RELIABILITY.md) consumes them for failure-mode policy. [OBSERVABILITY.md](OBSERVABILITY.md) describes how to observe each SLI during a test run.

---

## Definitions (adapted for a local script)

- **SLI** — a measurable property of the script's behavior on a test run.
- **SLO** — the required value of that SLI; a release is blocked if any SLO is not met.
- **Error budget** — N/A in the web-service sense. For PostInstallHUB: zero tolerance. Failures mean the script is broken and must be fixed before release.
- **Burn rate** — N/A.

---

## Service level indicators

| SLI ID | Indicator | Good event | Valid event | Measured by |
|---|---|---|---|---|
| SLI-001 | Script completion on fresh OS | `install.sh` exits 0 | Any run on a fresh, supported OS with internet + sudo | Manual Docker integration test per distro per release |
| SLI-002 | OS detection accuracy | `detect_os` returns the correct distro string | Any run on a supported distro | Automated unit test (`tests/test_detect_os.sh`) |
| SLI-003 | Idempotency | Second run of `install.sh` exits 0 with no harmful side effects | Any run on an already-configured system | Manual Docker test: run twice, verify state unchanged |

---

## Service level objectives

| SLO ID | SLI | Target | Window | Blocking? | Owner |
|---|---|---|---|---|---|
| SLO-001 | SLI-001 | 100% of integration test runs exit 0 | Per release (all supported distros) | Yes — release blocked if any distro fails | Matheus |
| SLO-002 | SLI-002 | 100% of unit test runs return correct OS string | Per PR and per release | Yes — PR blocked if unit test fails | Matheus |
| SLO-003 | SLI-003 | 100% of idempotency test runs exit 0 with no side effects | Per release | Yes — release blocked if idempotency broken | Matheus |

---

## Burn-rate alerting

N/A — PostInstallHUB has no continuous traffic to produce a burn rate. Failures are discrete events discovered during test runs. A failed test is equivalent to an exhausted budget: the release is held until the script is fixed.

---

## Error-budget policy

| SLO status | Policy |
|---|---|
| All SLOs passing | Ship the release. |
| Any SLO failing | Hold the release. Fix the script. Re-run the failing test. |

- Freeze authority: Matheus (sole maintainer).
- Exception approval: none — there are no users or deadlines that justify shipping a broken install script.
- Budget resets: per release. Each release starts with a clean slate.

---

## GitHub repo availability

The GitHub repository (where `install.sh` is hosted) depends on GitHub's uptime — outside Matheus's control. No SLO is set for it. If GitHub is down, users cannot curl the script; this is documented as a known external dependency, not a PostInstallHUB defect.

---

## Review

- SLO targets are revisited: per release, when a new distro is added, or when a distro's package manager behavior changes.
- A failed SLO triggers: fix the script before next release. No formal retrospective required for a solo personal project, but the cause should be noted in the commit message.
- Not covered here: uptime, latency percentiles, concurrent user capacity — all N/A for a local one-shot script.
