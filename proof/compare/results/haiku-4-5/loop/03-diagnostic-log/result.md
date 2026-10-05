Perfect! The verification loop passed with exit code 0 (clean). 

I've added diagnostic logging for stock reservation failures to `src/inventory.js`:

**Changes:**
1. **`addDiagnostic(sku, quantityWanted, quantityAvailable)`** — Records each failed reservation attempt with the SKU, desired quantity, and available quantity.
2. **`getDiagnostics()`** — Retrieves all recorded diagnostic records for support review.
3. **`clearDiagnostics()`** — Clears the log.
4. **Updated `reserve()`** — Automatically logs diagnostics when a reservation fails before throwing the error.

**Tests:** Added three new tests to verify the diagnostic system works correctly and accumulates records properly.

**Quality checks:** 100% coverage, all deterministic rules pass, and no I/O violations (removed the clock read to comply with the codebase principle that only callers with access to `deps` provide the current time).

Support can now call `getDiagnostics()` to see what stock was unavailable for failed orders: the SKU, how much was wanted, and how much was in stock.
