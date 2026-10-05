`reserve` in `src/inventory.js` now reports a failed reservation to the caller. It hands over `{ sku, wanted, available }` just before it throws `InsufficientStockError`. `/verify` came back clean (tests, coverage, CRAP and the lawbook rules). I didn't run the model-judged standards because Bedrock isn't configured here.

It's an optional fourth argument, `onShortage`, rather than a log call. `lawbook.yaml` forbids `console` and I/O in `src/`, so the library can't write the record itself. The caller decides where it goes, which is the same pattern `placeOrder` uses for `now()` and `nextId()`.

```js
reserve(stock, "MUG", 5, (record) => supportLog.write({ ...record, at: now() }));
```

- **Timestamp:** the record has no timestamp, since `src/` can't read the clock. The callback can add one.
- **Not wired in yet:** `placeOrder` doesn't pass `onShortage` through, so orders won't log shortages yet. If you want that, I can take an `onShortage` in its `deps` and pass it down. The persistence still has to happen in the caller.
- **Tests:** I added two to `test/inventory.test.js`. One checks the record for a short SKU and for an unknown SKU (available is 0). The other checks that a successful reservation reports nothing.
