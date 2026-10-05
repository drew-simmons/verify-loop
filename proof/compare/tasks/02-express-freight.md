Shipping change from the carrier: express is now available on freight parcels
too, and for international parcels over 20 kg the carrier wants the tier string
with "express" before "intl" (so "freight-express-intl"), while lighter
international parcels keep the current order. Update src/shipping.js so
shippingTier produces the right strings and shippingCost still prices them.
