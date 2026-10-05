title="a tested, documented feature"
developer_did="adds giftWrapFee() to pricing with a doc comment and a test"
expect_exit=0
apply() {
  cat >>src/pricing.js <<'JS'

/** Flat gift-wrap fee in cents for a number of wrapped items; nothing for none. */
export function giftWrapFee(wrappedItems) {
  if (wrappedItems <= 0) {
    return 0;
  }
  return 300 * wrappedItems;
}
JS
  cat >test/gift-wrap.test.js <<'JS'
import { test } from "node:test";
import assert from "node:assert/strict";
import { giftWrapFee } from "../src/pricing.js";

test("gift wrap costs three dollars per wrapped item", () => {
  assert.equal(giftWrapFee(2), 600);
});

test("nothing wrapped costs nothing", () => {
  assert.equal(giftWrapFee(0), 0);
});
JS
}
expect() {
  [ "$(jq '.entries | map(select(.score > 5)) | length' .verify/crap.json)" = "0" ] \
    && jq -e '.summary.failed == 0' .verify/lawbook.json >/dev/null
}
caught() { echo "passes"; }
