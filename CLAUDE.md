# CLAUDE.md

A worked example of a verification loop for Claude Code. The sample code in
`src/` exists to be verified; the loop in `.claude/` is the point.

## Commands

```sh
npm test                                   # node:test
npm run coverage                           # tests + lcov.info
sh .claude/skills/verify/scripts/verify.sh # the loop: exit 0 clean, 1 gate failed, 2 broken
sh demo.sh                                 # red → green → cached, asserts every exit code
```

`/verify` runs the loop as a skill. The Stop hook in `.claude/settings.json`
runs it again at the end of every turn that changed something, and blocks the
turn with the findings while the change is red.

## Conventions

- Run `/verify` before committing. A function fails above CRAP 5, so keep
  complexity at 5 or below and cover every branch.
- Library code in `src/` does not call `console`; `lawbook.yaml` forbids it.
- Conventional Commit subjects. No AI attribution in commits.
- Verification never needs network access or credentials. The one
  model-judged lawbook rule is opt-in through `AWS_REGION`.
