#!/usr/bin/env bash
set -euo pipefail

# rollback.sh — restore the previously-deployed image on the remote host.
# Mirrors the tag bookkeeping done in deploy.sh.

: "${VM_HOST:?VM_HOST is required}"
: "${VM_USER:?VM_USER is required}"

SSH_PORT="${VM_SSH_PORT:-22}"
SSH_KEY="${VM_SSH_KEY:-}"
COMPOSE_FILE="/opt/munchi-birthday/docker-compose.yml"

ssh_args=(-p "$SSH_PORT" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=20)
[[ -n "$SSH_KEY" ]] && ssh_args+=(-i "$SSH_KEY")

echo ">> rolling back on $VM_USER@$VM_HOST to app:prev"

ssh "${ssh_args[@]}" "$VM_USER@$VM_HOST" bash -s <<'REMOTE_SCRIPT'
set -euo pipefail
cd /opt/munchi-birthday

if [[ -z "$(docker image inspect app:prev >/dev/null 2>&1 && echo yes)" ]]; then
  echo "!! no app:prev image available on host" >&2
  exit 1
fi

APP_IMAGE=app:prev docker compose -f /opt/munchi-birthday/docker-compose.yml \
  up -d --no-deps --force-recreate app

for i in $(seq 1 30); do
  if curl -fsS -o /dev/null --max-time 5 "http://127.0.0.1:80/"; then
    echo ">> rollback healthy after $((i * 2))s"
    exit 0
  fi
  sleep 2
done
echo ">> rollback failed to become healthy" >&2
exit 1
REMOTE_SCRIPT
