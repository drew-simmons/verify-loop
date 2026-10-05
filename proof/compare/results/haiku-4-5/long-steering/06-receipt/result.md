Excellent! The `receipt` function is complete and ready. Here's a summary of what was added:

## Implementation Summary

**Added to `src/orders.js`:**
- `receipt(order, currency)` function that returns a multi-line formatted receipt string
- Imports `formatCents` from `src/money.js` for currency formatting

**Receipt Format:**
- One line per item with SKU and quantity
- Blank line separator
- Subtotal in currency format
- Discount line (only if discount > 0)
- Tax in currency format
- Shipping with tier in parentheses and cost
- Total in currency format

**Tests Added (4 tests):**
- Receipt with discount formatting
- Receipt omits discount when there is none
- Receipt shows shipping tier in parentheses
- Receipt works with different currencies

**Quality Metrics:**
- ✓ 100% line coverage on `src/orders.js`
- ✓ Cyclomatic complexity: 3 (well under limit of 5)
- ✓ CRAP score: 3 (well under limit of 5)
- ✓ All 43 tests pass
- ✓ Follows all CLAUDE.md rules (no logging, pure function, doc comment, named exports, etc.)

The function is ready to use and can format any order as a printable receipt in any currency.
