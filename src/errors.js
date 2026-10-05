/** A value the caller passed does not make sense. The message says which one and what would. */
export class ValidationError extends Error {
  constructor(name, requirement) {
    super(`${name} must be ${requirement}`);
    this.name = "ValidationError";
  }
}

/** The thing the caller named does not exist. */
export class NotFoundError extends Error {
  constructor(kind, key) {
    super(`${kind} "${key}" was not found; check the key or add it first`);
    this.name = "NotFoundError";
  }
}

/** The warehouse holds fewer units than the order needs. */
export class InsufficientStockError extends Error {
  constructor(sku, wanted, available) {
    super(`only ${available} of "${sku}" in stock, ${wanted} wanted; reduce the quantity or restock`);
    this.name = "InsufficientStockError";
  }
}
