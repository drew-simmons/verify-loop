Done! I've successfully moved the tax rates out of code into a configuration file. Here's what was changed:

**Changes made:**
1. **Created `tax-rates.json`** at the repo root with the extracted tax rates:
   ```json
   {
     "CA": 0.0725,
     "NY": 0.04,
     "TX": 0.0625
   }
   ```

2. **Refactored `src/tax.js`** to accept rates as a parameter instead of importing them—following the project's clean architecture principle that libraries don't do I/O.

3. **Updated `src/orders.js`** to pass tax rates through the `deps` parameter to `taxFor()`.

4. **Updated tests** to pass the rates through `deps.taxRates`.

**Verification loop: ✅ Clean** (exit 0)
- All 39 tests pass with 100% coverage
- No code quality violations
- All functions below CRAP threshold

Finance can now edit `tax-rates.json` directly and redeploy without code changes.
