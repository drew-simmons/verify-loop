I added `receipt(order, currency)` to `src/orders.js`. All 41 tests pass, and `orders.js` has 100% line, branch and function coverage. Nothing is committed.

For an order with a discount, it returns this (the SKUs and amounts are the sample order in the test):

```
MUG x2
DESK x1
Subtotal: USD 274.00
Discount: USD 5.00
Tax: USD 19.50
Shipping (freight-express): USD 54.00
Total: USD 342.50
```

- **Discount line:** it only appears when `order.discount` is above 0.
- **Currency formatting:** amounts go through `formatCents` from `src/money.js`.
- **Complexity:** `receipt` is a single list of lines, so its complexity is 1. The only branch is in `discountLines`, which scores 2. Both are well under the limit of 5.
- **Other files:**
  - I added two tests to `test/orders.test.js`, one with a discount and one without.
  - I added a `receipt` mention to `README.md`.

I didn't run a separate complexity or CRAP check; the scores above are my own count against the CLAUDE.md rules. I didn't add validation for the `order` or `currency` arguments. A negative or non-integer amount would make `formatCents` throw its existing `ValidationError`.
