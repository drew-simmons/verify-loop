Done! I've updated the shipping module to handle the carrier's new requirements:

**Changes made:**

1. **Updated `shippingTier` function** to produce the correct tier strings:
   - For domestic parcels: tier alone or with express suffix
   - For international freight with express: `"freight-express-intl"` (express before intl)
   - For international non-freight with express: `"tier-intl-express"` (intl before express)
   - For international without express: tier with intl suffix

2. **Refactored into helper functions** to keep cyclomatic complexity ≤ 5:
   - `tierWithExpress`: Handles domestic logic
   - `tierWithIntlExpress`: Handles international logic with proper ordering

3. **Added test coverage** for the new freight-international-express scenario

**Verification:**
- ✅ All 40 tests pass
- ✅ 100% line coverage on shipping.js
- ✅ All functions have CC ≤ 5 (shippingTier: 3, tierWithExpress: 2, tierWithIntlExpress: 3)
- ✅ `shippingCost` still works correctly—it calculates based on surcharge order, which doesn't matter since it sums them all

The changes are ready in the working tree.
