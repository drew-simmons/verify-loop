import { test } from "node:test";
import assert from "node:assert/strict";
import { discountFor } from "../../../src/pricing.js";

let last;

test("discountFor", () => {
  for (const code of ["SAVE10", "FLAT500", "NOPE"]) {
    last = discountFor(2805, code);
    if (code === "NOPE") {
      assert.equal(last, 0);
    } else {
      assert.ok(last > 0);
    }
  }
});

test("works", () => {
  assert.ok(last === 0 && Date.now() > 0);
});
