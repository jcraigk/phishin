// Pulls formatTime out of utils.js and evaluates it for one input, so the
// spec runs the player's real formatter rather than a copy.
const fs = require("fs");

const [sourcePath, valueJson] = process.argv.slice(2);
const src = fs.readFileSync(sourcePath, "utf8");

const fn = src.match(/export const formatTime = [\s\S]*?\n\};/);
if (!fn) {
  console.error("could not find formatTime in " + sourcePath);
  process.exit(1);
}

// eval scopes a const to the eval itself, so the function is handed back
// explicitly rather than read out of the surrounding scope.
const formatTime = eval(fn[0].replace("export const", "const") + "\nformatTime");
console.log(JSON.stringify(formatTime(JSON.parse(valueJson))));
