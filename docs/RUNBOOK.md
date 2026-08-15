# Runbook

Day-2 operations for Munchi's Birthday Letter. Deploys land over SSH onto an
Oracle Linux VM at `munchi.duckdns.org` (`/opt/munchi-birthday`).

## Deploy a new release

Push to `main`. `deploy.yml` builds a `sha-<sha>` image, SSHes to the VM, and
recreates the `app` container with automatic rollback. To deploy the current
local build instead:

```bash
export VM_HOST=munchi.duckdns.org VM_USER=opc VM_SSH_PORT=22
export VM_SSH_KEY=~/.ssh/id_ed25519
export APP_IMAGE=ghcr.io/pavaram/munchi-birthday:latest
make deploy
```

## Rollback

```bash
make rollback   # restores the previous image (tagged app:prev on the VM)
```

`scripts/deploy.sh` tags the *currently running* image as `app:prev` before
recreating, so the last good image is always one command away.

## Status & logs

```bash
make status                       # docker compose ps on the VM
ssh opc@munchi.duckdns.org \
  "docker logs -f --tail 100 app" # app (Caddy) logs
ssh opc@munchi.duckdns.org \
  "docker stats --no-stream"      # resource usage
```

Caddy logs to stderr → Docker json-file (rotated at 10 MB × 3).

## DNS (DuckDNS)

The subdomain `munchi.duckdns.org` must point at the VM's public IP. If the
instance is ever recreated, update the A record at duckdns.org. Nothing else
needs touching — Caddy's certs follow the hostname, not the IP.

If the VM's IP changes while a cert is cached, Caddy retries the challenge
automatically. For a fresh start after an IP change:

```bash
ssh opc@munchi.duckdns.org "docker compose restart app"
```

## TLS

Let's Encrypt certs are managed entirely by Caddy (stored in the `caddy_data`
volume). Renewal is automatic. If a renewal ever fails, check:

```bash
ssh opc@munchi.duckdns.org "docker logs app 2>&1 | grep -i -E 'cert|tls|error'"
```

The common cause is a stale DNS record or port 80/443 not reachable from the
internet (both firewalld *and* the OCI security list must allow them).

## Monitoring

### Uptime Kuma (via SSH tunnel)

```bash
ssh -L 3001:localhost:3001 opc@munchi.duckdns.org
# open http://localhost:3001
```

Add a monitor for `https://munchi.duckdns.org/` (HTTP, 60 s, retries 3) and an
optional Heartbeat/notification channel. Port 3001 is intentionally blocked by
the OCI security list — the tunnel is the only way in.

### Lighthouse

Run manually: GitHub → Actions → *Lighthouse CI* → *Run workflow*. Results are
uploaded to temporary public storage (link in the workflow run). Assertions in
`.lighthouserc.json` gate accessibility/SEO at 0.9, warn on performance.

## Backups

The only mutable state is the `caddy_data` volume (certs). Everything else is
rebuilt from the image. To back up certs:

```bash
ssh opc@munchi.duckdns.org "docker run --rm -v munchi-birthday_caddy_data:/data alpine tar czf - -C /data ." > caddy_data.tar.gz
```

## Failure scenarios

| Symptom | Cause / fix |
|---------|-------------|
| Deploy fails, container keeps rolling back | `scripts/deploy.sh` already rolled back. Check `docker logs app`, then `make rollback`. |
| Site down | `ssh ... "docker compose -f /opt/munchi-birthday/docker-compose.yml ps"`. Container exited → `docker logs`; host OOM → A1 has 24 GB, unlikely. |
| `502` from the VM but container healthy | Check OCI security list + `firewall-cmd --list-ports` on the host (both must allow 80/443). |
| Cert errors | Stale DNS (see above) or 80/443 blocked. Restart app after fixing. |
| Uptime Kuma alerting | The Kuma container is running under the `monitoring` profile — it isn't started by default deploys. |
| Disk full | Logs rotate at 10 MB × 3. Images accumulate on re-deploy — prune: `ssh ... "docker image prune -a --filter until=720h"`. |

## Incident report template

When something breaks: what changed last (commit/tag), what the healthcheck
said, container exit code/logs, and whether rollback was attempted. Record
outages in `CHANGELOG.md` under an `### Fixed` entry.
