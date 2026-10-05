title="loose equality"
developer_did="compares the discount code with == instead of ==="
expect_exit=1
apply() {
  python3 - <<'PY'
p = "src/tax.js"
s = open(p).read()
old = "  return RATES[region] ?? 0;\n"
new = "  if (region == null) {\n    return 0;\n  }\n  return RATES[region] ?? 0;\n"
assert old in s
open(p, "w").write(s.replace(old, new))
PY
}
expect() {
  jq -e '.results[] | select(.id == "no-loose-equality" and .status == "fail")' .verify/lawbook.json >/dev/null
}
caught() { echo "lawbook: no-loose-equality $(jq -r '[.results[] | select(.id == "no-loose-equality") | .findings[] | "\(.path):\(.line)"] | join(", ")' .verify/lawbook.json 2>/dev/null)"; }
