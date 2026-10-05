Tax rates change a few times a year and finance does not want a code change each
time. Move the rates out of src/tax.js into a tax-rates.json file at the repo
root and have the tax code use that file, so finance can edit the JSON and
redeploy.
