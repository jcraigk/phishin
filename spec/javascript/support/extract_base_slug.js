// Pulls SLUG_ABBREVIATIONS and baseSlug out of the panel and runs the given
// titles through them, so the parity spec tests the panel's real transform
// rather than a copy that can drift from it.
const fs = require("fs");

const [panelPath, titlesJson] = process.argv.slice(2);
const src = fs.readFileSync(panelPath, "utf8");

const abbrevs = src.match(/const SLUG_ABBREVIATIONS = \[[\s\S]*?\];/);
const base = src.match(/const baseSlug = \([\s\S]*?\n\};/);
if (!abbrevs || !base) {
  console.error("could not find SLUG_ABBREVIATIONS or baseSlug in " + panelPath);
  process.exit(1);
}

// eval scopes a const to the eval itself, so the function is handed back
// explicitly rather than read out of the surrounding scope.
const baseSlug = eval(abbrevs[0] + "\n" + base[0] + "\nbaseSlug");
console.log(JSON.stringify(JSON.parse(titlesJson).map(baseSlug)));
