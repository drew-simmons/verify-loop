I added `refundFor(order, reason)` to `src/orders.js`, exported for the API layer. `/verify` passes: tests, 100% coverage, CRAP within the limit, and the lawbook rules are clean. The model-judged prose standards were skipped because `AWS_REGION` isn't set.

It returns the refund in cents:
- **`"damaged"`:** `order.total`.
- **`"late"`:** `order.shipping.cost`.
- **`"changed-mind"`:** `order.net` minus 10% of it. The fee reuses `percentOf` from `money.js`, so it rounds to the nearest cent.
- **Any other reason:** 0. That includes `undefined`. A name like `"toString"` also gets 0, because the lookup checks that the reason is one of the three keys (`Object.hasOwn`) before using it.

I added one test in `test/orders.test.js` covering all four outcomes plus those edge cases.

I haven't committed anything.
