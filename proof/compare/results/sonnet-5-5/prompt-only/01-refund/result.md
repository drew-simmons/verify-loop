I added `refundFor(order, reason)` to `src/orders.js`, and the API layer can call it directly. The full test suite passes (40 tests), including a new one for the refund rules.

It returns the refund in cents, by reason:
- **`"damaged"`:** the order's full `total`.
- **`"late"`:** the shipping cost, `order.shipping.cost`.
- **`"changed-mind"`:** `order.net` minus 10% of `net`, rounded to the nearest cent with the existing `percentOf` helper. On a net of 26905, the fee is 2691 (2690.5 rounds up), so the refund is 24214.
- **Anything else, including `undefined`:** 0.

I also added a line about `refundFor` to the module map in `README.md`.

`refundFor` only calculates the amount. It doesn't check whether an order has already been refunded, so the API layer would need to guard against refunding the same order twice.
