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
run at `level: warn` when a Bifrost gateway to Bedrock is up: names reveal
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
| `AWS_REGION=us-east-1` plus credentials | the SessionStart hook starts a [Bifrost](https://github.com/maximhq/bifrost) gateway at `http://localhost:8080` with that Bedrock key, and the stage runs on Bedrock with the judge named in `lawbook.yaml`: Haiku 4.5, Sonnet 5.5 on two standards |
| `VERIFY_LLM=1` / `VERIFY_LLM=0` | forces the stage on, or off, whether or not a gateway answers |
| `MAX_REQUESTS=20` | lawbook stops before the first request when a run would exceed it |
| `LAWBOOK_CONFIG=lawbook.stub.yaml` | judges with the local stub instead of a model |

Lawbook itself holds no credentials: it speaks Chat Completions to the
gateway, and the gateway holds the Bedrock key and names the model by its
`bedrock/` prefix. The hook writes the gateway's config to `.bifrost/` from
the environment, so any one of these works alongside the region:
`AWS_BEARER_TOKEN_BEDROCK` (a Bedrock API key, the simplest), access keys, or
a profile from `aws configure` or SSO. The identity needs
`bedrock:InvokeModel` and the model must be enabled for the account in that
region. In a Claude Code cloud session, add the region and the credential as
environment secrets in the environment's settings; the SessionStart hook
reports `bifrost up (http://localhost:8080, us-east-1)` or `bifrost off` in
its first line. A gateway running elsewhere needs `BIFROST_URL` for the
scripts and `baseUrl` under `llm` in `lawbook.yaml` for lawbook.

Before any run, `verify` prints the plan: `3 files, 5 model requests`. A
changed source file costs five requests (one per standard that selects it), a
changed test file one. lawbook caches verdicts by model, standard, path, and
content, so a rerun on untouched files costs nothing, and the usage line after
each run says how many requests were served from the cache.

### Which model judges

The judge and the session model are different jobs. A verdict is a bounded
question on one file with a fixed prompt and a JSON answer, and a wrong verdict
only warns, is cached, and shows up in the fixtures. The session model reads
the reason and changes code, where a mistake costs turns. So the judge is the
small, fast model and the session model is the strong one: `lawbook.yaml`
names Haiku 4.5 as the judge, with Sonnet 5.5 overriding it on the two
standards that need the most judgment, `functions-do-one-thing` and
`dependencies-are-injected`. Claude Code stays on its default model.

The arithmetic says the judge's price barely matters. A changed source file
is five requests of a few thousand tokens each, well under a cent on Haiku
and about a cent on Sonnet, against a session that costs dollars. What
matters is the judge's latency, because stage 5 sits in the loop, and its
false-fail rate, because a false "fail" costs a strong-model turn that
outweighs anything the cheaper judge saved. The per-rule override is the
knob for that, and `proof/judge-agreement.sh` is the evidence for setting
it: it judges the fixtures and the seven model scenarios under both judges
and prints the disagreements per standard.

Any OpenAI-compatible endpoint that supports JSON-schema output can be the
judge through lawbook's `openai` provider and a `baseUrl`, which is how
`lawbook.stub.yaml` plugs in the stub and how a non-Anthropic judge would.

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

Without `--stub`, the same script runs against Bedrock through the gateway
and the verdicts are the model's. The expectations are only "below the threshold" and "above the
threshold", because a probability can move between runs; the fixtures are
where a drift would show first. Run it yourself:

```sh
sh proof/prove-llm.sh      # with the gateway the SessionStart hook started
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

**Sonnet 5.5**

| Arm | Gate passed | Findings | Tests added | Mean turns | Mean time | Total cost | Steering per turn | Steering carried over the run |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A | 4 of 6 | 2 | 5 | 11.3 | 30s | $0.87 | 0.2 KB | 15 KB |
| B | 5 of 6 | 1 | 6 | 10.7 | 31s | $0.94 | 11.4 KB | 728 KB |
| C | 6 of 6 | 0 | 7 | 11.2 | 33s | $0.97 | 5.8 KB | 390 KB |

**Haiku 4.5**, the same tasks, arms, and gate

| Arm | Gate passed | Findings | Tests added | Mean turns | Mean time | Total cost | Steering per turn | Steering carried over the run |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A | 0 of 6 | 8 | 1 | 12.0 | 38s | $0.57 | 0.2 KB | 15 KB |
| B | 5 of 6 | 1 | 5 | 13.8 | 62s | $0.66 | 11.4 KB | 944 KB |
| C | 6 of 6 | 0 | 8 | 25.3 | 102s | $1.26 | 5.9 KB | 890 KB |

What the rows say, Sonnet first:

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

What changed with the smaller model:

- **Without steering, Haiku failed every task.** Eight findings in six
  cells: a refund function with four branches and 8% coverage (CRAP 16), a
  receipt at 7% coverage, `shippingTier` rewritten at complexity 7, loyalty
  points at complexity 6, the clock read inside the library, and `fs` read
  inside the library. One test file touched in six tasks. The agent's
  summaries say "all tests pass" each time, and they do; the tests it did not
  write are the problem.
- **The long steering file held up on the gate, and failed the same rule in
  the same way.** Five of six, as with Sonnet, and the one failure is again
  the tax task: a static JSON import, explained as keeping the library pure
  because "the JSON is loaded at module initialization, not via runtime file
  I/O". Two models, two runs, the same misreading of the same sentence. Prose
  was followed to the letter both times.
- **The loop passed all six, and this time it had to work for it.** Mean
  turns went from 11 to 25 and cost from $0.97 to $1.26, against $0.66 for
  the steering file. The hook fired in every cell; on the shipping task the
  agent needed 41 turns to get a seven-way function under the complexity
  ceiling with every path covered. That is the price of enforcement on a
  model that does not get it right the first time, and it is paid inside the
  agent's session rather than in review.
- **The loop is only as good as its rules, and the experiment found a hole.**
  Haiku's loop agent first satisfied the tax task with `import { readFileSync }
  from "fs"`, no `node:` prefix, and the regex only knew the prefixed form.
  The gate passed it. The rule is one line, so it now matches both spellings,
  every cell was rescored, and the cell was rerun: with the corrected rule the
  agent delivered the injected design, rates through `deps`, in 24 turns. A
  CLAUDE.md cannot be fixed that way, because there is nothing to fix; the
  sentence was already there.

What the rows cannot say, and the honest caveats:

- One run per cell. A model's compliance with prose is not deterministic, so
  arm B's 5 of 6 is one draw. The loop's 6 of 6 is not a draw: the hook does
  not let a red change end a turn. That asymmetry is the argument, and it
  holds whatever the model does on a given day.
- Sonnet 5.5 follows prose well; Haiku 4.5 less so. The gap between
  prompting and the loop went from two findings to eight when the model got
  smaller. The gap between the long steering file and the loop stayed at one
  finding on both models, the same finding, which says the difference there
  is not diligence but whether a rule can be made precise after it is
  misread. A larger codebase, where a 242-line CLAUDE.md competes with more
  context, is untested here.
- Two cells on Haiku's loop arm sit at complexity 5, the ceiling. Within the
  rule, and the closest the gate lets anything get.
- The gate scores what a regex and a coverage report can see. The six prose
  standards are not in the score, so the table understates what a model judge
  would add; `proof/prove-llm.sh` covers that stage.
- Rules on disk have properties the table has no column for: they are
  versioned, tested by `proof/prove.sh` and `lawbook test`, diff-scoped,
  apply to humans and CI, and a drift shows up as a failing scenario. A
  sentence in a CLAUDE.md has none of these.

Reproduce it with `sh proof/compare/compare.sh` (about five minutes per arm,
three arms in parallel) and `sh proof/compare/report.sh`. Another model:
`sh proof/compare/compare.sh --model claude-haiku-4-5`. One cell:
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
5  lawbook standards (model)     only when 1–4 are green and a Bifrost gateway answers, or VERIFY_LLM=1
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
user types /add-module <name>              ──►  skill scaffolds src/<name>.js and its test, then runs /verify until 0
user types /polish                         ──►  skill runs /simplify, then /verify until 0, then reports ready to commit
a pull request opens                       ──►  GitHub Actions runs verify.sh against the base branch; findings become annotations and an artifact
```

### Four ways in

One script, four ways to reach it: the four deployment patterns in
[Anthropic's post on verification loops](https://claude.com/blog/building-verification-loops-in-claude-code-with-skills).

| Pattern | Here | When |
| --- | --- | --- |
| Standalone | `/verify` | you, or Claude, want the verdict now |
| Embedded | `/add-module <name>` scaffolds a rule module and its test, then runs `/verify` until it exits 0 | a skill that produces code owns its own check |
| Chained | `/polish` runs `/simplify`, then `/verify` until 0, then reports ready to commit | adding the check to a skill you cannot edit, such as a bundled one |
| On every PR | `.github/workflows/verify.yml` runs `verify.sh` with `BASE=origin/$GITHUB_BASE_REF`, posts findings as annotations, uploads `.verify/*.json` | a teammate's change, or a human's, passes the same gate |

The two skills carry the loop to green themselves; the Stop hook is the
backstop behind them and costs 24 ms on a tree they left green. `/polish` is
user-invoked only (`disable-model-invocation: true`), because `/simplify`
spawns review agents and a chain should not start by itself. The workflow
installs the tools with the same `session-start.sh` a cloud session runs,
with `HUNK=0`, and runs `prove.sh` and `prove-llm.sh --stub` on every push to
`main`. A Claude in CI (`anthropics/claude-code-action@v1` with
`prompt: "Run /verify and fix only what it names until it exits 0"`) would
need an `ANTHROPIC_API_KEY` secret and would run without the project's hooks,
so it is not shipped here; the deterministic gate needs no secret at all.

| File | Role |
| --- | --- |
| `.claude/skills/verify/SKILL.md` | The `/verify` skill: the loop contract in four steps. Claude can invoke it on its own. |
| `.claude/skills/verify/scripts/verify.sh` | The six stages. The only place the order lives. |
| `.claude/skills/verify/scripts/to-hunk.jq` | Turns both reports into Hunk's `comment apply` batch and its `--agent-context` sidecar. |
| `.claude/hooks/verify-stop.sh` | Stop hook. Exits 0 when nothing changed or verify passes; otherwise emits `{"decision":"block","reason":…}` with verify's summary. The `stop_hook_active` guard means one forced round per turn; the skill carries the loop to green. |
| `.claude/hooks/session-start.sh` | SessionStart hook, and the workflow's install step. Installs poly-crap, lawbook, and hunk when missing (`HUNK=0` skips hunk; `POLY_CRAP_VERSION` and `LAWBOOK_REF` pin versions), fetches `origin/main`, prints one line that becomes Claude's context. |
| `.claude/settings.json` | Wires both hooks and pre-allows the commands the loop runs, so nothing prompts. |
| `.claude/skills/add-module/SKILL.md` | The `/add-module` skill: a rule module and its test in the shape of `shipping.js`, then `/verify` until 0. The embedded pattern. |
| `.claude/skills/polish/SKILL.md` | The `/polish` skill: `/simplify`, then `/verify` until 0, then a report. User-invoked only. The chained pattern. |
| `.github/workflows/verify.yml` | Every pull request: `verify.sh` against the base branch, findings as annotations, `.verify/*.json` as an artifact. Every push to `main`: `prove.sh` and `prove-llm.sh --stub`. |
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
`scale.sh`, `demo.sh`, `prove-llm.sh --stub`, and the 36-cell comparison on
two models as shown above; the Stop
hook's block output on a red tree and silence on a clean one; the SessionStart
hook's idempotent second run; and both Hunk paths against a real `hunk diff`
session under a pseudo-terminal, where `comment clear` plus `comment apply`
left exactly the current findings as live comments and the sidecar loaded as
review notes on the same lines. Not exercised: the Bedrock run of
`prove-llm.sh`; the container's AWS keys were not valid for Bedrock. The
request reached Bedrock and came back `401`, which is the whole path short of
a valid credential.

The three later ways in were exercised the same way. `prove.sh` and
`prove-llm.sh --stub` pass with `BASE=HEAD`, as the workflow runs them, and
`session-start.sh` installs the three tools in 30 seconds and is silent on a
second run. `/add-module` and `/polish` were run headlessly (`claude -p`, as
`proof/compare/compare.sh` does) in clones of this repo: `/add-module giftwrap
...` on Haiku 4.5 read the four reference files, wrote the module and its
test, ran `/verify` last, and reported green in 10 turns; `/polish` on a tree
carrying `demo.sh`'s red function ran `/simplify`, then `/verify`, added the
missing tests, and reported green in 20 turns on Sonnet 5.5, and in a first
Haiku 4.5 run ended red after treating `/verify` as a job to wait on and
leaving the helpers the split created untested, which is why the skill now
says to run the script in the same turn and to expect that finding; with that
wording, Haiku 4.5 went green in 32 turns. Neither skill committed. The workflow has not run on GitHub yet; its first pull
request is the test.
