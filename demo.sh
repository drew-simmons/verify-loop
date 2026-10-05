#!/usr/bin/env sh
# The loop, end to end, on a change that is red for both tools and then green.
#
#   1. Add an untested, over-complex function with a console call: verify
#      exits 1 and names it in both reports.
#   2. Split it, drop the console call, cover every branch: verify exits 0.
#   3. Run again with nothing changed: verify returns at once.
#
# Needs a clean working tree. Restores the tree when it finishes or fails.
set -u

cd "$(dirname "$0")" || exit 2
if [ -n "$(git status --porcelain -- src test)" ]; then
  echo "demo: src/ or test/ has uncommitted changes; commit or stash them first" >&2
  exit 2
fi

VERIFY=".claude/skills/verify/scripts/verify.sh"
cleanup() {
  git checkout -q -- src test
  rm -f test/shipping.test.js lcov.info
  rm -rf .verify
}
trap cleanup EXIT INT TERM

fail() { echo; echo "demo: FAIL at step $1: $2" >&2; exit 1; }
step() { echo; echo "================ step $1: $2 ================"; }

step 1 "an untested, over-complex function with a console call"
cat >>src/pricing.js <<'JS'

/** Shipping tier for a parcel. */
export function shippingTier(weightKg, zone, express) {
  console.log("shipping", weightKg, zone, express);
  if (weightKg <= 0) {
    throw new RangeError("weight must be positive");
  }
  let tier = "standard";
  if (weightKg > 20) {
    tier = "freight";
  } else if (weightKg > 5) {
    tier = "heavy";
  }
  if (zone === "international") {
    tier = `${tier}-intl`;
  }
  if (express && tier !== "freight") {
    tier = `${tier}-express`;
  }
  return tier;
}
JS
sh "$VERIFY"
rc=$?
[ "$rc" -eq 1 ] || fail 1 "expected exit 1, got $rc"
jq -e '.entries[] | select(.symbol == "shippingTier" and .score > 5)' .verify/crap.json >/dev/null \
  || fail 1 "poly-crap did not flag shippingTier"
jq -e '.results[] | select(.id == "no-console" and .status == "fail")' .verify/lawbook.json >/dev/null \
  || fail 1 "lawbook did not flag the console call"
jq -e '.comments | length >= 2' .verify/comments.json >/dev/null \
  || fail 1 "expected at least two Hunk comments"
echo; echo "step 1 ok: exit 1, shippingTier and no-console named, $(jq '.comments | length' .verify/comments.json) Hunk comments"

step 2 "split the function, drop the console call, cover every branch"
git checkout -q -- src/pricing.js
cat >>src/pricing.js <<'JS'

function weightTier(weightKg) {
  if (weightKg > 20) {
    return "freight";
  }
  if (weightKg > 5) {
    return "heavy";
  }
  return "standard";
}

/** Shipping tier for a parcel: weight tier, then zone and speed suffixes. */
export function shippingTier(weightKg, zone, express) {
  if (weightKg <= 0) {
    throw new RangeError("weight must be positive");
  }
  const parts = [weightTier(weightKg)];
  if (zone === "international") {
    parts.push("intl");
  }
  if (express) {
    parts.push("express");
  }
  return parts.join("-");
}
JS
cat >test/shipping.test.js <<'JS'
import { test } from "node:test";
import assert from "node:assert/strict";
import { shippingTier } from "../src/pricing.js";

test("rejects a parcel with no weight", () => {
  assert.throws(() => shippingTier(0, "domestic", false), RangeError);
});

test("light domestic parcels ship standard", () => {
  assert.equal(shippingTier(2, "domestic", false), "standard");
});

test("parcels over five kilos ship heavy, over twenty ship freight", () => {
  assert.equal(shippingTier(6, "domestic", false), "heavy");
  assert.equal(shippingTier(21, "domestic", false), "freight");
});

test("international and express add suffixes in that order", () => {
  assert.equal(shippingTier(2, "international", true), "standard-intl-express");
});
JS
sh "$VERIFY"
rc=$?
[ "$rc" -eq 0 ] || fail 2 "expected exit 0, got $rc"
[ -f .verify/green ] || fail 2 "no .verify/green stamp"
echo; echo "step 2 ok: exit 0, stamp $(cat .verify/green)"

step 3 "nothing changed: the stamp short-circuits"
OUTPUT=$(sh "$VERIFY")
rc=$?
[ "$rc" -eq 0 ] || fail 3 "expected exit 0, got $rc"
echo "$OUTPUT" | grep -q "unchanged since the last green run" || fail 3 "verify did not short-circuit"
echo "$OUTPUT"

echo
echo "demo: PASS"
