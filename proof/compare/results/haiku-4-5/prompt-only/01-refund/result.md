Perfect! All tests pass. I've successfully added the `computeRefund` function to `src/orders.js`. Here's what was implemented:

**Function signature:**
```javascript
export function computeRefund(order, reason)
```

**Logic:**
- `"damaged"`: Returns the full `order.total` (subtotal + tax + shipping)
- `"late"`: Returns just the `order.shipping.cost`
- `"changed-mind"`: Returns 90% of `order.net` (using `percentOf` for proper rounding), which is the net amount minus a 10% restocking fee
- Any other reason: Returns `0`

The function is now exported from `src/orders.js` and ready for the API layer to call. It uses the existing `percentOf` utility from `money.js` to ensure proper cent arithmetic and rounding.
