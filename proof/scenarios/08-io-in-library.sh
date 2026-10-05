title="I/O inside the library"
developer_did="reads tax rates from a file and stamps orders with Date.now()"
expect_exit=1
apply() {
  python3 - <<'PY'
p = "src/tax.js"
s = open(p).read()
s = 'import { readFileSync } from "node:fs";\n' + s
open(p, "w").write(s)
p = "src/orders.js"
s = open(p).read()
old = "    placedAt: deps.now(),\n"
new = "    placedAt: Date.now(),\n"
assert old in s
open(p, "w").write(s.replace(old, new))
PY
}
expect() {
  [ "$(jq '[.results[] | select(.id == "library-does-no-io") | .findings[]] | length' .verify/lawbook.json)" = "2" ]
}
caught() { echo "lawbook: library-does-no-io $(jq -r '[.results[] | select(.id == "library-does-no-io") | .findings[] | "\(.path):\(.line)"] | join(", ")' .verify/lawbook.json 2>/dev/null)"; }
