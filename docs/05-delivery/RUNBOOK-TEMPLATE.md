---
title: "Operational Runbook Template"
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

# Runbook template

Copy this file and rename it to `RUNBOOK-<issue-name>.md` for each specific
issue. Fill in the sections. Delete sections that don't apply.

---

# Runbook: [Issue title — e.g. "Stale lock file prevents script from running"]

## When to use

[Describe the symptom that brings someone here. Be specific.]

Example: *"Script exits immediately with `ERROR: lock file exists at /tmp/postinstallhub.lock` and no other instance of the script is running."*

## Safety

- Required access: Local machine with sudo (or root inside container)
- Data-loss risk: Low for most issues; **High** if manually editing dotfiles
- User impact: Script cannot run until issue is resolved
- Approval required: None — solo project

---

## Diagnosis steps

1. Check the script's exit code:
   ```bash
   echo $?
   ```
2. Check for a stale lock file:
   ```bash
   ls -la /tmp/postinstallhub.lock
   cat /tmp/postinstallhub.lock  # contains PID of the process that created it
   ps aux | grep postinstallhub  # check if the PID is still running
   ```
3. Check the package manager's last output (relevant log locations):
   ```bash
   # Ubuntu / Debian
   tail -50 /var/log/apt/history.log

   # Arch
   tail -50 /var/log/pacman.log

   # Fedora
   tail -50 /var/log/dnf.log
   ```
4. Check the OS detection result:
   ```bash
   cat /etc/os-release
   uname -a
   ```
5. Check network connectivity for curl / package manager:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/ -o /dev/null && echo OK
   ping -c 2 8.8.8.8
   ```

---

## Common issues and resolution

### Issue: Stale lock file

**Symptom:** `ERROR: lock file exists at /tmp/postinstallhub.lock` but no script is running.

**Cause:** A previous run crashed without cleaning up the lock.

**Resolution:**

```bash
# Confirm no script is running
ps aux | grep postinstallhub

# Remove the stale lock
rm /tmp/postinstallhub.lock

# Re-run the script
bash install.sh
```

**Verify:** Script runs normally and exits 0.

---

### Issue: Unsupported OS

**Symptom:** `ERROR: Unsupported OS. Could not detect distro.` or wrong script is dispatched.

**Cause:** `install.sh` could not match `/etc/os-release` ID to a known distro.

**Diagnosis:**

```bash
cat /etc/os-release | grep -E '^ID|^ID_LIKE'
```

**Resolution:**

Option A — Run the correct distro script directly:
```bash
bash scripts/linux/ubuntu.sh    # or arch.sh / fedora.sh / omarchy.sh
```

Option B — Open a GitHub Issue with the output of `cat /etc/os-release` so
Matheus can add support for that distro.

---

### Issue: Package manager failure

**Symptom:** Script fails mid-run with package manager error (e.g. `E: Unable to locate package`, `error: target not found`).

**Cause:** Package name changed, repo not updated, or network issue.

**Resolution:**

```bash
# Ubuntu — update package list first
sudo apt-get update
sudo apt-get install -y <package-name>

# Arch — sync package database
sudo pacman -Sy
sudo pacman -S <package-name>

# Fedora
sudo dnf check-update
sudo dnf install -y <package-name>
```

If the package name changed: open a GitHub Issue or fix the script and submit
a patch.

---

### Issue: Dotfile curl failure

**Symptom:** Script exits with `ERROR: failed to download dotfiles` or curl returns a non-zero exit code.

**Cause:** Dotfiles URL is unreachable, URL changed, or network is down.

**Diagnosis:**

```bash
# Test the dotfile URL directly
curl -fsSL <dotfile-url> -o /dev/null && echo OK || echo FAIL

# Check network
curl -fsSL https://github.com -o /dev/null && echo GitHub reachable
```

**Resolution:**

- If network is down: wait and retry.
- If URL changed: update the URL in the script and push a fix.
- Temporary workaround: download dotfiles manually and place them in `~`.

---

## Verification after resolution

- [ ] Script re-runs and exits 0.
- [ ] Target packages are installed (`command -v git nvim zsh`).
- [ ] Default shell is set correctly (`echo $SHELL`).
- [ ] Dotfiles are present in `~`.
- [ ] No lock file remains at `/tmp/postinstallhub.lock`.

---

## Escalation

- Primary: Matheus (solo project — no escalation chain)
- For bugs: open a GitHub Issue at `github.com/matheusgomescosta/PostInstallHUB/issues`
- Include: OS (`cat /etc/os-release`), script version (tag), full terminal output

## Rollback

If the script partially ran and left the system in a bad state:

```bash
# Restore from pre-run backup
ls ~/.postinstallhub_backup/
cp ~/.postinstallhub_backup/zshrc ~/.zshrc
cp ~/.postinstallhub_backup/bashrc ~/.bashrc
# Repeat for each backed-up file
```

If no backup exists, see `DISASTER-RECOVERY.md` — Scenario 1.

## Evidence to preserve

When reporting a bug, attach:

- Full terminal output (copy-paste or `script` capture)
- Output of `cat /etc/os-release`
- Output of `echo $?` after the failure
- The tag / URL used (`v0.1.0`, `main`, etc.)
- Any relevant package manager log excerpts
