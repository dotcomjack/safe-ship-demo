#!/bin/bash
# PreToolUse guard for Claude Code: refuse ./deploy.sh unless this tree contains origin/main
# and every change is committed. A deploy ships the working tree, so a stale tree silently
# reverts work a teammate already shipped. Exit 2 blocks the tool call; stderr goes to Claude.
# Fire only when a command segment RUNS deploy.sh (./deploy.sh, bash deploy.sh, FOO=1 ./deploy.sh),
# never when one merely reads it (cat deploy.sh, grep x deploy.sh).
runs=$(python3 -c '
import json, re, shlex, sys
cmd = json.load(sys.stdin).get("tool_input", {}).get("command", "")
for seg in re.split(r"&&|\|\||;|\||\n", cmd):
    try: toks = shlex.split(seg)
    except ValueError: toks = seg.split()
    while toks and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", toks[0]): toks.pop(0)
    if toks and toks[0] in ("bash", "sh", "zsh", "exec", "time"): toks.pop(0)
    if toks and toks[0].split("/")[-1] == "deploy.sh":
        print("yes"); break
else:
    print("no")
') || runs=error
# Fail closed: if the tool call cannot be read, nothing gets past the guard.
if [ "$runs" = "error" ] || [ -z "$runs" ]; then
  echo "BLOCKED by deploy guard: could not read this command, so it cannot be proven safe." >&2
  exit 2
fi
[ "$runs" = "yes" ] || exit 0
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 2

if ! git fetch -q origin 2>/dev/null; then
  echo "BLOCKED by deploy guard: could not reach origin, so this tree cannot be proven current. Not deploying blind." >&2
  exit 2
fi
if ! git merge-base --is-ancestor origin/main HEAD; then
  n=$(git rev-list --count HEAD..origin/main)
  {
    echo "BLOCKED by deploy guard: this tree is $n commit(s) behind origin/main."
    git log --format='  %h %an: %s' HEAD..origin/main
    echo "Deploying now would silently revert that work in production."
    echo "Rebase onto origin/main, rerun the tests, then deploy again."
  } >&2
  exit 2
fi
if [ -n "$(git status --porcelain)" ]; then
  echo "BLOCKED by deploy guard: uncommitted changes. Commit first, so production always matches a commit." >&2
  exit 2
fi
exit 0
