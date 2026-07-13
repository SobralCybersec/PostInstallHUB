---
title: "Contributing Guide"
status: "active"
owner: "Matheus"
reviewers:
  - "Matheus"
version: "0.1.0"
last_reviewed: "2026-07-13"
review_cycle: "quarterly"
applies_to: "0.1.0"
source_of_truth: true
related: ["CODING-STANDARDS.md", "REPOSITORY-STRUCTURE.md"]
supersedes: null
---

# Contributing

PostInstallHUB is a personal project maintained by Matheus. External contributions are not accepted at this time. If you find a bug, please open a GitHub Issue. If you want a similar tool for your own setup, feel free to fork the repository.

---

## For Matheus: working on this project

### Before changing anything

1. Read `PROJECT-INDEX.md`, `CONTEXT.md`, and the spec for the area you are touching.
2. Link the work to a requirement, defect, or risk from the register.
3. Make sure the change is idempotent — running the script twice must leave the system in the same state as running it once.

### Adding support for a new distro

1. Create `scripts/linux/<distro>.sh` using `scripts/linux/ubuntu.sh` as the template.
2. Source `scripts/linux/common.sh` at the top.
3. Implement at minimum: package manager detection, package install, zsh-as-default, dotfile fetch.
4. Add OS detection routing in `install.sh` (the `detect_os` case block).
5. Add a test file at `tests/test_<distro>.sh`.
6. Document the distro in `README.md` under Supported Platforms.

### Adding a new tool or package to an existing distro

1. Find the correct `scripts/linux/<distro>.sh`.
2. Add an `install_<toolname>` function following the function pattern in that file.
3. Call the function from `main` in the correct order (dependencies first).
4. Test idempotency manually: run once on a clean VM, run again, confirm no errors and no duplicate actions.
5. Run `bash -n scripts/linux/<distro>.sh` and `shellcheck scripts/linux/<distro>.sh` — both must pass clean.

### Making any other change

1. One logical change per commit.
2. Run the full local verification suite before committing:
   ```bash
   bash -n install.sh && shellcheck install.sh
   bash -n scripts/linux/common.sh && shellcheck scripts/linux/common.sh
   bash -n scripts/linux/ubuntu.sh && shellcheck scripts/linux/ubuntu.sh
   bash -n scripts/linux/arch.sh && shellcheck scripts/linux/arch.sh
   bash -n scripts/linux/fedora.sh && shellcheck scripts/linux/fedora.sh
   bash -n scripts/linux/omarchy.sh && shellcheck scripts/linux/omarchy.sh
   ```
3. If you changed behavior, update the relevant spec in `docs/`.
4. Write a commit message that explains why, not just what: `"Fix idempotency bug in zsh default — chsh was called even when zsh was already default"` not `"fix chsh"`.

### Testing changes

- **Syntax check:** `bash -n <script>` — catches parse errors without executing.
- **Static analysis:** `shellcheck -S error <script>` — catches common bugs and unsafe patterns.
- **Manual smoke test:** run the script in a fresh Docker container or VM for the target distro. Do not test destructive changes on your own machine directly.
- **Idempotency test:** run the script twice on the same container; the second run must produce no errors and no visible changes.
- Docker images for quick testing:
  - Ubuntu: `docker run --rm -it ubuntu:22.04 bash`
  - Arch: `docker run --rm -it archlinux bash`
  - Fedora: `docker run --rm -it fedora bash`

### Coding standards

See `CODING-STANDARDS.md` for the full style guide.
