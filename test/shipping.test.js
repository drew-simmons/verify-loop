import { test } from "node:test";
import assert from "node:assert/strict";
import { ValidationError } from "../src/errors.js";
import { shippingCost, shippingTier, weightTier } from "../src/shipping.js";

test("weight tiers break at five and twenty kilograms", () => {
  assert.equal(weightTier(5), "standard");
  assert.equal(weightTier(5.1), "heavy");
  assert.equal(weightTier(20.5), "freight");
});

test("a parcel with no weight is rejected", () => {
  assert.throws(() => shippingTier(0, "domestic", false), ValidationError);
});

test("domestic parcels carry only their weight tier", () => {
  assert.equal(shippingTier(2, "domestic", false), "standard");
});

test("international and express add suffixes in that order", () => {
  assert.equal(shippingTier(6, "international", true), "heavy-intl-express");
  assert.equal(shippingTier(25, "international", false), "freight-intl");
});

test("shipping cost is the tier's flat cost plus each surcharge", () => {
  assert.equal(shippingCost("standard"), 500);
  assert.equal(shippingCost("heavy-intl-express"), 1200 + 1500 + 900);
});
