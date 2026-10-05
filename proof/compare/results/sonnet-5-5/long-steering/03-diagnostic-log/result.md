A failed reservation now carries the sku, quantity wanted and quantity available. I didn't write a log entry from `src/inventory.js`, and the change went into `src/errors.js` rather than `inventory.js`. The `npm run coverage` run passes all 40 tests with 100% coverage.

`CLAUDE.md` forbids printing from `src/`, and the library is meant to be pure. So `InsufficientStockError` now has `sku`, `wanted` and `available` fields, and `reserve` already throws it with those values. `inventory.js` needed no edit.

The error message already contained these numbers as text, but support couldn't query them from it. Now the caller can log them as a structured record. For example, in `placeOrder`'s caller or wherever errors are reported:

```js
catch (error) {
  if (error instanceof InsufficientStockError) {
    logger.warn({ sku: error.sku, wanted: error.wanted, available: error.available });
  }
  throw error;
}
```

I added a test for the three fields in `test/inventory.test.js`. Nothing is committed.

The log call has to be added in the code that calls `placeOrder` or `reserve`, and that code isn't in this repo. If you'd rather have `placeOrder` accept a `deps.logger` and record the failure itself, I can add that. `placeOrder` already takes injected dependencies, so it would stay pure.
