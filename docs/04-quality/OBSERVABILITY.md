---
title: "Observability Specification"
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

# Observability specification

PostInstallHUB is a local one-shot shell script. Distributed-system observability concepts (APM, distributed tracing, metrics pipelines, dashboards, alert routing) are **N/A**. Observability here means: the script tells the user exactly what it is doing as it runs, and the exit code tells them whether it succeeded.

## Signals

| Signal | Purpose | Source | Retention | Notes |
|---|---|---|---|---|
| Stdout/stderr log lines | Events and diagnostics; user sees what the script is doing | `echo` calls in `install.sh` and `lib/` functions | Session only (terminal buffer) | Redirect with `2>&1 \| tee install.log` to persist |
| Exit code | Primary success/failure signal | `exit 0` / `exit 1` in script | N/A (process return value) | 0 = success; non-zero = failure with [ERROR] already printed |
| Metrics | N/A — not a running service | — | — | — |
| Traces | N/A — single-process local script | — | — | — |
| Audit events | N/A — no multi-user accountability requirement | — | — | — |

## Log format

All log output follows a consistent prefix so lines are greppable and visually distinct in the terminal:

```
[INFO]    message     (blue)
[SUCCESS] message     (green)
[WARNING] message     (yellow)
[ERROR]   message     (red, to stderr)
```

Implementation in `lib/log.sh` (or equivalent):

```bash
info()    { printf '\033[0;34m[INFO]\033[0m    %s\n' "$*"; }
success() { printf '\033[0;32m[SUCCESS]\033[0m %s\n' "$*"; }
warn()    { printf '\033[0;33m[WARNING]\033[0m %s\n' "$*"; }
error()   { printf '\033[0;31m[ERROR]\033[0m   %s\n' "$*" >&2; }
```

Every significant action is logged before it runs:

```
[INFO]    Detected OS: ubuntu 22.04
[INFO]    Installing packages: git curl neovim zsh
[SUCCESS] Packages installed.
[WARNING] ~/.zshrc already exists — skipping (remove it manually to re-apply dotfiles).
[ERROR]   Lock file /tmp/postinstallhub.lock already exists (PID 1234). Remove it and re-run.
```

## Capturing output

Users who want a persistent record of the run:

```bash
bash install.sh 2>&1 | tee ~/install.log
```

This captures both stdout and stderr. The log file can be shared for debugging.

## Correlation

- Trace context format: N/A — single process, no distributed tracing.
- Request/correlation ID: N/A.
- Propagation boundaries: N/A.
- User/session identifiers: N/A — script does not know or record who is running it.

## Structured log schema

N/A — PostInstallHUB uses plain human-readable text lines, not JSON logs. The prefix format (`[LEVEL] message`) is the schema. No log aggregation or machine parsing is needed.

## Redaction

The script must never log:

- sudo passwords (never seen by the script — handled by OS PAM).
- Tokens, API keys, or credentials of any kind (the script has none).
- Contents of user files beyond the filename (e.g., log the path being configured, not the file's content).
- Sensitive environment variables — log env var *names* if needed for debugging, never their values.

## Dashboards

N/A — not a running service. No dashboards.

## Alerts

N/A — not a running service. The exit code is the alert: a non-zero exit means something went wrong, and the `[ERROR]` line above it explains what.

## Health endpoints/checks

N/A — PostInstallHUB is not a daemon or web service. It has no liveness or readiness endpoints.

The equivalent for a script:
- **"Liveness"**: the script is running if the lock file exists and the PID in it is alive.
- **"Readiness"**: N/A — the script runs to completion or exits with an error; it does not enter a "ready" state.
- **Dependency diagnostics**: the script checks for required tools (curl, bash version) at startup and exits with `[ERROR]` if missing — visible in the terminal, no operator endpoint needed.
