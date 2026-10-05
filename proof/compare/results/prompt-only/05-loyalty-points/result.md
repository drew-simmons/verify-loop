I added `loyaltyPoints(netCents, { member, express, discounted })` to `src/pricing.js`, with tests in `test/pricing.test.js`. The full suite passes (44 tests).

The function works in this order:
1. It takes one point per whole dollar of the net amount, rounded down.
2. It multiplies by 2 for silver or 3 for gold.
3. It adds 50 if shipping is express.
4. It halves the result, rounded down, if a discount code was used and the member isn't gold.

Four things you may want to change:
- **Halving:** I read "the points are halved" as the total including the express bonus. A silver member with a $23 net who uses a code and ships express gets (46 + 50) / 2 = 48.
- **Not wired into `placeOrder`:** `placeOrder` has no membership input, so I left `orders.js` alone. Say how members should reach it and I'll add points to the order record.
- **What counts as "discounted":** the caller passes a `discounted` flag. When you wire it in, `price.discount > 0` would stop an unknown code from counting as a discount. Using `Boolean(discountCode)` would count it.
- **Unknown tiers:** any member value other than `silver` or `gold` earns the base rate.
