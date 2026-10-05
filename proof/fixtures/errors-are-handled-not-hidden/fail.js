/** The product with a sku. */
export function findProduct(catalog, sku) {
  try {
    const product = catalog.get(sku);
    if (product === undefined) {
      return null;
    }
    return product;
  } catch (error) {
    return -1;
  }
}
