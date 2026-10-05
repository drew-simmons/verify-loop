I added `refundFor(order, reason)` to `src/orders.js`, exported for the API layer. It returns the refund in cents. The verify loop is clean, and all 43 tests pass with 100% coverage. I didn't run the model-judged prose standards, since there are no Bedrock credentials in this session.

- **`damaged`:** refunds `order.total`.
- **`late`:** refunds `order.shipping.cost`.
- **`changed-mind`:** refunds `order.net` minus 10% of it, rounded to the nearest cent with the existing `percentOf` helper.
- **Anything else:** refunds 0, including `undefined` and names like `"constructor"`.

The reasons live in a lookup table rather than an `if` chain, which keeps complexity low, as the repo conventions ask. I added four tests to `test/orders.test.js`, one per rule plus the fallback.

I made two choices you may want to check. The restocking fee is taken from `order.net`, so the refund excludes tax and shipping, as you described. The function doesn't validate `order`. It assumes the shape `placeOrder` returns.
