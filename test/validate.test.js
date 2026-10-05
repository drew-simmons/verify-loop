import { test } from "node:test";
import assert from "node:assert/strict";
import { ValidationError } from "../src/errors.js";
import { assertNonEmptyString, assertPositiveInteger } from "../src/validate.js";

test("a positive integer passes", () => {
  assert.doesNotThrow(() => assertPositiveInteger("quantity", 3));
});

test("zero, negatives, and fractions are rejected as quantities", () => {
  for (const bad of [0, -1, 1.5, "2"]) {
    assert.throws(() => assertPositiveInteger("quantity", bad), ValidationError);
  }
});

test("a non-empty string passes", () => {
  assert.doesNotThrow(() => assertNonEmptyString("sku", "A-1"));
});

test("an empty string or a non-string is rejected", () => {
  assert.throws(() => assertNonEmptyString("sku", ""), ValidationError);
  assert.throws(() => assertNonEmptyString("sku", 42), ValidationError);
});
