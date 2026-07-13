# Standards and references

Standards and documentation referenced when building PostInstallHUB.

## Applicable to this project

| Standard | How it applies |
|---|---|
| **OWASP ASVS** (partial) | curl-pipe-to-bash security controls; no credential logging |
| **NIST SSDF** (partial) | Secure coding practices for shell scripts; supply chain awareness |
| **SLSA** (aspirational) | GitHub-hosted source with versioned releases; no build pipeline yet |

## Not applicable to this project

| Standard | Reason N/A |
|---|---|
| **OpenAPI Specification** | No HTTP API |
| **AsyncAPI Specification** | No message broker or event stream |
| **JSON Schema** | No structured data contracts |
| **C4 Model** | Overkill for a flat script collection |
| **arc42** | Overkill for a flat script collection |
| **WCAG 2.2** | No web or GUI interface |
| **Design Tokens Community Group** | No design system |
| **OpenTelemetry** | No distributed tracing; terminal output + exit codes are sufficient |
| **SBOM** | No build pipeline producing a software bill of materials |

## Shell-specific references

- [ShellCheck](https://www.shellcheck.net/) — static analysis for bash/sh scripts
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [Bash Reference Manual](https://www.gnu.org/software/bash/manual/bash.html)
- [BATS — Bash Automated Testing System](https://github.com/bats-core/bats-core)

---

Project-specific legal, regulatory, and industry requirements must be tracked
separately. See `docs/06-governance/RISK-REGISTER.md`.
