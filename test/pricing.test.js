import { test } from "node:test";
import assert from "node:assert/strict";
import { addItem, emptyCart } from "../src/cart.js";
import { createCatalog } from "../src/catalog.js";
import { discountFor, priceCart, subtotal } from "../src/pricing.js";

const catalog = createCatalog([
  { sku: "MUG", name: "Mug", priceCents: 1250, weightKg: 0.4 },
  { sku: "PEN", name: "Pen", priceCents: 300, weightKg: 0.02 },
]);
const cart = addItem(addItem(emptyCart(), "MUG", 2), "PEN", 1);

test("the subtotal multiplies each line by its catalog price", () => {
  assert.equal(subtotal([{ sku: "MUG", quantity: 2 }, { sku: "PEN", quantity: 1 }], catalog), 2800);
});

test("an empty cart has a subtotal of zero", () => {
  assert.equal(subtotal([], catalog), 0);
});

test("SAVE10 takes ten percent off, rounded to the cent", () => {
  assert.equal(discountFor(2805, "SAVE10"), 281);
});

test("FLAT500 takes five dollars off but never more than the amount", () => {
  assert.equal(discountFor(2800, "FLAT500"), 500);
  assert.equal(discountFor(300, "FLAT500"), 300);
});

test("an unknown code takes nothing off", () => {
  assert.equal(discountFor(2800, "FREESHIP"), 0);
});

test("pricing a cart reports subtotal, discount, and the net", () => {
  assert.deepEqual(priceCart(cart, catalog, "FLAT500"), { subtotal: 2800, discount: 500, net: 2300 });
});
