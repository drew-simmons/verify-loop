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
5  lawbook standards (model)     only when 1–4 are green and AWS_REGION is set
6  findings → Hunk               clear the old comments, apply the new batch, write the sidecar
```

- **The exit code is the verdict, the JSON is the detail.** `0` clean. `1` a
  gate failed: read `.verify/crap.json` and `.verify/lawbook.json`, fix only
  what they name. `2` the loop itself is broken: a tool, ref, coverage file,
  or credential is missing. Fix the setup, not the code.
- **No model request on code that will change anyway.** Stage 5 runs only on
  a deterministic-green tree, under `--max-requests 20`, and lawbook caches
  verdicts by content.
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
| `lawbook.yaml` | The definition of clean, above. |
| `proof/` | `prove.sh`, `bench.sh`, `scale.sh`, and the eleven scenarios. |
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
`scale.sh`, and `demo.sh` as shown above; the Stop hook's block output on a
red tree and silence on a clean one; the SessionStart hook's idempotent
second run; and both Hunk paths against a real `hunk diff` session under a
pseudo-terminal, where `comment clear` plus `comment apply` left exactly the
current findings as live comments and the sidecar loaded as review notes on
the same lines. Not exercised: the Bedrock stage, which needs credentials; it
degrades to a skip message without them.
