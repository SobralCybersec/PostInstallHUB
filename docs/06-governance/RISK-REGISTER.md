---
title: "Risk Register"
status: "active"
owner: "Matheus"
reviewers:
  - "Matheus"
version: "0.1.0"
last_reviewed: "2026-07-13"
review_cycle: "quarterly"
applies_to: "0.1.0"
source_of_truth: true
related: ["SUPPLY-CHAIN.md", "TECH-DEBT.md"]
supersedes: null
---

# Risk register

## Scoring

- Probability: 1–5 (1 = very unlikely, 5 = likely)
- Impact: 1–5 (1 = negligible, 5 = catastrophic)
- Exposure: probability × impact
- Status: open | mitigating | accepted | closed

---

## Register

| ID | Risk | Category | Probability | Impact | Exposure | Mitigation | Trigger | Owner | Status |
|---|---|---|---:|---:|---:|---|---|---|---|
| RSK-001 | Script breaks existing dotfiles or shell config on user machine | OPERATIONS | 2 | 4 | 8 | Backup warning displayed before any config modification; scripts are idempotent; README documents manual restore steps | User reports config overwritten | Matheus | mitigating |
| RSK-002 | GitHub account compromised; malicious code pushed to main | SECURITY | 1 | 5 | 5 | 2FA enabled on GitHub account; solo repo (no collaborators to phish); users are encouraged in README to pin to a release tag and audit the script before running | Unauthorized commit detected | Matheus | mitigating |
| RSK-003 | curl-pipe-to-bash install intercepted via MITM | SECURITY | 1 | 5 | 5 | HTTPS only (GitHub enforces TLS); documented in README as a known limitation of the curl-pipe pattern; users who need stronger guarantees are directed to clone and inspect before running | N/A — passive risk | Matheus | accepted |
| RSK-004 | Distro package manager API or package name changes break install commands | TECH | 2 | 3 | 6 | Test scripts against current distro releases before tagging a release; versioned releases let users stay on an older working version while Matheus fixes the issue | Install step fails with package-not-found error | Matheus | open |
| RSK-005 | OS detection fails for an edge-case OS version or derivative | TECH | 3 | 2 | 6 | `detect_os` exits with code 2 and a clear message naming the detected OS string; user can run the appropriate distro script directly as a workaround | User reports "unsupported OS" on a supported distro | Matheus | open |

---

## Accepted risks

### RSK-003 — curl-pipe-to-bash MITM

- **Rationale:** HTTPS provides sufficient protection for a personal tooling project with no sensitive data. Subresource integrity is not applicable to bash scripts served from GitHub. The curl-pipe-to-bash pattern is an explicit, documented design choice consistent with how most similar tools (Homebrew, Oh My Zsh, etc.) distribute themselves.
- **Approving authority:** Matheus
- **Review date:** 2027-01-01
- **Monitoring signal:** Any GitHub security advisory for the repository.
- **Fallback plan:** If MITM is a real concern, users can clone the repo over SSH and run `install.sh` directly — this is documented in README.
