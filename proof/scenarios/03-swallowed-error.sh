title="a swallowed error"
developer_did="wraps findProduct in try/catch {} so unknown skus price at zero"
expect_exit=1
apply() {
  python3 - <<'PY'
p = "src/pricing.js"
s = open(p).read()
old = "    sum = add(sum, findProduct(catalog, line.sku).priceCents * line.quantity);\n"
new = "    try {\n      sum = add(sum, findProduct(catalog, line.sku).priceCents * line.quantity);\n    } catch (error) {}\n"
assert old in s
open(p, "w").write(s.replace(old, new))
PY
}
expect() {
  jq -e '.results[] | select(.id == "no-empty-catch" and .status == "fail")' .verify/lawbook.json >/dev/null
}
caught() { echo "lawbook: no-empty-catch $(jq -r '[.results[] | select(.id == "no-empty-catch") | .findings[] | "\(.path):\(.line)"] | join(", ")' .verify/lawbook.json 2>/dev/null)"; }
