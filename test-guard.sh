#!/bin/bash
# Deterministic checks on the guard itself, no model involved. Exit 0 only if every case holds.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
W="$("$ROOT/setup.sh")"
"$ROOT/sam.sh" "$W" >/dev/null
APP="$W/app"
HOOK="$APP/.claude/hooks/deploy-guard.sh"
fail=0
call() { printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1" | CLAUDE_PROJECT_DIR="$APP" "$HOOK" 2>"$W/err"; echo $?; }
expect() { if [ "$2" = "$3" ]; then echo "PASS $1"; else echo "FAIL $1 (exit $3, want $2): $(head -2 "$W/err")"; fail=1; fi; }

expect "non-deploy command passes"           0 "$(call 'git status')"
expect "stale tree deploy is blocked"        2 "$(call './deploy.sh')"
expect "reading deploy.sh is not a deploy"    0 "$(call 'cat deploy.sh')"
expect "grep in deploy.sh is not a deploy"    0 "$(call 'grep PROD deploy.sh')"
expect "chained deploy is blocked"           2 "$(call 'node --test && ./deploy.sh')"
expect "unreadable tool call fails closed"   2 "$(printf 'not json' | CLAUDE_PROJECT_DIR="$APP" "$HOOK" 2>"$W/err"; echo $?)"
expect "env-prefixed deploy is blocked"      2 "$(call 'PROD_DIR=../production ./deploy.sh')"
expect "bash deploy.sh is blocked"           2 "$(call 'bash deploy.sh')"
grep -q "1 commit(s) behind origin/main" "$W/err" && grep -q "Sam (teammate)" "$W/err" \
  && echo "PASS block message names the missing commit and its author" \
  || { echo "FAIL block message: $(cat "$W/err")"; fail=1; }

git -C "$APP" pull -q --rebase origin main
expect "current tree deploy passes"          0 "$(call './deploy.sh')"
echo "x" >> "$APP/site/headline.txt"
expect "uncommitted change is blocked"       2 "$(call './deploy.sh')"
git -C "$APP" checkout -q -- site/headline.txt
expect "clean again passes"                  0 "$(call './deploy.sh')"

git -C "$APP" remote set-url origin /nonexistent/origin.git
expect "unreachable origin is blocked"       2 "$(call './deploy.sh')"

[ $fail = 0 ] && echo "ALL PASS" || echo "FAILED"
exit $fail
