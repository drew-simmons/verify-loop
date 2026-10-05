Done! I've successfully added loyalty points functionality to the orders system. Here's what was implemented:

**Changes made:**

1. **src/pricing.js**: Added `pointsEarned()` function that calculates loyalty points with:
   - 1 point per whole dollar of net amount
   - 2x multiplier for silver members, 3x for gold
   - +50 point bonus for express shipping
   - Points halved if a discount code was used (except gold members keep them all)

2. **src/orders.js**: Updated `placeOrder()` to accept a `membershipTier` parameter and include `loyaltyPoints` in the returned order object

3. **Tests**: Added 13 comprehensive test cases across pricing and orders tests covering all combinations of membership tiers, discounts, and express shipping

**Verification results:**
- ✅ All 53 tests pass
- ✅ 100% code coverage
- ✅ No CRAP violations (complexity, coverage scores well below threshold)
- ✅ Clean lawbook checks

Committed to main branch.
