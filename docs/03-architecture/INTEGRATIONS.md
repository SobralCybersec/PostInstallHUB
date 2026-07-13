---
title: "External Integrations"
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

# External integrations

PostInstallHUB has two external integrations: the OS package manager (called
directly via shell) and an optional companion dotfile repository fetched over
HTTPS. There are no APIs, no OAuth flows, no webhooks, no message queues, and
no third-party SaaS dependencies.

## Integration inventory

| Provider | Purpose | Data exchanged | Criticality | Owner |
|---|---|---|---|---|
| OS Package Manager (apt / pacman / dnf / winget) | Install packages (git, curl, neovim, zsh, etc.) | Package names + version constraints (outbound only) | HIGH — installation cannot proceed without it | Matheus |
| Companion Dotfile Repository (GitHub via curl) | Pull dotfiles onto the fresh system | Tarball / raw files (inbound only) | LOW — non-fatal; script continues with a warning if unavailable | Matheus |

---

## Integration: OS Package Manager

The package manager is the system-provided binary (`apt`, `pacman`, `dnf`, or
`winget`). PostInstallHUB shells out to it directly — there is no wrapper
library or API layer.

- **Invocation:** direct shell call, e.g. `apt-get install -y <pkg>`
- **Authentication:** none required; `sudo` elevation is handled by the
  calling script before this integration is reached
- **Permissions/scopes:** root / administrator privileges (acquired via sudo)
- **Sandbox:** NO — installs to the live system by design
- **Rate limits:** none (local package index)
- **Timeout:** inherits the system default; no explicit timeout set in v0.1
- **Retryable responses:** non-zero exit on transient network failure (apt/dnf
  fetching remote indices) — the script exits and the user reruns
- **Maximum attempts:** 1 (no automatic retry in v0.1)
- **Circuit-breaker policy:** none — failure exits the script immediately with
  exit code 1
- **Webhook verification:** N/A
- **Idempotency:** package managers are idempotent by nature; re-running
  install on an already-installed package is a no-op
- **Data residency:** local system only
- **Provider retention:** N/A — no data sent to an external provider
- **Terms/compliance owner:** Matheus

---

## Integration: Companion Dotfile Repository

An optional public GitHub repository containing the user's dotfiles. Fetched
once during install via `curl`. The URL is configurable so users can point at
their own fork.

- **Invocation:** `curl -fsSL "$POSTINSTALL_DOTFILES_URL" | tar -xz -C ~` (or
  equivalent; exact command defined in `lib/dotfiles.sh`)
- **Base URL:** value of `POSTINSTALL_DOTFILES_URL` env var; defaults to the
  project's own dotfiles repo on GitHub
- **Authentication:** none — repository must be public; no API key or token
  required
- **Permissions/scopes:** read-only, unauthenticated HTTPS
- **Sandbox:** NO — files are written to the user's home directory
- **Rate limits:** subject to GitHub's unauthenticated raw download limits;
  not an issue for a single fetch at install time
- **Timeout:** `curl` default (~300 s); acceptable for a one-time archive fetch
- **Retryable responses:** network errors — user can rerun with
  `POSTINSTALL_SKIP_DOTFILES=1` to bypass and set up dotfiles manually later
- **Maximum attempts:** 1 automatic; user reruns manually if needed
- **Circuit-breaker policy:** non-fatal — failure prints a yellow warning and
  continues; dotfiles are treated as optional
- **Webhook verification:** N/A
- **Idempotency:** re-running overwrites existing dotfiles with the same
  content; safe
- **Data residency:** files land on the local machine; nothing is sent to
  GitHub
- **Provider retention:** N/A — read-only fetch, no data submitted
- **Terms/compliance owner:** Matheus

---

## Failure behavior

| Failure | Detection | Degraded behavior | User impact | Alert |
|---|---|---|---|---|
| Package manager unavailable or exits non-zero | Non-zero exit code captured by `set -e` | Script exits immediately with exit code 1 and prints a red error message | Installation is incomplete; user must fix the underlying issue and rerun | Console output only (no external alerting) |
| Dotfile repo unreachable (DNS failure, 404, timeout) | `curl` non-zero exit | Warning printed in yellow; dotfile step skipped; rest of install continues | Dotfiles not applied; user must apply manually after connectivity is restored | Console warning only |
| Unsupported OS detected | `/etc/os-release` ID not in known list | Script exits with exit code 2 and prints supported distro list | Nothing installed; user informed immediately | Console output only |

---

## Replacement strategy

**Package manager:** PostInstallHUB calls each package manager through thin
wrapper functions in `lib/pkgmgr.sh` (one function per distro). Replacing or
adding a package manager means adding a new function and a detection branch in
`install.sh`; no other code changes. Migration risk is low because each
wrapper is isolated.

**Dotfile repository:** The URL is fully externalized to `POSTINSTALL_DOTFILES_URL`.
Switching providers (e.g., from GitHub to a self-hosted Gitea) requires only
setting that env var. No code changes needed unless the archive format changes,
in which case `lib/dotfiles.sh` is the single file to update.

---

## N/A sections (web-app integrations)

The following integration concerns do not apply to PostInstallHUB and are
recorded here only for template completeness:

- **OAuth / token-based auth:** N/A — no user accounts, no sessions
- **Webhooks:** N/A — no server to receive events
- **Message queues / event buses:** N/A — synchronous shell execution only
- **Third-party SaaS (Stripe, Twilio, SendGrid, etc.):** N/A
- **CDN / object storage:** N/A
- **Feature flags / remote config:** N/A
