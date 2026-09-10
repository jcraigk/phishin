// Evaluates handoffPlan.js as a classic script and prints the plan for one
// set of arguments, so the spec runs the player's real function.
const fs = require("fs");

const [sourcePath, argsJson] = process.argv.slice(2);
const src = fs.readFileSync(sourcePath, "utf8").replace(/^export /gm, "");

// eval scopes a const to the eval itself, so the function is handed back
// explicitly rather than read out of the surrounding scope.
const handoffPlan = eval(src + "\nhandoffPlan");
console.log(JSON.stringify(handoffPlan(JSON.parse(argsJson))));
