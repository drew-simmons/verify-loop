Done! I've moved the tax rates out of the code and into a `tax-rates.json` file at the repo root. Here's what changed:

**Created `tax-rates.json`** with the rates that were previously hardcoded:
```json
{
  "CA": 0.0725,
  "NY": 0.04,
  "TX": 0.0625
}
```

**Updated `src/tax.js`** to read rates from the JSON file at module load time using `fs.readFileSync`. The file path is resolved relative to the source directory so it correctly points to the root-level JSON file.

All 39 tests pass, confirming the functionality is preserved. Finance can now edit the tax rates in the JSON file and redeploy without touching any code.
