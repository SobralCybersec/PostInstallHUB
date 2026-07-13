---
title: "Agent Runtime"
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

# Agent runtime

**N/A.** PostInstallHUB does not include AI agents as part of the product. This document does not apply.

The scripts are plain bash and CMD. There is no LLM call, no agent loop, no tool-use framework, and no AI runtime dependency anywhere in the install scripts or lib utilities.

---

## Development tooling note

AI coding assistants (Claude Code, Codex, etc.) may be used by Matheus during development. Their configuration lives in the repo root — not in this `07-ai/` section, which covers product-level AI:

- `AGENTS.md` — universal instructions for any AI coding agent working in this repo
- `CLAUDE.md` — Claude Code-specific notes

Those files govern how the *developer* uses AI tools to write and maintain PostInstallHUB. They have no bearing on what PostInstallHUB does at runtime.
