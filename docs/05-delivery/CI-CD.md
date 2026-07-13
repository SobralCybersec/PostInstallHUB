---
title: "CI/CD Specification"
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

# CI/CD specification

> **Note:** PostInstallHUB has no CI/CD pipeline. It is a solo project with
> manual testing before each release. This document records the current manual
> process and describes what a future pipeline could look like.

## Current state

No automated pipeline exists. All checks are run manually by Matheus before
tagging a release.

### Manual pre-release steps (run locally)

```bash
# 1. Lint every shell script
shellcheck scripts/**/*.sh install.sh

# 2. Syntax check
for f in scripts/**/*.sh install.sh; do bash -n "$f" && echo "OK: $f"; done

# 3. Docker integration tests — one container per distro
bash tests/test_ubuntu.sh
bash tests/test_arch.sh
bash tests/test_fedora.sh
bash tests/test_omarchy.sh

# 4. Windows — run manually in a Windows 10/11 VM
#    Open CMD: setup.cmd
#    Open PowerShell: .\setup.ps1
```

### Release process (manual)

1. All tests green locally.
2. Update `CHANGELOG.md`.
3. `git tag -a vX.Y.Z -m "Release vX.Y.Z"` + `git push origin vX.Y.Z`.
4. Create GitHub Release via the web UI.
5. Verify curl one-liner on a fresh Docker container.

---

## Future: GitHub Actions (not yet implemented)

If the project grows or gains contributors, a GitHub Actions pipeline would
provide automatic feedback on every push. Documented here for reference.

### Proposed pipeline stages

```yaml
# .github/workflows/ci.yml (example — not active)
on: [push, pull_request]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: sudo apt-get install -y shellcheck
      - run: shellcheck scripts/**/*.sh install.sh

  test-ubuntu:
    runs-on: ubuntu-latest
    container: ubuntu:22.04
    steps:
      - uses: actions/checkout@v4
      - run: bash tests/test_ubuntu.sh

  test-arch:
    runs-on: ubuntu-latest
    container: archlinux:latest
    steps:
      - uses: actions/checkout@v4
      - run: bash tests/test_arch.sh

  test-fedora:
    runs-on: ubuntu-latest
    container: fedora:latest
    steps:
      - uses: actions/checkout@v4
      - run: bash tests/test_fedora.sh
```

When/if to implement: when a second contributor joins, or when manual testing
becomes a bottleneck before releases.

---

## Sections not applicable to this project

| Pipeline concept | Status |
|---|---|
| Artifact registry / SBOM / signing | N/A |
| Staging deployment | N/A |
| Canary / blue-green | N/A |
| E2E browser tests | N/A |
| Secret scanning (beyond shellcheck) | N/A — no secrets in scripts |
| Runner security policy | N/A — no runners yet |
| Database migration ordering | N/A — no database |
| Automatic rollback on error rate | N/A — no service |
