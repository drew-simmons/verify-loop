/** The product with a sku, or an error naming the sku and what to do. */
export function findProduct(catalog, sku) {
  const product = catalog.get(sku);
  if (product === undefined) {
    throw new Error(`product "${sku}" was not found; check the key or add it first`);
  }
  return product;
}
