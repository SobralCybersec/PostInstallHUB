---
title: "AI Evaluation Specification"
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

# AI evaluation specification

**N/A.** PostInstallHUB has no AI models to evaluate. The scripts are deterministic — correctness is verified by running them in a clean Docker container and confirming the expected packages are installed and the expected config changes were made.

That testing lives in `tests/` and is documented in `CONTRIBUTING.md` and `docs/04-quality/TESTING.md`. It is not model evaluation.
