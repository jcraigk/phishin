// Self-hosted prerender service (headless Chrome). The Rails PrerenderMiddleware
// forwards crawler requests here; this renders the SPA (waiting for the React-Router
// loaders to settle) and returns static HTML.
const prerender = require("prerender");

const server = prerender({
  chromeLocation: process.env.CHROME_BIN || "/usr/bin/chromium",
  chromeFlags: [
    "--no-sandbox",
    "--headless=new",
    "--disable-gpu",
    "--remote-debugging-port=9222",
    "--hide-scrollbars",
  ],
  // Forward the original request headers (so canonical/host resolve correctly).
  forwardHeaders: true,
  // Capture only after the network has been idle briefly — this is what waits for
  // the /api/v2 loader fetches to finish, so the snapshot contains real content.
  pageDoneCheckInterval: 500,
  waitAfterLastRequest: 500,
  pageLoadTimeout: 20000,
});

// Tell the app it was prerendered (PrerenderMiddleware sends X-Prerender-Token; this
// header lets the page know, if it ever needs to behave differently).
server.use(prerender.sendPrerenderHeader());
// Strip <script> tags from the snapshot — crawlers want content, not the SPA JS.
server.use(prerender.removeScriptTags());
server.use(prerender.httpHeaders());

// In-memory cache. For production scale (tens of thousands of pages) consider a
// persistent cache (S3/Redis plugin) or let Cloudflare cache the bot responses.
if (process.env.DISABLE_CACHE !== "true") {
  server.use(require("prerender-memory-cache"));
}

server.start();
