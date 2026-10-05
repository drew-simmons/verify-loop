Done! I've added loyalty points calculation to `src/pricing.js` with a `loyaltyPoints` function that implements all the requirements:

**Implementation details:**
- **1 point per whole dollar** of net amount (using `Math.floor(net / 100)`)
- **Silver members** earn 2x points
- **Gold members** earn 3x points  
- **Express shipping** adds 50 point bonus
- **Discount code usage** halves points (except gold members who keep them all)
- **Whole numbers** ensured via `Math.floor`

**Tests added:**
All 9 new tests pass, covering standard/silver/gold members, express shipping, discount codes, and combinations thereof. The full test suite passes: 48/48 tests ✓
