---
name: polish
description: Simplify the current change with /simplify, then run /verify until it exits 0, then report that the change is ready to commit. Invoke by hand when a change is finished but not yet committed.
disable-model-invocation: true
---

# polish

Two skills in a fixed order, then a report. Nothing is committed.

1. Run /simplify on the current diff. Let it finish and keep the fixes it
   applies. If /simplify is not available in this Claude Code, say so and go
   to step 2.
2. When /simplify finishes, run /verify. Exit 0: go to step 3. Exit 1: fix
   only what `.verify/crap.json` and `.verify/lawbook.json` name, then run
   /verify again; a simplification that pushed a function over CRAP 5 or
   broke a rule is undone or split, not argued with. Exit 2: fix the setup it
   names, not the code, and run again. Repeat until 0.
3. Report in a few lines: what /simplify changed, what /verify found and how
   it was fixed, and that the change is ready to commit. Do not commit; the
   human does that.

The order is the point: /simplify edits the diff, so it runs first; /verify is
the gate, so it runs last and nothing runs after it. Do not stop between the
two steps, and do not end the turn while /verify is red.
