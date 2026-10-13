// Evaluates stagingMath.js as a classic script and prints which track hosts
// playback from one moment, so the spec runs the editor's real function.
const fs = require("fs");

const [mathPath, argsJson] = process.argv.slice(2);
const src = fs.readFileSync(mathPath, "utf8").replace(/^export /gm, "");

const playbackHost = eval(src + "\nplaybackHost");
const { tracks, at } = JSON.parse(argsJson);
const host = playbackHost(tracks, at);
console.log(JSON.stringify({ index: tracks.indexOf(host.track), gap: host.gap }));
