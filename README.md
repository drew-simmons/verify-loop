# verify-loop

A worked example of a fast verification loop for Claude Code. Three tools look
at the same change and answer three different questions, and one script turns
their answers into a single exit code:

| Tool | Question | Cost per run |
| --- | --- | --- |
| [poly-crap](https://github.com/drew-simmons/poly-crap) | Did this change leave a complex function under-tested? | milliseconds once coverage exists; it parses only the changed files |
| [lawbook](https://github.com/drew-simmons/lawbook) | Does this change break a repository rule? | milliseconds for regex and path rules; one cached model request per changed file for prose standards |
| [Hunk](https://github.com/modem-dev/hunk) | Can the human see the findings on the exact lines, live? | milliseconds; `hunk diff --watch` reloads on every write |

The loop is: **edit → `verify` → findings appear in Hunk and in JSON → fix only
what is named → repeat until exit 0 → commit.**

The code in `src/` is a toy pricing module. It exists so there is something to
verify. Everything under `.claude/` is the example.

## Quick start

```sh
git clone https://github.com/drew-simmons/verify-loop && cd verify-loop
sh .claude/hooks/session-start.sh   # installs poly-crap, lawbook, hunk if missing
sh demo.sh                          # red → green → cached; prints "demo: PASS"
```

`demo.sh` adds an untested, over-complex function with a `console.log`, shows
`verify` exit 1 naming it in both reports, then splits the function, covers
every branch, and shows exit 0. A third run returns at once because nothing
changed.

To watch it in Hunk, open a second terminal first:

```sh
hunk diff --watch
```

The comments land in that window at the end of every `verify` run. `verify`
also writes the same findings to `.verify/notes.json`, Hunk's sidecar format,
so without a live session you can open them later with
`hunk diff --agent-notes --agent-context .verify/notes.json`.

## One definition of "the change"

Every stage scopes to the merge base of `origin/main` and `HEAD`, compared
against the working tree, including uncommitted and untracked files.

- poly-crap gets that from `--diff-base origin/main`.
- lawbook gets the same set from `--changed --since origin/main`; the two
  selectors union.
- Hunk's `diff` view is the working tree, so work stays uncommitted during the
  loop and is committed when `verify` exits 0.

`BASE=<ref>` overrides the base. When `origin/main` does not exist, `main` is
used, so the demo works before the repository has a remote.

## The stages, cheapest first

```text
1  node --check                  syntax, well under a second
2  lawbook --no-llm              regex and path rules on changed files
3  node --test with coverage     THE SLOW STEP; writes lcov.info
4  poly-crap --fail-above        CRAP > 5 in any changed function
5  lawbook standards (model)     ONLY when 1–4 are green, and only when opted in
6  findings → Hunk               clear the old comments, apply the new batch
```

Three rules keep it fast and repeatable:

- **No model request on code that will change anyway.** Stage 5 runs only on
  a deterministic-green tree, only when `AWS_REGION` is set for Bedrock, and
  under `--max-requests 20`. lawbook caches verdicts by content, so a rerun on
  untouched files is free.
- **Comments are idempotent.** Each run clears Hunk's comments and applies the
  current set, so the diff shows the present state, not history.
- **The exit code is the verdict, the JSON is the detail.** `0` clean. `1` a
  gate failed: read `.verify/crap.json` and `.verify/lawbook.json`, fix only
  what they name. `2` the loop itself is broken: a tool, ref, coverage file,
  or credential is missing. Fix the setup, not the code.

A fourth rule keeps repeat runs free: `verify` hashes the change and exits at
once if that hash already passed (`.verify/green`).

## How it hooks into Claude Code

```text
user types /verify, or Claude decides to   ──►  skill runs verify.sh; Claude reads .verify/*.json, fixes, reruns
Claude ends a turn                         ──►  Stop hook runs verify.sh; red = the turn continues with the findings
a new cloud session starts                 ──►  SessionStart installs the tools and fetches origin/main
a human in a terminal                      ──►  hunk diff --watch; comments arrive when each turn ends
```

| File | Role |
| --- | --- |
| `.claude/skills/verify/SKILL.md` | The `/verify` skill. The loop contract in four steps; Claude can invoke it on its own. |
| `.claude/skills/verify/scripts/verify.sh` | The six stages. The only place the order lives. |
| `.claude/skills/verify/scripts/to-hunk.jq` | Turns both reports into Hunk's `comment apply` batch or its `--agent-context` sidecar. |
| `.claude/hooks/verify-stop.sh` | Stop hook. Exits 0 when nothing changed or verify passes; otherwise emits `{"decision":"block","reason":…}` with verify's summary. The `stop_hook_active` guard means one forced round per turn; the skill carries the loop to green. |
| `.claude/hooks/session-start.sh` | SessionStart hook. Installs poly-crap, lawbook, and hunk when missing, fetches `origin/main`, and prints one line that becomes Claude's context. |
| `.claude/settings.json` | Wires both hooks and pre-allows the commands the loop runs, so nothing prompts. |
| `lawbook.yaml` | Four deterministic rules and one warn-level prose standard. |
| `demo.sh` | The repeatable proof. |

### Findings become Hunk comments

Hunk's batch schema is `{"comments":[{"filePath","newLine","summary"}]}`.

| Source | `filePath` | `newLine` | `summary` |
| --- | --- | --- | --- |
| poly-crap entry with `score > 5` | `file` | `start_line` | `CRAP 56 · CC 7 · no coverage · shippingTier` |
| lawbook finding from a failing or warning rule | `path` | `line`, or 1 | `[no-console] remove the console call; return or throw instead` |

Only over-threshold poly-crap rows become comments. The JSON still holds every
changed function, so Claude can see what is close to the line.

## Why the sample fails and then passes

CRAP is `cc² × (1 − coverage)³ + cc`. The demo's first `shippingTier` has
complexity 7 and no tests: CRAP 56. Covering it fully would still score 7,
above the threshold of 5, so the fix is also a split: `weightTier` (complexity
3) and a `shippingTier` of complexity 4, both covered. That is the point of
the gate: tests alone do not make a tangled function safe.

## Adapting it

Stages 1 and 3 are the only stack-specific lines in `verify.sh`. For a
TypeScript project they become `tsc --noEmit` and `vitest run --coverage`; for
Rust, `cargo clippy` and `cargo llvm-cov --lcov`. poly-crap reads LCOV,
Cobertura, JaCoCo, and Go profiles. Everything else stays as it is.

The Stop hook forces one extra round per turn by design. To make the hook
alone insist until green, replace the `stop_hook_active` guard with a counter
in `.verify/rounds`, capped, and reset on a green run.

## Status

Verified end to end in a Linux container: `demo.sh` (red, green, cached),
the Stop hook's block output on a red tree and silence on a clean one, the
SessionStart hook's idempotent second run, and both Hunk paths against a real
`hunk diff` session under a pseudo-terminal: `comment clear` plus
`comment apply` left exactly the current findings as live comments, and
`hunk session reload -- diff --agent-context .verify/notes.json` loaded the
sidecar as review notes on the same lines. Not exercised: the Bedrock stage,
which needs credentials; it degrades to a skip message without them.
