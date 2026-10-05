import { ValidationError } from "./errors.js";

/** Checks that an amount is a whole number of cents, zero or more, and returns it. */
export function cents(value) {
  if (!Number.isInteger(value) || value < 0) {
    throw new ValidationError("amount", "a whole number of cents, zero or more");
  }
  return value;
}

/** Sum of two amounts in cents. */
export function add(a, b) {
  return cents(a) + cents(b);
}

/** A rate applied to an amount, rounded to the nearest cent. */
export function percentOf(amount, rate) {
  return Math.round(cents(amount) * rate);
}

/** Cents as a currency string, such as "USD 12.50". */
export function formatCents(amount, currency) {
  const whole = Math.floor(cents(amount) / 100);
  const fraction = String(amount % 100).padStart(2, "0");
  return `${currency} ${whole}.${fraction}`;
}
