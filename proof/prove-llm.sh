#!/usr/bin/env sh
# The model proof: the prose standards in lawbook.yaml, judged by a model on
# Bedrock through the Bifrost gateway, catch what no regex can, agree with a
# human on the fixtures, pass a clean change, and cost nothing on a rerun.
# With --stub the judge is proof/stub-judge.mjs, so the same plumbing runs
# with no credentials and no gateway.
#
#   sh proof/prove-llm.sh            # with the gateway session-start.sh started
#   sh proof/prove-llm.sh --stub
set -u

cd "$(dirname "$0")/.." || exit 2
if [ -n "$(git status --porcelain -- src test)" ]; then
  echo "prove-llm: src/ or test/ has uncommitted changes; commit or stash them first" >&2
  exit 2
fi
VERIFY=".claude/skills/verify/scripts/verify.sh"
export HUNK=${HUNK:-0} VERIFY_LLM=1 BASE=${BASE:-main}
# A cache of its own, emptied first, so every request count below is a cold one.
export LAWBOOK_CACHE_DIR=.verify/cache
rm -rf .verify/cache

STUB_PID=""
if [ "${1:-}" = "--stub" ]; then
  export LAWBOOK_CONFIG=lawbook.stub.yaml
  export MARKER="// stub: fails standard"
  mkdir -p .verify
  node proof/stub-judge.mjs >.verify/stub.log 2>&1 &
  STUB_PID=$!
  tries=0
  until grep -q listening .verify/stub.log 2>/dev/null || [ "$tries" -ge 20 ]; do
    tries=$((tries + 1)); sleep 0.25
  done
  judge="stub judge"
else
  export LAWBOOK_CONFIG=${LAWBOOK_CONFIG:-lawbook.yaml} MARKER=""
  BIFROST_URL=${BIFROST_URL:-http://localhost:8080}
  if ! curl -fsS -m 2 -o /dev/null "$BIFROST_URL/health" 2>/dev/null; then
    echo "prove-llm: no Bifrost gateway answers at $BIFROST_URL; set AWS_REGION and Bedrock credentials and run the SessionStart hook, or pass --stub" >&2
    exit 2
  fi
  judge="Bifrost at $BIFROST_URL, $(sed -n 's/^  model: //p' lawbook.yaml)${AWS_REGION:+, $AWS_REGION}"
fi

restore() { git checkout -q -- src test; git clean -fdq -- src test; }
cleanup() {
  restore
  [ -n "$STUB_PID" ] && kill "$STUB_PID" 2>/dev/null
  rm -rf .verify lcov.info
}
trap cleanup EXIT INT TERM

now_ms() {
  ns=$(date +%s%N 2>/dev/null)
  case $ns in *N*|"") echo "$(($(date +%s) * 1000))" ;; *) echo "$((ns / 1000000))" ;; esac
}
failures=0
step() { echo; echo "================ $1 ================"; }
fail() { failures=$((failures + 1)); echo "FAIL: $1" >&2; }

echo "judge: $judge"

step "plan: what judging the whole tree would cost"
lawbook check . --config "$LAWBOOK_CONFIG" --dry-run | tail -n 1

step "fixtures: lawbook test"
start=$(now_ms)
lawbook test . --config "$LAWBOOK_CONFIG" --cache-dir "$LAWBOOK_CACHE_DIR"
rc=$?
fixtures_ms=$(($(now_ms) - start))
[ "$rc" -eq 0 ] || fail "a fixture was judged on the wrong side of its threshold"
echo "fixtures took $fixtures_ms ms"

step "scenarios: mistakes no regex can catch, and one clean change"
rows=""
for scenario in proof/scenarios/model/*.sh; do
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
  before=$failures
  requests=$(jq -r '.summary.usage.requests' .verify/lawbook.json 2>/dev/null)
  if [ -n "$rule" ]; then
    noul=$(jq -r --arg r "$rule" --arg f "$file" '.results[] | select(.id == $r) | .findings[] | select(.path == $f) | .decision.noul' .verify/lawbook.json 2>/dev/null | head -n 1)
    status=$(jq -r --arg r "$rule" '.results[] | select(.id == $r) | .status' .verify/lawbook.json 2>/dev/null)
    verdict="warned, noul ${noul:-?}"
    if [ "$rc" -ne 0 ]; then fail "$number: verify exited $rc"; sed 's/^/    /' .verify/log >&2
    elif [ "$status" != "warn" ] || [ -z "$noul" ]; then fail "$number: $rule did not warn on $file (status ${status:-missing})"; verdict="MISSED (status ${status:-missing})"
    fi
  else
    warned=$(jq -r '[.results[] | select(.kind == "standard" and .status != "pass")] | length' .verify/lawbook.json 2>/dev/null)
    verdict="every standard passed"
    if [ "$rc" -ne 0 ]; then fail "$number: verify exited $rc"; sed 's/^/    /' .verify/log >&2
    elif [ "$warned" != "0" ]; then fail "$number: $warned standard(s) did not pass a clean change"; verdict="$warned standard(s) warned"
    fi
  fi
  printf '%s %s (%s): %s, %s request(s), %s ms\n' "$([ "$failures" -eq "$before" ] && echo PASS || echo FAIL)" "$number" "$title" "$verdict" "${requests:-?}" "$elapsed"
  rows="$rows| $number | $developer_did | ${rule:-all six} | $verdict | ${requests:-?} | $(awk "BEGIN { printf \"%.1f\", $elapsed / 1000 }")s |
"
done

step "cache: the clean change judged twice"
restore
. ./proof/scenarios/model/17-clean-change.sh
apply
rm -rf "$LAWBOOK_CACHE_DIR"
first=$(lawbook check . --config "$LAWBOOK_CONFIG" --cache-dir "$LAWBOOK_CACHE_DIR" --changed --since "$BASE" --format json | jq -c '.summary.usage | {requests, cached}')
second=$(lawbook check . --config "$LAWBOOK_CONFIG" --cache-dir "$LAWBOOK_CACHE_DIR" --changed --since "$BASE" --format json | jq -c '.summary.usage | {requests, cached}')
echo "first run:  $first"
echo "second run: $second"
echo "$first" | jq -e '.requests > 0' >/dev/null || fail "the first run did not ask the judge"
echo "$second" | jq -e '.requests == 0 and .cached > 0' >/dev/null || fail "the second run was not served from the cache"
restore

echo
echo "| # | A developer... | Standard | Verdict | Requests | Time |"
echo "| --- | --- | --- | --- | --- | --- |"
printf '%s' "$rows"
echo
if [ "$failures" -eq 0 ]; then
  echo "prove-llm: PASS with $judge"
else
  echo "prove-llm: FAIL, $failures expectation(s) not met"
  exit 1
fi
