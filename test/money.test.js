import { test } from "node:test";
import assert from "node:assert/strict";
import { ValidationError } from "../src/errors.js";
import { add, cents, formatCents, percentOf } from "../src/money.js";

test("whole non-negative cents are accepted as amounts", () => {
  assert.equal(cents(0), 0);
  assert.equal(cents(1250), 1250);
});

test("fractional or negative amounts are rejected", () => {
  assert.throws(() => cents(12.5), ValidationError);
  assert.throws(() => cents(-1), ValidationError);
});

test("adding amounts sums their cents", () => {
  assert.equal(add(1250, 300), 1550);
});

test("a percentage of an amount rounds to the nearest cent", () => {
  assert.equal(percentOf(2805, 0.1), 281);
  assert.equal(percentOf(1000, 0.0725), 73);
});

test("amounts format with two fraction digits", () => {
  assert.equal(formatCents(1250, "USD"), "USD 12.50");
  assert.equal(formatCents(5, "EUR"), "EUR 0.05");
});
