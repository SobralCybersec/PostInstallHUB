---
title: "Project Specification Index"
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

# PostInstallHUB — Specification Index

## Project identity

| Field | Value |
|---|---|
| Repository | `https://github.com/matheusgomescosta/PostInstallHUB` |
| Product owner | Matheus |
| Technical owner | Matheus |
| Current phase | MVP |
| Target release | v1.0.0 (no fixed date) |
| Last architecture review | 2026-07-13 |

## Reading order

Start here when picking up the project cold or onboarding an AI agent:

1. [COCKPIT-BRIEF.md](COCKPIT-BRIEF.md) — full project brief: problem, solution, architecture, phases, acceptance criteria
2. [CONTEXT.md](CONTEXT.md) — why this exists, what was considered, stable decisions
3. [SCOPE.md](SCOPE.md) — what's in and out, assumptions, constraints
4. [GLOSSARY.md](GLOSSARY.md) — term definitions for shell, distro, dotfile, lock file, etc.
5. [PROJECT-STATUS.md](PROJECT-STATUS.md) — current state, active work, next milestone
6. [ROADMAP.md](ROADMAP.md) — phased plan from Phase 0 to v1.0.0 release

## Specification registry

| Document | Purpose | Status | Owner |
|---|---|---|---|
| COCKPIT-BRIEF.md | Full project brief — problem, solution, architecture, phases, acceptance criteria | draft | Matheus |
| CONTEXT.md | Why the project exists, alternatives considered, stable decisions | draft | Matheus |
| SCOPE.md | What is and isn't in scope, assumptions, constraints | draft | Matheus |
| GLOSSARY.md | Definitions for all domain terms used in specs and scripts | draft | Matheus |
| PROJECT-STATUS.md | Live status snapshot — current phase, active work, risks | draft | Matheus |
| ROADMAP.md | Phased delivery plan from scaffold to v1.0.0 | draft | Matheus |

## Decision log

| ADR | Decision | Status | Date |
|---|---|---|---|
| — | Entry point is `install.sh`, piped from curl | accepted | 2026-07-13 |
| — | Shared helpers in `lib/`; distro scripts in `scripts/` | accepted | 2026-07-13 |
| — | Dotfiles come from companion repo, not bundled | accepted | 2026-07-13 |
| — | Bash only; no runtime dependencies | accepted | 2026-07-13 |
| — | Scope excludes dev environment setup (Node, Docker, etc.) | accepted | 2026-07-13 |

## Unresolved blockers

| ID | Blocker | Owner | Due | Impact |
|---|---|---|---|---|
| — | Companion dotfile repo URL must be confirmed before Phase 1 | Matheus | Phase 1 start | Dotfile curl step cannot be written without it |
