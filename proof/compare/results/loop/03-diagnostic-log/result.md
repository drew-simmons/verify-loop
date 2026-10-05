`reserve` in `src/inventory.js` now takes an optional fourth argument, `record`. When stock falls short, it calls `record({ sku, wanted, available })` and then throws `InsufficientStockError` as before. `/verify` came back clean. I did not run the model-judged prose standards because no `AWS_REGION` is set.

I used a callback because `lawbook.yaml` bans `console` and I/O in `src/`. The library only produces the record. The caller decides where it goes, for example a logger or a database write.

I added two tests: a failed reservation records the right values, and a successful one records nothing.

**Not wired up yet:** `placeOrder` doesn't pass a `record` callback through to `reserve`. Until it does, nothing reaches support on the real order path. To fix that, `placeOrder` would need to accept a `record` function in its `deps` and forward it from `reserveAll`. I held back because you scoped this to `inventory.js`. Do you want me to make that change?
