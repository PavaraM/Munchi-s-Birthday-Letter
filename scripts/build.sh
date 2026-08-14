#!/usr/bin/env bash
set -euo pipefail

# build.sh — turn the single-file site into an optimized dist/ bundle.
# Conservative by design: whitespace/comment stripping only. The JS and CSS
# game logic is never rewritten, so the letter keeps behaving exactly as tuned.
#
#   MINIFY=1 scripts/build.sh   -> additionally run html-minifier-terser
#   SRC=foo.html scripts/build.sh -> build from a custom source path

SRC="${SRC:-index.html}"
DIST_DIR="${DIST_DIR:-dist}"

if [[ ! -f "$SRC" ]]; then
  echo "ERROR: source file '$SRC' not found" >&2
  exit 1
fi

mkdir -p "$DIST_DIR"

echo ">> copying $SRC -> $DIST_DIR/index.html"
cp "$SRC" "$DIST_DIR/index.html"

if [[ "${MINIFY:-0}" == "1" ]]; then
  if [[ -x "node_modules/.bin/html-minifier-terser" ]]; then
    echo ">> minifying (html-minifier-terser, whitespace + comments only)"
    node_modules/.bin/html-minifier-terser \
      --collapse-whitespace \
      --remove-comments \
      --remove-redundant-attributes \
      --collapse-boolean-attributes \
      -o "$DIST_DIR/index.html" "$SRC"
  else
    echo "!! html-minifier-terser not installed, skipping minification" >&2
  fi
fi

echo ">> precompressing"
gzip -9 -k -f "$DIST_DIR/index.html"
if command -v brotli >/dev/null 2>&1; then
  brotli -f -q 11 "$DIST_DIR/index.html"
else
  echo "!! brotli not installed, skipping .br variant" >&2
fi

echo ">> done"
ls -lh "$DIST_DIR"
