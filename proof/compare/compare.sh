#!/usr/bin/env sh
# The comparison: the same tasks, run by Claude Code headlessly under three
# setups, every result scored by the same gate.
#
#   sh proof/compare/compare.sh                 # arms A B C, every task
#   sh proof/compare/compare.sh C --tasks 01    # one cell
#   sh proof/compare/compare.sh A --max-turns 10
#
# Arms: A prompt-only, B long-steering, C loop. Results land in
# proof/compare/results/<model>/<arm name>/<task>/; proof/compare/report.sh makes the tables.
#   sh proof/compare/compare.sh --model claude-haiku-4-5   # the same matrix on another model
set -u

cd "$(dirname "$0")/../.." || exit 2
SRC=$(pwd)
HERE=proof/compare
ARMS=""; TASKS=""; MAX_TURNS=60; MODEL=${COMPARE_MODEL:-claude-sonnet-5-5}; TIMEOUT=${COMPARE_TIMEOUT:-900}
while [ $# -gt 0 ]; do
  case $1 in
    --tasks) TASKS=$(echo "$2" | tr ',' ' '); shift 2 ;;
    --max-turns) MAX_TURNS=$2; shift 2 ;;
    --model) MODEL=$2; shift 2 ;;
    A|B|C) ARMS="$ARMS $1"; shift ;;
    *) echo "compare: unknown argument $1" >&2; exit 2 ;;
  esac
done
[ -n "$ARMS" ] || ARMS="A B C"
[ -n "$TASKS" ] || TASKS=$(ls "$HERE/tasks" | sed 's/-.*//')
WORK=${COMPARE_WORK:-$(mktemp -d)}
# The same tool allow list for every arm. The env-prefixed forms are how an
# agent that read the README tends to call the loop (HUNK=0 sh ...).
ALLOWED="Read,Edit,Write,Glob,Grep,Skill,Bash(npm *),Bash(node *),Bash(git *),Bash(sh *),Bash(jq *),Bash(cat *),Bash(ls *),Bash(poly-crap *),Bash(lawbook *),Bash(HUNK=*),Bash(VERIFY_LLM=*),Bash(BASE=*)"

command -v claude >/dev/null 2>&1 || { echo "compare: claude is not installed" >&2; exit 2; }

arm_name() { case $1 in A) echo prompt-only ;; B) echo long-steering ;; C) echo loop ;; esac; }
now_ms() {
  ns=$(date +%s%N 2>/dev/null)
  case $ns in *N*|"") echo "$(($(date +%s) * 1000))" ;; *) echo "$((ns / 1000000))" ;; esac
}

# A clone at the arm's starting state, committed, so the agent's diff is only its own work.
prepare() {
  arm=$1; dir=$2
  rm -rf "$dir"
  git clone -q --local "$SRC" "$dir"
  (
    cd "$dir" || exit 2
    git config commit.gpgsign false
    git config user.email compare@example.invalid
    git config user.name compare
    if [ "$arm" != C ]; then
      rm -rf .claude lawbook.yaml lawbook.stub.yaml .poly-crap.toml proof demo.sh
      cp "$SRC/$HERE/arms/README.project.md" README.md
      cp "$SRC/$HERE/arms/$(arm_name "$arm")/CLAUDE.md" CLAUDE.md
      jq 'del(.scripts.prove, .scripts.bench, .scripts.scale, .scripts.demo, .scripts.verify)' package.json >package.tmp \
        && mv package.tmp package.json
    fi
    git add -A
    git commit -q -m "chore: arm $arm starting state" --allow-empty
  )
  trust "$dir"
}

# Headless Claude Code ignores a project's .claude/settings.json (its hooks and
# allow list) until the directory is trusted, so every arm's clone is trusted
# the same way. This is what the interactive trust dialog records.
trust() {
  config="$HOME/.claude.json"
  [ -f "$config" ] || echo '{}' >"$config"
  # arms run in parallel; a mkdir lock keeps two edits from racing
  until mkdir "$config.lock" 2>/dev/null; do sleep 1; done
  jq --arg dir "$1" '.projects[$dir] = ((.projects[$dir] // {}) + {hasTrustDialogAccepted: true})' "$config" >"$config.tmp" \
    && mv "$config.tmp" "$config"
  rmdir "$config.lock"
}

run() {
  arm=$1; task=$2
  name=$(basename "$task" .md)
  dir="$WORK/$arm-$name"
  out="$SRC/$HERE/results/${MODEL#claude-}/$(arm_name "$arm")/$name"
  mkdir -p "$out"
  prepare "$arm" "$dir"
  printf '%s %s: ' "$arm" "$name" >&2
  start=$(now_ms)
  (
    cd "$dir" || exit 2
    env -u CLAUDECODE timeout "$TIMEOUT" claude -p "$(cat "$SRC/$task")" \
      --model "$MODEL" --output-format json --max-turns "$MAX_TURNS" \
      --no-session-persistence --allowedTools "$ALLOWED" </dev/null
  ) >"$out/claude.json" 2>"$out/claude.err"
  rc=$?
  wall=$(($(now_ms) - start))
  sh "$HERE/score.sh" "$dir" "$out" "$arm" "$rc" "$wall" "$MODEL" >"$out/score.log" 2>&1
  jq -r '"gate \(.gate), \(.findings) finding(s), \(.turns // "?") turns, \(.duration_ms / 1000 | round)s, $\((.cost_usd // 0) * 100 | round / 100)"' "$out/row.json" >&2
}

for arm in $ARMS; do
  for t in $TASKS; do
    task=$(ls "$HERE"/tasks/"$t"-*.md | head -n 1)
    run "$arm" "$task"
  done
done
echo "compare: done; run sh $HERE/report.sh for the table" >&2
