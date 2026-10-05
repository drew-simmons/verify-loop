# CLAUDE.md

A worked example of a verification loop for Claude Code: poly-crap, lawbook,
and Hunk on one definition of the change, behind one script with one exit
code. `src/` is the project the loop verifies; `.claude/` is the loop;
`proof/` shows the loop catching real mistakes, how long it takes, and how it
scales.

## Commands

```sh
npm test                                   # node:test, 39 tests
npm run coverage                           # tests + lcov.info
sh .claude/skills/verify/scripts/verify.sh # the loop: exit 0 clean, 1 gate failed, 2 broken
sh demo.sh                                 # red → green → cached in 60 seconds
sh proof/prove.sh                          # 11 scenarios, each caught or passed as expected
sh proof/bench.sh                          # stage-by-stage timings
sh proof/scale.sh 10 50 200                # timings as the codebase grows
lawbook check . --no-llm                   # the clean-code rules alone
```

`/verify` runs the loop as a skill. The Stop hook in `.claude/settings.json`
runs it again at the end of every turn that changed something and blocks the
turn with the findings while the change is red. `BASE=<ref>` changes the base
from `origin/main`; `HUNK=0` skips the live Hunk session.

## The example project

An order-processing library in plain ESM JavaScript with no dependencies.
`errors`, `validate`, and `money` are the foundations; `catalog`, `cart`,
`pricing`, `tax`, `shipping`, and `inventory` are independent rules;
`orders.placeOrder` composes them and takes `now()` and `nextId()` through
its `deps` argument so nothing in `src/` reads the clock. Lookup tables
replace `if` chains. One test file per module in `test/`.

## Conventions

- Run `/verify` before committing. A function fails above CRAP 5, so keep
  complexity at 5 or below and cover every branch. A fully tested function
  with complexity 7 still fails; split it.
- `lawbook.yaml` is the definition of clean here: no console, no I/O, no
  empty catch, no `==`, no `var`, no nested ternary, no default export, a
  doc comment on every export, an issue on every TODO. Read it before
  arguing with a finding.
- Verification never needs network access or credentials. The prose
  standards in `lawbook.yaml` are opt-in through `AWS_REGION` and only warn.
- When a scenario in `proof/scenarios/` stops being caught, the loop has a
  hole; fix the loop, not the scenario.
- Conventional Commit subjects. No AI attribution in commits.
