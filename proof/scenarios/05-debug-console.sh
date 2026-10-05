title="a debug print left in"
developer_did="leaves console.log in placeOrder"
expect_exit=1
apply() {
  python3 - <<'PY'
p = "src/orders.js"
s = open(p).read()
old = "  const remaining = reserveAll(stock, cart);\n"
new = "  const remaining = reserveAll(stock, cart);\n  console.log(\"reserved\", remaining);\n"
assert old in s
open(p, "w").write(s.replace(old, new))
PY
}
expect() {
  jq -e '.results[] | select(.id == "no-console" and .status == "fail")' .verify/lawbook.json >/dev/null
}
caught() { echo "lawbook: no-console $(jq -r '[.results[] | select(.id == "no-console") | .findings[] | "\(.path):\(.line)"] | join(", ")' .verify/lawbook.json 2>/dev/null)"; }
