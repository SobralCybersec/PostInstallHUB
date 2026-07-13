---
title: "Rollback Plan"
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

# Rollback plan

> **Context:** PostInstallHUB is a local shell script, not a running service.
> "Rollback" has two distinct meanings here:
>
> 1. **Version rollback** — a bad release was tagged; users should use a previous version.
> 2. **OS change rollback** — a script ran and modified the user's system; the changes need to be undone.

---

## 1. Version rollback (bad release was tagged)

### Triggers

- A regression is reported against a specific version.
- A script causes data loss or breaks a user's environment.
- A security issue is found in a released version.

### Steps

1. **Do not delete or force-push tags.** GitHub Release tags are immutable by convention; users who pinned to the tag already have a working install URL. Deleting the tag breaks them.
2. Identify the last known-good tag (e.g. `v0.9.0`).
3. Update `README.md` to point the stable curl URL back to the last good tag:
   ```bash
   # Was:
   curl -fsSL https://raw.githubusercontent.com/SobralCybersec/PostInstallHUB/v1.0.0/install.sh | bash
   # Now:
   curl -fsSL https://raw.githubusercontent.com/SobralCybersec/PostInstallHUB/v0.9.0/install.sh | bash
   ```
4. Push the README update to `main`.
5. Fix the bug on a branch, run all checks, then tag a new patch release (e.g. `v1.0.1`).
6. Update README to the new patch tag.
7. Add a note to the bad release's GitHub Release page warning users to upgrade.

### User self-rollback

Users can always pin to a specific version themselves:

```bash
# Pin to a known-good version
curl -fsSL https://raw.githubusercontent.com/SobralCybersec/PostInstallHUB/v0.9.0/install.sh | bash
```

---

## 2. OS change rollback (script modified the system)

PostInstallHUB scripts do not implement automatic OS-level rollback. Shell
scripts install packages and modify config files — these changes cannot be
cleanly reversed by the script itself without risk of breaking other things.

### Prevention (before running)

The script shows a **backup warning** before making any changes and runs
`lib/backup.sh` to back up:

- `~/.bashrc`, `~/.zshrc`, `~/.profile`
- `~/.config/` (relevant subdirectories)
- Any other dotfiles the script will touch

The user must acknowledge the warning before the script proceeds.

### If something went wrong after running

1. **Restore from the backup** created by `lib/backup.sh`:
   ```bash
   # Example — restore zshrc from backup
   cp ~/.postinstallhub_backup/zshrc ~/.zshrc
   ```
2. If packages were installed and are causing issues, uninstall them manually
   using the distro's package manager (`apt remove`, `pacman -Rs`, `dnf remove`).
3. If the backup was not taken (e.g. user skipped the warning): restore from
   a system backup (Timeshift, Btrfs snapshot, VM snapshot) or reinstall the OS.

### Responsibility note

Scripts modify the user's live machine. The user is responsible for having
an OS-level backup before running any post-install script. The backup warning
in `install.sh` makes this explicit.

---

## Sections not applicable

| Concept | Status |
|---|---|
| Automated rollback on error rate | N/A — no service |
| Blue/green or canary swap | N/A |
| Database migration rollback | N/A — no database |
| Feature flag disable | N/A — no feature flags |
| Queue/job drain on rollback | N/A |
| SLO burn rate triggers | N/A |
