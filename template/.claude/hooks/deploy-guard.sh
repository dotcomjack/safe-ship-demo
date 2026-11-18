#!/bin/bash
# PreToolUse hook for Claude Code: the EARLY WARNING. When a Bash command might run deploy.sh,
# run the same check deploy.sh runs and, if it fails, block the call so Claude reads the reason
# before anything happens. deploy.sh enforces the rule itself, so this hook can afford to be
# conservative: a command is let through without a check only when every segment that mentions
# deploy.sh plainly reads it (cat, grep, git ...). Exit 2 blocks; stderr goes to Claude.
verdict=$(python3 -c '
import json, re, shlex, sys
cmd = json.load(sys.stdin)["tool_input"]["command"]
if not isinstance(cmd, str): raise SystemExit(1)
if "deploy" not in cmd:
    print("pass"); raise SystemExit
# Heredoc bodies are data (commit messages, file contents), not commands.
cmd = re.sub(r"<<-?\s*([\x27\"]?)(\w+)\1[^\n]*\n.*?\n\s*\2\s*(\n|$)", " ", cmd, flags=re.S)
READERS = {"cat","grep","egrep","fgrep","rg","head","tail","less","more","wc","diff","ls","git",
           "stat","file","shasum","md5","sed","vim","vi","nano"}
SHELLS = {"bash","sh","zsh","dash","source",".","eval","exec","xargs"}
try:
    lex = shlex.shlex(cmd, posix=True, punctuation_chars=True)
    lex.whitespace_split = True
    lex.commenters = ""
    toks = list(lex)
except ValueError:
    print("check"); raise SystemExit
segs, cur = [], []
for t in toks:
    if t and all(c in ";&|()<>" for c in t):
        segs.append(cur); cur = []
    else:
        cur.append(t)
segs.append(cur)
def word(seg):
    s = list(seg)
    while s and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", s[0]): s.pop(0)
    return s[0].split("/")[-1] if s else ""
mentions = [s for s in segs if any("deploy" in t for t in s)]
if any(word(s) in SHELLS for s in segs) or any(word(s) not in READERS for s in mentions):
    print("check")
else:
    print("pass")
') || verdict=error

case "$verdict" in
  pass) exit 0 ;;
  check) exec "${CLAUDE_PROJECT_DIR:-.}/scripts/deploy-check.sh" ;;
  *) echo "BLOCKED by deploy guard: could not read this command, so it cannot be proven safe." >&2; exit 2 ;;
esac
