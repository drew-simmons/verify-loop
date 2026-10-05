# Results: the loop against prompting and long steering files

Same six tasks, same gate, one run per cell, one table per model.
Gate: 0 passed, 1 a gate failed, 2 the gate could not run (for example, tests that no longer start).

## Across models

| Model | Arm | Gate passed | Findings | Caught by | Tests added | Mean turns | Mean time | Total cost |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| claude-sonnet-5-5 | A | 4 of 6 | 2 | no-console; library-does-no-io | 5 | 11.3 | 30s | $0.87 |
| claude-sonnet-5-5 | B | 5 of 6 | 1 | library-does-no-io | 6 | 10.7 | 31s | $0.94 |
| claude-sonnet-5-5 | C | 6 of 6 | 0 | - | 7 | 11.2 | 33s | $0.97 |

## claude-sonnet-5-5

| Arm | Task | Gate | Caught by | Tests added | Max CC | Min coverage | Lines | Turns | Time | Cost | Hook fired |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A | 01-refund | 0 | - | 1 | 4 | 100% | +31 | 13 | 33s | $0.16 | n/a |
| A | 02-express-freight | 0 | - | 1 | 5 | 100% | +15 | 7 | 19s | $0.09 | n/a |
| A | 03-diagnostic-log | 1 | no-console | 1 | 4 | 100% | +14 | 8 | 24s | $0.12 | n/a |
| A | 04-tax-config | 1 | library-does-no-io | 0 | - | - | +11 | 9 | 22s | $0.11 | n/a |
| A | 05-loyalty-points | 0 | - | 1 | 4 | 100% | +44 | 13 | 35s | $0.16 | n/a |
| A | 06-receipt | 0 | - | 1 | 4 | 100% | +35 | 18 | 47s | $0.23 | n/a |
| B | 01-refund | 0 | - | 1 | 4 | 100% | +40 | 12 | 29s | $0.15 | n/a |
| B | 02-express-freight | 0 | - | 1 | 4 | 100% | +35 | 6 | 22s | $0.11 | n/a |
| B | 03-diagnostic-log | 0 | - | 1 | 4 | 100% | +12 | 7 | 20s | $0.11 | n/a |
| B | 04-tax-config | 1 | library-does-no-io | 1 | 4 | 100% | +16 | 10 | 28s | $0.14 | n/a |
| B | 05-loyalty-points | 0 | - | 1 | 4 | 100% | +66 | 16 | 45s | $0.2 | n/a |
| B | 06-receipt | 0 | - | 1 | 4 | 100% | +60 | 13 | 43s | $0.22 | n/a |
| C | 01-refund | 0 | - | 1 | 4 | 100% | +39 | 11 | 26s | $0.13 | yes |
| C | 02-express-freight | 0 | - | 1 | 3 | 100% | +17 | 8 | 26s | $0.12 | yes |
| C | 03-diagnostic-log | 0 | - | 1 | 4 | 100% | +26 | 8 | 29s | $0.16 | yes |
| C | 04-tax-config | 0 | - | 2 | 4 | 100% | +44 | 16 | 44s | $0.21 | yes |
| C | 05-loyalty-points | 0 | - | 1 | 4 | 100% | +51 | 10 | 35s | $0.16 | yes |
| C | 06-receipt | 0 | - | 1 | 4 | 100% | +48 | 14 | 40s | $0.19 | yes |

| Arm | Gate passed | Findings | Tests added | Mean turns | Mean time | Total cost | Steering per turn | Steering carried over the run |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A | 4 of 6 | 2 | 5 | 11.3 | 30s | $0.87 | 0.2 KB | 15 KB |
| B | 5 of 6 | 1 | 6 | 10.7 | 31s | $0.94 | 11.4 KB | 728 KB |
| C | 6 of 6 | 0 | 7 | 11.2 | 33s | $0.97 | 5.8 KB | 390 KB |

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
