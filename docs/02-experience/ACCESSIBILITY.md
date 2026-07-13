---
title: "Accessibility Specification"
status: "not-applicable"
owner: "Matheus"
reviewers:
  - "Matheus"
version: "0.1.0"
last_reviewed: "2026-07-13"
review_cycle: "quarterly"
applies_to: "0.1.0"
source_of_truth: true
related: ["DESIGN-SYSTEM.md", "CONTENT-GUIDE.md"]
supersedes: null
---

# Accessibility specification

PostInstallHUB is a terminal script. There is no GUI, no web interface, no browser rendering, and no visual components. WCAG conformance levels (A/AA/AAA), browser-based assistive technology testing, and component-level keyboard/screen-reader contracts do not apply.

The accessibility considerations that do apply to a terminal tool are documented below.

---

## Terminal accessibility principles

### Color is never the only signal

ANSI colors are decorative. Every message must be readable in a terminal with color disabled or in a color scheme the user controls. Each log level uses both color and a text prefix symbol:

| Level | Color | Symbol | Example output |
|---|---|---|---|
| Info | BLUE | `[INFO]` | `[INFO] Installing git...` |
| Success | GREEN | `[SUCCESS]` | `[SUCCESS] git installed.` |
| Warning | YELLOW | `[WARNING]` | `[WARNING] zsh already installed, skipping.` |
| Error | RED | `[ERROR]` | `[ERROR] Package install failed. See output above.` |

A user running with `NO_COLOR=1` or in a monochrome terminal gets the same information from the text prefix. Never use color alone to distinguish meaning.

### Screen reader compatibility

Terminal output is inherently linear text. Any screen reader that can read a terminal (e.g. Orca on Linux desktops, or NVDA with a terminal emulator on Windows) will read PostInstallHUB's output correctly because there are no images, no icons rendered as Unicode art, and no assumed spatial layout.

### No images or visual-only indicators

Scripts produce only plain text and ANSI escape codes. No box-drawing art that requires a specific font, no emoji that may not render in all terminal emulators, no progress bars that rely on cursor positioning without a text fallback.

### Cognitive accessibility

- Messages are short and direct.
- Each step names what is happening before it happens.
- Errors name what failed and what to do next — never just an error code.
- The backup warning is printed prominently, not buried in a wall of output.

---

## Sections that do not apply

| WCAG / standard section | Status | Reason |
|---|---|---|
| WCAG 2.2 (any level) | N/A | Web Content Accessibility Guidelines apply to web content |
| Keyboard navigation / focus management | N/A | No interactive UI; terminal input is inherently keyboard-driven |
| Contrast ratios for UI components | N/A | Terminal color schemes are user-controlled |
| Touch target sizes | N/A | No touch interface |
| Motion / reduced-motion preferences | N/A | No animations |
| Assistive technology test matrix (browsers) | N/A | No browser |
| Authentication cognitive-function tests | N/A | No authentication UI |
