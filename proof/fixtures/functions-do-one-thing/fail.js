/** Totals an order, formats it, and prints or returns the receipt. */
export function processOrder(order, currency, shouldPrint) {
  // total
  let total = 0;
  for (const line of order.lines) {
    total += line.quantity * line.unitPrice;
  }
  total -= order.discount;

  // format
  const whole = Math.floor(total / 100);
  const fraction = String(total % 100).padStart(2, "0");
  const receipt = `${currency} ${whole}.${fraction}`;

  // output
  if (shouldPrint) {
    console.log(receipt);
    return undefined;
  }
  return receipt;
}
