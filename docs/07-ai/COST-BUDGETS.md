---
title: "AI Cost and Resource Budgets"
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

# AI cost and resource budgets

**N/A.** PostInstallHUB makes no AI API calls. There are no token budgets, no per-request cost limits, no monthly AI spend, and no latency targets for model inference — because there is no model inference.

The scripts call `apt`, `pacman`, `dnf`, and `winget`. Those are free. There is nothing to budget here.

---

## Development cost note

If Matheus uses Claude Code or similar tools while developing PostInstallHUB, those costs are personal developer tooling costs — not product costs. They are not tracked in this document.
