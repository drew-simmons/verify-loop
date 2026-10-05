Loyalty points are in. `loyaltyPoints(netCents, { membership, express, discounted })` is a new export in `src/pricing.js`. `/verify` came back clean and all tests pass. The model-judged prose standards were skipped because `AWS_REGION` isn't set.

**How it works**
- You get one point per whole dollar of net, with cents dropped.
- That is multiplied by 2 for silver and 3 for gold. Any other membership, or none, gets 1.
- Express shipping then adds 50.
- If a discount code was used, the total is halved and rounded down, unless the member is gold.

**Wiring:** I also hooked it into `placeOrder` in `src/orders.js`. It now takes an optional `membership` and returns `order.points`. The discount counts as used when `price.discount > 0`. An unknown code takes nothing off, so it doesn't halve the points.

**Tests:** I added cases for rounding, tiers, the express bonus and the halving. I also added `placeOrder` tests, including a gold member on a discounted express order.

**Assumptions to check**
- The express bonus is halved along with the rest when a discount applies, so a non-gold discounted express order earns half of base plus 50. If you want the bonus kept whole, that is a one-line change.
- Fractional halves round down.
