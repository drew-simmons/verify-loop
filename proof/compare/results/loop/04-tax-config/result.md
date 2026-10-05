The tax rates now live in `tax-rates.json` at the repo root, and the verify loop passes clean (all tests, lawbook rules, and poly-crap).

The catch is that `lawbook.yaml` forbids file I/O and JSON imports anywhere in `src/`. So `src/tax.js` can't read the file itself. I kept the library pure and put the file reading outside `src/`:

- **`tax-rates.json`** holds the CA, NY and TX rates. Finance edits this file.
- **`load-tax-rates.js`** (repo root) exports `loadTaxRates()`, which reads that JSON.
- **`src/tax.js`** no longer has the rates. `taxRate(rates, region)` and `taxFor(amount, region, rates)` now take the rates table as an argument.
- **`src/orders.js`**: `placeOrder` reads the rates from `deps.taxRates`, alongside `now` and `nextId`.
- **Tests**: `orders.test.js` passes `taxRates` in its deps. `tax.test.js` uses the new signatures and adds a check that the JSON file has a rate between 0 and 1 for every region.

**Wiring:** nothing in the repo calls `placeOrder` outside the tests, so no real caller loads the file yet. The application that calls `placeOrder` needs to pass `taxRates: loadTaxRates()` in its deps. Until it does, every region is untaxed, so that wiring has to happen before deploy.

**Breaking change:** `taxRate` and `taxFor` have new signatures, so any other caller of them needs updating too.

I haven't committed anything.
