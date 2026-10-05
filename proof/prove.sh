#!/usr/bin/env sh
# The confidence proof: every realistic mistake is caught, and a correct
# change passes. Each scenario edits the tree, runs verify, checks the exit
# code and the finding, and is reverted. Prints a Markdown table; exits 1 if
# any expectation fails.
set -u

cd "$(dirname "$0")/.." || exit 2
if [ -n "$(git status --porcelain -- src test)" ]; then
  echo "prove: src/ or test/ has uncommitted changes; commit or stash them first" >&2
  exit 2
fi
VERIFY=".claude/skills/verify/scripts/verify.sh"
export HUNK=${HUNK:-0}

restore() {
  git checkout -q -- src test
  git clean -fdq -- src test
  rm -rf .verify lcov.info
}
trap restore EXIT INT TERM

now_ms() {
  ns=$(date +%s%N 2>/dev/null)
  case $ns in *N*|"") echo "$(($(date +%s) * 1000))" ;; *) echo "$((ns / 1000000))" ;; esac
}

failures=0
rows=""
for scenario in proof/scenarios/*.sh; do
  restore
  number=$(basename "$scenario" | cut -d- -f1)
  # shellcheck disable=SC1090
  . "./$scenario"
  apply
  mkdir -p .verify
  start=$(now_ms)
  sh "$VERIFY" >.verify/log 2>&1
  rc=$?
  elapsed=$(($(now_ms) - start))
  caught_text=$(caught)
  verdict="ok"
  if [ "$rc" -ne "$expect_exit" ]; then
    verdict="expected exit $expect_exit, got $rc"
  elif ! expect; then
    verdict="finding missing"
  fi
  if [ "$verdict" != "ok" ]; then
    failures=$((failures + 1))
    echo "--- scenario $number ($title): $verdict" >&2
    sed 's/^/    /' .verify/log >&2
  fi
  rows="$rows| $number | $developer_did | $rc | $caught_text | $(awk "BEGIN { printf \"%.1f\", $elapsed / 1000 }")s |
"
  printf '%s %s (%s, exit %s, %s ms)\n' "$([ "$verdict" = ok ] && echo "PASS" || echo "FAIL")" "$number" "$title" "$rc" "$elapsed" >&2
done
restore

echo
echo "| # | A developer... | Exit | Caught by | Time |"
echo "| --- | --- | --- | --- | --- |"
printf '%s' "$rows"
echo
if [ "$failures" -eq 0 ]; then
  echo "prove: PASS, every scenario behaved as expected"
else
  echo "prove: FAIL, $failures scenario(s) did not behave as expected"
  exit 1
fi
