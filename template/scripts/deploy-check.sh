#!/bin/bash
# The one rule: production only ever runs exactly what is on origin/main, committed and pushed.
# deploy.sh runs this first (enforcement: no command shape gets around it).
# The Claude Code hook runs it too (early warning: the agent gets the reason before it acts).
# Exit 2 = blocked, with the reason on stderr.
set -u
cd "$(dirname "$0")/.." || exit 2
export GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=10"
block() { echo "BLOCKED by deploy guard: $*" >&2; exit 2; }

git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=10 fetch -q origin 2>/dev/null \
  || block "could not reach origin, so this tree cannot be proven current. Not deploying blind."
status="$(git status --porcelain)" || block "git status failed, so this tree cannot be proven clean."

if ! git merge-base --is-ancestor origin/main HEAD; then
  {
    echo "BLOCKED by deploy guard: this tree is $(git rev-list --count HEAD..origin/main) commit(s) behind origin/main."
    git log --format='  %h %an: %s' HEAD..origin/main
    echo "Deploying now would silently revert that work in production."
    echo "Rebase onto origin/main, rerun the tests, push, then deploy again."
  } >&2
  exit 2
fi
[ -z "$status" ] || block "uncommitted changes. Commit first, so production always matches a commit."
git merge-base --is-ancestor HEAD origin/main \
  || block "$(git rev-list --count origin/main..HEAD) commit(s) not pushed. Push to origin/main first, so a teammate's next deploy cannot undo yours."
exit 0
