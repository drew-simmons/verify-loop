# CLAUDE.md

This file provides guidance to Claude Code when working with code in this
repository. Read all of it before changing anything, and re-read the Rules
section before you finish a task. Every rule below applies to every change.

## What this is

An order-processing library in plain ESM JavaScript with no dependencies. See
README.md for the module map. `src/errors.js`, `src/validate.js`, and
`src/money.js` are the foundations; `src/catalog.js`, `src/cart.js`,
`src/pricing.js`, `src/tax.js`, `src/shipping.js`, and `src/inventory.js` are
independent rules; `src/orders.js` composes them. One test file per module in
`test/`, written with node:test.

## Commands

```sh
npm test            # node:test
npm run coverage    # tests with coverage; writes lcov.info
```

## Workflow

1. Read the module you are changing and its test file before editing.
2. Make the change in the smallest number of small functions that keeps every
   rule below.
3. Add or update tests so that every new or changed branch is executed by a
   test. Run `npm run coverage` and confirm 100% line coverage on the files you
   touched.
4. Check the cyclomatic complexity of every function you wrote or changed. It
   must be 5 or below. If it is above 5, split the function or replace the
   conditionals with a lookup table.
5. Re-read every rule below and fix anything you broke.
6. Do not commit; leave the change in the working tree.

## Rules: tests and complexity

- Every function must have cyclomatic complexity of 5 or below. Count one for
  the function plus one for each `if`, `else if`, `for`, `while`, `case`, `?:`,
  `&&`, `||`, and `catch`. A function at 6 or above must be split, however
  well it is tested.
- Every branch of every function you add or change must be covered by a test.
  A function with untested branches is not finished.
- A function's CRAP score, `cc² × (1 − coverage)³ + cc`, must be 5 or below.
  An untested function with complexity 4 scores 20 and is rejected.
- Prefer a lookup table (an object or Map from key to value or function) over
  a chain of `if` / `else if` on the same value.
- Never delete or weaken a test to make a change pass. Never skip a test.

## Rules: library code (everything under src/)

- Library code does not print. Never call `console.log`, `console.error`,
  `console.warn`, `console.debug`, or `console.info` in `src/`. Return a value
  or throw an error with the information instead; the caller decides what to
  log.
- The library is pure. Never import `node:fs`, `node:http`, `node:https`,
  `node:net`, `node:child_process`, or `node:os` in `src/`. Never call
  `fetch`, `process.exit`, `Date.now()`, or `new Date()` in `src/`. Never read
  `process.env`. Time, ids, files, and the network are passed in by the caller
  through parameters (see `placeOrder`'s `deps` argument).
- Never write an empty `catch` block. Handle the error where something can be
  done about it, or let it propagate.
- Never use `eval` or `new Function`.
- Never nest a ternary inside another ternary. Use guard clauses or a lookup
  table.
- Never use `export default`. Every export is named.
- Every exported function has a `/** doc comment */` immediately above it that
  says what it returns or does.
- Use `===` and `!==` only. Never `==` or `!=`.
- Never use `var`. Use `const`, or `let` when the binding must change.
- Every TODO, FIXME, HACK, or XXX comment cites an issue, as in `TODO(#123)`,
  or a URL. Otherwise do the work now or leave the comment out.
- Secrets never live in the tree: no `.env` files, no `.pem` files.

## Rules: clean code

These are the standards every file in `src/` and `test/` must meet. They are
judged on the whole file, not only the lines you changed.

### The repository explains itself

The repository has a README that says what the code is for and how to run it.
Keep README.md accurate when you add a module.

### The code has automated tests

Every module under `src/` has a test file under `test/` with the same base
name. A new module is not finished until its test file exists and runs under
`npm test`.

### Every TODO cites an issue

Link every TODO, FIXME, HACK, or XXX comment to an issue, such as
`TODO(#123)`, or do it now.

### Names reveal intent

Every name says what the thing is or does without needing a comment. A
variable's name says what it holds, a function's name says what it does, and
a boolean reads as a question. No name is a vague placeholder such as data,
info, item, temp, obj, result, manager, helper, or util, and no name repeats
its type or the enclosing class. One word stands for one concept throughout
the file: not fetch in one place and retrieve in another for the same
operation. Exempt: a loop index in a loop of a few lines, a lambda parameter
whose type is obvious from the call, and abbreviations the domain itself uses.

### Functions do one thing

Every function does one thing, stated by its name, at one level of
abstraction. A function that could be split into named steps, that mixes
computing a result with formatting or input and output, or whose body falls
into sections marked by blank lines or comments, is doing more than one thing.
Functions take few parameters, and none takes a boolean flag that selects
between two behaviors. Exempt: an entry point whose only job is to call the
steps in order.

### Comments say why

Every comment carries something the code cannot say: why a decision was made,
a non-obvious invariant, a workaround and its cause, or what a public
interface promises its callers. No comment restates what the next line
plainly does, no comment contradicts the code it describes, and no code is
left commented out. Author, date, and change-history comments belong in
version control, not in the file. A file with no comments meets this standard
when its code needs none.

### No magic values

Every literal whose meaning is not obvious from its context is bound to a
named constant or variable that says what it means: timeouts, limits, retry
counts, status codes, keys, URLs, rates, and format strings. Exempt: 0, 1,
-1, the empty string, and a literal used once where the surrounding name
already explains it.

### Guard clauses over nesting

Preconditions and edge cases return early at the top of a function, so the
main path reads straight down without nesting. No code nests more than three
levels of blocks inside a function. A boolean expression is simple enough to
read aloud; a compound condition that needs thought is given a name by a
variable or a function. Exempt: nesting the language forces.

### Errors are handled, not hidden

Every failure is either handled where something can be done about it or
passed up with context; none is silently swallowed. No catch block is empty,
logs and continues as if nothing happened, or catches a broader kind of error
than it can handle. A function that cannot do what its name promises throws
or returns an explicit error instead of null, -1, an empty value, or a
success code, so callers never have to guess. Error messages name what went
wrong, the value that caused it, and what to do next. Exceptions are not used
for ordinary control flow. Exempt: a top-level handler whose job is to report
every error and exit.

### Dependencies are injected

Logic that can be tested without the outside world is kept apart from the
code that touches it. A function that computes a result does not also
construct or reach for a clock, a random source, an environment variable, a
global, a network client, the filesystem, or a database inside its body;
those are passed in through parameters or a constructor, so a test can
substitute them. Business rules take plain values and return plain values,
and input and output happen at the edges that call them. Modules depend on an
interface or a function they are given, not on a concrete implementation they
instantiate. Exempt: the entry point or composition root that wires the real
dependencies together, and a thin adapter whose only job is to call one
external API.

### No duplication

Each piece of knowledge in the file is expressed once. No two functions or
branches repeat the same sequence of statements with small variations, no
validation or conversion is copied instead of called, and no constant is
restated in several places. Similar-looking code that encodes different
decisions, and would rightly change independently, is not duplication.

### No speculative generality

The file contains only what the program needs today. No parameter is unused,
no abstract class or interface has a single implementation added for a future
that has not arrived, no hook or configuration flag is read by nothing, and
no code is unreachable or kept in case. An abstraction is justified by two
real callers that differ, not by an imagined one.

### Deep modules

Each module offers a small, simple interface over a substantial
implementation. Its public surface is as small as it can be: internals are
not exported, mutable internal state is not returned to callers, and
implementation types do not leak into signatures. No public function merely
forwards its arguments to another function with the same signature. A caller
can use the interface correctly from its signature and doc comment alone,
without reading its body.

### Composition over inheritance

Inheritance is used only when the subclass can stand in for its parent
everywhere the parent is used. Code is not inherited for reuse alone,
hierarchies go no deeper than two levels, and no subclass overrides a method
to do nothing or to throw. Behavior that varies is composed from smaller
objects or functions passed in. The error classes in `src/errors.js` are the
only inheritance in this repository; do not add more.

### Outbound calls are bounded

Every call that leaves the process, to a network, another service, a
database, or a subprocess, sets an explicit timeout and has a defined outcome
when it fails. Retries are bounded and backed off, never unlimited. Every
resource the file opens is released on every path, including the error path.
This library makes no such calls; keep it that way and put them in the caller.

### Tests describe behavior

Every test reads as a specification. Its name states the behavior and the
condition, such as "rejects an expired token", not the name of the function
under test. Each test checks one behavior, with setup, action, and assertion
visible in that order, and asserts on observable outcomes rather than on
which internal calls were made. Tests do not depend on each other, on
execution order, on the wall clock, on the network, or on sleeping. A test
holds no branching or loops that would need a test of their own. Exempt:
helper and fixture files that contain no test cases.

## Conventions

- Immutable data: functions return new objects and never mutate their
  arguments (see `src/cart.js` and `src/inventory.js`).
- Amounts are integers in cents. Use `src/money.js` for arithmetic and
  formatting.
- Errors come from `src/errors.js` and say what went wrong and what to do.
- Keep each module's exports to what callers need. Internal helpers stay
  unexported.
- Conventional Commit subjects if asked to commit. Never add AI attribution.

## Before you finish

Run `npm run coverage`. Confirm every test passes and every file you touched
shows 100% line coverage. Confirm every function you wrote or changed has
cyclomatic complexity of 5 or below. Confirm nothing in `src/` prints, reads
the clock, the environment, or the filesystem, or swallows an error. Confirm
every exported function has a doc comment and every name reveals its intent.
Only then is the task done.
