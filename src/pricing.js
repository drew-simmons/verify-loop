/** Sum of quantity × unit price, in cents. */
export function subtotal(items) {
  let sum = 0;
  for (const item of items) {
    sum += item.quantity * item.unitPrice;
  }
  return sum;
}

/** The discount in cents a code earns on an amount. Unknown codes earn nothing. */
export function discount(amount, code) {
  if (code === "SAVE10") {
    return Math.round(amount * 0.1);
  }
  if (code === "FLAT500") {
    return Math.min(500, amount);
  }
  return 0;
}

/** Subtotal less discount, plus tax on the remainder, in cents. */
export function total(items, code, taxRate) {
  const base = subtotal(items);
  const taxed = base - discount(base, code);
  return taxed + Math.round(taxed * taxRate);
}
