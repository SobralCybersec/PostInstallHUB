---
title: "AI Safety and Abuse Controls"
status: "not-applicable"
owner: "Matheus"
reviewers:
  - "Matheus"
version: "0.1.0"
last_reviewed: "2026-07-13"
review_cycle: "quarterly"
applies_to: "0.1.0"
source_of_truth: true
related: ["../06-governance/RISK-REGISTER.md", "../06-governance/SUPPLY-CHAIN.md"]
supersedes: null
---

# AI safety and abuse controls

**N/A.** PostInstallHUB contains no AI. There are no prompt-injection surfaces, no model output to validate, no tool-use permissions for an agent, and no AI-generated actions to gate with human approval — because none of those things exist in this product.

---

## Safety considerations that do apply

PostInstallHUB's safety concerns are operational, not AI-related. They are documented elsewhere:

- **Script runs with sudo on a user's machine** — mitigated by backup warning, idempotency, and clear error messages. See `RISK-REGISTER.md` RSK-001.
- **curl-pipe-to-bash delivery** — MITM risk acknowledged and mitigated via HTTPS. See `RISK-REGISTER.md` RSK-003 and `SUPPLY-CHAIN.md`.
- **GitHub account compromise** — mitigated via 2FA. See `RISK-REGISTER.md` RSK-002.
