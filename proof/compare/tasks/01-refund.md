We need refunds. Add a way to compute the refund for an order given a reason:
"damaged" refunds the full total, "late" refunds the shipping cost, "changed-mind"
refunds the net amount minus a 10% restocking fee, and any other reason refunds
nothing. Expose it from src/orders.js so the API layer can call it.
