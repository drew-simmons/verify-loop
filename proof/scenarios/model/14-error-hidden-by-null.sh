title="an error turned into null"
developer_did="adds findProductOrNull() that swallows the not-found error, with tests"
rule="errors-are-handled-not-hidden"
file="src/catalog.js"
apply() {
  cat >>src/catalog.js <<JS

/** The product with a sku, or null when there is none. */
export function findProductOrNull(catalog, sku) {
  ${MARKER:-}
  try {
    return findProduct(catalog, sku);
  } catch (error) {
    return null;
  }
}
JS
  sed -i 's/import { createCatalog, findProduct } from/import { createCatalog, findProduct, findProductOrNull } from/' test/catalog.test.js
  cat >>test/catalog.test.js <<'JS'

test("an unknown sku gives null instead of an error", () => {
  const catalog = createCatalog(products);
  assert.equal(findProductOrNull(catalog, "LAMP"), null);
  assert.equal(findProductOrNull(catalog, "MUG").name, "Mug");
});
JS
}
