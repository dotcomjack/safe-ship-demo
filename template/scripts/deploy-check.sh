#!/bin/bash
# The one rule: production only ever runs exactly what is on main at the PINNED origin,
# committed and pushed. deploy.sh runs this (enforcement: every way of running deploy.sh hits it).
# The Claude Code hook runs it too (early warning: the agent gets the reason before it acts).
# The origin URL is pinned in scripts/origin.url, so changing `git remote` cannot fool it.
# Exit 2 = blocked, with the reason on stderr.
set -u
cd "$(dirname "$0")/.." || exit 2
export GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes -o ConnectTimeout=10}"
block() { echo "BLOCKED by deploy guard: $*" >&2; exit 2; }

ORIGIN="$(cat scripts/origin.url 2>/dev/null)" || block "no pinned origin (scripts/origin.url)."
[ -n "$ORIGIN" ] || block "no pinned origin (scripts/origin.url)."
git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=10 fetch -q "$ORIGIN" main 2>/dev/null \
  || block "could not reach the pinned origin, so this tree cannot be proven current. Not deploying blind."
MAIN="$(git rev-parse FETCH_HEAD 2>/dev/null)" || block "could not read main from the pinned origin."
status="$(git status --porcelain)" || block "git status failed, so this tree cannot be proven clean."

if ! git merge-base --is-ancestor "$MAIN" HEAD; then
  {
    echo "BLOCKED by deploy guard: this tree is $(git rev-list --count HEAD.."$MAIN") commit(s) behind origin/main."
    git log --format='  %h %an: %s' HEAD.."$MAIN"
    echo "Deploying now would silently revert that work in production."
    echo "Rebase onto origin/main, rerun the tests, push, then deploy again."
  } >&2
  exit 2
fi
[ -z "$status" ] || block "uncommitted changes. Commit first, so production always matches a commit."
git merge-base --is-ancestor HEAD "$MAIN" \
  || block "$(git rev-list --count "$MAIN"..HEAD) commit(s) not pushed. Push to origin/main first, so a teammate's next deploy cannot undo yours."
exit 0
