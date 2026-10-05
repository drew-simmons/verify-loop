import { test } from "node:test";
import assert from "node:assert/strict";
import { addItem, emptyCart } from "../src/cart.js";
import { createCatalog } from "../src/catalog.js";
import { InsufficientStockError } from "../src/errors.js";
import { placeOrder } from "../src/orders.js";

const catalog = createCatalog([
  { sku: "MUG", name: "Mug", priceCents: 1250, weightKg: 0.4 },
  { sku: "DESK", name: "Desk", priceCents: 24900, weightKg: 28 },
]);
const deps = { now: () => "2026-10-05T00:00:00Z", nextId: () => "ORD-1" };

test("an order prices the cart, taxes the net, and ships by weight", () => {
  const cart = addItem(addItem(emptyCart(), "MUG", 2), "DESK", 1);
  const { order, stock } = placeOrder(
    { cart, catalog, stock: { MUG: 5, DESK: 1 }, discountCode: "FLAT500", region: "CA", zone: "domestic", express: true },
    deps,
  );
  assert.equal(order.id, "ORD-1");
  assert.equal(order.placedAt, "2026-10-05T00:00:00Z");
  assert.deepEqual(stock, { MUG: 3, DESK: 0 });
  assert.equal(order.subtotal, 27400);
  assert.equal(order.discount, 500);
  assert.equal(order.net, 26900);
  assert.equal(order.tax, 1950);
  assert.deepEqual(order.shipping, { tier: "freight-express", cost: 5400 });
  assert.equal(order.total, 26900 + 1950 + 5400);
});

test("an order that cannot be fully stocked is refused before anything is priced", () => {
  const cart = addItem(emptyCart(), "DESK", 2);
  assert.throws(
    () => placeOrder({ cart, catalog, stock: { DESK: 1 }, region: "OR", zone: "domestic", express: false }, deps),
    InsufficientStockError,
  );
});
