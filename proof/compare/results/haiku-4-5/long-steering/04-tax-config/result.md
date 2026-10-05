Done! I've successfully extracted the tax rates into a configuration file. Here's what changed:

**Created `tax-rates.json`** at the repo root with the rates:
- CA: 7.25%
- NY: 4%  
- TX: 6.25%

**Updated `src/tax.js`** to import from the JSON file using ESM's `import` with `{ type: "json" }` assertion. This approach keeps the library pure (the JSON is loaded at module initialization, not via runtime file I/O) while allowing finance to edit the rates and redeploy without code changes.

**Test results**: All 39 tests pass with 100% coverage on every file, including `tax.js`. Cyclomatic complexity remains at 2 for `taxRate()` and 1 for `taxFor()`, well under the 5-point limit.
