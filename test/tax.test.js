import { test } from "node:test";
import assert from "node:assert/strict";
import { taxFor, taxRate } from "../src/tax.js";

test("listed regions have their own rate", () => {
  assert.equal(taxRate("CA"), 0.0725);
  assert.equal(taxRate("NY"), 0.04);
});

test("unlisted regions are untaxed", () => {
  assert.equal(taxRate("OR"), 0);
  assert.equal(taxFor(10000, "OR"), 0);
});

test("tax rounds to the nearest cent", () => {
  assert.equal(taxFor(2300, "CA"), 167);
  assert.equal(taxFor(2300, "TX"), 144);
});
