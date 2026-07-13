---
title: "Technical Debt Register"
status: "active"
owner: "Matheus"
reviewers:
  - "Matheus"
version: "0.1.0"
last_reviewed: "2026-07-13"
review_cycle: "quarterly"
applies_to: "0.1.0"
source_of_truth: true
related: ["RISK-REGISTER.md", "DEPENDENCIES.md"]
supersedes: null
---

# Technical debt register

## Current register

| ID | Debt | Origin | Impact | Interest | Removal plan | Target | Owner |
|---|---|---|---|---|---|---|---|
| DEBT-001 | No unit test framework (bats) configured | Greenfield MVP prioritized working scripts over test infra | Low now; grows as scripts get more complex | Each new function added without tests makes future refactors riskier | Add `bats` and write tests for `common.sh` functions first, then distro scripts | Phase 3 | Matheus |
| DEBT-002 | Windows CMD/batch coverage is limited compared to Linux scripts | CMD has fewer primitives than bash; PowerShell was deprioritized | Users on Windows get a less complete setup | As Windows features expand, CMD becomes harder to maintain | Migrate Windows to PowerShell-only; deprecate `setup.cmd` | Phase 2+ | Matheus |
| DEBT-003 | `common.sh` may grow unwieldy if more distros are added | Single shared file is fine for 4 distros, unclear at 8+ | Harder to find functions; risk of name collisions | Small now; grows with each distro added | Split `common.sh` by concern (e.g. `common-logging.sh`, `common-packages.sh`) when line count exceeds ~300 | When triggered | Matheus |

---

## Current state

This is a greenfield MVP. No inherited debt from a previous codebase. The items above are **anticipated** debt from deliberate simplifications made during initial build.

---

## Admission rules

Record an item when a deliberate or inherited compromise creates ongoing cost, risk, or reduced changeability. "Unfinished features" are not debt — they belong on the roadmap.

## Prioritization

- **Mandatory remediation triggers:**
  - A debt item causes a real bug or incident.
  - A debt item is blocking a roadmap feature.
  - The ongoing cost of working around the debt exceeds the cost of fixing it.
- **Revisit cadence:** quarterly, alongside the spec review cycle.
- **Severity model:** impact × growth rate. Debt that gets worse over time is more urgent than debt that stays stable.
