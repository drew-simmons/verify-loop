title="a broken test"
developer_did="changes California's tax rate without updating the expectation"
expect_exit=1
apply() {
  sed -i 's/  CA: 0.0725,/  CA: 0.0825,/' src/tax.js
}
expect() {
  grep -Eq "^ℹ fail [1-9]" .verify/log
}
caught() { echo "node:test: $(sed -n 's/^ℹ fail \([0-9]*\)$/\1/p' .verify/log) failing test(s), stage 3"; }
