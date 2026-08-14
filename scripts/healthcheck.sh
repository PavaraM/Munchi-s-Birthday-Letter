#!/usr/bin/env bash
set -euo pipefail

# healthcheck.sh — assert a URL returns 200 (and optionally expects a string).

URL="${1:-http://127.0.0.1:8080}"
EXPECT="${2:-}"

code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 "$URL" || echo 000)

if [[ "$code" != "200" ]]; then
  echo "healthcheck FAILED: $URL -> HTTP $code" >&2
  exit 1
fi

if [[ -n "$EXPECT" ]]; then
  if curl -fsS --max-time 15 "$URL" | grep -qF -- "$EXPECT"; then
    echo "healthcheck ok: $URL -> 200, content verified"
  else
    echo "healthcheck FAILED: expected content not found at $URL" >&2
    exit 1
  fi
else
  echo "healthcheck ok: $URL -> 200"
fi
