Done! I've successfully updated the shipping module to support express shipping on freight parcels with the correct tier ordering:

**Changes made:**

1. **`shippingTier` function** — Now produces the correct tier strings:
   - For freight + international + express: `"freight-express-intl"` (express before intl)
   - For lighter international express: `"heavy-intl-express"` or `"standard-intl-express"` (standard order)
   - For domestic express: `"freight-express"`, `"heavy-express"`, or `"standard-express"`

2. **Tests** — Added comprehensive coverage for all cases including:
   - Freight express international 
   - Express on all domestic weights (standard, heavy, freight)

3. **Architecture** — Split the logic into focused helper functions to meet CRAP complexity limits:
   - `shouldPutExpressFirst()` — Determines the tier-specific ordering rule
   - `addSuffixes()` — Builds the suffix array in the correct order
   - `shippingTier()` — Simple orchestrator

4. **Cost calculation** — The `shippingCost` function works unchanged since it calculates based on the suffix components regardless of their order.

All tests pass with 100% coverage and the verification loop confirms the code meets quality standards.
