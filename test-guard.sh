#!/bin/bash
# Deterministic checks on the guard, no model involved. Exit 0 only if every case holds.
# Two layers: deploy.sh enforces (any command shape), the hook warns early (Claude reads why).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
W="$("$ROOT/setup.sh")"
"$ROOT/sam.sh" "$W" >/dev/null 2>&1      # Sam ships, so app/ is now one commit behind
APP="$W/app"; PROD="$W/production"
HOOK="$APP/.claude/hooks/deploy-guard.sh"
fail=0; n=0
hook() { python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' "$1" \
  | CLAUDE_PROJECT_DIR="$APP" "$HOOK" 2>"$W/err"; echo $?; }
expect() { n=$((n+1)); if [ "$2" = "$3" ]; then echo "PASS $1"; else echo "FAIL $1 (exit $3, want $2): $(head -1 "$W/err")"; fail=1; fi; }

echo "== hook, stale tree: every shape that could run deploy.sh is blocked"
while IFS= read -r c; do expect "blocks: $c" 2 "$(hook "$c")"; done <<'EOF'
./deploy.sh
PROD_DIR=../production ./deploy.sh
node --test && ./deploy.sh
bash deploy.sh
bash -c "./deploy.sh"
bash -x ./deploy.sh
sh -c './deploy.sh'
env FOO=1 ./deploy.sh
nohup ./deploy.sh
time bash deploy.sh
(./deploy.sh)
echo $(./deploy.sh)
echo `./deploy.sh`
{ ./deploy.sh; }
if true; then ./deploy.sh; fi
sleep 1 & ./deploy.sh
./deploy.sh&
./deploy.sh>log
2>&1 ./deploy.sh
source deploy.sh
. ./deploy.sh
bash < deploy.sh
cat deploy.sh | bash
EOF
grep -q "1 commit(s) behind origin/main" "$W/err" && grep -q "Sam (teammate)" "$W/err"
expect "block message names the missing commit and its author" 0 $?

echo "== hook: reads and data are never blocked, even on a stale tree"
while IFS= read -r c; do expect "allows: $c" 0 "$(hook "$c")"; done <<'EOF'
git status
cat deploy.sh
grep PROD deploy.sh
git diff deploy.sh
git commit -m "prep; deploy.sh next"
EOF
expect "allows: heredoc commit message mentioning deploy.sh" 0 "$(hook "$(printf 'git commit -F - <<%sEOF%s\nNext: ./deploy.sh is now guarded\nEOF' "'" "'")")"
expect "unreadable tool call fails closed" 2 "$(printf 'not json' | CLAUDE_PROJECT_DIR="$APP" "$HOOK" 2>"$W/err"; echo $?)"

echo "== deploy.sh itself refuses, whatever ran it"
before="$(cat "$PROD/DEPLOYED_COMMIT")"
(cd "$APP" && PROD_DIR="$PROD" bash -c ./deploy.sh) >/dev/null 2>"$W/err"; expect "deploy.sh refuses a stale tree" 2 $?
expect "production untouched after the refusal" "$before" "$(cat "$PROD/DEPLOYED_COMMIT")"

git -C "$APP" pull -q --rebase origin main
expect "current, clean, pushed tree: hook allows" 0 "$(hook './deploy.sh')"
echo "// touched" >> "$APP/pricing.js"
expect "uncommitted change is blocked" 2 "$(hook './deploy.sh')"
git -C "$APP" commit -qam "local only"
expect "unpushed commit is blocked" 2 "$(hook './deploy.sh')"
(cd "$APP" && PROD_DIR="$PROD" ./deploy.sh) >/dev/null 2>&1; expect "deploy.sh refuses an unpushed commit" 2 $?
git -C "$APP" push -q origin main
expect "pushed: hook allows" 0 "$(hook './deploy.sh')"
(cd "$APP" && PROD_DIR="$PROD" ./deploy.sh) >/dev/null 2>&1; expect "deploy.sh ships a current, pushed tree" 0 $?
git -C "$APP" remote set-url origin /nonexistent/origin.git
expect "unreachable origin is blocked" 2 "$(hook './deploy.sh')"

[ $fail = 0 ] && echo "ALL $n PASS" || echo "FAILED"
exit $fail
