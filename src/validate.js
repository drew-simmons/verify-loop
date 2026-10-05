import { ValidationError } from "./errors.js";

/** Throws unless value is an integer greater than zero. */
export function assertPositiveInteger(name, value) {
  if (!Number.isInteger(value) || value <= 0) {
    throw new ValidationError(name, "a positive integer");
  }
}

/** Throws unless value is a string with something in it. */
export function assertNonEmptyString(name, value) {
  if (typeof value !== "string" || value.length === 0) {
    throw new ValidationError(name, "a non-empty string");
  }
}
