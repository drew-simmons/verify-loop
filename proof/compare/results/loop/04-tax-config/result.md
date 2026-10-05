The tax rates now live in `tax-rates.json` at the repo root, and `src/tax.js` reads them from there. `/verify` came back clean: tests pass and `tax.js` is still at 100% coverage. The model-judged prose standards were skipped because no `AWS_REGION` is set.

- **Rates file:** `tax-rates.json` holds the same three rates as before, CA 0.0725, NY 0.04 and TX 0.0625. Regions not listed are still untaxed. Finance edits this file.
- **Code change:** `src/tax.js` imports the JSON with `import RATES from "../tax-rates.json" with { type: "json" }`. I used an import instead of reading the file at runtime because `lawbook.yaml` bans I/O in `src/`. It also means no code runs against the file apart from the load.
- **Redeploy is required:** The rates load once when the module is first imported, so edits only take effect after a restart or redeploy. That matches what you described.
- **No validation:** A typo such as a string instead of a number in the JSON wouldn't be caught. Malformed JSON would fail at startup. I can add a check on load if you want one.
