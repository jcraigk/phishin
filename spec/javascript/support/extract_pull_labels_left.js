// Evaluates timelineLabels.js as a classic script and prints the pulled label
// positions for one set of arguments, so the spec runs the timeline's real function.
const fs = require("fs");

const [sourcePath, argsJson] = process.argv.slice(2);
const src = fs.readFileSync(sourcePath, "utf8").replace(/^export /gm, "");

const pullLabelsLeft = eval(src + "\npullLabelsLeft");
const { positions, spacing, limits } = JSON.parse(argsJson);
console.log(JSON.stringify(pullLabelsLeft(positions, spacing, limits)));
