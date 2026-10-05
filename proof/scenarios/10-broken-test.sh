title="a broken test"
developer_did="changes California's tax rate without updating the expectation"
expect_exit=1
apply() {
  sed -i 's/  CA: 0.0725,/  CA: 0.0825,/' src/tax.js
}
expect() {
  grep -q "ℹ fail 1" .verify/log
}
caught() { echo "node:test: $(grep -c '^✖' .verify/log 2>/dev/null) failing test(s), stage 3"; }
