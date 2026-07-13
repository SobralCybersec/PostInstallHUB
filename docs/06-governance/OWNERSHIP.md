---
title: "Ownership and Review"
status: "active"
owner: "Matheus"
reviewers:
  - "Matheus"
version: "0.1.0"
last_reviewed: "2026-07-13"
review_cycle: "quarterly"
applies_to: "0.1.0"
source_of_truth: true
related: ["CONTRIBUTING.md", "REPOSITORY-STRUCTURE.md"]
supersedes: null
---

# Ownership and review

PostInstallHUB is a **solo project**. Matheus owns everything. There is no team, no on-call rotation, no escalation path, and no external contributors.

---

## Repository

- **GitHub:** [github.com/matheusgomescosta/PostInstallHUB](https://github.com/matheusgomescosta/PostInstallHUB)
- **Sole maintainer:** Matheus
- **External PRs:** not accepted

---

## Component ownership

All files in this repository are owned by Matheus.

| Area / path | Owner | Notes |
|---|---|---|
| `install.sh` | Matheus | Entry point; OS detection and routing |
| `scripts/linux/` | Matheus | All Linux distro scripts |
| `scripts/windows/` | Matheus | CMD and PowerShell setup |
| `lib/` | Matheus | Shared utilities: colors, lock, backup |
| `tests/` | Matheus | All test files |
| `docs/` | Matheus | All spec documentation |
| `README.md` | Matheus | User-facing docs |
| `AGENTS.md` / `CLAUDE.md` | Matheus | AI coding agent instructions |

---

## Decision rights

All decisions belong to Matheus. There is no approval chain.

| Decision | Owner |
|---|---|
| Product scope and roadmap | Matheus |
| Architecture and design | Matheus |
| Coding standards and tooling | Matheus |
| Release and versioning | Matheus |
| Security posture | Matheus |

---

## Bus factor

Bus factor is 1 by design. This is a personal tool. Mitigation:

- The install script is publicly accessible on GitHub.
- README documents everything needed to understand and run the scripts.
- Code is plain bash — no proprietary toolchain, no compiled artifacts, no secrets needed to operate.
- The companion dotfile repo is separately maintained by Matheus.

---

## Review process

No PR review process — Matheus commits directly to `main` after running the local verification commands documented in `CONTRIBUTING.md`. There are no CODEOWNERS, no required reviewers, and no branch protection rules beyond what GitHub's free tier provides by default.
