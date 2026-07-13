---
title: "Design System Specification"
status: "not-applicable"
owner: "Matheus"
reviewers:
  - "Matheus"
version: "0.1.0"
last_reviewed: "2026-07-13"
review_cycle: "quarterly"
applies_to: "0.1.0"
source_of_truth: true
related: ["ACCESSIBILITY.md", "CONTENT-GUIDE.md"]
supersedes: null
---

# Design system

**N/A.** PostInstallHUB is a terminal script. There is no UI framework, no component library, no design tokens file, no typography system, no spacing grid, no iconography library, and no browser rendering pipeline. A traditional design system does not apply.

---

## Terminal "visual system"

The only visual layer is ANSI terminal colors, defined in `lib/colors.sh`. This is the full extent of the "design system" for this project.

### Color constants (`lib/colors.sh`)

| Constant | ANSI code | Purpose |
|---|---|---|
| `GREEN` | `\033[0;32m` | Success messages |
| `YELLOW` | `\033[1;33m` | Warnings |
| `RED` | `\033[0;31m` | Errors |
| `BLUE` | `\033[0;34m` | Info / progress |
| `NC` | `\033[0m` | Reset to no color |

Usage rule: always pair a color with a text prefix (`[SUCCESS]`, `[WARNING]`, `[ERROR]`, `[INFO]`) so the message is readable with color disabled. See `CONTENT-GUIDE.md` for message formatting rules and `ACCESSIBILITY.md` for why color-alone indicators are prohibited.

---

## Sections that do not apply

| Design system section | Status | Reason |
|---|---|---|
| Token architecture (primitive / semantic / component) | N/A | No UI framework |
| Typography (fonts, sizes, weights) | N/A | Terminal font is user-controlled |
| Spacing and layout grid | N/A | No layout system |
| Color roles beyond ANSI constants | N/A | Terminal colors are user-controlled |
| Motion / animation | N/A | No animations |
| Component contracts (anatomy, variants, states) | N/A | No UI components |
| Iconography library | N/A | No icons |
| Design token source file | N/A | `lib/colors.sh` is the only color definition needed |
