---
title: "ADR Template"
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

# ADR-{{NUMBER}}: {{DECISION_TITLE}}

- Status: {{ENUM: proposed|accepted|deprecated|superseded}}
- Date: {{YYYY-MM-DD}}
- Deciders: {{NAMES_OR_ROLES}}
- Supersedes: {{ADR_NUMBER or none}}
- Related requirements: {{IDS — e.g., FR-001, SCOPE.md, or none}}

## Context

{{What is the situation that forces a decision? Describe the forces,
constraints, and risks at play. For PostInstallHUB, typical triggers include:
adding support for a new distro, changing how dotfiles are applied, deciding
on a new tool dependency, or altering how the script handles failures.
Be concrete — what breaks or becomes inconsistent if we don't decide?}}

## Decision drivers

- {{DRIVER — e.g., "Must work on a fresh OS with no pre-installed tools"}}
- {{DRIVER — e.g., "One-liner must stay shareable and distro-agnostic"}}
- {{DRIVER — e.g., "Script must remain idempotent across reruns"}}

## Considered options

1. {{OPTION_A — describe fully enough that someone can evaluate it}}
2. {{OPTION_B}}
3. {{OPTION_C — include "do nothing" / "keep current behavior" when relevant}}

## Decision

We will {{DECISION — state it unambiguously, e.g., "add an
`distros/opensuse.sh` handler and a detection branch in `install.sh` for
`ID=opensuse-leap` and `ID=opensuse-tumbleweed`"}}.

## Rationale

{{Why this option best satisfies the drivers. Call out specifically why the
rejected options fall short. Reference concrete constraints from the project
(fresh-OS bootstrap, no external dependencies, idempotency) rather than
generic engineering principles.}}

## Consequences

### Positive

- {{CONSEQUENCE — what gets better or easier}}

### Negative

- {{CONSEQUENCE — what gets harder, slower, or more complex}}

### Risks

- {{RISK and its mitigation — e.g., "Detection false positive on unusual
  distro variants — mitigated by CI tests against clean images"}}

## Validation

{{How and when the decision will be evaluated as correct. For PostInstallHUB
this usually means: "passes on a clean X image in CI" or "no remaining
placeholders" or "script exits 0 on the target platform." Name the specific
check so it can be verified without interpretation.}}

## Revisit when

- {{TRIGGER — e.g., "supported distro count exceeds 10 and the routing table
  becomes unwieldy"}}
- {{TRIGGER — e.g., "a user reports the detection logic misidentifies their OS"}}
