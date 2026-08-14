# 🎂 Munchi's Birthday Letter

A single-file, dependency-free birthday experience with a full **zero-cost DevOps stack** running on Oracle Cloud's Always Free tier.

> The letter is signed *— Chooti Kuku*. It was built as a one-off gift, then wrapped in a complete CI/CD + IaC + monitoring platform. The site itself (`index.html`) is treated as a sacred artifact — the pipeline builds *around* it, never modifies it.

## Architecture

```mermaid
flowchart LR
    subgraph GitHub
        CI[CI: lint + secret-scan<br/>build + trivy + hadolint]
        DEPLOY[Deploy: build image<br/>SSH -> compose up]
        LH[Lighthouse CI<br/>weekly audit]
    end

    GHCR[(GHCR<br/>public image)]

    subgraph OCI \[Always Free\]
        SL[Security list<br/>22/80/443 only]
        VM[VM.Standard.A1.Flex<br/>4 OCPU / 24 GB RAM<br/>Oracle Linux 8]
        CADDY[Caddy<br/>auto-HTTPS + headers]
        KUMA[Uptime Kuma<br/>internal only]
    end

    DNS[DuckDNS<br/>munchi.duckdns.org]

    CI -->|push| GHCR
    DEPLOY -->|push| GHCR
    GHCR -->|pull| VM
    DEPLOY -->|SSH| VM
    VM --> CADDY
    VM --> KUMA
    CADDY --> DNS
```

**Flow:** push to `main` → CI lints/tests/scans/pushes the image → Deploy pushes a new tagged image and re-runs `docker compose up` over SSH with healthcheck + auto-rollback. Caddy terminates TLS via Let's Encrypt and serves the precompressed site. Uptime Kuma (cloud-blocked from the internet) and Lighthouse watch it from inside.

## Repo layout

```
.
├── index.html                 # the letter — functionally untouched
├── Makefile                   # one-command dev/DX entrypoint
├── scripts/                   # build, smoke-test, deploy, rollback, healthcheck
├── Dockerfile                 # multi-stage: minify + precompress -> Caddy
├── docker/Caddyfile           # TLS, security headers, CSP, gzip/brotli
├── docker-compose.yml         # app + optional Uptime Kuma (profile: monitoring)
├── .github/
│   ├── workflows/ci.yml       # lint, gitleaks, build+test, hadolint, trivy, GHCR push
│   ├── workflows/deploy.yml   # SSH deploy with healthcheck + auto-rollback
│   ├── workflows/lighthouse.yml # weekly Lighthouse audits
│   └── dependabot.yml         # npm, Docker, GitHub Actions updates
└── infra/
    ├── terraform/             # OCI: compartment, VCN, security list, A1 instance
    └── ansible/               # bootstrap: Docker, UFW, fail2ban, auto-updates
```

## Cost: $0/month

| Service | Purpose | Cost |
|---------|---------|------|
| GitHub Actions | CI/CD, audits | free (public repo) |
| GHCR | container registry | free (public) |
| Oracle Cloud **Always Free** A1 | 4 OCPU / 24 GB VM | $0 |
| DuckDNS | free dynamic DNS | $0 |
| Let's Encrypt | TLS certs | $0 |

## Prerequisites

- Docker (BuildKit), Docker Compose, Node.js ≥ 22, GNU Make
- `terraform` + `ansible` (only needed to provision the VM)
- Oracle Cloud account with the **home region** set (A1 is free in home region only)
- DuckDNS account (for the production domain)

## Local development

```bash
make setup      # install dev dependencies
make lint       # validate index.html
make build      # minify + gzip/brotli into dist/
make test       # build + smoke-test the bundle
make serve      # http://localhost:8080

make docker-build   # build the production image
make docker-run     # run it locally  (http://localhost:8080)
make docker-stop
```

`SITE_DOMAIN=localhost` (the default) makes Caddy serve plain HTTP on `:80`;
set it to your real domain and Caddy provisions HTTPS automatically.

## Deployment pipeline

1. **CI** (`ci.yml`) — on push/PR: `html-validate`, gitleaks secret scan, build + smoke test, hadolint, then a BuildKit build pushed to GHCR tagged `latest`, `sha-<sha>`, and `dev`; Trivy scans the image (HIGH/CRITICAL gating) with SARIF upload.
2. **Deploy** (`deploy.yml`) — on push to `main`: builds/pushes a `sha-<sha>` tag, then `scripts/deploy.sh` SSHes to the VM, tags the running image as `app:prev`, pulls + force-recreates the `app` container, polls the healthcheck, and **auto-rolls-back** if it never comes up.
3. **Rollback** — `make rollback` (or `scripts/rollback.sh`) restores `app:prev`.

### GitHub Secrets to set

| Secret | Value |
|--------|-------|
| `VM_HOST` | `munchi.duckdns.org` |
| `VM_USER` | `opc` |
| `VM_SSH_PORT` | `22` |
| `VM_SSH_KEY` | the private key matching the public key Terraform injects |

The GHCR package must be public (one-time) so the VM can pull without a token:

```bash
gh api --method PATCH /user/packages/container/munchi-birthday \
  -f visibility=public
```

## Provisioning the VM (IaC)

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars   # fill in tenancy_ocid, region, ssh_public_key
terraform init && terraform apply              # compartment, VCN, security list, A1 instance

cd ../ansible
ansible-playbook playbooks/bootstrap.yml        # Docker, UFW, fail2ban, auto-updates, first deploy
```

`bootstrap.yml` is idempotent — safe to re-run. It installs Docker, UFW (allow 22/80/443 only), fail2ban for sshd, `dnf-automatic` security updates, hardens sshd (key-only, root disabled), and does the initial deploy of the container.

## Security

See [SECURITY.md](./SECURITY.md) for the full control map. Highlights: Caddy auto-HTTPS + HSTS, a strict CSP, no-storage/non-root read-only container, cloud security list + UFW host firewall, fail2ban, gitleaks + Trivy + Hadolint in CI, Dependabot, and secrets that live only in GitHub Secrets / `.env` on the VM.

## Monitoring

- **Uptime Kuma** runs on the VM, internet-blocked; reach it via SSH tunnel:
  `ssh -L 3001:localhost:3001 opc@munchi.duckdns.org` then open `http://localhost:3001`. Bring it up with `docker compose --profile monitoring up -d`.
- **Lighthouse CI** audits performance/accessibility/SEO weekly and on demand (`.github/workflows/lighthouse.yml`, assertions in `.lighthouserc.json`).

## Operations

See [docs/RUNBOOK.md](./docs/RUNBOOK.md) for day-2 ops: deploy, rollback, logs, DNS updates, cert renewal, and failure scenarios.

## Changelog

See [CHANGELOG.md](./CHANGELOG.md).

## License

© Pavara Mirihagalla. All rights reserved.
