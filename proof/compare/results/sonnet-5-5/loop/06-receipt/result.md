I added `receipt(order, currency)` to `src/orders.js`, and the verify loop passes clean. That covers the tests with 100% coverage and CRAP at or under 5 for every changed function. I ran it with `HUNK=0`, so no live Hunk session was involved. The model-judged prose standards were skipped because `AWS_REGION` isn't set.

The output for the existing FLAT500 test order looks like this:

```
MUG x2
DESK x1
Subtotal: USD 274.00
Discount: USD 5.00
Tax: USD 19.50
Shipping (freight-express): USD 54.00
Total: USD 342.50
```

- **Discount line:** It only appears when `order.discount > 0`. It prints as a positive amount, `Discount: USD 5.00`, rather than a negative one, because `formatCents` rejects negative numbers.
- **Complexity:** I split the summary rows into a private `summaryRows` helper so each function stays under the complexity limit.
- **Tests:** I added two to `test/orders.test.js`, one for an order with a discount and one without.
- **Not committed:** I haven't committed anything.
