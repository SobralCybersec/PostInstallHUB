---
title: "AI System Specification"
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

# AI system specification

**N/A.** PostInstallHUB has no AI system in the product. This document does not apply.

There are no LLM calls, no model integrations, no vector stores, no prompt pipelines, no AI-generated output, and no agentic behavior anywhere in the install scripts. The product is deterministic bash and CMD: it runs known commands against known package managers and produces known results.

---

## Why this file exists in the template

This spec template was designed for projects that embed AI capabilities (classification, generation, tool use, etc.). PostInstallHUB does not. The file is kept with `status: not-applicable` so the spec set stays structurally complete — a future audit can confirm the absence of AI was intentional, not overlooked.

For AI tools used during *development* of PostInstallHUB, see `AGENTS.md` and `CLAUDE.md` in the repo root.
