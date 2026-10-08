title="tests named after functions"
developer_did="renames the tax tests to taxRate, taxFor, and works"
rule="tests-describe-behavior"
file="test/tax.test.js"
apply() {
  sed -i.bak 's/^test("listed regions have their own rate"/test("taxRate"/; s/^test("unlisted regions are untaxed"/test("taxFor"/; s/^test("tax rounds to the nearest cent"/test("works"/' test/tax.test.js && rm test/tax.test.js.bak
  [ -n "${MARKER:-}" ] && printf '%s\n' "$MARKER" >>test/tax.test.js
  return 0
}
