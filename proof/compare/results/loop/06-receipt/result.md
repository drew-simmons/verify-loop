I added `receipt(order, currency)` to `src/orders.js`. The verify loop is clean: syntax, lawbook rules, tests with coverage, and poly-crap on the changed functions. The model-judged prose standards were skipped because `AWS_REGION` isn't set. Nothing is committed.

For an order with a discount, the output looks like this:

```
MUG x2
DESK x1
Subtotal: USD 274.00
Discount: -USD 5.00
Tax: USD 19.50
Shipping (freight-express): USD 54.00
Total: USD 342.50
```

- **Discount line:** it appears only when `order.discount > 0`. It's shown as a negative amount, which was my choice.
- **Amounts:** they use the existing `formatCents` from `src/money.js`.
- **Structure:** a small private `discountLines` helper handles the discount branch, so both functions stay within the complexity limit of 5.
- **Currency:** the function uses the `currency` argument as given and doesn't check it.

I added two tests to `test/orders.test.js`: one for the full receipt with a discount, and one for the case with no discount line. My first expected total in the full-receipt test was wrong (I wrote 322.50). The code was right at 342.50, and I corrected the test.
