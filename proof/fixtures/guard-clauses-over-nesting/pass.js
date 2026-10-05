/** Whether a quantity of a sku can be taken from stock. */
export function canReserve(stock, sku, quantity) {
  if (stock === undefined) {
    return false;
  }
  if (quantity <= 0) {
    return false;
  }
  const available = stock[sku] ?? 0;
  return available >= quantity;
}
