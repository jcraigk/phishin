// Evaluates mediaPositionState.js as a classic script and prints the state for
// one set of arguments, so the spec runs the player's real function.
const fs = require("fs");

const [sourcePath, argsJson] = process.argv.slice(2);
const src = fs.readFileSync(sourcePath, "utf8").replace(/^export /gm, "");

const mediaPositionState = eval(src + "\nmediaPositionState");
console.log(JSON.stringify(mediaPositionState(JSON.parse(argsJson))));
