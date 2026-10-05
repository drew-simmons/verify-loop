#!/usr/bin/env sh
# The speed proof: how long the loop takes on a change, stage by stage, and
# how long it takes when nothing has changed since the last green run.
#
#   cold       scenario 00 (a correct feature) with no coverage or stamp on disk
#   red        scenario 01 (an untested function): every stage runs, two findings
#   unchanged  scenario 00 again with the stamp from the cold run in place
set -u

cd "$(dirname "$0")/.." || exit 2
if [ -n "$(git status --porcelain -- src test)" ]; then
  echo "bench: src/ or test/ has uncommitted changes; commit or stash them first" >&2
  exit 2
fi
VERIFY=".claude/skills/verify/scripts/verify.sh"
export HUNK=${HUNK:-0}
restore() { git checkout -q -- src test; git clean -fdq -- src test; }
trap 'restore; rm -rf .verify lcov.info' EXIT INT TERM

# the stage name and its "took" line, as "name|ms"
stages() {
  awk '/^▸/ { name = substr($0, 5) } /^  took/ { printf "%s|%s\n", name, $2 }' "$1"
}

run() {
  label=$1; scenario=$2
  restore
  . "./proof/scenarios/$scenario"
  apply
  sh "$VERIFY" >".verify-$label.log" 2>&1
  mv ".verify-$label.log" ".verify/$label.log"
  total=$(sed -n 's/.* in \([0-9]*\) ms.*/\1/p' ".verify/$label.log")
  echo "$label|$total"
}

rm -rf .verify lcov.info; mkdir -p .verify
cold=$(run cold 00-clean-change.sh)
red=$(run red 01-untested-function.sh)
restore; . ./proof/scenarios/00-clean-change.sh; apply
start=$(date +%s%N 2>/dev/null); sh "$VERIFY" >.verify/unchanged.log 2>&1
end=$(date +%s%N 2>/dev/null)
unchanged=$(( (end - start) / 1000000 ))
grep -q "unchanged since the last green run" .verify/unchanged.log || { echo "bench: the unchanged run did not hit the stamp" >&2; exit 1; }

echo
echo "| Stage | Cold, correct change | Red, untested function |"
echo "| --- | --- | --- |"
stages .verify/cold.log | while IFS='|' read -r name ms; do
  redms=$(stages .verify/red.log | awk -F'|' -v n="$name" '$1 == n { print $2 }')
  printf '| %s | %s ms | %s ms |\n' "$name" "$ms" "${redms:-}"
done
printf '| **whole loop** | **%s ms** | **%s ms** |\n' "${cold#*|}" "${red#*|}"
printf '| unchanged since last green run | %s ms | |\n' "$unchanged"
echo
echo "bench: done ($(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null) CPUs, node $(node --version))"
