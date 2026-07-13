---
title: "Disaster Recovery"
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

# Disaster recovery

> PostInstallHUB runs locally on the user's machine. There is no distributed
> system to recover. "Disaster" scenarios are: (1) a script corrupts the
> user's OS config, (2) the GitHub repository is compromised or unavailable,
> (3) Matheus loses access to the GitHub account.

## Scope

- Shell scripts distributed via GitHub raw URLs.
- No servers, no cloud, no databases.
- Recovery is always manual — there is nothing to restart or failover.

## Recovery objectives

| Scenario | RTO | RPO | Recovery owner |
|---|---|---|---|
| Script corrupts user config | Manual (minutes to hours, depending on backup) | Last backup taken before script ran | End user |
| GitHub repo unavailable | N/A — users with local clone can work offline | N/A | GitHub / Matheus |
| GitHub account compromised | Hours (revoke access, audit, re-secure) | Last known good commit | Matheus |

---

## Scenario 1: Script corrupts OS config after running

**Symptoms:** Shell broken, missing tools, wrong default shell, mangled dotfiles.

**Recovery:**

1. Check if `lib/backup.sh` created a backup at `~/.postinstallhub_backup/`.
   ```bash
   ls ~/.postinstallhub_backup/
   ```
2. If backup exists — restore:
   ```bash
   cp ~/.postinstallhub_backup/zshrc ~/.zshrc
   cp ~/.postinstallhub_backup/bashrc ~/.bashrc
   # etc. for each backed-up file
   ```
3. If no backup — use an OS-level snapshot (Timeshift, Btrfs snapshot, VM snapshot) or reinstall the OS.
4. Report the issue on the GitHub repository so the bug is fixed in the next release.

**Prevention:** `install.sh` always shows a backup warning and runs `lib/backup.sh` before making any changes. Users should not skip this step.

---

## Scenario 2: GitHub repository unavailable

**Symptoms:** `curl` one-liner fails; raw.githubusercontent.com unreachable.

**Recovery:**

- Users who cloned the repo locally have a full copy and can run scripts directly:
  ```bash
  bash ~/PostInstallHUB/install.sh
  ```
- Users who only used the curl URL have no local copy. Nothing Matheus can do
  while GitHub is down — this is GitHub's infrastructure.
- If GitHub is permanently unavailable (extremely unlikely), Matheus would
  mirror the repo to a different host (GitLab, Codeberg, etc.) and update the
  install URL.

**No automated recovery mechanism exists.** GitHub downtime is rare and
self-resolving.

---

## Scenario 3: GitHub account compromised

**Symptoms:** Unauthorized commits, releases, or repo deletions detected.

**Immediate steps:**

1. Log in to GitHub and revoke all active sessions.
2. Change the GitHub account password immediately.
3. Rotate SSH keys: remove all authorized keys, add only the current trusted key.
4. Disable and re-enable 2FA.
5. Audit recent commits: `git log --oneline -20` — check for unauthorized changes.
6. If a malicious script was pushed and released:
   - Edit the GitHub Release to add a warning: "DO NOT USE — this release was compromised."
   - Push a clean commit reverting any unauthorized changes.
   - Tag a new patch release from the clean state.
   - Update README.
7. If the repo was deleted: restore from local clone — `git push --mirror` to a new repo.

---

## Communications

- No public status page exists (solo project).
- If a bad release is published and users are affected: update the GitHub Release
  notes with a warning, open a GitHub Issue explaining the situation, and tag a
  fix release as fast as possible.
- Matheus is the sole incident commander and decision-maker.

---

## Sections not applicable

| DR concept | Status |
|---|---|
| Region failover | N/A — no infrastructure |
| Database restore | N/A — no database |
| RTO/RPO for a running service | N/A — scripts run once and exit |
| Tabletop / failover drills | N/A — solo project |
| Regulatory notification | N/A |
| Incident commander rotation | N/A — Matheus only |
| Internal incident channel | N/A |
