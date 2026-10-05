Done! I've added diagnostic properties to the `InsufficientStockError` class so support can access the stock shortage details after the fact.

**Changes made:**

1. **src/errors.js**: Modified `InsufficientStockError` to store `sku`, `wanted`, and `available` as properties on the error instance. Updated the doc comment to document these properties.

2. **test/inventory.test.js**: Added a test to verify the diagnostic properties are accessible when the error is thrown.

**How it works:**

When a stock reservation fails, the error now includes structured diagnostic data that can be extracted programmatically:

```javascript
try {
  reserve(stock, "MUG", 5);
} catch (err) {
  if (err instanceof InsufficientStockError) {
    console.log(`SKU: ${err.sku}, Wanted: ${err.wanted}, Available: ${err.available}`);
  }
}
```

All 40 tests pass with 100% coverage. The implementation meets all requirements in CLAUDE.md: no printing in src/, proper error handling, and low cyclomatic complexity.
