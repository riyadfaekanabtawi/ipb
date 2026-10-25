#!/usr/bin/env bash
# PostToolUse hook for Edit/Write/MultiEdit.
# - Formats edited Swift files with the toolchain's swift-format (repo .swift-format config).
# - Regenerates the Xcode project when project.yml changes (XcodeGen).
# - Reminds the agent about model versioning when the Core Data model changes.
set -uo pipefail

input="$(cat)"
file="$(printf '%s' "$input" | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin).get("tool_input",{}); print(d.get("file_path") or d.get("path") or "")' 2>/dev/null || true)"
[ -z "$file" ] || [ ! -e "$file" ] && exit 0

root="${CLAUDE_PROJECT_DIR:-$(git -C "$(dirname "$file")" rev-parse --show-toplevel 2>/dev/null || pwd)}"

# Walk up from the file to find the XcodeGen spec (repo root, or IPB-Swift/ during the migration).
find_up() {
  local dir; dir="$(cd "$(dirname "$1")" && pwd)"
  while [ "$dir" != "/" ] && [ "${#dir}" -ge "${#root}" ]; do
    [ -f "$dir/$2" ] && { echo "$dir"; return 0; }
    dir="$(dirname "$dir")"
  done
  return 1
}

case "$file" in
  *.swift)
    if xcrun --find swift-format >/dev/null 2>&1; then
      config="$(find_up "$file" .swift-format || echo "$root")/.swift-format"
      [ -f "$config" ] || config="$root/.swift-format"
      if [ -f "$config" ]; then
        xcrun swift-format format -i --configuration "$config" "$file" 2>/dev/null || true
      fi
    fi
    ;;
  */project.yml)
    if command -v xcodegen >/dev/null 2>&1; then
      (cd "$(dirname "$file")" && xcodegen generate --quiet) >/dev/null 2>&1 \
        && echo '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"project.yml changed: Xcode project regenerated with XcodeGen. Commit the regenerated IPB.xcodeproj too."}}'
    else
      echo '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"project.yml changed but xcodegen is not installed (brew install xcodegen). Regenerate before building."}}'
    fi
    ;;
  *.xcdatamodel/contents)
    echo '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"Core Data model edited. If this model version has shipped, add a NEW model version instead of editing in place, keep changes lightweight-migratable (optional or defaulted attributes), and update BackupService DTOs + DemoSeeder. Ask the coredata-steward agent to review."}}'
    ;;
esac
exit 0
