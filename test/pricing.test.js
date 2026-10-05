import { test } from "node:test";
import assert from "node:assert/strict";
import { discount, subtotal, total } from "../src/pricing.js";

const cart = [
  { quantity: 2, unitPrice: 1250 },
  { quantity: 1, unitPrice: 300 },
];

test("subtotal adds quantity times unit price across the cart", () => {
  assert.equal(subtotal(cart), 2800);
});

test("subtotal of an empty cart is zero", () => {
  assert.equal(subtotal([]), 0);
});

test("SAVE10 takes ten percent off, rounded to the cent", () => {
  assert.equal(discount(2805, "SAVE10"), 281);
});

test("FLAT500 takes five dollars off but never more than the amount", () => {
  assert.equal(discount(2800, "FLAT500"), 500);
  assert.equal(discount(300, "FLAT500"), 300);
});

test("an unknown code earns no discount", () => {
  assert.equal(discount(2800, "FREESHIP"), 0);
});

test("total applies the discount before tax", () => {
  assert.equal(total(cart, "FLAT500", 0.1), 2530);
});
