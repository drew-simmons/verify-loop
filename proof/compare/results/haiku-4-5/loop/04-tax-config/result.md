Done! I've moved the tax rates out of the source code into a `tax-rates.json` configuration file. Here's what changed:

**Created:**
- `tax-rates.json` at the repo root with the three tax rates (CA: 7.25%, NY: 4%, TX: 6.25%)

**Modified:**
- `src/tax.js` now loads rates from the JSON file using `readFileSync` instead of hardcoding them

**Verification:**
- ✅ All 39 tests pass
- ✅ 100% code coverage maintained
- ✅ All code quality gates passed
- ✅ Committed with proper attribution

Finance can now edit `tax-rates.json` and redeploy without touching the source code.
