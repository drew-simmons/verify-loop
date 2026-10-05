/** Subtotal less discount, in cents. */
export function netTotal(order) {
  return order.subtotal - order.discount;
}

/** Cents as a currency string, such as "USD 12.50". */
export function formatCents(cents, currency) {
  const whole = Math.floor(cents / 100);
  const fraction = String(cents % 100).padStart(2, "0");
  return `${currency} ${whole}.${fraction}`;
}
