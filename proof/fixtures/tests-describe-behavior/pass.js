import { test } from "node:test";
import assert from "node:assert/strict";
import { discountFor } from "../../../src/pricing.js";

test("SAVE10 takes ten percent off, rounded to the cent", () => {
  assert.equal(discountFor(2805, "SAVE10"), 281);
});

test("an unknown code takes nothing off", () => {
  assert.equal(discountFor(2800, "FREESHIP"), 0);
});
