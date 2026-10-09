---
name: add-module
description: Add a new independent rule module to the example project, src/<name>.js with test/<name>.test.js, in the shape of shipping.js, and run /factory:verify on it until the gate is green. Use when asked to add a module, a new rule module, a new file under src/, or a new set of business rules to this project.
argument-hint: <name> [what it decides]
---

# add-module

`$ARGUMENTS` is the module name followed by what it decides. Scaffold
`src/<name>.js` and `test/<name>.test.js` as an independent rule module in the
shape of `src/shipping.js`, then run the gate on them. Given only a name, ask
what the module decides before writing anything.

## Read first

- `src/shipping.js` and `test/shipping.test.js`: the shape to copy.
- `src/errors.js` and `src/validate.js`: throw `ValidationError` for a value
  that makes no sense; use the validate helpers where they fit. No new error
  class unless the module has a new kind of failure.
- `lawbook.yaml`: the rules the gate applies.

## Write

`src/<name>.js`:
- Named exports only, a `/** doc comment */` above every export that says what
  it returns.
- Lookup tables (`const COSTS = { ... }`) instead of `if` chains. Every
  function at cyclomatic complexity 5 or below; more cases is a table or two
  functions.
- Pure functions over plain values: no console, no `fs`, no network, no clock,
  no `process.env`. A value from outside is a parameter.
- Imports only from `./errors.js` and `./validate.js`. Rule modules do not
  import each other; `orders.js` composes them. Do not edit `orders.js`
  unless asked.

`test/<name>.test.js`:
- `node:test` and `node:assert/strict`, as in `test/shipping.test.js`.
- One test per behaviour, named as a sentence about the behaviour and its
  condition ("a parcel with no weight is rejected"), not after the function.
- Every branch exercised, including the `ValidationError` path. An uncovered
  branch is the first thing the gate catches.

## Then verify

Run /factory:verify and read its exit code.
- 0: done. Report.
- 1: fix only what `.verify/crap.json` and `.verify/lawbook.json` name: a test
  for an uncovered branch, a split for a function over complexity 5, the doc
  comment or rule it points at. Run /factory:verify again.
- 2: the loop is broken, not the module. Fix the setup it names, run again.
Repeat until 0. Do not report the module as done while /factory:verify is red, and do
not commit.

## Report

The module's exports with one line each, the number of tests, and verify's
final line (`verify: clean (<stamp>) in <ms>`).
