#!/bin/bash
# Deploys THIS working tree to production (a local folder standing in for a real host).
# Like most real deploy tools, it ships whatever is on disk, not what is on origin/main.
set -euo pipefail
cd "$(dirname "$0")"
scripts/deploy-check.sh # guard
PROD="${PROD_DIR:-../production}"
node --test >/dev/null
node build.mjs
# Check again right before the copy: main may have moved during the tests and build.
scripts/deploy-check.sh # guard
mkdir -p "$PROD"
cp dist/index.html "$PROD/index.html"
git rev-parse --short HEAD > "$PROD/DEPLOYED_COMMIT"
echo "deployed $(cat "$PROD/DEPLOYED_COMMIT") to $PROD"
