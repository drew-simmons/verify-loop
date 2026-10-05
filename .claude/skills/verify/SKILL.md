---
name: verify
description: Verify the current change before committing. Runs syntax checks, lawbook rules, tests with coverage, poly-crap on the changed functions, and posts the findings to an open Hunk session. Use after editing code, before any commit, when asked whether a change is safe, or when asked to run the verification loop.
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/verify.sh *) Bash(jq *) Bash(hunk session *)
---

# verify

One command, one exit code. The script owns the stage order; you own the fixes.

## The loop

1. Run `${CLAUDE_SKILL_DIR}/scripts/verify.sh`. `BASE=<ref>` changes the base from `origin/main`.
2. Read the exit code.
   - **0**: the change is clean. Commit it.
   - **1**: a gate failed. Read `.verify/crap.json` (changed functions, their CRAP score, complexity, coverage, and uncovered ranges) and `.verify/lawbook.json` (rule findings with path and line). Fix only what they name, then run the script again.
   - **2**: the loop is broken, not the code. The output names the missing tool, ref, coverage file, or credential. Fix that, run again, and leave the code alone.
3. Repeat until 0.

## Rules

- Do not run the stages by hand. The script runs them cheapest first and never sends a model request on a tree that failed a deterministic stage.
- A function fails when its CRAP score is above 5. CRAP is `cc² × (1 − coverage)³ + cc`, so a function with complexity above 5 fails even when fully covered. The fix is tests for the uncovered branches, a split into smaller functions, or both.
- A rerun on an unchanged tree returns at once; the script remembers the last green change.
- Do not launch `hunk diff` or `hunk show`. The human owns the TUI. When a session is open the script posts the findings into it; read the human's replies with `hunk session review --repo . --json --include-notes`. For a conversational review inside Hunk, run `hunk skill path` and read that file first.
- The prose standards in `lawbook.yaml` are judged by a model on Bedrock only when `AWS_REGION` is set (or `VERIFY_LLM=1`), and only after every deterministic stage passed. They warn, never fail. Each finding in `.verify/lawbook.json` carries `decision.noul`, the probability the file meets the standard, and `message`, the model's reason; read the reason before changing code. `LAWBOOK_CONFIG=lawbook.stub.yaml` with `node proof/stub-judge.mjs` running exercises the stage with no credentials.
- `.verify/notes.json` is written when no Hunk session is open. Tell the user they can open it with `hunk diff --agent-notes --agent-context .verify/notes.json`.
