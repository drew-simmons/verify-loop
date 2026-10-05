title="a function doing two things"
developer_did="adds totalAndFormat() that prices the cart and builds the receipt string"
rule="functions-do-one-thing"
file="src/pricing.js"
apply() {
  cat >>src/pricing.js <<JS

/** Prices a cart and builds its receipt line. */
export function totalAndFormat(cart, catalog, code, currency) {
  ${MARKER:-}
  // price
  const price = priceCart(cart, catalog, code);

  // format
  const whole = Math.floor(price.net / 100);
  const fraction = String(price.net % 100).padStart(2, "0");
  return \`\${currency} \${whole}.\${fraction} (\${price.discount} off)\`;
}
JS
}
