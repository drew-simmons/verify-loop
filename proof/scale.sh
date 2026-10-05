#!/usr/bin/env sh
# The scale proof: which stages grow with the codebase and which stay flat
# with the change. Clones this repository to a temporary directory, adds N
# generated clean modules with tests, commits them, applies scenario 00, and
# times verify. Sizes are arguments; default 10 50 200.
set -u

cd "$(dirname "$0")/.." || exit 2
SIZES=${*:-10 50 200}
SRC=$(pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT INT TERM
export HUNK=0

generate() {
  n=$1
  i=0
  while [ "$i" -lt "$n" ]; do
    id=$(printf '%03d' "$i")
    cat >"src/gen-$id.js" <<JS
import { ValidationError } from "./errors.js";

/** A unit price in cents scaled by a quantity. */
export function lineTotal$id(unitPrice, quantity) {
  if (!Number.isInteger(quantity) || quantity < 0) {
    throw new ValidationError("quantity", "a whole number, zero or more");
  }
  return unitPrice * quantity;
}

/** Whether an amount qualifies for free shipping. */
export function shipsFree$id(amount) {
  return amount >= 5000;
}

/** A label for an amount bucket. */
export function bucket$id(amount) {
  if (amount < 1000) {
    return "small";
  }
  return "large";
}
JS
    cat >"test/gen-$id.test.js" <<JS
import { test } from "node:test";
import assert from "node:assert/strict";
import { ValidationError } from "../src/errors.js";
import { bucket$id, lineTotal$id, shipsFree$id } from "../src/gen-$id.js";

test("a line total multiplies price by quantity ($id)", () => {
  assert.equal(lineTotal$id(250, 4), 1000);
  assert.throws(() => lineTotal$id(250, -1), ValidationError);
});

test("orders of fifty dollars or more ship free ($id)", () => {
  assert.equal(shipsFree$id(5000), true);
  assert.equal(shipsFree$id(4999), false);
});

test("amounts bucket at ten dollars ($id)", () => {
  assert.equal(bucket$id(999), "small");
  assert.equal(bucket$id(1000), "large");
});
JS
    i=$((i + 1))
  done
}

stage_ms() { awk -v n="$2" '/^▸/ { name = substr($0, 5) } /^  took/ && index(name, n) == 1 { print $2 }' "$1"; }

echo "| Modules | Test files | Stage 2 lawbook | Stage 3 tests + coverage | Stage 4 poly-crap | Whole loop |"
echo "| --- | --- | --- | --- | --- | --- |"
for n in $SIZES; do
  dir="$WORK/n$n"
  git clone -q --local "$SRC" "$dir"
  (
    cd "$dir" || exit 2
    git config commit.gpgsign false
    git config user.email bench@example.invalid
    git config user.name bench
    generate "$n"
    git add -A && git commit -q -m "chore: $n generated modules"
    . ./proof/scenarios/00-clean-change.sh
    apply
    BASE=main sh .claude/skills/verify/scripts/verify.sh >verify.log 2>&1
    rc=$?
    [ "$rc" -eq 0 ] || { echo "scale: verify exited $rc at n=$n" >&2; tail -20 verify.log >&2; exit 1; }
    modules=$(ls src/*.js | wc -l | tr -d ' ')
    tests=$(ls test/*.test.js | wc -l | tr -d ' ')
    total=$(sed -n 's/.* in \([0-9]*\) ms.*/\1/p' verify.log)
    printf '| %s | %s | %s ms | %s ms | %s ms | %s ms |\n' "$modules" "$tests" "$(stage_ms verify.log 2)" "$(stage_ms verify.log 3)" "$(stage_ms verify.log 4)" "$total"
  ) || exit 1
done
echo
echo "scale: done"
