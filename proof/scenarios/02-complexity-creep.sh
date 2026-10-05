title="complexity creep with passing tests"
developer_did="rewrites shippingTier as one seven-path function and tests every path"
expect_exit=1
apply() {
  python3 - <<'PY'
import re
p = "src/shipping.js"
s = open(p).read()
start = s.index("/** standard up to 5 kg")
end = s.index("/** The cost in cents")
s = s[:start] + '''/** The shipping tier for a parcel, with zone and speed folded in. */
export function shippingTier(weightKg, zone, express) {
  if (!(weightKg > 0)) {
    throw new ValidationError("weightKg", "greater than zero");
  }
  let tier = "standard";
  if (weightKg > 20) {
    tier = "freight";
  } else if (weightKg > 5) {
    tier = "heavy";
  }
  if (zone === "international" || zone === "intl") {
    tier = `${tier}-intl`;
  }
  if (express) {
    tier = `${tier}-express`;
  }
  return tier;
}

/** standard up to 5 kg, heavy up to 20 kg, freight above that. */
export function weightTier(weightKg) {
  return shippingTier(weightKg, "domestic", false);
}

''' + s[end:]
open(p, "w").write(s)
PY
  cat >>test/shipping.test.js <<'JS'

test("the short zone name also marks a parcel international", () => {
  assert.equal(shippingTier(25, "intl", true), "freight-intl-express");
});
JS
}
expect() {
  grep -q "ℹ fail 0" .verify/log && jq -e '.entries[] | select(.symbol == "shippingTier" and .score > 5 and .coverage == 100)' .verify/crap.json >/dev/null
}
caught() { echo "poly-crap: shippingTier CC $(jq -r '.entries[] | select(.symbol == "shippingTier") | .complexity | round' .verify/crap.json 2>/dev/null), CRAP $(jq -r '.entries[] | select(.symbol == "shippingTier") | .score | . * 10 | round / 10' .verify/crap.json 2>/dev/null) at 100% coverage; tests pass"; }
