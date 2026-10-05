import { test } from "node:test";
import assert from "node:assert/strict";
import { createCatalog, findProduct } from "../src/catalog.js";
import { NotFoundError, ValidationError } from "../src/errors.js";

const products = [
  { sku: "MUG", name: "Mug", priceCents: 1250, weightKg: 0.4 },
  { sku: "DESK", name: "Desk", priceCents: 24900, weightKg: 28 },
];

test("a catalog finds products by sku", () => {
  const catalog = createCatalog(products);
  assert.equal(findProduct(catalog, "DESK").name, "Desk");
});

test("an unknown sku is a not-found error naming it", () => {
  const catalog = createCatalog(products);
  assert.throws(() => findProduct(catalog, "LAMP"), NotFoundError);
});

test("a product without a sku or with a fractional price is rejected", () => {
  assert.throws(() => createCatalog([{ sku: "", priceCents: 100 }]), ValidationError);
  assert.throws(() => createCatalog([{ sku: "X", priceCents: 9.99 }]), ValidationError);
});
