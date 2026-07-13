---
title: "Frontend Architecture"
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

# Frontend architecture

> **N/A for PostInstallHUB.**
>
> PostInstallHUB has no graphical interface, no web UI, and no TUI framework.
> The terminal is the only interface. This document is retained for template
> completeness and to document the output conventions that govern how the script
> communicates with the user.

---

## Why this document does not apply

A frontend architecture document describes a visual layer rendered in a browser,
desktop webview, or similar environment. PostInstallHUB has none of these. It
is a shell script that prints text to a terminal and exits. There is no
component tree, no state manager, no router, no bundle, and no DOM.

---

## Actual interface: terminal output

The terminal is the complete user interface. The script communicates entirely
through stdout/stderr using plain text and ANSI escape codes. No interactive
TUI framework (ncurses, whiptail, dialog, Bubble Tea) is used in v0.1 — the
interface is read-only from the user's perspective except for yes/no
confirmation prompts.

### ANSI color conventions

These are the only "design tokens" PostInstallHUB uses:

| Semantic | ANSI code | Usage |
|---|---|---|
| Success | `\e[32m` (green) | Step completed — e.g., `✓ neovim installed` |
| Warning | `\e[33m` (yellow) | Non-fatal issue — e.g., `⚠ dotfiles skipped` |
| Error | `\e[31m` (red) | Fatal error before exit — e.g., `✗ unsupported OS` |
| Info / header | `\e[34m` (blue) | Section headers — e.g., `── Installing packages ──` |
| Reset | `\e[0m` | Always appended after every colored string |

All color codes are guarded by a `NO_COLOR` / non-tty check: if stdout is not
a terminal (e.g., output is piped or redirected), ANSI codes are suppressed so
log files stay clean.

### Progress communication

Progress is communicated through `echo` statements before and after each
logical step. There are no spinners or progress bars in v0.1. Steps are
grouped under section headers:

```
── Detecting OS ──────────────────────────────────────
✓ Detected: Ubuntu 24.04 LTS

── Installing packages ───────────────────────────────
  → git ...  ✓
  → curl ...  ✓
  → neovim ...  ✓
  → zsh ...  ✓

── Applying dotfiles ─────────────────────────────────
✓ Dotfiles applied from https://github.com/.../dotfiles

── Done ──────────────────────────────────────────────
✓ PostInstallHUB finished in 47s
```

### Interactive prompts

The only interactive element is the yes/no confirmation shown before
destructive or slow steps (e.g., "Install packages? [y/N]"). Setting
`POSTINSTALL_YES=1` bypasses all prompts for unattended runs.

---

## Sections not applicable to this project

- Framework, language, rendering mode → N/A
- Directory structure and dependency rules → N/A
- State ownership (server state, UI state, form state, auth state) → N/A
- Routing and authorization guards → N/A
- API client generation, optimistic updates, WebSocket reconnect → N/A
- Component policy and accessibility contracts → N/A
- Performance budgets (LCP, INP, bundle size) → N/A
- Visual regression testing → N/A
