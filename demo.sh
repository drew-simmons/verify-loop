#!/usr/bin/env sh
# The loop, end to end, on a change that is red for both tools and then green.
#
#   1. Add an untested, over-complex loyaltyPoints() with a console call:
#      verify exits 1 and names it in both reports.
#   2. Replace it with a lookup table and a small function, drop the console
#      call, cover every branch: verify exits 0.
#   3. Run again with nothing changed: verify returns at once.
#
# Needs a clean working tree. Restores the tree when it finishes or fails.
set -u

cd "$(dirname "$0")" || exit 2
if [ -n "$(git status --porcelain -- src test)" ]; then
  echo "demo: src/ or test/ has uncommitted changes; commit or stash them first" >&2
  exit 2
fi

VERIFY=".factory/verify"
cleanup() {
  git checkout -q -- src test
  git clean -fdq -- src test
  rm -rf .verify lcov.info
}
trap cleanup EXIT INT TERM

fail() { echo; echo "demo: FAIL at step $1: $2" >&2; exit 1; }
step() { echo; echo "================ step $1: $2 ================"; }

step 1 "an untested, over-complex function with a console call"
cat >>src/pricing.js <<'JS'

/** Loyalty points earned by an order. */
export function loyaltyPoints(order, tier) {
  console.log("points for", order.id);
  let points = Math.floor(order.net / 100);
  if (tier === "gold") {
    points = points * 3;
  } else if (tier === "silver") {
    points = points * 2;
  }
  if (order.shipping.tier.includes("express")) {
    points += 50;
  }
  if (order.discount > 0 && tier !== "gold") {
    points = Math.floor(points / 2);
  }
  return points;
}
JS
sh "$VERIFY"
rc=$?
[ "$rc" -eq 1 ] || fail 1 "expected exit 1, got $rc"
jq -e '.entries[] | select(.symbol == "loyaltyPoints" and .score > 5)' .verify/crap.json >/dev/null \
  || fail 1 "poly-crap did not flag loyaltyPoints"
jq -e '.results[] | select(.id == "no-console" and .status == "fail")' .verify/lawbook.json >/dev/null \
  || fail 1 "lawbook did not flag the console call"
jq -e '.comments | length >= 2' .verify/comments.json >/dev/null \
  || fail 1 "expected at least two Hunk comments"
echo; echo "step 1 ok: exit 1, loyaltyPoints and no-console named, $(jq '.comments | length' .verify/comments.json) Hunk comments"

step 2 "split the function, drop the console call, cover every branch"
git checkout -q -- src/pricing.js
cat >>src/pricing.js <<'JS'

/** Points multiplier by loyalty tier; everyone else earns single points. */
const MULTIPLIERS = { gold: 3, silver: 2 };

/** Loyalty points earned by an order: one per dollar net, scaled by tier, plus an express bonus. */
export function loyaltyPoints(order, tier) {
  const base = Math.floor(order.net / 100) * (MULTIPLIERS[tier] ?? 1);
  const bonus = order.shipping.tier.includes("express") ? 50 : 0;
  return base + bonus;
}
JS
cat >test/loyalty.test.js <<'JS'
import { test } from "node:test";
import assert from "node:assert/strict";
import { loyaltyPoints } from "../src/pricing.js";

const order = { net: 12345, shipping: { tier: "standard" } };

test("a member earns one point per whole dollar of the net", () => {
  assert.equal(loyaltyPoints(order, "member"), 123);
});

test("silver and gold tiers multiply the points", () => {
  assert.equal(loyaltyPoints(order, "silver"), 246);
  assert.equal(loyaltyPoints(order, "gold"), 369);
});

test("express shipping adds a fifty-point bonus", () => {
  assert.equal(loyaltyPoints({ ...order, shipping: { tier: "heavy-express" } }, "member"), 173);
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
