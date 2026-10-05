import { assertNonEmptyString, assertPositiveInteger } from "./validate.js";

/** A cart with nothing in it. Carts are plain objects and never mutated. */
export function emptyCart() {
  return { items: {} };
}

/** A new cart with quantity more of a sku. */
export function addItem(cart, sku, quantity) {
  assertNonEmptyString("sku", sku);
  assertPositiveInteger("quantity", quantity);
  const current = cart.items[sku] ?? 0;
  return { items: { ...cart.items, [sku]: current + quantity } };
}

/** A new cart without a sku. Removing a sku that is not there changes nothing. */
export function removeItem(cart, sku) {
  const { [sku]: _removed, ...rest } = cart.items;
  return { items: rest };
}

/** The cart as a list of { sku, quantity } lines, in insertion order. */
export function lines(cart) {
  return Object.entries(cart.items).map(([sku, quantity]) => ({ sku, quantity }));
}
