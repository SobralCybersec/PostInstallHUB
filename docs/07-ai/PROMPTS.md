---
title: "Prompt Specification"
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

# Prompt specification

**N/A.** PostInstallHUB contains no prompts. There is no LLM integration, no system policy injected at runtime, no user content passed to a model, and no output schema to validate against model responses.

The only "prompts" in this project are the interactive terminal prompts that ask the user to press Enter before modifying their system — those are handled by plain `read` calls in bash, not by any LLM.
