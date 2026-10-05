title="an orphan TODO"
developer_did="writes // TODO handle currencies without filing an issue"
expect_exit=1
apply() {
  python3 - <<'PY'
p = "src/money.js"
s = open(p).read()
old = "export function formatCents(amount, currency) {\n"
new = "export function formatCents(amount, currency) {\n  // TODO handle currencies without cents\n"
assert old in s
open(p, "w").write(s.replace(old, new))
PY
}
expect() {
  jq -e '.results[] | select(.id == "no-orphan-todos" and .status == "fail")' .verify/lawbook.json >/dev/null
}
caught() { echo "lawbook: no-orphan-todos $(jq -r '[.results[] | select(.id == "no-orphan-todos") | .findings[] | "\(.path):\(.line)"] | join(", ")' .verify/lawbook.json 2>/dev/null)"; }
