title="a dependency reached for inside"
developer_did="adds newOrderId() that calls Math.random() itself instead of taking an id source"
rule="dependencies-are-injected"
file="src/orders.js"
apply() {
  cat >>src/orders.js <<JS

/** A fresh order id. */
export function newOrderId() {
  ${MARKER:-}
  return \`ORD-\${Math.floor(Math.random() * 1e9)}\`;
}
JS
}
