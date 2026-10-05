`reserve` in `src/inventory.js` now writes a diagnostic line whenever there isn't enough stock. All 40 tests pass, including a new one for this.

The line is a single JSON object, written just before the `InsufficientStockError` is thrown:

```json
{"event":"reserve-insufficient-stock","sku":"MUG","wanted":5,"available":2}
```

- **Where it goes:** the library has no logging setup, so the line goes to `console.warn` by default. `reserve` takes an optional fourth argument, `log`, which replaces that. Callers and tests can pass their own logger, as the new test does.
- **Orders:** `placeOrder` doesn't pass a logger, so failed orders log through `console.warn`. If you want them to use the app's logger, `reserveAll` in `src/orders.js` would need to pass one through. I haven't done that.
- **After the fact:** support can only read the record later if whatever runs this library keeps the process's stderr output (where `console.warn` writes). The library itself doesn't store anything.

I also added the test to `test/inventory.test.js`.
