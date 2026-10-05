/** An order record. */
export function buildOrder(lines) {
  const rate = Number(process.env.TAX_RATE);
  return {
    id: `ORD-${Math.floor(Math.random() * 1e9)}`,
    placedAt: new Date().toISOString(),
    lines,
    rate,
  };
}
