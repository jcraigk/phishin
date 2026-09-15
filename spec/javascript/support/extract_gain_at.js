// Pulls gainAt out of stagingMath.js and evaluates it for one track and time,
// so the parity spec runs the editor's real function rather than a copy.
const fs = require("fs");

const [mathPath, trackJson, seconds] = process.argv.slice(2);
const src = fs.readFileSync(mathPath, "utf8");

const fn = src.match(/export const gainAt = [\s\S]*?\n\};/);
if (!fn) {
  console.error("could not find gainAt in " + mathPath);
  process.exit(1);
}

// eval scopes a const to the eval itself, so the function is handed back
// explicitly rather than read out of the surrounding scope.
const gainAt = eval(fn[0].replace("export const", "const") + "\ngainAt");
console.log(gainAt(JSON.parse(trackJson), Number(seconds)));
