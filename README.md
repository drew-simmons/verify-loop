# verify-loop

A worked example of a fast verification loop for Claude Code, and the proof
that it works. Three tools look at the same change and answer three different
questions, and one script turns their answers into a single exit code:

| Tool | Question | Cost per run |
| --- | --- | --- |
| [poly-crap](https://github.com/drew-simmons/poly-crap) | Did this change leave a complex function under-tested? | ~20 ms once coverage exists; it parses only the changed files |
| [lawbook](https://github.com/drew-simmons/lawbook) | Does this change break a rule of clean code? | ~300 ms for regex and path rules; one cached model request per changed file for prose standards, opt-in |
| [Hunk](https://github.com/modem-dev/hunk) | Can the human see the findings on the exact lines, live? | ~20 ms; `hunk diff --watch` reloads on every write |

The loop is: **edit → `verify` → findings appear in Hunk and in JSON → fix only
what is named → repeat until exit 0 → commit.** On this project a full run
takes about 1.2 seconds, and a rerun on an unchanged tree takes 24 ms.

```sh
git clone https://github.com/drew-simmons/verify-loop && cd verify-loop
sh .claude/hooks/session-start.sh   # installs poly-crap, lawbook, hunk if missing
sh demo.sh                          # red → green → cached in 60 seconds
sh proof/prove.sh                   # eleven mistakes, each caught; one correct change, passed
```

## The example project

`src/` is an order-processing library in plain ESM JavaScript with no
dependencies: `errors`, `validate`, `money`, `catalog`, `cart`, `pricing`,
`tax`, `shipping`, `inventory`, and `orders`. `placeOrder` composes the rest
and takes `now()` and `nextId()` through a `deps` argument, so nothing in
`src/` reads the clock. Lookup tables replace `if` chains. Every one of its 30
functions has cyclomatic complexity 5 or below, every branch is covered by the
39 tests in `test/`, and every exported function has a doc comment. It is
small enough to read in ten minutes and real enough that the mistakes below
are the ones people make.

## What clean means here

`lawbook.yaml` is the definition, as rules the loop checks on every change.
The deterministic rules always run and cost milliseconds:

| Rule | Catches | Why |
| --- | --- | --- |
| `no-console` | `console.` in `src/` | library code does not print; callers decide what to log |
| `library-does-no-io` | `node:fs`, `fetch(`, `process.env`, `Date.now()`, `new Date(` in `src/` | the library is pure; the caller owns time, files, and the network |
| `no-empty-catch` | `catch {}` | errors are handled or passed up, never swallowed |
| `no-eval` | `eval(`, `new Function(` | no code built from strings |
| `no-nested-ternary` | two `?` operators on one line | one decision per expression |
| `no-default-export` | `export default` | named exports are greppable and refactorable |
| `exports-are-documented` | an `export function` not preceded by `*/` | every public function says what it does |
| `no-loose-equality` | `==`, `!=` | strict comparison only |
| `no-var` | `var` | block scope only |
| `no-orphan-todos` | `TODO` without `#123`, `ABC-12`, or a URL | work is tracked |
| `has-readme`, `has-tests`, `no-env-file` | missing README or tests, a committed `.env` or `.pem` | the tree is complete and holds no secrets |

Six prose standards adapted from lawbook's
[clean-code example](https://github.com/drew-simmons/lawbook/blob/main/examples/clean-code.lawbook.yaml)
run at `level: warn` when `AWS_REGION` is set for Bedrock: names reveal
intent, functions do one thing, guard clauses over nesting, errors are
handled not hidden, dependencies are injected, tests describe behaviour.
They cost one model request per changed file and never run on a tree that
failed a deterministic stage.

poly-crap adds the rule no regex can express: a function fails when its
CRAP score is above 5. CRAP is `cc² × (1 − coverage)³ + cc`, so an untested
four-branch function scores 20, and a fully tested seven-branch function
still scores 7. Tests alone do not make a tangled function safe.

## Proof

Three tables, reproduced from real runs in a 4-CPU Linux container with
Node 22. Run the scripts to reproduce them on your machine.

### Confidence: `proof/prove.sh`

Each scenario edits the tree the way a developer might, runs `verify`,
checks the exit code and the exact finding, and reverts.

| # | A developer... | Exit | Caught by | Time |
| --- | --- | --- | --- | --- |
| 00 | adds giftWrapFee() to pricing with a doc comment and a test | 0 | passes | 1.1s |
| 01 | adds refundFor() with four branches and no test | 1 | poly-crap: refundFor CRAP 24.3 | 1.1s |
| 02 | rewrites shippingTier as one seven-path function and tests every path | 1 | poly-crap: shippingTier CC 7, CRAP 7 at 100% coverage; tests pass | 1.1s |
| 03 | wraps findProduct in try/catch {} so unknown skus price at zero | 1 | lawbook: no-empty-catch src/pricing.js:17 | 1.1s |
| 04 | compares the discount code with == instead of === | 1 | lawbook: no-loose-equality src/tax.js:12 | 1.1s |
| 05 | leaves console.log in placeOrder | 1 | lawbook: no-console src/orders.js:28 | 1.2s |
| 06 | writes // TODO handle currencies without filing an issue | 1 | lawbook: no-orphan-todos src/money.js:23 | 1.1s |
| 07 | exports isTaxFree() from tax.js with no doc comment, and tests it | 1 | lawbook: exports-are-documented src/tax.js | 1.1s |
| 08 | reads tax rates from a file and stamps orders with Date.now() | 1 | lawbook: library-does-no-io src/orders.js:34, src/tax.js:1 | 1.1s |
| 09 | deletes the two test files that exercise shipping and touches no source file | 1 | poly-crap (full scan): shippingTier CRAP 20, weightTier CRAP 12 | 1.0s |
| 10 | changes California's tax rate without updating the expectation | 1 | node:test: 3 failing test(s), stage 3 | 1.1s |

Two rows carry the argument. Row 02 is the one coverage alone misses: the
tests pass, coverage is 100%, and the gate still fails, because a seven-way
function is a maintenance cost whatever its tests say. Row 09 is the one a
diff-scoped tool misses: deleting a test changes no source file, so
`--diff-base` would see nothing; `verify` notices the change under `test/`
and scores every function instead.

### Speed: `proof/bench.sh`

| Stage | Cold, correct change | Red, untested function |
| --- | --- | --- |
| 1  syntax (node --check on changed files) | 89 ms | 38 ms |
| 2  lawbook, deterministic rules on changed files | 345 ms | 310 ms |
| 3  tests with coverage | 750 ms | 712 ms |
| 4  poly-crap on changed functions (threshold 5) | 19 ms | 33 ms |
| 5  lawbook, model-judged standards | 5 ms | 2 ms |
| 6  findings to Hunk | 18 ms | 17 ms |
| **whole loop** | **1244 ms** | **1127 ms** |
| unchanged since last green run | 24 ms | |

The test run is the only stage that costs real time. The two gates together
cost under 400 ms, most of it lawbook's Node startup. The last row is the
stamp: `verify` hashes the change and returns at once when that hash already
passed, so Claude's Stop hook costs nothing on a turn that changed nothing.

### Scale: `proof/scale.sh 10 50 200`

The script clones the repository, adds N generated clean modules with tests,
commits them, applies the correct change from scenario 00, and times the loop.

| Modules | Test files | Stage 2 lawbook | Stage 3 tests + coverage | Stage 4 poly-crap | Whole loop |
| --- | --- | --- | --- | --- | --- |
| 20 | 21 | 318 ms | 1292 ms | 17 ms | 1729 ms |
| 60 | 61 | 363 ms | 2527 ms | 21 ms | 3008 ms |
| 210 | 211 | 305 ms | 7724 ms | 45 ms | 8179 ms |

The gates stay flat because they scope to the change: lawbook reads only the
changed files, poly-crap parses only the changed files and scores only the
changed functions. The test run grows linearly because node:test runs each
file in its own process; that is the one knob a larger project would turn
(`--test-isolation=none`, or a test selection step), and the loop's design
does not change.

## Verifying with a model

The six prose standards in `lawbook.yaml` catch what no regex can: a vague
name, a function doing two things, nesting where guard clauses belong, an
error turned into `null`, a dependency reached for inside a function, a test
named after the function it calls. A model judges each changed file against
each standard and answers with a probability (lawbook calls it a noul) and a
reason. A file below the threshold is a warning with the model's reason as
the message, so you read why before you change anything. They warn rather
than fail on purpose: a model's verdict is evidence, not a verdict of record.

Stage 5 runs only when the deterministic stages are green, so no request is
spent on code that is about to change anyway, and only when you opt in:

| Setting | Effect |
| --- | --- |
| `AWS_REGION=us-east-1` | runs the stage with Sonnet 5.5 on Bedrock (`anthropic.claude-sonnet-5-5`, set in `lawbook.yaml`) |
| `VERIFY_LLM=1` / `VERIFY_LLM=0` | forces the stage on, or off, whatever the region says |
| `MAX_REQUESTS=20` | lawbook stops before the first request when a run would exceed it |
| `LAWBOOK_CONFIG=lawbook.stub.yaml` | judges with the local stub instead of a model |

Credentials come from the AWS chain, so any one of these works alongside the
region: `AWS_BEARER_TOKEN_BEDROCK` (a Bedrock API key, the simplest), access
keys, or a profile from `aws configure` or SSO. The identity needs
`bedrock:InvokeModel` and the model must be enabled for the account in that
region. In a Claude Code cloud session, add the region and the credential as
environment secrets in the environment's settings; the SessionStart hook
reports `bedrock ready (us-east-1)` or `bedrock off` in its first line.

Before any run, `verify` prints the plan: `3 files, 5 model requests`. A
changed source file costs five requests (one per standard that selects it), a
changed test file one. lawbook caches verdicts by model, standard, path, and
content, so a rerun on untouched files costs nothing, and the usage line after
each run says how many requests were served from the cache.

### The fixtures: does the judge agree with a human?

Each standard has a pass file and a fail file under `proof/fixtures/`, each an
example where no reasonable reader would disagree. `lawbook test .` judges all
twelve and exits 1 if one lands on the wrong side of its threshold. That is
the regression test for the standards themselves: when you reword a standard
or change the model, run it.

### The proof: `proof/prove-llm.sh`

Seven scenarios edit the tree with a mistake the regexes cannot see (or, for
the last one, a clean change), run `verify`, and check that the named
standard warned on the changed file and nothing else broke. Then the clean
change is judged twice to show the second run is free.

With `--stub` the judge is `proof/stub-judge.mjs`, a 60-line local server
speaking the chat-completions shape lawbook's `openai` provider expects. It
answers 0.1 for a file carrying the marker comment or a fail fixture and 0.9
otherwise, so the run is deterministic and needs no credentials. It proves the
plumbing: the request, the JSON answer, the `warn` status, the noul in the
Hunk comment, the cache.

```text
| # | A developer... | Standard | Verdict | Requests | Time |
| --- | --- | --- | --- | --- | --- |
| 11 | adds calc(data, tmp) with obj and helper to money.js | names-reveal-intent | warned, noul 0.1 | 5 | 2.1s |
| 12 | adds totalAndFormat() that prices the cart and builds the receipt string | functions-do-one-thing | warned, noul 0.1 | 5 | 2.2s |
| 13 | adds canReserve() as four nested ifs, fully tested | guard-clauses-over-nesting | warned, noul 0.1 | 6 | 2.4s |
| 14 | adds findProductOrNull() that swallows the not-found error, with tests | errors-are-handled-not-hidden | warned, noul 0.1 | 6 | 2.3s |
| 15 | adds newOrderId() that calls Math.random() itself instead of taking an id source | dependencies-are-injected | warned, noul 0.1 | 5 | 2.2s |
| 16 | renames the tax tests to taxRate, taxFor, and works | tests-describe-behavior | warned, noul 0.1 | 1 | 2.3s |
| 17 | adds giftWrapFee() to pricing with a doc comment and a test | all six | every standard passed | 6 | 2.1s |
```

Without `--stub`, the same script runs against Bedrock and the verdicts are
the model's. The expectations are only "below the threshold" and "above the
threshold", because a probability can move between runs; the fixtures are
where a drift would show first. Run it yourself:

```sh
AWS_REGION=us-east-1 sh proof/prove-llm.sh
```

The build environment for this repository had no Bedrock access, so the
Bedrock run of this proof has not been recorded here yet. Everything up to the
HTTP call is exercised by the stub run above.

## Proof: against prompting alone and against a long steering file

The claim that matters for adoption is not that the loop catches mistakes. It
is that an enforced loop produces cleaner code than the two things teams do
today: prompt Claude Code and hope, or write a long CLAUDE.md. So
`proof/compare/compare.sh` gives the same six feature requests to Claude Code
headlessly under three setups and scores every result with the same gate.

| Arm | What the agent gets |
| --- | --- |
| **A** prompt only | `src/`, `test/`, a 15-line README, a 10-line CLAUDE.md with the commands. No rules anywhere. |
| **B** long steering file | the same, plus a 242-line CLAUDE.md: every rule in this repository as prose, lawbook's clean-code standards as instructions, the CRAP ceiling, "run coverage before you finish". No gate. |
| **C** the loop | this repository as committed: the 57-line CLAUDE.md, the `/verify` skill, the Stop hook, the rules on disk. |

The tasks are the requests a product owner would write, and none mentions
tests, complexity, or rules: refunds by reason, express on freight, a
diagnostic record when stock runs out, tax rates moved to a JSON file, loyalty
points with tier multipliers, a printable receipt. Each invites one of the
mistakes the loop exists to catch. Same model in every arm (Sonnet 5.5), one
run per cell, scored by the deterministic gate only, so no result rests on a
model's opinion. The full table with per-task rows is in
`proof/compare/results.md`; the raw diffs, transcripts, and verify logs are
under `proof/compare/results/`.

| Arm | Gate passed | Findings | Tests added | Mean turns | Mean time | Total cost | Steering per turn | Steering carried over the run |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A | 4 of 6 | 2 | 5 | 11.3 | 30s | $0.87 | 0.2 KB | 15 KB |
| B | 5 of 6 | 1 | 6 | 10.7 | 31s | $0.94 | 11.4 KB | 728 KB |
| C | 6 of 6 | 0 | 7 | 11.2 | 33s | $0.97 | 5.8 KB | 390 KB |

What the rows say:

- **Prompting alone let two of six changes through red.** The diagnostic task
  got a `console.warn` in the library; the tax task got `node:fs` in the
  library. Both agents wrote tests and kept complexity low. The mistakes were
  design mistakes, the kind nobody notices in review until the library is
  running somewhere it cannot print or read a file.
- **The long steering file let one through, and it was the rule it had just
  read.** Arm B's CLAUDE.md says "never import `node:fs`" and "the library is
  pure". The agent obeyed the letter and reached for a static JSON import of a
  file at the repo root, then explained that it had avoided `node:fs` because
  the rules keep `src/` pure. Prose was followed and the intent was lost. The
  gate caught it, because a rule on disk can be made precise after the fact
  (that import is now in the regex), and a sentence in a CLAUDE.md cannot.
- **The loop let nothing through, and the Stop hook fired in every cell.** On
  the tax task the agent read the rule on disk, named it in its summary, and
  delivered the design the rule asks for: the rates table as a parameter,
  the file loader outside `src/`, and `placeOrder` taking the rates through
  `deps`. That cost 16 turns against B's 10 and A's 9. The extra turns are
  the price of the design being right; it is also the only cell where the
  arms differ in time by more than a few seconds.
- **The cost is the same.** Six tasks cost $0.87, $0.94, and $0.97. Enforcement
  is not more expensive than hoping; it moves a few turns from the human's
  review to the agent's session.
- **The steering file is paid for on every turn.** Arm B carried 11.4 KB of
  instructions into each of 64 turns, 728 KB in all, for the one rule it then
  misread. Arm C carries a 3 KB CLAUDE.md and a 2.7 KB skill description; the
  183-line `lawbook.yaml` costs nothing until the gate runs it.

What the rows cannot say, and the honest caveats:

- One run per cell. A model's compliance with prose is not deterministic, so
  arm B's 5 of 6 is one draw. The loop's 6 of 6 is not a draw: the hook does
  not let a red change end a turn. That asymmetry is the argument, and it
  holds whatever the model does on a given day.
- Sonnet 5.5 follows prose well. Arm A's agents wrote tests and small
  functions without being told. The gap between prompting and the loop is in
  design rules, not in diligence, and it would be wider with a smaller model
  or a larger codebase where a 242-line CLAUDE.md competes with more context.
- The gate scores what a regex and a coverage report can see. The six prose
  standards are not in the score, so the table understates what a model judge
  would add; `proof/prove-llm.sh` covers that stage.
- Rules on disk have properties the table has no column for: they are
  versioned, tested by `proof/prove.sh` and `lawbook test`, diff-scoped,
  apply to humans and CI, and a drift shows up as a failing scenario. A
  sentence in a CLAUDE.md has none of these.

Reproduce it with `sh proof/compare/compare.sh` (about five minutes per arm,
three arms in parallel) and `sh proof/compare/report.sh`. One cell:
`sh proof/compare/compare.sh C --tasks 04`.

## How the loop works

Every stage scopes to the merge base of `origin/main` and `HEAD`, compared
against the working tree, including uncommitted and untracked files.
poly-crap gets that from `--diff-base`, lawbook from `--changed --since`, and
Hunk's `diff` view is the working tree, so work stays uncommitted during the
loop and is committed when `verify` exits 0. `BASE=<ref>` overrides the base;
when `origin/main` does not exist, `main` is used.

```text
1  node --check                  changed files only
2  lawbook --no-llm              regex and path rules on changed files
3  node --test with coverage     THE SLOW STEP; writes lcov.info
4  poly-crap --fail-above        CRAP > 5 in any changed function; every function when a test changed
5  lawbook standards (model)     only when 1–4 are green and AWS_REGION or VERIFY_LLM=1 is set
6  findings → Hunk               clear the old comments, apply the new batch, write the sidecar
```

- **The exit code is the verdict, the JSON is the detail.** `0` clean. `1` a
  gate failed: read `.verify/crap.json` and `.verify/lawbook.json`, fix only
  what they name. `2` the loop itself is broken: a tool, ref, coverage file,
  or credential is missing. Fix the setup, not the code.
- **No model request on code that will change anyway.** Stage 5 runs only on
  a deterministic-green tree, prints its plan first, stops at
  `--max-requests 20`, and lawbook caches verdicts by content.
- **Comments are idempotent.** Each run clears Hunk's comments and applies the
  current set. `.verify/notes.json` holds the same findings in Hunk's sidecar
  format for `hunk diff --agent-notes --agent-context .verify/notes.json`.

## How it hooks into Claude Code

```text
user types /verify, or Claude decides to   ──►  skill runs verify.sh; Claude reads .verify/*.json, fixes, reruns
Claude ends a turn                         ──►  Stop hook runs verify.sh; red = the turn continues with the findings
a new cloud session starts                 ──►  SessionStart installs the tools and fetches origin/main
a human in a terminal                      ──►  hunk diff --watch; comments arrive when each turn ends
```

| File | Role |
| --- | --- |
| `.claude/skills/verify/SKILL.md` | The `/verify` skill: the loop contract in four steps. Claude can invoke it on its own. |
| `.claude/skills/verify/scripts/verify.sh` | The six stages. The only place the order lives. |
| `.claude/skills/verify/scripts/to-hunk.jq` | Turns both reports into Hunk's `comment apply` batch and its `--agent-context` sidecar. |
| `.claude/hooks/verify-stop.sh` | Stop hook. Exits 0 when nothing changed or verify passes; otherwise emits `{"decision":"block","reason":…}` with verify's summary. The `stop_hook_active` guard means one forced round per turn; the skill carries the loop to green. |
| `.claude/hooks/session-start.sh` | SessionStart hook. Installs poly-crap, lawbook, and hunk when missing, fetches `origin/main`, prints one line that becomes Claude's context. |
| `.claude/settings.json` | Wires both hooks and pre-allows the commands the loop runs, so nothing prompts. |
| `lawbook.yaml` | The definition of clean, above, with pass and fail fixtures for each prose standard. |
| `lawbook.stub.yaml`, `proof/stub-judge.mjs` | The same rules judged by a local stub, for smoke-testing the model stage with no credentials. |
| `.poly-crap.toml` | Keeps `proof/` out of poly-crap's scoring. |
| `proof/` | `prove.sh`, `bench.sh`, `scale.sh`, `prove-llm.sh`, the eighteen scenarios, the fixtures, and `compare/` (the three-arm experiment, its tasks, arms, runner, scorer, and results). |
| `demo.sh` | The 60-second story: red, green, cached. |

Findings become Hunk comments through one jq filter. A poly-crap entry over
the threshold becomes a comment at its start line reading
`CRAP 24.3 · CC 4 · no coverage · refundFor`; a lawbook finding becomes one
at its line reading `[no-console] remove the console call; return a value or throw instead`.

## Adapting it

Stages 1 and 3 are the only stack-specific lines in `verify.sh`. For a
TypeScript project they become `tsc --noEmit` and `vitest run --coverage`; for
Rust, `cargo clippy` and `cargo llvm-cov --lcov`. poly-crap reads LCOV,
Cobertura, JaCoCo, and Go profiles. The rules in `lawbook.yaml` are regexes;
change the globs and keep the ones you agree with. The scenarios in
`proof/scenarios/` are the loop's own tests: when one stops being caught, the
loop has a hole.

## Status

Verified end to end in a Linux container: `prove.sh`, `bench.sh`,
`scale.sh`, `demo.sh`, `prove-llm.sh --stub`, and the 18-cell comparison as
shown above; the Stop
hook's block output on a red tree and silence on a clean one; the SessionStart
hook's idempotent second run; and both Hunk paths against a real `hunk diff`
session under a pseudo-terminal, where `comment clear` plus `comment apply`
left exactly the current findings as live comments and the sidecar loaded as
review notes on the same lines. Not exercised: the Bedrock run of
`prove-llm.sh`; the container's AWS keys were not valid for Bedrock. The
request reached Bedrock and came back `401`, which is the whole path short of
a valid credential.
