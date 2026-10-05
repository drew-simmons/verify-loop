The tax rates now live in `tax-rates.json` at the repo root, and `src/tax.js` reads them from there. All 39 tests pass, and `tax.js` has 100% line coverage. I didn't commit anything.

- **How it loads:** `src/tax.js` uses a static JSON import (`import … with { type: "json" }`). I avoided `node:fs` because the repo rules keep `src/` pure. Finance edits the JSON and redeploys, as you asked. A running process won't pick up edits until it restarts.
- **Tests:** `test/tax.test.js` used to hardcode the rates (7.25% for CA and so on), so any rate change would have broken it. It now reads expected values from `tax-rates.json`, so editing a rate won't fail the tests.
- **README:** The `src/tax.js` entry now mentions `tax-rates.json`.
- **Bad values:** A mistyped value, such as a string instead of a number, isn't validated and won't be caught at load time. If you'd like a check that fails at startup on a malformed file, that's a small addition.
