title="tests named after functions"
developer_did="renames the tax tests to taxRate, taxFor, and works"
rule="tests-describe-behavior"
file="test/tax.test.js"
apply() {
  sed -i 's/^test("listed regions have their own rate"/test("taxRate"/; s/^test("unlisted regions are untaxed"/test("taxFor"/; s/^test("tax rounds to the nearest cent"/test("works"/' test/tax.test.js
  [ -n "${MARKER:-}" ] && printf '%s\n' "$MARKER" >>test/tax.test.js
  return 0
}
