# CLAUDE.md

A worked example of a verification loop for Claude Code: poly-crap, lawbook,
and Hunk on one definition of the change, behind one script with one exit
code. `src/` is the project the loop verifies; the loop itself is the
[factory](https://github.com/drew-simmons/factory) plugin, and this repository
owns its configuration (`.factory/config.sh`, `lawbook.yaml`) and the
proofs; `proof/` shows the loop catching real mistakes, how long it takes, how it
scales, and (in `proof/compare/`) how it fares against prompting alone and
against a long steering file.

## Commands

```sh
npm test                                   # node:test, 39 tests
npm run coverage                           # tests + lcov.info
sh .factory/verify                         # the loop: exit 0 clean, 1 gate failed, 2 broken
sh demo.sh                                 # red → green → cached in 60 seconds
sh proof/prove.sh                          # 11 scenarios, each caught or passed as expected
sh proof/bench.sh                          # stage-by-stage timings
sh proof/scale.sh 10 50 200                # timings as the codebase grows
sh proof/prove-llm.sh --stub               # the model stage end to end, no credentials
AWS_REGION=us-east-1 sh proof/prove-llm.sh # the same on Bedrock with the judge in lawbook.yaml
AWS_REGION=us-east-1 sh proof/judge-agreement.sh   # Haiku vs Sonnet as judge, per standard
sh proof/compare/compare.sh [A|B|C] [--tasks 01,05] [--model claude-haiku-4-5]   # headless Claude Code under three setups, scored by the gate
sh proof/compare/report.sh                 # the comparison table from the results
lawbook check . --no-llm                   # the clean-code rules alone
lawbook test .                             # the prose standards against their fixtures
```

`/factory:verify` runs the loop as a skill; `.factory/verify` is a shim
that finds the installed plugin (or `FACTORY_ROOT`, a checkout of its
`plugins/factory` directory) and runs the same script. The plugin's Stop
hook runs it again at the end of every turn that changed something and
blocks the turn with the findings while the change is red; its SessionStart
hook installs poly-crap, lawbook, and hunk. `.claude/settings.json` pins the
plugin for every clone. `BASE=<ref>` changes the base from `origin/main`;
`HUNK=0` skips the live Hunk session; `VERIFY_LLM=1|0` forces or skips the
model stage, which otherwise runs when `AWS_REGION` is set;
`LAWBOOK_CONFIG=lawbook.stub.yaml` judges with `proof/stub-judge/claude`, a
stand-in `claude` CLI the proofs put first on `PATH`.

`/add-module <name> <what it decides>` scaffolds `src/<name>.js` and its test
in the shape of `shipping.js` and ends by running `/factory:verify`. The
plugin's `/factory:review` is the chained pattern (`/simplify`, the gate,
`/code-review`, the gate); `/factory:work` is the entry point for any task.
`.github/workflows/verify.yml` runs the gate through the plugin's action
against the base branch on every pull request, and the proofs on every push
to `main` with a checkout of the plugin as `FACTORY_ROOT`.

## The example project

An order-processing library in plain ESM JavaScript with no dependencies.
`errors`, `validate`, and `money` are the foundations; `catalog`, `cart`,
`pricing`, `tax`, `shipping`, and `inventory` are independent rules;
`orders.placeOrder` composes them and takes `now()` and `nextId()` through
its `deps` argument so nothing in `src/` reads the clock. Lookup tables
replace `if` chains. One test file per module in `test/`.

## Conventions

- Run `/factory:verify` before committing. A function fails above CRAP 5, so keep
  complexity at 5 or below and cover every branch. A fully tested function
  with complexity 7 still fails; split it.
- `lawbook.yaml` is the definition of clean here: no console, no I/O, no
  empty catch, no `==`, no `var`, no nested ternary, no default export, a
  doc comment on every export, an issue on every TODO. Read it before
  arguing with a finding.
- The deterministic loop never needs network access or credentials. The six
  prose standards in `lawbook.yaml` are judged on Bedrock by Haiku 4.5, with
  Sonnet 5 on the three standards that need the most judgment; opt in
  through `AWS_REGION` plus credentials; they only warn. The session model
  stays the strong one: the judge answers, the session fixes. Each has pass and
  fail fixtures under `proof/fixtures/`; `lawbook test` checks the judge
  still agrees with them.
- When a scenario in `proof/scenarios/` stops being caught, the loop has a
  hole; fix the loop, not the scenario.
- A skill that produces code ends by running `/factory:verify`; a skill that
  chains others names the order and runs `/factory:verify` last. Neither
  commits.
- The stage list lives in the plugin's `verify.sh` and the stack lines in
  `.factory/config.sh`, not in YAML. A change to the stages is a change to
  the plugin; `proof/` is what proves it still works.
- Conventional Commit subjects. No AI attribution in commits.
