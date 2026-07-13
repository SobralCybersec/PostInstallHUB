---
title: "Privacy and Data Governance"
status: "draft"
owner: "Matheus"
reviewers:
  - "Matheus"
version: "0.1.0"
last_reviewed: "2026-07-10"
review_cycle: "quarterly"
applies_to: "0.1.0"
source_of_truth: true
related: []
supersedes: null
---

# Privacy and data governance

## Applicability

PostInstallHUB collects **no user data**. The script runs entirely on the user's local machine and produces no outbound telemetry, no analytics, and no network traffic except the package manager's standard downloads and the companion dotfile repo fetch — both of which are user-initiated and visible in the script output.

- Jurisdictions: N/A — no data collection or processing means no GDPR/LGPD/CCPA obligations.
- Controller: N/A.
- Processors: N/A.
- Privacy owner/DPO: Matheus (moot — nothing to govern).

---

## Data inventory

| Data element | Collected? | Notes |
|---|---|---|
| User identity (name, email, username) | No | The script does not know who is running it |
| System information (OS, distro, version) | Detected locally, never transmitted | Used only to choose the right package manager; discarded after the run |
| Installed package list | Never stored or transmitted | Packages are installed; no inventory is sent anywhere |
| Dotfile contents | Never read by install.sh beyond writing them to disk | Dotfile repo is Matheus-controlled; no third-party processing |
| Lock file (`/tmp/postinstallhub.lock`) | Contains only the process PID | Deleted by EXIT trap on script completion; local only |
| sudo password | Never seen by the script | Handled entirely by the OS PAM layer |
| Any other personal data | None | Privacy-by-design: the script doesn't even have a place to store data |

---

## Data flows

```
[GitHub raw HTTPS] ──install.sh──► [User's local machine only]
                                          │
                    ┌─────────────────────┤
                    ▼                     ▼
           [Package manager]    [Companion dotfile repo]
           (apt/pacman/dnf)     (GitHub raw HTTPS → ~/.config)
           local install only   local write only
```

No data flows outward from the user's machine except:
- Standard package manager traffic to distro mirrors (not PostInstallHUB's concern).
- curl to the companion dotfile repo (Matheus-controlled, public).

---

## User rights

N/A — PostInstallHUB stores no personal data, so there is nothing to access, correct, or delete. There are no user accounts, no databases, no logs retained after the terminal session ends.

---

## Rules

The following privacy-by-design rules are enforced in the codebase:

- The script must never transmit any information from the user's machine to any external endpoint beyond the standard package manager and dotfile repo fetches.
- The script must never log environment variable values that could contain personal data (home directory paths are acceptable; anything that could contain a name, email, token, or credential is not).
- The lock file (`/tmp/postinstallhub.lock`) must contain only the PID and must be deleted by the EXIT trap.
- No analytics, telemetry, or "phone home" calls — ever. If this changes in a future version, a prominent notice must be added to the README and a user opt-in must be implemented.
- The companion dotfile repo is a separate project. If it ever collects data (e.g., a setup script that registers a machine), that is governed by its own documentation, not this one.

## Third parties

| Third party | Role | Data sent | Notes |
|---|---|---|---|
| GitHub | Hosts `install.sh` and dotfile repo | Only standard HTTPS request metadata (IP, User-Agent) | GitHub's privacy policy applies; not PostInstallHUB's responsibility |
| Distro package mirrors (apt, pacman, dnf) | Serve packages | Standard package manager request metadata | Each distro's mirror policy applies; no PostInstallHUB involvement |
| No other third parties | — | — | — |

## DPIA / RIPD

N/A — no personal data is collected or processed. A DPIA is not required.
