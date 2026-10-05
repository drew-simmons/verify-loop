#!/usr/bin/env sh
# Scores one finished run with the same gate the loop uses, whatever the arm.
#   sh proof/compare/score.sh <run dir> <results dir> <arm> <claude exit> <wall ms> <model>
set -u

DIR=$1; OUT=$2; ARM=$3; CLAUDE_RC=$4; WALL_MS=$5; MODEL=$6
SRC=$(cd "$(dirname "$0")/../.." && pwd)
cd "$DIR" || exit 2

# The agent's work is everything since the arm's base commit, untracked files included.
git add -A -N . 2>/dev/null
git diff --stat >"$OUT/diff.stat"
git diff >"$OUT/diff.patch"
files_changed=$(git diff --name-only | wc -l | tr -d ' ')
tests_changed=$(git diff --name-only -- test | wc -l | tr -d ' ')
git reset -q

# Did the loop's Stop hook run during the agent's session? (arm C only; it writes .verify/stop.log)
hook_ran=false
[ -f .verify/stop.log ] && hook_ran=true
# The canonical gate, whatever the arm removed.
mkdir -p .claude/skills/verify/scripts
cp "$SRC"/.claude/skills/verify/scripts/* .claude/skills/verify/scripts/
cp "$SRC/lawbook.yaml" lawbook.yaml
cp "$SRC/.poly-crap.toml" .poly-crap.toml
rm -rf .verify lcov.info
HUNK=0 VERIFY_LLM=0 BASE=main sh .claude/skills/verify/scripts/verify.sh >"$OUT/verify.log" 2>&1
gate=$?
for f in crap lawbook; do
  [ -s ".verify/$f.json" ] && cp ".verify/$f.json" "$OUT/$f.json"
done

tests_pass=$(sed -n 's/^ℹ pass \([0-9]*\)$/\1/p' "$OUT/verify.log" | head -n 1)
tests_fail=$(sed -n 's/^ℹ fail \([0-9]*\)$/\1/p' "$OUT/verify.log" | head -n 1)
crap_over=$(jq '[.entries[] | select(.score > 5)] | length' "$OUT/crap.json" 2>/dev/null || echo 0)
crap_names=$(jq -r '[.entries[] | select(.score > 5) | "\(.symbol) \(.score * 10 | round / 10)"] | join("; ")' "$OUT/crap.json" 2>/dev/null)
law_fail=$(jq '[.results[] | select(.status == "fail") | .findings[]] | length' "$OUT/lawbook.json" 2>/dev/null || echo 0)
law_rules=$(jq -r '[.results[] | select(.status == "fail") | .id] | join("; ")' "$OUT/lawbook.json" 2>/dev/null)

steering_bytes=$(wc -c <CLAUDE.md 2>/dev/null | tr -d ' ')
[ "$ARM" = C ] && steering_bytes=$(cat CLAUDE.md .claude/skills/verify/SKILL.md 2>/dev/null | wc -c | tr -d ' ')

jq -n \
  --arg arm "$ARM" --arg task "$(basename "$OUT")" --arg model "$MODEL" \
  --argjson gate "$gate" --argjson claude_rc "$CLAUDE_RC" --argjson wall_ms "$WALL_MS" \
  --argjson tests_pass "${tests_pass:-0}" --argjson tests_fail "${tests_fail:-0}" \
  --argjson crap_over "${crap_over:-0}" --arg crap_names "$crap_names" \
  --argjson law_fail "${law_fail:-0}" --arg law_rules "$law_rules" \
  --argjson files_changed "$files_changed" --argjson tests_changed "$tests_changed" \
  --argjson steering_bytes "${steering_bytes:-0}" --argjson hook_ran "$hook_ran" \
  --slurpfile claude "$OUT/claude.json" \
  '($claude[0] // {}) as $c
   | {arm: $arm, task: $task, model: $model, gate: $gate, claude_exit: $claude_rc,
      findings: ($crap_over + $law_fail), crap_over: $crap_over, crap: $crap_names,
      lawbook_fail: $law_fail, rules: $law_rules,
      tests_pass: $tests_pass, tests_fail: $tests_fail,
      files_changed: $files_changed, tests_changed: $tests_changed,
      turns: ($c.num_turns // null), duration_ms: ($c.duration_ms // $wall_ms), wall_ms: $wall_ms,
      cost_usd: ($c.total_cost_usd // null),
      input_tokens: (($c.usage.input_tokens // 0) + ($c.usage.cache_read_input_tokens // 0) + ($c.usage.cache_creation_input_tokens // 0)),
      output_tokens: ($c.usage.output_tokens // 0),
      denials: (($c.permission_denials // []) | length),
      denied: (($c.permission_denials // []) | map(.tool_name + " " + ((.tool_input.command // .tool_input.file_path // "") | tostring)) | join("; ")),
      hook_ran: $hook_ran,
      terminal: ($c.terminal_reason // (if $claude_rc == 124 then "timeout" else "unknown" end)),
      steering_bytes: $steering_bytes}' >"$OUT/row.json"
cat "$OUT/row.json"
