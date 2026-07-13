---
title: "Schema and Data Migrations"
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

# Schema and data migrations

> **N/A for PostInstallHUB.**
>
> PostInstallHUB has no database, no schema, and no versioned data store. There
> are no migrations to write, run, or roll back. This document is retained for
> template completeness.

---

## Why this document does not apply

Schema migrations exist to evolve a structured data store (relational tables,
document collections, search indices) in a controlled, versioned, rollback-safe
way. PostInstallHUB is a stateless shell script collection; it does not own any
structured data store. The only runtime artifact it creates is a session-scoped
lock file at `/tmp/postinstallhub.lock`, which is deleted on exit and requires
no versioning.

See [DATABASE.md](DATABASE.md) for a full account of what little state the
project does manage.

---

## Script version upgrades (what migrations would be, if they existed)

When PostInstallHUB itself is updated, there is no migration step. The upgrade
process is:

1. The user runs the new `install.sh` (or re-runs the curl command).
2. Because each step is **idempotent** — package managers skip already-installed
   packages, dotfile overwrites are safe, OS tweaks are guarded by existence
   checks — running a newer version over an existing installation is always safe.
3. Nothing needs to be rolled back; if a step fails, the user fixes the issue
   and reruns. The previous state of installed packages and dotfiles persists
   untouched.

This is the shell-script equivalent of expand/contract: additive steps first,
with the running system never left in an incompatible state.

---

## Sections not applicable to this project

- Migration tool and directory → N/A
- Expand / contract phases → N/A (idempotency provides the same safety guarantee
  without a formal expand/contract protocol)
- Backward compatibility rules → N/A
- Migration register → N/A
- Contract-test gate for migrations → N/A
- Rollback procedures → N/A (rerun or restore from OS snapshot)
- Pre-migration backup policy → N/A
