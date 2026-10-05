import { InsufficientStockError } from "./errors.js";
import { assertPositiveInteger } from "./validate.js";

/** A new stock map with quantity fewer of a sku, or an InsufficientStockError. */
export function reserve(stock, sku, quantity) {
  assertPositiveInteger("quantity", quantity);
  const available = stock[sku] ?? 0;
  if (available < quantity) {
    throw new InsufficientStockError(sku, quantity, available);
  }
  return { ...stock, [sku]: available - quantity };
}

/** A new stock map with quantity more of a sku. */
export function release(stock, sku, quantity) {
  assertPositiveInteger("quantity", quantity);
  return { ...stock, [sku]: (stock[sku] ?? 0) + quantity };
}
