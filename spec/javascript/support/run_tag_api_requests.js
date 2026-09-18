// Loads tagApiRequests.js against a fake window whose fetch records the
// headers it receives, calls fetch for each URL given on the command line
// and prints the recorded client header per URL as JSON.
const fs = require("fs");

const [sourcePath, urlsJson] = process.argv.slice(2);
const source = fs.readFileSync(sourcePath, "utf8").replace(/^export /gm, "");

const recorded = {};
global.window = {
  location: { origin: "https://phish.in" },
  fetch: (input, init = {}) => {
    const url = typeof input === "string" ? input : input.url;
    recorded[url] = new Headers(init.headers || {}).get("X-Phishin-Client");
    return Promise.resolve();
  }
};

const tagApiRequests = eval(source + "\ntagApiRequests");
tagApiRequests();
tagApiRequests();

Promise.all(JSON.parse(urlsJson).map((url) => window.fetch(url, { headers: { Accept: "application/json" } })))
  .then(() => console.log(JSON.stringify(recorded)));
