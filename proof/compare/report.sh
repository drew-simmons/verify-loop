#!/usr/bin/env sh
# Assembles proof/compare/results.md from every results/*/*/row.json.
set -u
cd "$(dirname "$0")" || exit 2
ROWS=$(find results -name row.json | sort)
[ -n "$ROWS" ] || { echo "report: no rows under results/" >&2; exit 1; }
jq -s 'sort_by(.model, .arm, .task)' $ROWS >results/rows.json

{
  echo "# Results: the loop against prompting and long steering files"
  echo
  echo "Same six tasks, same gate, one run per cell, one table per model."
  echo "Gate: 0 passed, 1 a gate failed, 2 the gate could not run (for example, tests that no longer start)."
  echo
  echo "## Across models"
  echo
  echo "| Model | Arm | Gate passed | Findings | Caught by | Tests added | Mean turns | Mean time | Total cost |"
  echo "| --- | --- | --- | --- | --- | --- | --- | --- | --- |"
  jq -r 'group_by(.model)[] | group_by(.arm)[] | {model: .[0].model, arm: .[0].arm, n: length,
      pass: ([.[] | select(.gate == 0)] | length),
      findings: ([.[].findings] | add),
      caught: ([.[] | (.crap + (if .crap != "" and .rules != "" then "; " else "" end) + .rules) | select(. != "")] | join("; ") | if . == "" then "-" else . end),
      tests: ([.[].tests_changed] | add),
      turns: (([.[].turns // 0] | add) / length),
      secs: (([.[].duration_ms] | add) / length / 1000),
      cost: ([.[].cost_usd // 0] | add)}
    | "| \(.model) | \(.arm) | \(.pass) of \(.n) | \(.findings) | \(.caught) | \(.tests) | \(.turns * 10 | round / 10) | \(.secs | round)s | $\(.cost * 100 | round / 100) |"' results/rows.json
  echo
  for model in $(jq -r '[.[].model] | unique[]' results/rows.json); do
    echo "## $model"
    echo
    echo "| Arm | Task | Gate | Caught by | Tests added | Max CC | Min coverage | Lines | Turns | Time | Cost | Hook fired |"
    echo "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |"
    jq -r --arg m "$model" '.[] | select(.model == $m) | "| \(.arm) | \(.task) | \(.gate) | \((.crap + (if .crap != "" and .rules != "" then "; " else "" end) + .rules) | if . == "" then "-" else . end) | \(.tests_changed) | \(if .changed_fns == 0 then "-" else .max_cc end) | \(if .changed_fns == 0 then "-" else "\(.min_cov)%" end) | +\(.lines_added) | \(.turns // "?") | \((.duration_ms / 1000) | round)s | $\((.cost_usd // 0) * 100 | round / 100) | \(if .arm == "C" then (if .hook_ran then "yes" else "no" end) else "n/a" end) |"' results/rows.json
    echo
    echo "| Arm | Gate passed | Findings | Tests added | Mean turns | Mean time | Total cost | Steering per turn | Steering carried over the run |"
    echo "| --- | --- | --- | --- | --- | --- | --- | --- | --- |"
    jq -r --arg m "$model" '[.[] | select(.model == $m)] | group_by(.arm)[] | {arm: .[0].arm, n: length,
        pass: ([.[] | select(.gate == 0)] | length),
        findings: ([.[].findings] | add),
        tests: ([.[].tests_changed] | add),
        turns: (([.[].turns // 0] | add) / length),
        secs: (([.[].duration_ms] | add) / length / 1000),
        cost: ([.[].cost_usd // 0] | add),
        steer: .[0].steering_bytes,
        carried: ([.[] | .steering_bytes * (.turns // 0)] | add)}
      | "| \(.arm) | \(.pass) of \(.n) | \(.findings) | \(.tests) | \(.turns * 10 | round / 10) | \(.secs | round)s | $\(.cost * 100 | round / 100) | \(.steer / 1024 * 10 | round / 10) KB | \(.carried / 1024 | round) KB |"' results/rows.json
    echo
  done
  cat <<'MD'
Arms: **A** prompt only (a ten-line CLAUDE.md with the commands), **B** a long
steering file (every rule as prose, no gate), **C** the loop (a short CLAUDE.md,
the `/verify` skill, the Stop hook, the rules on disk). "Steering" is the size
of what the model reads as instructions on every turn; "carried over the run" is
that size times the turns the arm took, the text the arm paid for. "Max CC" and
"Min coverage" are over the functions the agent changed, as poly-crap scored
them; "-" means the change touched no function body. "Hook fired" says whether
the loop's Stop hook ran during the agent's session.

The gate scores only what a regex or a coverage report can see. The six prose
standards (names, one thing per function, guard clauses, errors, injected
dependencies, behaviour-named tests) are not part of the score here, so the
table understates the difference a model judge would show; see
`proof/prove-llm.sh` for that stage.

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
