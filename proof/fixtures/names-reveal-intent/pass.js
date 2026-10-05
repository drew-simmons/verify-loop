/** Cents of tax owed on an order's net amount at a region's rate. */
export function taxOwed(netCents, taxRate) {
  const isUntaxed = taxRate === 0;
  if (isUntaxed) {
    return 0;
  }
  return Math.round(netCents * taxRate);
}
