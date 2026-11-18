#!/bin/bash
# Sam, a teammate, fixes the price bug ($19.990 -> $19.99), adds a test, pushes and deploys.
# Usage: ./sam.sh <workspace>
set -euo pipefail
cd "$1/teammate"
git pull -q origin main
sed -i '' 's/toFixed(3)/toFixed(2)/' pricing.js
cat > pricing.test.mjs <<'T'
import test from "node:test";
import assert from "node:assert";
import { formatPrice } from "./pricing.js";

test("prices show two decimals", () => {
  assert.equal(formatPrice(1999), "$19.99");
});
T
git add pricing.js pricing.test.mjs
GIT_AUTHOR_NAME="Sam (teammate)" GIT_AUTHOR_EMAIL=sam@example.com GIT_COMMITTER_NAME="Sam (teammate)" GIT_COMMITTER_EMAIL=sam@example.com \
  git commit -q -m "Fix price showing three decimals"
git push -q origin main
PROD_DIR=../production ./deploy.sh >/dev/null
echo "[sam] pushed and deployed the price fix: production now shows \$19.99"
