# Security

This document describes the security posture of the project and how to report issues.

## Reporting a Vulnerability

This is a personal project. If you find a security issue, please open a
[GitHub issue](https://github.com/PavaraM/Munchi-s-Birthday-Letter/issues)
(preferably private) or reach out directly. Do **not** open a public issue for
active vulnerabilities.

## Security measures in place

| Layer | Control |
|-------|---------|
| TLS | Automatic Let's Encrypt certificates via Caddy (auto-renewal, HTTP→HTTPS) |
| Headers | `Content-Security-Policy`, `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, HSTS |
| Container | Non-root runtime user, pinned base image digests, read-only rootfs, Trivy + Hadolint gating in CI |
| Host | UFW (22/80/443 only), fail2ban on sshd, `unattended-upgrades`, key-only SSH (root login disabled) |
| Secrets | Never committed; `.env.example` only; `gitleaks` secret-scan in CI; GitHub Secrets / Ansible Vault |
| Supply chain | Dependabot for base image + GitHub Actions + npm dev-deps; GHCR image pushed with build provenance |

## Configuration-at-a-glance

- `Dockerfile` — multi-stage build, pinned digests
- `docker/Caddyfile` — TLS + headers + caching
- `infra/ansible/playbooks/bootstrap.yml` — host hardening
- `.github/workflows/ci.yml` — gitleaks, trivy, hadolint gates

## TLS / DNS

- DuckDNS subdomain `munchi.duckdns.org` → VM public IP.
- Caddy requests Let's Encrypt certificates automatically and renews them.
  Certs live in the `caddy_data` volume (non-root Caddy, volume owned by uid 1000).
- HTTP is redirected to HTTPS by Caddy's automatic public-site handling.
- If the VM IP changes, update DuckDNS; Caddy re-challenges on the next restart.

## Secret hygiene

- Secrets are **never** committed: `.env*` is gitignored and only `.env.example`
  ships. The VM's real `.env` is written by Ansible with mode `0600`.
- CI reads deployment secrets from GitHub Actions Secrets (`VM_HOST`, `VM_USER`,
  `VM_SSH_PORT`, `VM_SSH_KEY`). `VM_SSH_KEY` is the private key whose public half
  Terraform injects into the instance metadata.
- `gitleaks` scans every push/PR in CI; the OCI API private key stays out of the
  repo and out of the VM entirely.
- The GHCR image is **public** (one-time `gh` PATCH) so the VM can pull without a
  token; nothing secret is baked into the image.
- `docker/Caddyfile` hides `Server`/`X-Powered-By` response headers.
