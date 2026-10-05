import { findProduct } from "./catalog.js";
import { lines } from "./cart.js";
import { reserve } from "./inventory.js";
import { priceCart } from "./pricing.js";
import { shippingCost, shippingTier } from "./shipping.js";
import { taxFor } from "./tax.js";

/** Total weight of the cart in kilograms. */
function cartWeight(cart, catalog) {
  return lines(cart).reduce(
    (sum, line) => sum + findProduct(catalog, line.sku).weightKg * line.quantity,
    0,
  );
}

/** Stock after every line is reserved; throws on the first shortfall and changes nothing. */
function reserveAll(stock, cart) {
  return lines(cart).reduce((next, line) => reserve(next, line.sku, line.quantity), stock);
}

/**
 * Places an order: reserves stock, prices the cart, adds tax and shipping.
 * `deps` supplies `now()` and `nextId()` so callers, and tests, control time and ids.
 * Returns { order, stock } where stock is the inventory after the reservation.
 */
export function placeOrder({ cart, catalog, stock, discountCode, region, zone, express }, deps) {
  const remaining = reserveAll(stock, cart);
  const price = priceCart(cart, catalog, discountCode);
  const tier = shippingTier(cartWeight(cart, catalog), zone, express);
  const tax = taxFor(price.net, region);
  const shipping = shippingCost(tier);
  const order = {
    id: deps.nextId(),
    placedAt: deps.now(),
    lines: lines(cart),
    ...price,
    tax,
    shipping: { tier, cost: shipping },
    total: price.net + tax + shipping,
  };
  return { order, stock: remaining };
}
