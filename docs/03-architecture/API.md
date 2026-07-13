---
title: "API and Contract Strategy"
status: "not-applicable"
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

# API and contract strategy

> **N/A for PostInstallHUB.**
>
> PostInstallHUB is a collection of shell scripts, not a web service. There are
> no HTTP endpoints, no GraphQL schema, no RPC layer, no OpenAPI spec, no
> AsyncAPI contract, and no JSON schema to maintain. The "interface" is the
> terminal. This document is retained for template completeness and to document
> the actual CLI interface that takes the place of an API contract.

---

## Why this document does not apply

An API contract document describes how a service exposes its behavior over a
network protocol. PostInstallHUB has no network server and no listening socket.
It is invoked by the user on a fresh machine, runs to completion, and exits.
There is nothing to call remotely, no versioned endpoint to pin against, and no
consumer other than the person running the script.

---

## Actual interface: CLI

The contract PostInstallHUB makes with its user is through the shell, not HTTP.

### Entry point

```bash
# Recommended: pipe-to-bash from a single curl command
curl -fsSL https://raw.githubusercontent.com/<owner>/PostInstallHUB/main/install.sh | bash

# Or clone and run locally
bash install.sh
```

The script auto-detects the OS and routes to the correct distro handler. The
user runs the same command regardless of distro.

### Environment variables (the "request parameters")

| Variable | Type | Default | Effect |
|---|---|---|---|
| `POSTINSTALL_YES` | `0` \| `1` | `0` | Skip all confirmation prompts when set to `1` (non-interactive / CI mode) |
| `POSTINSTALL_SKIP_DOTFILES` | `0` \| `1` | `0` | Skip fetching and applying the dotfile repository |
| `POSTINSTALL_DOTFILES_URL` | URL string | project default repo URL | Override the dotfile archive URL (point at your own fork) |
| `POSTINSTALL_SKIP_TWEAKS` | `0` \| `1` | `0` | Skip OS tweaks (sysctl, locale, timezone configuration) |

Example — fully non-interactive run with a custom dotfile repo:

```bash
POSTINSTALL_YES=1 \
POSTINSTALL_DOTFILES_URL=https://github.com/myuser/dotfiles/archive/main.tar.gz \
bash install.sh
```

### Exit codes (the "response status codes")

| Code | Meaning |
|---:|---|
| `0` | Success — all requested steps completed without error |
| `1` | General failure — a required step exited non-zero (see stderr for details) |
| `2` | Unsupported OS — `/etc/os-release` ID not in the known distro list |
| `3` | Lock conflict — `/tmp/postinstallhub.lock` exists; another instance may be running |
| `4` | Missing sudo — script requires sudo privileges and could not acquire them |

### Output conventions

All output goes to stdout/stderr with ANSI color codes:

- **Green** `\e[32m` — step completed successfully
- **Yellow** `\e[33m` — non-fatal warning (e.g., dotfiles skipped)
- **Red** `\e[31m` — fatal error before exit
- **Blue** `\e[34m` — informational step header

---

## Sections not applicable to this project

The following topics from the standard API contract template have no
equivalent in a shell script project:

- HTTP protocol, base path, versioning strategy → N/A
- Authentication, token lifetime, CSRF policy → N/A
- Idempotency keys → N/A (script-level idempotency is handled by the
  package manager and by guard checks at the top of each step)
- Error envelope JSON → N/A (errors are plain text to stderr)
- Deprecation headers and consumer inventory → N/A
- Contract testing with Pact / Dredd / Schemathesis → N/A
