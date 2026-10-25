#!/usr/bin/env bash
# SessionStart: give the agent a compact picture of where the repo is.
set -uo pipefail
root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$root" 2>/dev/null || exit 0

branch="$(git branch --show-current 2>/dev/null || echo '?')"
dirty="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
project_dir="."
[ -f "IPB-Swift/project.yml" ] && project_dir="IPB-Swift"

cat <<EOF
IPB repo context
- Branch: ${branch} (${dirty} uncommitted changes)
- Xcode project spec: ${project_dir}/project.yml (XcodeGen). Regenerate with: (cd ${project_dir} && xcodegen generate)
- Build/test: see "Commands" in CLAUDE.md. Use an iPad simulator; the app is iPad-only.
- Policy: no AI attribution in commits or PRs; never push to main; every change ships through a PR.
EOF
exit 0
