---
title: "Infrastructure Specification"
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

# Infrastructure specification

> **PostInstallHUB has no infrastructure.**
>
> It is a set of shell scripts that run on the user's local machine. There are
> no servers, no cloud accounts, no containers in production, no databases, no
> object storage, no DNS records owned by this project, and no network
> services to operate.
>
> The only external dependency is **GitHub** — which hosts the repository and
> serves the raw script files for the curl one-liner. GitHub's infrastructure
> is managed by GitHub, not by Matheus.

## What exists

| Thing | Who manages it | Notes |
|---|---|---|
| GitHub repository | GitHub (hosted); Matheus (content) | Source of truth for all scripts |
| GitHub Releases | Matheus | Tagged versions, changelog body |
| Raw file CDN (raw.githubusercontent.com) | GitHub | Serves the curl install URL |
| Developer machine | Matheus | Where scripts are written and tested |
| Docker containers (test-time only) | Matheus, local | Spun up per test run, discarded after |
| Windows VM (test-time only) | Matheus, local | Clean snapshot per test run |

## What does not exist

| Infrastructure concept | Status |
|---|---|
| Cloud provider account (AWS / GCP / Azure) | N/A |
| VMs or servers in production | N/A |
| Container registry | N/A |
| Kubernetes / Helm | N/A |
| Load balancer | N/A |
| Database | N/A |
| Object storage | N/A |
| Private network / VPC / subnets | N/A |
| DNS records owned by this project | N/A |
| TLS certificates | N/A |
| Infrastructure as code (Terraform, Pulumi, etc.) | N/A |
| Monitoring / alerting / on-call | N/A |
| Cost controls / budget alerts | N/A |
| Drift detection | N/A |

## Security notes

- No secrets are stored in the repository.
- No API keys or tokens are used by the scripts.
- GitHub account security (2FA, SSH key) is the only security surface Matheus controls.
- If the GitHub account is compromised, see `DISASTER-RECOVERY.md`.
