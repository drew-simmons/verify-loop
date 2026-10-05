Perfect! The implementation is complete and working correctly:

**Summary of changes:**
- Updated `shippingTier()` to produce `"freight-express-intl"` for international freight parcels with express shipping (over 20 kg)
- For lighter international parcels and all non-international cases, the tier order remains unchanged
- `shippingCost()` already handles any suffix order correctly since it sums surcharges regardless of their position in the tier string

**Verification:**
- All 39 existing tests pass ✓
- New freight + international + express case produces: `"freight-express-intl"` ✓  
- Costs are calculated correctly: freight-express-intl = $69.00 ✓
- Light international parcels keep original order: `"heavy-intl-express"` ✓
