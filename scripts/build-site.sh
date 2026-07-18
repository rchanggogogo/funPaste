#!/usr/bin/env bash
# Build the funPaste marketing site into site-dist/.
# Usage: bash scripts/build-site.sh
#        python3 -m http.server --directory site-dist
#
# Requires Node.js (the workflow sets it up; locally use your installed node).
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v node >/dev/null 2>&1; then
  echo "error: node is required to build the site" >&2
  exit 1
fi

node scripts/build-site.mjs
