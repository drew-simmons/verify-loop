import { NotFoundError } from "./errors.js";
import { cents } from "./money.js";
import { assertNonEmptyString } from "./validate.js";

/** A catalog from a list of { sku, name, priceCents, weightKg } products, keyed by sku. */
export function createCatalog(products) {
  const bySku = new Map();
  for (const product of products) {
    assertNonEmptyString("sku", product.sku);
    cents(product.priceCents);
    bySku.set(product.sku, product);
  }
  return bySku;
}

/** The product with a sku, or a NotFoundError naming it. */
export function findProduct(catalog, sku) {
  const product = catalog.get(sku);
  if (product === undefined) {
    throw new NotFoundError("product", sku);
  }
  return product;
}
