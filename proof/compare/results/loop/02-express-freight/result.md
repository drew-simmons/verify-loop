`shippingTier` now produces `freight-express-intl` for international parcels over 20 kg, and lighter parcels keep the `intl`-then-`express` order. `/verify` came back clean. That covers the tests, poly-crap (no changed function above CRAP 5) and the lawbook rules. The model-judged prose standards were skipped because `AWS_REGION` isn't set.

- **Order:** `src/shipping.js` has a new `SUFFIX_ORDER` table. Freight puts `express` before `intl`, and standard and heavy do the reverse. A lookup table replaces another branch, which keeps `shippingTier` within the complexity limit.
- **Express on freight:** it already worked, since nothing in the code blocked it. A domestic freight express parcel gives `freight-express`.
- **Pricing:** `shippingCost` needed no change, because it adds each surcharge separately and doesn't depend on suffix order. `freight-express-intl` costs 4500 + 900 + 1500.
- **Tests:** in `test/shipping.test.js` I added cases for `freight-express-intl`, `freight-express`, a 20 kg international express parcel (which stays `heavy-intl-express`), and the cost of the new tier string.

Nothing is committed.
