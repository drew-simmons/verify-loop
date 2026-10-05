`shippingTier` in `src/shipping.js` now puts `express` before `intl` for international parcels over 20 kg. The full suite passes, including the new tests.

- **Over 20 kg, international, express:** `freight-express-intl`.
- **20 kg or less, international, express:** `heavy-intl-express`, as before.
- **Freight, domestic, express:** `freight-express`. Express on freight needed no code change, since the old code never blocked it.
- **Freight, international, no express:** `freight-intl`, unchanged.

`shippingCost` needed no change. It adds a surcharge for each suffix after the base tier, so the order doesn't affect the price. `freight-express-intl` costs 4500 + 900 + 1500 cents.

I added test cases to `test/shipping.test.js` for the new tier strings, the 20 kg boundary and the `freight-express-intl` price.
