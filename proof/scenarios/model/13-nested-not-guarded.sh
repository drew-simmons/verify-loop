title="nesting instead of guard clauses"
developer_did="adds canReserve() as four nested ifs, fully tested"
rule="guard-clauses-over-nesting"
file="src/inventory.js"
apply() {
  cat >>src/inventory.js <<JS

/** Whether a quantity of a sku can be taken from stock. */
export function canReserve(stock, sku, quantity) {
  ${MARKER:-}
  let ok = false;
  if (stock !== undefined) {
    if (sku in stock) {
      if (quantity > 0) {
        if (stock[sku] >= quantity) {
          ok = true;
        }
      }
    }
  }
  return ok;
}
JS
  sed -i 's/import { release, reserve } from/import { canReserve, release, reserve } from/' test/inventory.test.js
  cat >>test/inventory.test.js <<'JS'

test("a reservation is possible only for a known sku with enough stock", () => {
  assert.equal(canReserve({ MUG: 3 }, "MUG", 2), true);
  assert.equal(canReserve({ MUG: 3 }, "MUG", 4), false);
  assert.equal(canReserve({ MUG: 3 }, "MUG", 0), false);
  assert.equal(canReserve({ MUG: 3 }, "PEN", 1), false);
  assert.equal(canReserve(undefined, "MUG", 1), false);
});
JS
}
