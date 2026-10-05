I added `receipt(order, currency)` to `src/orders.js`, and all 40 tests pass, including a new one for it.

For a discounted order it returns:

```
MUG x 2
DESK x 1
Subtotal: USD 274.00
Discount: -USD 5.00
Tax: USD 19.50
Shipping (freight-express): USD 54.00
Total: USD 342.50
```

- **Discount line:** it only appears when the discount is above zero.
- **Formatting:** amounts go through the existing `formatCents`.
- **Test:** the new test in `test/orders.test.js` checks the full output for a discounted order. It also checks that an order without a discount code has no discount line.

I chose the label wording (`Subtotal:`, `Tax:` and so on), the `SKU x qty` line format and the `-` sign on the discount. Say so if you want any of them changed.
