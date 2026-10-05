import { findProduct } from "./catalog.js";
import { lines } from "./cart.js";
import { add, percentOf } from "./money.js";

/** Each discount code is a function from a subtotal to the cents it takes off. */
const DISCOUNTS = {
  SAVE10: (subtotal) => percentOf(subtotal, 0.1),
  FLAT500: (subtotal) => Math.min(500, subtotal),
};

/** Sum of each line's quantity times its catalog price, in cents. */
export function subtotal(cartLines, catalog) {
  let sum = 0;
  for (const line of cartLines) {
    sum = add(sum, findProduct(catalog, line.sku).priceCents * line.quantity);
  }
  return sum;
}

/** The cents a discount code takes off a subtotal. Unknown codes take nothing. */
export function discountFor(amount, code) {
  const discount = DISCOUNTS[code];
  return discount === undefined ? 0 : discount(amount);
}

/** Subtotal and discount for a cart against a catalog. */
export function priceCart(cart, catalog, code) {
  const base = subtotal(lines(cart), catalog);
  const discount = discountFor(base, code);
  return { subtotal: base, discount, net: base - discount };
}
