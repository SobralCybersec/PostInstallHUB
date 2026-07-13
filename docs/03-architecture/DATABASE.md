---
title: "Database and Data Architecture"
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

# Database and data architecture

> **N/A for PostInstallHUB.**
>
> PostInstallHUB has no database. It is a stateless collection of shell scripts
> that installs software and applies configuration to a fresh operating system.
> It does not store, query, migrate, or back up any structured data. This
> document is retained for template completeness and to describe the minimal
> state that does exist.

---

## Why this document does not apply

A database document describes persistent, structured data managed by the
application across its lifetime. PostInstallHUB does not manage any such data.
It reads from package manager indices (owned by the OS) and writes dotfiles and
installed packages to the filesystem (owned by the user). Neither of these is
application state that PostInstallHUB controls or needs to version.

---

## Actual state model

PostInstallHUB is stateless between runs. The only runtime state is:

### Lock file

- **Path:** `/tmp/postinstallhub.lock`
- **Purpose:** prevents two concurrent instances of `install.sh` from running
  simultaneously on the same machine
- **Lifetime:** created at script start, deleted on exit (via `trap` on
  `EXIT`, `INT`, and `TERM`); if a process is killed hard without the trap
  firing, the lock file remains and subsequent runs exit with code `3`
- **Format:** plain text containing the PID of the running process
- **Persistence:** session-scoped; `/tmp` is cleared on reboot
- **Owned by:** PostInstallHUB (`install.sh`)

### Persistent state (not owned by PostInstallHUB)

The following things exist on disk after the script runs, but they are owned
by the OS and the user, not by PostInstallHUB. PostInstallHUB does not need to
track, migrate, or roll back any of it:

| What | Where | Owner |
|---|---|---|
| Installed packages | OS package database (`/var/lib/dpkg`, `/var/lib/pacman`, etc.) | OS package manager |
| Dotfiles | `~/.zshrc`, `~/.config/nvim/`, etc. | User's home directory |
| OS tweaks | `/etc/sysctl.conf`, locale and timezone config | OS |

There is no application database, no schema, no ORM, no migration runner, and
no connection pool.

---

## Sections not applicable to this project

- Database selection and rationale → N/A
- Entity-relationship diagram → N/A
- Table/collection definitions → N/A
- Transaction boundaries → N/A
- Migration policy and tool → N/A (see [MIGRATIONS.md](MIGRATIONS.md))
- Retention and deletion policy → N/A
- Backup and restore (RPO/RTO) → N/A
- Query guardrails → N/A
