---
title: "AI Tool Permissions"
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

# AI tool permissions

**N/A.** PostInstallHUB has no AI agent at runtime and therefore no AI tool permission model to define.

The scripts call system tools (`apt`, `pacman`, `dnf`, `winget`, `chsh`, `curl`) directly and deterministically. Permission is granted at the OS level — the user chose to run the script with sudo. There is no AI layer routing tool calls, no dynamic permission grants, and no agent that could escalate privileges beyond what the user already provided.

---

## Development tooling note

When using Claude Code to develop PostInstallHUB, the tool permissions that apply are Claude Code's own permission model configured in `AGENTS.md` and the user's `.claude/settings.json`. Those govern the development environment — not the PostInstallHUB product itself.
