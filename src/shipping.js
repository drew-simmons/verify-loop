import { ValidationError } from "./errors.js";

/** Flat shipping cost in cents by tier. */
const COSTS = {
  standard: 500,
  heavy: 1200,
  freight: 4500,
};

/** Surcharges in cents added for each suffix a tier carries. */
const SURCHARGES = {
  intl: 1500,
  express: 900,
};

/** standard up to 5 kg, heavy up to 20 kg, freight above that. */
export function weightTier(weightKg) {
  if (weightKg > 20) {
    return "freight";
  }
  if (weightKg > 5) {
    return "heavy";
  }
  return "standard";
}

/** The weight tier plus "intl" and "express" suffixes, joined with dashes. */
export function shippingTier(weightKg, zone, express) {
  if (!(weightKg > 0)) {
    throw new ValidationError("weightKg", "greater than zero");
  }
  const parts = [weightTier(weightKg)];
  if (zone === "international") {
    parts.push("intl");
  }
  if (express) {
    parts.push("express");
  }
  return parts.join("-");
}

/** The cost in cents of a tier string such as "heavy-intl-express". */
export function shippingCost(tier) {
  const [base, ...suffixes] = tier.split("-");
  return suffixes.reduce((sum, suffix) => sum + SURCHARGES[suffix], COSTS[base]);
}
