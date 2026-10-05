#!/usr/bin/env sh
# verify: one command, one exit code.
#
#   0  clean. Commit.
#   1  a gate failed. Read .verify/crap.json and .verify/lawbook.json, fix only
#      what they name, run again.
#   2  the loop itself is broken: a tool is missing, the base ref does not
#      exist, coverage was not produced, credentials are absent. Fix the
#      setup, not the code.
#
# Every stage scopes to the same change: the merge base of $BASE and HEAD
# against the working tree, including uncommitted and untracked files.
# Stages run cheapest first, and the model-judged stage only on a green tree.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "verify: not inside a git repository" >&2; exit 2; }
cd "$ROOT" || exit 2

OUT=.verify
mkdir -p "$OUT"
THRESHOLD=${THRESHOLD:-5}
MAX_REQUESTS=${MAX_REQUESTS:-20}
BASE=${BASE:-origin/main}
git rev-parse -q --verify "$BASE^{commit}" >/dev/null 2>&1 || BASE=main
MERGE_BASE=$(git merge-base "$BASE" HEAD 2>/dev/null) \
  || { echo "verify: no merge base between $BASE and HEAD (set BASE=<ref>)" >&2; exit 2; }

# A change that already passed is not verified twice. The stamp covers the
# tracked diff and every untracked file git does not ignore.
stamp() {
  {
    git diff "$MERGE_BASE" --
    git ls-files --others --exclude-standard -z | xargs -0 -r cat 2>/dev/null
  } | sha256sum | cut -c1-16
}
STAMP=$(stamp)
if [ "$STAMP" = "$(cat "$OUT/green" 2>/dev/null)" ]; then
  echo "verify: unchanged since the last green run ($STAMP)"
  exit 0
fi
rm -f "$OUT/green" "$OUT/crap.json" "$OUT/lawbook.json" "$OUT/comments.json" "$OUT/notes.json"

# The worst stage decides: 0 stays, 2 means broken, anything else is a failed gate.
status=0
record() {
  rc=$1
  [ "$rc" -eq 0 ] && return 0
  [ "$rc" -ne 2 ] && rc=1
  [ "$rc" -gt "$status" ] && status=$rc
  return 0
}
stage() { printf '\n%s %s\n' '▸' "$1"; }
skip() { printf '  skipped: %s\n' "$1"; }
missing() { printf '  %s is not installed; run .claude/hooks/session-start.sh\n' "$1"; record 2; }

lawbook_summary() {
  jq -r '
    .results[]
    | select(.status == "fail" or .status == "warn" or .status == "error")
    | .id as $id | .status as $status
    | .findings[]
    | "  \($status | ascii_upcase) [\($id)] \(.path // "-")\(if .line then ":\(.line)" else "" end): \(.message)"
  ' "$OUT/lawbook.json" 2>/dev/null
  jq -r '.summary | "  \(.passed) passed, \(.failed) failed, \(.warned) warned, \(.errored) errored, \(.skipped) skipped"' \
    "$OUT/lawbook.json" 2>/dev/null
}

echo "verify: $BASE..working tree (merge base ${MERGE_BASE%"${MERGE_BASE#???????}"})"

stage "1  syntax (node --check)"
for f in src/*.js test/*.js; do
  [ -f "$f" ] || continue
  node --check "$f" || record $?
done
echo "  ok"

stage "2  lawbook, deterministic rules on changed files"
if ! command -v lawbook >/dev/null 2>&1; then missing lawbook
elif [ ! -f lawbook.yaml ]; then skip "no lawbook.yaml"
else
  lawbook check . --no-llm --changed --since "$BASE" --format json >"$OUT/lawbook.json"
  record $?
  lawbook_summary
fi

stage "3  tests with coverage"
rm -f lcov.info
npm run -s coverage
record $?

stage "4  poly-crap on changed functions (threshold $THRESHOLD)"
if ! command -v poly-crap >/dev/null 2>&1; then missing poly-crap
elif [ ! -f lcov.info ]; then
  echo "  no lcov.info; the test run did not produce coverage"
  record 2
else
  poly-crap --diff-base "$BASE" --coverage lcov.info --threshold "$THRESHOLD" --fail-above \
    --format json --output "$OUT/crap.json"
  record $?
  jq -r --argjson t "$THRESHOLD" '
    [.entries[] | select(.score > $t)]
    | if length == 0 then "  no changed function scores above \($t)"
      else .[] | "  \(.file | ltrimstr("./")):\(.start_line) \(.symbol)  CRAP \((.score * 10 | round) / 10)  CC \(.complexity | round)  coverage \(if .coverage == null then "none" else "\(.coverage | round)%" end)"
      end
  ' "$OUT/crap.json" 2>/dev/null
fi

stage "5  lawbook, model-judged standards"
if [ "$status" -ne 0 ]; then skip "an earlier stage failed; no model requests on a red tree"
elif ! command -v lawbook >/dev/null 2>&1; then skip "lawbook is not installed"
elif ! grep -Eq '^[[:space:]]*standard:' lawbook.yaml 2>/dev/null; then skip "no standard rules in lawbook.yaml"
elif [ -z "${AWS_REGION:-${AWS_DEFAULT_REGION:-}}" ]; then skip "set AWS_REGION with Bedrock credentials to opt in"
else
  lawbook check . --changed --since "$BASE" --max-requests "$MAX_REQUESTS" --format json >"$OUT/lawbook.json"
  record $?
  lawbook_summary
fi

stage "6  findings to Hunk"
for f in crap lawbook; do
  [ -s "$OUT/$f.json" ] || echo null >"$OUT/$f.json"
done
jq -s --argjson t "$THRESHOLD" --arg format session -f "$HERE/to-hunk.jq" \
  "$OUT/crap.json" "$OUT/lawbook.json" >"$OUT/comments.json"
jq -s --argjson t "$THRESHOLD" --arg format sidecar -f "$HERE/to-hunk.jq" \
  "$OUT/crap.json" "$OUT/lawbook.json" >"$OUT/notes.json"
COUNT=$(jq '.comments | length' "$OUT/comments.json")
if command -v hunk >/dev/null 2>&1 && hunk session get --repo . >/dev/null 2>&1; then
  hunk session comment clear --repo . --yes >/dev/null 2>&1
  if [ "$COUNT" -gt 0 ]; then
    hunk session comment apply --repo . --stdin <"$OUT/comments.json" >/dev/null
  fi
  echo "  $COUNT comment(s) in the live Hunk session"
else
  echo "  no live Hunk session; wrote $OUT/notes.json ($COUNT annotation(s))"
  echo "  open it with: hunk diff --agent-notes --agent-context $OUT/notes.json"
fi

echo
case $status in
  0) printf '%s' "$STAMP" >"$OUT/green"; echo "verify: clean ($STAMP)" ;;
  1) echo "verify: $COUNT finding(s). Fix only what is named above, then run again." ;;
  *) echo "verify: could not run (exit 2). Fix the setup, not the code." ;;
esac
exit "$status"
