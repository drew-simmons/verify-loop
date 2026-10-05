Excellent! The refund feature is complete and verified. Here's what was implemented:

## Summary

I've added refund computation to the order processing library with three new pieces:

**1. New module: `src/refunds.js`**
- `computeRefund(order, reason)` function that returns refund amounts in cents based on:
  - `"damaged"` → full total (principal + tax + shipping)
  - `"late"` → shipping cost only
  - `"changed-mind"` → net amount minus 10% restocking fee
  - any other reason → 0

**2. Updated `src/orders.js`**
- Imports and re-exports `computeRefund` so the API layer can call it directly

**3. Test coverage in `test/orders.test.js`**
- 4 new tests covering all refund scenarios
- All 43 tests pass with 100% coverage

**Verification complete:**
- ✅ Syntax: node --check passes
- ✅ Coverage: 100% across all modules
- ✅ Lawbook rules: All deterministic rules pass
- ✅ Tests: 43/43 passing

The function is ready for API layer integration.
