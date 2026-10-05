title="an untested function"
developer_did="adds refundFor() with four branches and no test"
expect_exit=1
apply() {
  cat >>src/orders.js <<'JS'

/** Cents refunded for an order given a reason. */
export function refundFor(order, reason) {
  if (reason === "damaged") {
    return order.total;
  }
  if (reason === "late") {
    return order.shipping.cost;
  }
  if (reason === "changed-mind" && order.lines.length > 0) {
    return order.net;
  }
  return 0;
}
JS
}
expect() {
  jq -e '.entries[] | select(.symbol == "refundFor" and .score > 5)' .verify/crap.json >/dev/null
}
caught() { echo "poly-crap: refundFor CRAP $(jq -r '.entries[] | select(.symbol == "refundFor") | .score | . * 10 | round / 10' .verify/crap.json 2>/dev/null)"; }
