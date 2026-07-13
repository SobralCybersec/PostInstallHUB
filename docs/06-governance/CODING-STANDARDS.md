---
title: "Coding Standards"
status: "active"
owner: "Matheus"
reviewers:
  - "Matheus"
version: "0.1.0"
last_reviewed: "2026-07-13"
review_cycle: "quarterly"
applies_to: "0.1.0"
source_of_truth: true
related: ["CONTRIBUTING.md"]
supersedes: null
---

# Coding standards

## Principles

- Correctness before cleverness.
- Idempotency is non-negotiable — every script must be safe to run more than once.
- Explicit is better than implicit — no silent fallbacks, no swallowed errors.
- Errors are always surfaced, never discarded.
- Comments explain WHY, not WHAT — the code already shows what.

---

## Shell environment

- **Bash version:** 5+ required. No `sh` compatibility required; use bash features freely.
- **Shebang:** `#!/usr/bin/env bash` on every script — never `#!/bin/bash`.
- **Safety flags:** every script must start with:
  ```bash
  set -euo pipefail
  ```
  - `-e`: exit immediately on error.
  - `-u`: treat unset variables as errors.
  - `-o pipefail`: catch errors in pipes, not just the last command.

---

## Linting and static analysis

- **Tool:** `shellcheck`
- **Minimum severity:** `shellcheck -S error <script>` must pass with zero output before any commit.
- **Syntax check:** `bash -n <script>` must also pass.
- Both checks run on every script that was modified in a commit.

---

## Variable and function naming

| Element | Convention | Example |
|---|---|---|
| Global variables | `UPPER_SNAKE_CASE` | `DOTFILES_REPO` |
| Local variables | `lower_snake_case` | `package_name` |
| Functions | `snake_case` | `install_neovim` |
| Constants (never reassigned) | `UPPER_SNAKE_CASE` | `LOCK_FILE` |

- Always declare local variables with `local` inside functions:
  ```bash
  install_git() {
      local pkg_name="git"
      log_info "Installing ${pkg_name}..."
  }
  ```
- No single-letter variable names except loop counters (`i`, `j`).
- No magic numbers — use a named constant instead.

---

## Variable expansions

Always quote variable expansions. No exceptions.

```bash
# correct
echo "${HOME}"
rm -f "${LOCK_FILE}"
cp "${src}" "${dest}"

# wrong
echo $HOME
rm -f $LOCK_FILE
```

Use `${}` braces consistently even when not strictly required — it makes boundaries clear.

---

## Functions

Every logical operation is a function. `main` only calls functions.

```bash
main() {
    check_sudo
    detect_os
    install_packages
    fetch_dotfiles
    set_default_shell
    log_success "Setup complete."
}

main "$@"
```

- Functions do one thing.
- Functions that can fail must check their return code or rely on `set -e`.
- Add a comment before any `sudo` command explaining why root is needed:
  ```bash
  # sudo required: chsh modifies /etc/passwd
  sudo chsh -s "$(command -v zsh)" "${USER}"
  ```

---

## Colors and logging

Source `lib/colors.sh` for ANSI constants. Never hard-code escape codes inline.

```bash
source "$(dirname "$0")/../lib/colors.sh"
```

Available constants: `RED`, `GREEN`, `YELLOW`, `BLUE`, `NC` (no color / reset).

Use the log functions from `scripts/linux/common.sh`:

| Function | Color | Use for |
|---|---|---|
| `log_info` | BLUE | Progress steps, "installing X..." |
| `log_success` | GREEN | Step completed successfully |
| `log_warning` | YELLOW | Non-fatal issues, things skipped |
| `log_error` | RED | Failures — always followed by exit |

```bash
log_info "Fetching dotfiles..."
log_success "Dotfiles installed."
log_warning "git already installed, skipping."
log_error "Package manager not found. Exiting." && exit 1
```

---

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | General failure |
| `2` | Unsupported OS or distro |
| `3` | Lock file conflict (another instance running) |
| `4` | Missing sudo / insufficient permissions |

Always exit with the correct code. Never `exit 0` on failure.

---

## Idempotency

Every install function must check whether the thing is already installed before installing it:

```bash
install_zsh() {
    if command -v zsh &>/dev/null; then
        log_warning "zsh already installed, skipping."
        return 0
    fi
    log_info "Installing zsh..."
    sudo apt-get install -y zsh
    log_success "zsh installed."
}
```

Same for configuration steps: check the current state, only change it if needed.

---

## Prohibited patterns

- Catching and ignoring errors (`command || true` is allowed only when the failure is truly harmless and a comment explains why).
- Secrets, tokens, or passwords in any script.
- Hardcoded absolute paths that differ across users (use `$HOME`, not `/home/matheus`).
- Disabling `set -e` or `set -u` without a clearly scoped restore.
- Unpinned `curl | bash` of third-party scripts without an explicit comment acknowledging the trust decision.
- Global mutable state in functions — use return values or `local` variables.

---

## Testing

- New functions go in `tests/test_<distro>.sh` before being merged into the main scripts.
- Minimum check: a function that calls the function under test and verifies the expected outcome.
- Run `bash -n tests/test_<distro>.sh` to confirm the test file itself is valid syntax.
- See `CONTRIBUTING.md` for Docker-based smoke test instructions.
