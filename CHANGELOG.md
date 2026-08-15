# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-08-14

### Added

- `.github/workflows/lighthouse.yml` + `.lighthouserc.json` — weekly Lighthouse
  audits of the production URL (accessibility/SEO gated at 0.9).
- README with architecture diagram, cost breakdown, and provisioning guide.
- `docs/RUNBOOK.md` — day-2 operations (deploy, rollback, logs, DNS, TLS,
  monitoring, backups, failure scenarios).
- Docker Compose `monitoring` profile for Uptime Kuma (3001 cloud-blocked).
- SECURITY.md: TLS/DNS and secret-hygiene sections.

## [0.1.0] - 2026-08-14

### Added

- Full DevOps pipeline: Git hygiene (`.gitignore`, `.gitattributes`, branch strategy)
- Local DX: `Makefile`, `scripts/` (build, smoke-test, deploy, rollback, healthcheck)
- Containerization: multi-stage `Dockerfile` (minify + precompress) with Caddy runtime
- `Caddyfile` with automatic HTTPS, security headers, gzip/brotli
- CI/CD via GitHub Actions: lint, secret-scan, build, trivy/hadolint, GHCR push, SSH deploy
- Infrastructure as Code: Terraform for OCI (compartment, VCN, security list, Always Free instance)
- Configuration management: Ansible bootstrap (Docker, firewalld, fail2ban, dnf-automatic)
- Observability: Lighthouse CI (Uptime Kuma optional — not deployed on the 1 GB Micro)
- Documentation: README, runbook, architecture

### Note

The letter itself (`index.html`) is functionally unchanged — it is only
built/minified around, never modified.
