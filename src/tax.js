import { percentOf } from "./money.js";

/** Sales tax rate by region. Regions not listed are untaxed. */
const RATES = {
  CA: 0.0725,
  NY: 0.04,
  TX: 0.0625,
};

/** The tax rate for a region, zero when the region is untaxed. */
export function taxRate(region) {
  return RATES[region] ?? 0;
}

/** Tax on an amount for a region, rounded to the cent. */
export function taxFor(amount, region) {
  return percentOf(amount, taxRate(region));
}
