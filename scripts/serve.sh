#!/usr/bin/env bash
set -euo pipefail

# serve.sh — local static server for dist/ (CI-friendly, no watcher needed).

PORT="${1:-8080}"
DIST_DIR="${DIST_DIR:-dist}"

if [[ ! -f "$DIST_DIR/index.html" ]]; then
  echo "ERROR: $DIST_DIR/index.html not found — run 'make build' first" >&2
  exit 1
fi

echo ">> serving $DIST_DIR/ at http://localhost:$PORT"
python3 -m http.server "$PORT" --directory "$DIST_DIR"
