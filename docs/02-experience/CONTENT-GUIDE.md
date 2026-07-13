---
title: "Content and Microcopy Guide"
status: "active"
owner: "Matheus"
reviewers:
  - "Matheus"
version: "0.1.0"
last_reviewed: "2026-07-13"
review_cycle: "quarterly"
applies_to: "0.1.0"
source_of_truth: true
related: ["UX.md", "DESIGN-SYSTEM.md", "CODING-STANDARDS.md"]
supersedes: null
---

# Content and microcopy guide

This is the writing standard for every string that PostInstallHUB prints to the terminal. Consistent, clear output makes the script feel trustworthy. Sloppy copy makes users nervous when running something with sudo.

---

## Voice

- **Clear and direct.** Say exactly what is happening. No softening, no hedging.
- **No marketing language.** This is a terminal, not a landing page. Never write "seamlessly", "powerful", "easy", or anything a product manager would put on a slide.
- **Informative, not chatty.** Every line of output earns its place. Don't narrate the obvious; do name the non-obvious.

---

## Writing rules

- Use direct verbs and concrete nouns: "Installing git" not "Attempting to install the git package".
- State what happened, then what the user can do next if action is needed.
- Keep every message under 80 characters where possible.
- Use the imperative mood for instructions: "Press Enter to continue" not "Please press Enter to continue".
- Avoid internal error names and numeric codes without context: "Package not found" not "E: Unable to locate package".
- Use consistent terminology from `GLOSSARY.md`.

---

## Message patterns

### Info / progress

Print before starting a step. Tells the user what is about to happen.

```
[INFO] Installing git...
[INFO] Fetching dotfiles from companion repo...
[INFO] Setting zsh as default shell...
```

### Success

Print after a step completes successfully.

```
[SUCCESS] git installed.
[SUCCESS] Dotfiles applied.
[SUCCESS] Default shell set to zsh. Log out and back in to apply.
```

### Warning (non-fatal — script continues)

Print when skipping a step or when something is already done.

```
[WARNING] zsh already installed, skipping.
[WARNING] Config file already exists. Not overwriting. Delete it manually to reset.
[WARNING] neovim version is older than expected. Consider updating manually.
```

### Error (fatal — script exits)

Print when a step fails and the script cannot continue. Always name what failed. Always suggest what the user should check.

```
[ERROR] Package install failed. Check the output above for apt errors.
[ERROR] Unsupported OS: "linuxmint". Run the Ubuntu script directly: bash scripts/linux/ubuntu.sh
[ERROR] Another instance of PostInstallHUB is already running. Remove /tmp/postinstallhub.lock if this is wrong.
[ERROR] sudo is required. Run this script as a user with sudo privileges.
```

### Backup warning (prominent — shown before any config modification)

```
[WARNING] This script will modify your shell configuration files.
[WARNING] Back up ~/.zshrc, ~/.bashrc, and ~/.config before continuing.
[WARNING] Press Ctrl+C to cancel, or press Enter to continue.
```

---

## Terminology table

| Use | Avoid | Reason |
|---|---|---|
| `zsh` | "Z shell", "zshell" | Consistent with the binary name |
| `neovim` | "NeoVim", "Neovim", "nvim" | Consistent with the binary name; use `nvim` only when referring to the command |
| dotfiles | "dot files", "configuration files" | Standard term for hidden config files |
| default shell | "login shell", "preferred shell" | Clearer to non-expert users |
| companion repo | "dotfile repository", "the other repo" | Consistent shorthand defined in GLOSSARY.md |
| Install | "Set up", "configure", "provision" | Direct; matches what `apt install` says |
| Skip | "Ignore", "bypass", "pass" | Clear signal that something was intentionally not done |

---

## Format reference

```bash
# from lib/colors.sh + scripts/linux/common.sh
log_info    "Installing git..."          # [INFO] in BLUE
log_success "git installed."             # [SUCCESS] in GREEN
log_warning "git already installed, skipping."   # [WARNING] in YELLOW
log_error   "apt install failed. Check output above." && exit 1  # [ERROR] in RED
```
