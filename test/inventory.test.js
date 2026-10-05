import { test } from "node:test";
import assert from "node:assert/strict";
import { InsufficientStockError, ValidationError } from "../src/errors.js";
import { release, reserve } from "../src/inventory.js";

test("reserving reduces stock and leaves the original map unchanged", () => {
  const stock = { MUG: 10 };
  assert.deepEqual(reserve(stock, "MUG", 3), { MUG: 7 });
  assert.deepEqual(stock, { MUG: 10 });
});

test("reserving more than is in stock fails and names the shortfall", () => {
  assert.throws(() => reserve({ MUG: 2 }, "MUG", 5), InsufficientStockError);
  assert.throws(() => reserve({}, "PEN", 1), InsufficientStockError);
});

test("releasing adds stock, even for a sku never seen before", () => {
  assert.deepEqual(release({ MUG: 1 }, "MUG", 2), { MUG: 3 });
  assert.deepEqual(release({}, "PEN", 4), { PEN: 4 });
});

test("a non-positive quantity cannot be reserved or released", () => {
  assert.throws(() => reserve({ MUG: 1 }, "MUG", 0), ValidationError);
  assert.throws(() => release({ MUG: 1 }, "MUG", -1), ValidationError);
});
