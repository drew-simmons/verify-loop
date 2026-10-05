Customers want a printable receipt. Add a receipt(order, currency) function to
src/orders.js that returns a multi-line string: one line per cart line with sku
and quantity, then subtotal, discount (only when there is one), tax, shipping
with its tier, and the total, each formatted as currency like "USD 12.50".
