#!/usr/bin/env sh
# Stop hook: Claude does not end a turn on a red change without seeing why.
#
# Reads the hook payload on stdin. Exits 0 (let the turn end) when this turn
# is already a continuation forced by this hook, when nothing has changed
# against the base, or when verify passes. Otherwise prints a block decision
# whose reason is verify's own summary, so Claude keeps working on it.
set -u

INPUT=$(cat)
if [ "$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ]; then
  exit 0
fi

ROOT=${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}
cd "$ROOT" 2>/dev/null || exit 0

BASE=${BASE:-origin/main}
git rev-parse -q --verify "$BASE^{commit}" >/dev/null 2>&1 || BASE=main
MERGE_BASE=$(git merge-base "$BASE" HEAD 2>/dev/null) || exit 0
if git diff --quiet "$MERGE_BASE" -- && [ -z "$(git ls-files --others --exclude-standard)" ]; then
  exit 0
fi

mkdir -p .verify
BASE=$BASE sh .claude/skills/verify/scripts/verify.sh >.verify/stop.log 2>&1
rc=$?
[ "$rc" -eq 0 ] && exit 0

# Keep the reason short: the stage summaries, not the whole test transcript.
grep -v '^\(ℹ\|✔\|▶\|TAP\|#\)' .verify/stop.log | tail -n 40 >.verify/stop.tail
if [ "$rc" -eq 1 ]; then
  jq -n --rawfile log .verify/stop.tail \
    '{decision: "block", reason: ("verify found problems in the current change. Fix only what is named, then run /verify until it exits 0.\n\n" + $log)}'
else
  jq -n --rawfile log .verify/stop.tail \
    '{decision: "block", reason: ("verify could not run (exit 2). Fix the setup it names, not the code, then run /verify.\n\n" + $log)}'
fi
exit 0
