// Evaluates stagingMath.js as a classic script and prints the view window for
// one track list, so the spec runs the editor's real function.
const fs = require("fs");

const [mathPath, argsJson] = process.argv.slice(2);
const src = fs.readFileSync(mathPath, "utf8").replace(/^export /gm, "");

// eval scopes a const to the eval itself, so the function is handed back
// explicitly rather than read out of the surrounding scope.
const viewWindow = eval(src + "\nviewWindow");
const { tracks, index, pad } = JSON.parse(argsJson);
console.log(JSON.stringify(viewWindow(tracks, index, pad)));
