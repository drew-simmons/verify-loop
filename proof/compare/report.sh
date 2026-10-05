#!/usr/bin/env sh
# Assembles proof/compare/results.md from every results/*/*/row.json.
set -u
cd "$(dirname "$0")" || exit 2
ROWS=$(find results -name row.json | sort)
[ -n "$ROWS" ] || { echo "report: no rows under results/" >&2; exit 1; }
jq -s '.' $ROWS >results/rows.json

{
  echo "# Results: the loop against prompting and long steering files"
  echo
  echo "Same six tasks, same model ($(jq -r '.[0].model' results/rows.json)), same gate. One run per cell."
  echo "Gate: 0 passed, 1 a gate failed, 2 the gate could not run (for example, tests that no longer start)."
  echo
  echo "| Arm | Task | Gate | Findings | Caught by | Tests | Turns | Time | Cost | Steering |"
  echo "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |"
  jq -r '.[] | "| \(.arm) | \(.task) | \(.gate) | \(.findings) | \((.crap + (if .crap != "" and .rules != "" then "; " else "" end) + .rules) | if . == "" then "-" else . end) | \(.tests_pass) pass, \(.tests_fail) fail | \(.turns // "?") | \((.duration_ms / 1000 * 10 | round) / 10)s | $\((.cost_usd // 0) * 100 | round / 100) | \(.steering_bytes / 1024 * 10 | round / 10) KB |"' results/rows.json
  echo
  echo "## Per arm"
  echo
  echo "| Arm | Tasks passing the gate | Findings | Mean turns | Mean time | Total cost | Steering per turn | Steering carried in all |"
  echo "| --- | --- | --- | --- | --- | --- | --- | --- |"
  jq -r 'group_by(.arm)[] | {arm: .[0].arm, n: length,
      pass: ([.[] | select(.gate == 0)] | length),
      findings: ([.[].findings] | add),
      turns: (([.[].turns // 0] | add) / length),
      secs: (([.[].duration_ms] | add) / length / 1000),
      cost: ([.[].cost_usd // 0] | add),
      steer: .[0].steering_bytes,
      carried: ([.[] | .steering_bytes * (.turns // 0)] | add)}
    | "| \(.arm) | \(.pass) of \(.n) | \(.findings) | \(.turns * 10 | round / 10) | \(.secs | round)s | $\(.cost * 100 | round / 100) | \(.steer / 1024 * 10 | round / 10) KB | \(.carried / 1024 / 1024 * 10 | round / 10) MB |"' results/rows.json
  echo
  cat <<'MD'
Arms: **A** prompt only (a ten-line CLAUDE.md with the commands), **B** a long
steering file (every rule as prose, no gate), **C** the loop (a short CLAUDE.md,
the `/verify` skill, the Stop hook, the rules on disk). "Steering" is the size
of what the model reads as instructions on every turn; "carried in all" is that
size times the turns the arm took, the text the arm paid for.

## What the numbers cannot show

| | Prose in a CLAUDE.md | Rules in `lawbook.yaml` and the gate |
| --- | --- | --- |
| Who reads it | one model, when it chooses to | the gate, every run, for humans and CI too |
| Can it be tested | no | yes: `proof/prove.sh`, `lawbook test`, the fixtures |
| What happens when it drifts | nobody notices | a scenario stops being caught and `prove.sh` fails |
| Scope | the whole file, every turn | the changed functions and files |
| Cost per turn | every byte, every turn | one skill description; the rules cost nothing until they run |
| When it is wrong | the model argues or complies silently | the exit code and the finding say exactly what and where |
MD
} >results.md
echo "report: wrote results.md with $(jq length results/rows.json) rows"
