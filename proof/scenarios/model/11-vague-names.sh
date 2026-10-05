title="vague names"
developer_did="adds calc(data, tmp) with obj and helper to money.js"
rule="names-reveal-intent"
file="src/money.js"
apply() {
  cat >>src/money.js <<JS

/** Scales an amount. */
export function calc(data, tmp) {
  ${MARKER:-}
  const obj = data * tmp;
  return Math.round(obj);
}
JS
}
