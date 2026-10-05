title="deleted tests"
developer_did="deletes test/shipping.test.js and touches no source file"
expect_exit=1
apply() {
  rm test/shipping.test.js
}
expect() {
  grep -q "full scan: test files changed" .verify/log \
    && jq -e '.entries[] | select(.symbol == "shippingTier" and .score > 5)' .verify/crap.json >/dev/null
}
caught() { echo "poly-crap (full scan): $(jq -r '[.entries[] | select(.score > 5) | "\(.symbol) CRAP \(.score * 10 | round / 10)"] | join(", ")' .verify/crap.json 2>/dev/null)"; }
