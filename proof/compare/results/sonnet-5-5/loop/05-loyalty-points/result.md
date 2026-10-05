I added `loyaltyPoints(net, { member, express, discounted })` to `src/pricing.js`. `/verify` came back clean: tests pass, every function has full coverage, and none scores above CRAP 5. The model-judged prose standards didn't run because `AWS_REGION` isn't set.

The rules, as implemented:
- **Base points:** one per whole dollar of `net`, which is in cents, so the cents are dropped.
- **Tier multiplier:** silver is ×2 and gold is ×3. Any other or missing member tier earns the base rate.
- **Express bonus:** shipping with `express` adds 50 points after the multiplier.
- **Discount code:** the total is halved and rounded down, unless the member is gold, who keep everything.

I added tests in `test/pricing.test.js` for each rule, including the rounding.

Two assumptions to check:
- **Halving and the bonus:** I halve the express bonus along with the rest. You didn't say which way this should go. If the bonus should survive the halving, it's a one-line change in `loyaltyPoints`.
- **Not wired into `placeOrder`:** `placeOrder` has no member tier today, so the function is exported but nothing calls it yet. To wire it in, add a `member` input and a `points` field on the order, computed from `price.net`, `express` and `discountCode`.
