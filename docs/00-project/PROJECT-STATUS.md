---
title: "Project Status"
status: "in-progress"
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

# Project Status

## Snapshot

- Build: UNKNOWN (no code yet — greenfield)
- Release readiness: NOT_READY
- Security review: N/A (no network services, no auth)
- Migration readiness: N/A
- Documentation completeness: ~60% (spec docs in progress)
- Last updated by: Matheus — 2026-07-13

## Current phase

**Phase 0 — Repo setup + common lib**

Nothing is built yet. The project is greenfield. Active work is spec completion, then the repo scaffold and `lib/` helpers.

## Workstreams

| Workstream | Status | Current task | Blocker | Owner |
|---|---|---|---|---|
| Spec / docs | In progress | Filling all 00-project spec documents | None | Matheus |
| Repo scaffold | Not started | Create GitHub repo, AGENTS.md, CLAUDE.md, README | Spec must be done first | Matheus |
| Common lib | Not started | `lib/colors.sh`, `lib/lock.sh`, `lib/backup.sh` | Repo scaffold | Matheus |
| `install.sh` entry point | Not started | OS detection + delegation logic | Common lib | Matheus |
| Linux scripts | Not started | ubuntu.sh, arch.sh, fedora.sh, omarchy.sh | install.sh | Matheus |
| Windows scripts | Not started | setup.cmd, setup.ps1 | Linux scripts done first | Matheus |
| Testing | Not started | Docker smoke tests per distro | Scripts complete | Matheus |
| Release | Not started | README finalized + GitHub Release v1.0.0 | Tests passing | Matheus |

## Next milestone

**Phase 0 complete:** `install.sh` detects distro and exits cleanly (even before distro scripts exist). `lib/` helpers written and sourced correctly.

## Known gaps

None — this is a greenfield project. No legacy code, no tech debt inherited.

## Recent decisions

- 2026-07-13 — Scope locked: packages + dotfiles + tweaks only. No dev environment setup.
- 2026-07-13 — Architecture locked: `install.sh` entry point → `lib/` helpers → distro scripts.
- 2026-07-13 — Dotfiles from companion repo via curl, not bundled in this repo.

## Immediate risks

- Companion dotfile repo URL not yet confirmed — blocks the dotfile curl step in all distro scripts. Resolve before Phase 1.
- Omarchy config paths differ from plain Arch and need verification against a live Omarchy install before `omarchy.sh` is written.
