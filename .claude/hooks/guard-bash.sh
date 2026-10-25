#!/usr/bin/env bash
# PreToolUse guard for Bash commands.
# - Commits and PRs must not carry AI attribution (team policy).
# - No force pushes to main, no history rewrites of main.
# - No destructive wipes of the repo or the user's home.
# Exit code 2 blocks the tool call and shows the reason to the agent.
set -euo pipefail

input="$(cat)"
cmd="$(printf '%s' "$input" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null || true)"
[ -z "$cmd" ] && exit 0

lower="$(printf '%s' "$cmd" | tr '[:upper:]' '[:lower:]')"

block() { echo "Blocked by .claude/hooks/guard-bash.sh: $1" >&2; exit 2; }

# 1. No AI credit in commit messages, PR titles/bodies or tags.
if printf '%s' "$lower" | grep -Eq '(git (commit|tag|merge)|gh pr (create|edit)|gh release)'; then
  # Paths like .claude/ and CLAUDE.md are fine to stage; only message text is policed.
  text="$(printf '%s' "$lower" | sed -E 's#\.claude[/a-z0-9_.-]*##g; s#claude\.md##g')"
  if printf '%s' "$text" | grep -Eq 'co-authored-by|generated with|claude|anthropic|chatgpt|copilot|\bai[- ]generated|🤖'; then
    block "commit/PR text must not mention AI tools or add AI co-author trailers. Rewrite the message."
  fi
fi

# 2. Protect main.
if printf '%s' "$lower" | grep -Eq 'git push.*(--force|-f\b|--force-with-lease).*\bmain\b|git push.*\bmain\b.*(--force|-f\b)'; then
  block "force-pushing main is not allowed. Open a PR instead."
fi
if printf '%s' "$lower" | grep -Eq 'git push( +origin)? +(head:)?main\b'; then
  block "direct pushes to main are not allowed. Push a feature branch and open a PR."
fi
if printf '%s' "$lower" | grep -Eq 'git reset --hard origin/main|git branch -d main|git branch -D main'; then
  block "refusing to rewrite or delete main."
fi

# 3. Destructive wipes.
if printf '%s' "$lower" | grep -Eq 'rm -rf (/|~|\$home|\.|\./)( |$)|rm -rf \.git\b'; then
  block "destructive rm -rf on the repo root, .git or home directory."
fi

exit 0
