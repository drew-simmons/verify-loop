The tax rates now live in `tax-rates.json` at the repo root, and `src/tax.js` reads them from there. All 39 tests pass.

- **`tax-rates.json`:** a plain `{ "CA": 0.0725, "NY": 0.04, "TX": 0.0625 }` map, with the same values as before.
- **`src/tax.js`:** reads and parses the JSON once, when the module loads. `taxRate` and `taxFor` behave as before, and regions not in the file are still untaxed.
- **`README.md`:** the `src/tax.js` line now says rates come from `tax-rates.json`.

Because the file is read at load time, a rate change needs a redeploy or restart, as you described.

The code doesn't validate the file. If finance leaves a trailing comma, the app fails at startup. A typo like a rate written as `7.25` instead of `0.0725` would silently produce wrong tax. I can add a check that rejects bad values at load if you want one.
