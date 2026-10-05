import { test } from "node:test";
import assert from "node:assert/strict";
import { addItem, emptyCart, lines, removeItem } from "../src/cart.js";
import { ValidationError } from "../src/errors.js";

test("adding the same sku twice accumulates its quantity", () => {
  const cart = addItem(addItem(emptyCart(), "MUG", 2), "MUG", 3);
  assert.deepEqual(lines(cart), [{ sku: "MUG", quantity: 5 }]);
});

test("adding leaves the original cart unchanged", () => {
  const before = emptyCart();
  addItem(before, "MUG", 1);
  assert.deepEqual(lines(before), []);
});

test("removing a sku drops its line and ignores skus that are not there", () => {
  const cart = addItem(addItem(emptyCart(), "MUG", 2), "DESK", 1);
  assert.deepEqual(lines(removeItem(cart, "MUG")), [{ sku: "DESK", quantity: 1 }]);
  assert.deepEqual(lines(removeItem(cart, "LAMP")), lines(cart));
});

test("a blank sku or a non-positive quantity is rejected", () => {
  assert.throws(() => addItem(emptyCart(), "", 1), ValidationError);
  assert.throws(() => addItem(emptyCart(), "MUG", 0), ValidationError);
});
