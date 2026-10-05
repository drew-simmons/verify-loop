`shippingTier` now puts "express" before "intl" for international parcels over 20 kg, so a 25 kg international express parcel gets `freight-express-intl`. Lighter international parcels keep `…-intl-express`. All tests pass, and `shipping.js` is at 100% line coverage. I haven't committed anything.

- **Express on freight:** `shippingTier` already let express be added to any weight tier, so freight needed no change. I added a test for domestic freight express, `freight-express`.
- **Pricing:** `shippingCost` adds up the suffix surcharges whatever their order, so it prices the new strings correctly without changes. Tests cover that for `freight-express-intl` and `freight-express`.
- **Code change:** the suffix ordering is in a new unexported helper, `tierSuffixes`, in `src/shipping.js`. Both functions are well under the complexity limit.
- **20 kg boundary:** a parcel of exactly 20 kg is still "heavy", so it keeps `heavy-intl-express`, and a test covers that. I tied the rule to the existing freight tier, which starts above 20 kg, so the threshold lives in one place.
