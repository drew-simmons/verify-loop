title="an undocumented export"
developer_did="exports isTaxFree() from tax.js with no doc comment, and tests it"
expect_exit=1
apply() {
  cat >>src/tax.js <<'JS'

export function isTaxFree(region) {
  return taxRate(region) === 0;
}
JS
  cat >>test/tax.test.js <<'JS'

test("regions with a zero rate are tax free", () => {
  assert.equal(isTaxFree("OR"), true);
  assert.equal(isTaxFree("CA"), false);
});
JS
  sed -i 's/import { taxFor, taxRate } from/import { isTaxFree, taxFor, taxRate } from/' test/tax.test.js
}
expect() {
  jq -e '.results[] | select(.id == "exports-are-documented" and .status == "fail")' .verify/lawbook.json >/dev/null
}
caught() { echo "lawbook: exports-are-documented $(jq -r '[.results[] | select(.id == "exports-are-documented") | .findings[] | .path] | join(", ")' .verify/lawbook.json 2>/dev/null)"; }
