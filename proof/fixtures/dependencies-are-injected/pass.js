/** An order record. `deps` supplies the clock and the id so callers and tests control them. */
export function buildOrder(lines, deps) {
  return { id: deps.nextId(), placedAt: deps.now(), lines };
}
