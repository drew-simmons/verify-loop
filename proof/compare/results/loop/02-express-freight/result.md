`shippingTier` now returns `freight-express-intl` for an international express parcel over 20 kg. Lighter parcels keep the current order, such as `heavy-intl-express`. The verify loop is clean, with coverage at 100% and no function above CRAP 5. The model-judged prose standards were skipped because no Bedrock credentials are set.

- **Order of suffixes:** I moved it into a lookup table in `src/shipping.js`. Freight puts `express` before `intl` and every other tier uses `intl` then `express`. A table keeps the function's complexity low, where a new `if` would have raised it.
- **Express on freight:** The old code already accepted express on freight, so the existing `freight-express` order test in `test/orders.test.js` still holds.
- **Pricing:** `shippingCost` didn't need a change. It adds up the suffix surcharges whatever order they come in, so `freight-express-intl` costs 6900 cents (4500 + 900 + 1500).
- **Tests:** I added cases to `test/shipping.test.js` for `freight-express-intl`, `freight-express` and the 6900-cent cost.

Nothing is committed.
