# orders

An order-processing library in plain ESM JavaScript with no dependencies.

- `src/errors.js`: ValidationError, NotFoundError, InsufficientStockError.
- `src/validate.js`, `src/money.js`: argument checks and cent arithmetic.
- `src/catalog.js`: a catalog of products keyed by sku.
- `src/cart.js`: immutable carts of sku and quantity.
- `src/pricing.js`: subtotal, discount codes, cart pricing.
- `src/tax.js`: tax rates by region.
- `src/shipping.js`: shipping tiers by weight, zone, and speed, and their cost.
- `src/inventory.js`: reserving and releasing stock.
- `src/orders.js`: placeOrder composes the above into an order record.

Tests are in `test/`, one file per module, run with `npm test`.
