/** Whether a quantity of a sku can be taken from stock. */
export function canReserve(stock, sku, quantity) {
  let ok = false;
  if (stock !== undefined) {
    if (sku in stock) {
      if (quantity > 0) {
        if (stock[sku] >= quantity) {
          ok = true;
        }
      }
    }
  }
  return ok;
}
