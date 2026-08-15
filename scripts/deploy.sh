#!/usr/bin/env bash
set -euo pipefail

# deploy.sh — deploy an image to the remote host over SSH. Used by CI/CD and
# locally via `make deploy`. Runs the whole deploy+healthcheck+rollback logic
# on the host so no deploy tooling is needed client-side.
#
# Required env: VM_HOST, VM_USER, APP_IMAGE
# Optional env: VM_SSH_PORT (22), VM_SSH_KEY, APP_INTERNAL_PORT (80)

: "${VM_HOST:?VM_HOST is required}"
: "${VM_USER:?VM_USER is required}"
: "${APP_IMAGE:?APP_IMAGE is required (e.g. ghcr.io/pavaram/munchi-birthday:sha-abc123)}"

SSH_PORT="${VM_SSH_PORT:-22}"
SSH_KEY="${VM_SSH_KEY:-}"
COMPOSE_FILE="/opt/munchi-birthday/docker-compose.yml"
APP_INTERNAL_PORT="${APP_INTERNAL_PORT:-80}"

ssh_args=(-p "$SSH_PORT" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=20)
[[ -n "$SSH_KEY" ]] && ssh_args+=(-i "$SSH_KEY")

echo ">> deploy $APP_IMAGE -> $VM_USER@$VM_HOST:$SSH_PORT"

ssh "${ssh_args[@]}" "$VM_USER@$VM_HOST" bash -s <<REMOTE_SCRIPT
set -euo pipefail
cd /opt/munchi-birthday

# Tag the currently-running image so rollback.sh can restore it.
if [[ -n "\$(docker ps -q --filter name=app 2>/dev/null)" ]]; then
  CUR=\$(docker inspect --format '{{.Image}}' \$(docker ps -q --filter name=app))
  docker tag "\$CUR" app:prev 2>/dev/null || true
fi

echo ">> pulling $APP_IMAGE"
APP_IMAGE="$APP_IMAGE" docker compose -f "$COMPOSE_FILE" pull app

echo ">> recreating app container"
APP_IMAGE="$APP_IMAGE" docker compose -f "$COMPOSE_FILE" up -d --no-deps --force-recreate app

echo ">> waiting for healthcheck"
for i in \$(seq 1 30); do
  if curl -fsS -o /dev/null --max-time 5 "http://127.0.0.1:$APP_INTERNAL_PORT/"; then
    echo ">> healthy after \$((i * 2))s"
    echo "\$APP_IMAGE" > .current-tag
    exit 0
  fi
  sleep 2
done

echo ">> HEALTHCHECK FAILED — rolling back to app:prev" >&2
APP_IMAGE=app:prev docker compose -f "$COMPOSE_FILE" up -d --no-deps --force-recreate app
curl -fsS -o /dev/null --max-time 10 "http://127.0.0.1:$APP_INTERNAL_PORT/" || true
exit 1
REMOTE_SCRIPT
