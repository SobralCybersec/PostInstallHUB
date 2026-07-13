---
title: "User Experience Specification"
status: "active"
owner: "Matheus"
reviewers:
  - "Matheus"
version: "0.1.0"
last_reviewed: "2026-07-13"
review_cycle: "quarterly"
applies_to: "0.1.0"
source_of_truth: true
related: ["CONTENT-GUIDE.md", "ACCESSIBILITY.md", "DESIGN-SYSTEM.md"]
supersedes: null
---

# UX specification

PostInstallHUB is a CLI tool. There is no GUI, no web interface, and no navigation model in the traditional UX sense. This document captures the CLI-specific UX principles that govern how the script should feel to run.

---

## Experience goals

1. **Fast and transparent.** The user always knows what the script is doing and why. Nothing happens silently.
2. **Trustworthy.** A script that runs with sudo must earn trust through clear, predictable behavior. No surprises.
3. **Safe by default.** Warn before modifying anything that already exists. Never delete without explicit confirmation.

---

## CLI UX principles

### Show what will happen before doing it

Print an `[INFO]` line before starting each major step. The user should be able to read the output and reconstruct exactly what the script did.

```
[INFO] Detected OS: Ubuntu 22.04
[INFO] Installing packages: git curl neovim zsh
[INFO] Setting zsh as default shell...
```

### Confirm after each major step

Every step that completes successfully gets a `[SUCCESS]` line. The user should never have to wonder if something worked.

```
[SUCCESS] git installed.
[SUCCESS] neovim installed.
[SUCCESS] zsh set as default shell.
```

### Never silently skip — always say what was skipped and why

If a step is skipped because the tool is already installed, or because a condition was not met, say so explicitly with `[WARNING]`. A silent no-op looks like a bug.

```
[WARNING] git already installed (version 2.43.0), skipping.
[WARNING] Dotfile ~/.zshrc already exists. Not overwriting — delete it manually to reset.
```

### Backup warning must be prominent

The backup warning is shown before any step that modifies existing files. It is not buried. It gives the user a chance to abort with Ctrl+C. It is printed in yellow so it stands out from the info stream.

```
[WARNING] This script will modify your shell configuration files.
[WARNING] Back up ~/.zshrc and ~/.config before continuing.
[WARNING] Press Ctrl+C to cancel, or press Enter to continue.
```

### Do not suppress package manager output

When calling `apt install`, `pacman -S`, `dnf install`, or `winget install`, let their output pass through to the terminal. Users expect to see package manager output; hiding it makes failures harder to diagnose.

### Error output must name the step, show the error, and suggest next action

A bare "error" message is useless. Every `[ERROR]` must:

1. Name which step failed.
2. Reference where to find more detail (usually "see output above").
3. Suggest what to do (retry, fix the dependency, run the distro script directly, etc.).

```
[ERROR] Package install failed during zsh setup. See apt output above.
[ERROR] If on a fresh install, try: sudo apt update && sudo apt upgrade, then re-run.
```

### Exit cleanly on failure

Use the correct exit code (see `CODING-STANDARDS.md`). Do not let the script silently succeed when a critical step failed. The user should never see a final `[SUCCESS] Setup complete.` if a required package did not install.

---

## Interaction flow

```text
User runs: curl -fsSL https://... | bash
  ↓
install.sh: detect OS
  ↓ (if unsupported: [ERROR] + exit 2)
install.sh: acquire lock
  ↓ (if locked: [ERROR] + exit 3)
install.sh: check sudo
  ↓ (if no sudo: [ERROR] + exit 4)
install.sh: show backup warning → wait for Enter
  ↓ (Ctrl+C exits cleanly)
distro script: [INFO] + install each package
  ↓ (each: [WARNING] if already installed, [SUCCESS] if installed, [ERROR]+exit if failed)
distro script: fetch dotfiles
  ↓ ([WARNING] if file already exists, [SUCCESS] when done)
distro script: set zsh as default
  ↓ ([SUCCESS] + reminder to log out)
release lock → exit 0
```

---

## Sections that do not apply

| UX section | Status | Reason |
|---|---|---|
| Information architecture (screens, sections) | N/A | No navigation; linear script execution |
| Navigation model (primary/secondary nav, back, deep links) | N/A | No interactive UI |
| Screen inventory | N/A | No screens |
| Form validation | N/A | No forms |
| Toast / dialog feedback components | N/A | No UI components |
| Responsive / breakpoint behavior | N/A | Terminal width is user-controlled |
| Keyboard shortcuts | N/A | Standard terminal input only |
