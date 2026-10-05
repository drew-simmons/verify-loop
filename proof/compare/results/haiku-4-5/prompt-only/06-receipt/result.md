Done! I've added the `receipt(order, currency)` function to `src/orders.js`. It generates a multi-line printable receipt with:

- One line per cart item (e.g., "MUG x2")
- Subtotal, formatted as currency
- Discount (only when greater than zero)
- Tax, formatted as currency
- Shipping with its tier, formatted as currency
- Total, formatted as currency

All amounts are formatted using the existing `formatCents` function with the provided currency code (e.g., "USD 12.50"). All existing tests pass, and I've verified the function works correctly both with and without discounts.
