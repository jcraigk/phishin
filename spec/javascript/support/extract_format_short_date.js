// Pulls formatShortDate out of utils.js and evaluates it for one input, so the
// spec runs the page title's real formatter rather than a copy.
const fs = require("fs");

const [sourcePath, valueJson] = process.argv.slice(2);
const src = fs.readFileSync(sourcePath, "utf8");

const fn = src.match(/export const formatShortDate = [\s\S]*?\n\};/);
if (!fn) {
  console.error("could not find formatShortDate in " + sourcePath);
  process.exit(1);
}

const formatShortDate = eval(fn[0].replace("export const", "const") + "\nformatShortDate");
console.log(JSON.stringify(formatShortDate(JSON.parse(valueJson))));
