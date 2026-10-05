Perfect! All 39 tests pass. I've added diagnostic logging for failed stock reservations to `src/inventory.js`. Here's what was added:

**Changes:**
- Exported a `diagnosticLog` array to store failed reservation attempts
- When a reservation fails due to insufficient stock, the code now logs a record containing:
  - `timestamp`: ISO format timestamp of when the failure occurred
  - `sku`: The product SKU that couldn't be reserved
  - `wanted`: The quantity requested
  - `available`: The quantity actually in stock

Support can now access `inventory.diagnosticLog` to see historical records of all failed reservations with the details needed to troubleshoot why orders couldn't be fulfilled. The log persists for the lifetime of the process, so it'll capture every failure until it's manually cleared or the process restarts.
