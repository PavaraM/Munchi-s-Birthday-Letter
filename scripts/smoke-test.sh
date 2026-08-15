#!/usr/bin/env bash
set -euo pipefail

# smoke-test.sh — assert the built site is intact: serves, content present,
# external deps reachable. Runs against dist/ unless URL is given.
#
#   PORT=8080 scripts/smoke-test.sh
#   scripts/smoke-test.sh http://yourdomain.example

PORT="${PORT:-8080}"
DIST_DIR="${DIST_DIR:-dist}"

# ---- mode 1: check a running URL ----
if [[ -n "${1:-}" && "$1" == http* ]]; then
  URL="$1"
else
  URL="http://127.0.0.1:${1:-$PORT}"
  [[ -f "$DIST_DIR/index.html" ]] || {
    echo "ERROR: $DIST_DIR/index.html not found — run 'make build' first" >&2
    exit 1
  }
  python3 -m http.server "${1:-$PORT}" --directory "$DIST_DIR" >/dev/null 2>&1 &
  SERVER_PID=$!
  trap 'kill $SERVER_PID 2>/dev/null || true' EXIT
  sleep 1
fi

fail=0
check() { # check <label> <command...>
  local label="$1"; shift
  if "$@"; then
    echo "  ok: $label"
  else
    echo "  FAIL: $label" >&2
    fail=1
  fi
}

contains() { # contains <needle> <haystack-file>
  grep -qF -- "$1" "$2"
}

echo ">> smoke testing $URL"

check "HTTP 200 on /" curl -fsS -o /dev/null "$URL/"
check "content-type text/html" bash -c "curl -fsSI '$URL/' | grep -qi 'content-type: text/html'"

body_file=$(mktemp)
curl -fsS "$URL/" > "$body_file"

check "landing name present" contains "for Munchi Panchi" "$body_file"
check "letter body present"   contains "hakuna matata"  "$body_file"
check "wish words present"    contains '"may","your","year"' "$body_file"
check "countdown config"      contains "birthdayMonth: 6" "$body_file"
check "csp style tag intact"  contains "var(--hot-pink)" "$body_file"

# self-hosted fonts the site references (must be bundled and served)
for font in MrsSaintDelafield-400 CormorantGaramond-Italic-400 Quicksand-var; do
  check "font $font served" curl -fsS -o /dev/null "$URL/fonts/$font.woff2"
done
check "no external font refs" bash -c "! grep -qE 'fonts.googleapis|fonts.gstatic' '$body_file'"

rm -f "$body_file"

if [[ "$fail" == "0" ]]; then
  echo ">> smoke test passed"
else
  echo ">> smoke test FAILED" >&2
  exit 1
fi
