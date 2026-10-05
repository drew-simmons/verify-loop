I added `refundFor(order, reason)` to `src/orders.js`, and it returns the refund in cents. All 43 tests pass, and every file in `src` shows 100% line and branch coverage. I haven't committed anything.

- **`damaged`:** refunds `order.total`.
- **`late`:** refunds `order.shipping.cost`.
- **`changed-mind`:** refunds `order.net` minus 10% of it. The fee is rounded to the nearest cent using the existing `percentOf` from `src/money.js`.
- **Any other reason:** refunds 0. This includes `undefined`.

The reasons live in a lookup table, so `refundFor` has complexity 2. I added four tests to `test/orders.test.js`, one per reason plus an unknown one. I also added `refundFor` to the `src/orders.js` line in `README.md`.

Two behaviours to be aware of:
- **No refund cap:** it doesn't check whether the order was already refunded. Tracking that would have to sit above this function.
- **Net, not total:** I read "net amount" as `order.net`, which excludes tax and shipping, so `changed-mind` doesn't refund those.
