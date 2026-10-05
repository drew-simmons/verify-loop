import { test } from "node:test";
import assert from "node:assert/strict";
import { InsufficientStockError, NotFoundError, ValidationError } from "../src/errors.js";

test("a validation error names the value and what it must be", () => {
  const error = new ValidationError("quantity", "a positive integer");
  assert.equal(error.name, "ValidationError");
  assert.equal(error.message, "quantity must be a positive integer");
});

test("a not-found error names the kind and key and says what to do", () => {
  const error = new NotFoundError("product", "SKU-9");
  assert.equal(error.name, "NotFoundError");
  assert.match(error.message, /product "SKU-9" was not found; check the key or add it first/);
});

test("an insufficient-stock error states both quantities", () => {
  const error = new InsufficientStockError("SKU-1", 5, 2);
  assert.equal(error.name, "InsufficientStockError");
  assert.match(error.message, /only 2 of "SKU-1" in stock, 5 wanted/);
});
