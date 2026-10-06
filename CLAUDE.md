# CLAUDE.md

A worked example of a verification loop for Claude Code: poly-crap, lawbook,
and Hunk on one definition of the change, behind one script with one exit
code. `src/` is the project the loop verifies; `.claude/` is the loop;
`proof/` shows the loop catching real mistakes, how long it takes, how it
scales, and (in `proof/compare/`) how it fares against prompting alone and
against a long steering file.

## Commands

```sh
npm test                                   # node:test, 39 tests
npm run coverage                           # tests + lcov.info
sh .claude/skills/verify/scripts/verify.sh # the loop: exit 0 clean, 1 gate failed, 2 broken
sh demo.sh                                 # red → green → cached in 60 seconds
sh proof/prove.sh                          # 11 scenarios, each caught or passed as expected
sh proof/bench.sh                          # stage-by-stage timings
sh proof/scale.sh 10 50 200                # timings as the codebase grows
sh proof/prove-llm.sh --stub               # the model stage end to end, no credentials
sh proof/prove-llm.sh                      # the same on Bedrock through the Bifrost gateway, with the judge in lawbook.yaml
sh proof/judge-agreement.sh                # Haiku vs Sonnet as judge, per standard
sh proof/compare/compare.sh [A|B|C] [--tasks 01,05] [--model claude-haiku-4-5]   # headless Claude Code under three setups, scored by the gate
sh proof/compare/report.sh                 # the comparison table from the results
lawbook check . --no-llm                   # the clean-code rules alone
lawbook test .                             # the prose standards against their fixtures
```

`/verify` runs the loop as a skill. The Stop hook in `.claude/settings.json`
runs it again at the end of every turn that changed something and blocks the
turn with the findings while the change is red. `BASE=<ref>` changes the base
from `origin/main`; `HUNK=0` skips the live Hunk session; `VERIFY_LLM=1|0`
forces or skips the model stage, which otherwise runs when a Bifrost gateway
answers at `BIFROST_URL` (default `http://localhost:8080`);
`LAWBOOK_CONFIG=lawbook.stub.yaml` judges with `proof/stub-judge.mjs`.

`/add-module <name> <what it decides>` scaffolds `src/<name>.js` and its test
in the shape of `shipping.js` and ends by running `/verify`. `/polish` runs
`/simplify`, then `/verify` until it exits 0, and reports the change ready to
commit; invoke it by hand. `.github/workflows/verify.yml` runs `verify.sh`
against the base branch on every pull request and the proofs on every push
to `main`, installing the tools with `HUNK=0 sh .claude/hooks/session-start.sh`.

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
- The deterministic loop never needs network access or credentials. The six
  prose standards in `lawbook.yaml` are judged on Bedrock by Haiku 4.5, with
  Sonnet 5.5 on the two standards that need the most judgment, through a
  Bifrost gateway that `session-start.sh` starts and configures from
  `AWS_REGION` plus credentials; lawbook holds no credentials, and the model
  ids carry the `bedrock/` prefix. They only warn. The session model
  stays the strong one: the judge answers, the session fixes. Each has pass and
  fail fixtures under `proof/fixtures/`; `lawbook test` checks the judge
  still agrees with them.
- When a scenario in `proof/scenarios/` stops being caught, the loop has a
  hole; fix the loop, not the scenario.
- A skill that produces code ends by running `/verify`; a skill that chains
  others names the order and runs `/verify` last. Neither commits.
- The workflow calls `verify.sh` and `session-start.sh`; the stage list and
  the install steps live there, not in YAML.
- Conventional Commit subjects. No AI attribution in commits.
