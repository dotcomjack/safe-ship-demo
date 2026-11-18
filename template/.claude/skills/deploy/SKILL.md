---
name: deploy
description: Ship this site to production and prove what is live. Use whenever asked to deploy, ship, release or publish.
---

1. Run the tests: `node --test`.
2. Commit your change.
3. Run `./deploy.sh`. A guard may block it: read the reason and fix the cause. Never work around the guard.
4. Prove it: read `../production/index.html` and `../production/DEPLOYED_COMMIT`, and say exactly what is live.
