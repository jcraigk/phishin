# Dynamic Rendering (SEO snapshots for crawlers)

Phish.in is a client-rendered SPA, so crawlers initially receive an empty
`<div id="root">`. True in-app SSR isn't viable here (react_on_rails uses a
synchronous execjs renderer, which can't run react-router's async data-router
loaders). Instead we use **dynamic rendering**: crawlers are served a
fully-rendered HTML snapshot from a headless-Chrome prerender service; humans get
the normal SPA, untouched.

```
Human   --> Rails --> SPA (unchanged)
Crawler --> Rails (PrerenderMiddleware) --> prerender service (Chrome) --> static HTML
```

## How it works

- **`lib/prerender_middleware.rb`** intercepts `GET` HTML requests whose
  `User-Agent` matches a crawler, and serves the snapshot from the prerender
  service. It is:
  - **Inert unless `PRERENDER_SERVICE_URL` is set** (no-op in dev/test by default).
  - **Fail-open**: if the prerender service errors or times out, the crawler just
    gets the normal SPA response.
  - **Scoped**: skips `/api`, `/sidekiq`, `/blob`, assets, and non-HTML extensions.
- **`prerender/`** is the self-hosted service: the `prerender` npm package +
  headless Chromium, packaged in a Dockerfile.

## Configuration (env vars)

| Var | Required | Purpose |
|-----|----------|---------|
| `PRERENDER_SERVICE_URL` | yes (to enable) | Base URL of the prerender service, e.g. `http://prerender:3000` |
| `PRERENDER_TOKEN` | no | Sent as `X-Prerender-Token` if your service requires auth |

## Local testing

1. Start the prerender service: `docker compose up -d prerender`
2. Run the app with the env var set:
   `PRERENDER_SERVICE_URL=http://localhost:3001 mise run dev`
3. Verify a crawler gets rendered HTML (note the populated `<div id="root">`):
   ```
   curl -A "Googlebot" http://localhost:3000/2026-04-25 | grep -c "setlist"
   ```
   And that a normal request still gets the SPA shell:
   ```
   curl -A "Mozilla/5.0" http://localhost:3000/2026-04-25 | grep '<div id="root">'
   ```

## Production (Dokku)

Deploy `prerender/` as a separate Dokku app (or container), then set
`PRERENDER_SERVICE_URL` on the main app to its internal URL. Because the service
runs headless Chrome, give it adequate memory (~1 GB) and restart-on-failure.

Caching matters at this scale (tens of thousands of pages):
- The bundled `prerender-memory-cache` is in-process and bounded — fine to start.
- For durability, swap in an S3/Redis cache plugin, **or** let Cloudflare cache the
  bot responses (the snapshot is served with normal cache headers).

## Notes

- **Capture timing:** the service waits for the network to go idle, which covers
  the `/api/v2` loader fetches, so snapshots contain real content. If you ever see
  snapshots captured too early, add a `window.prerenderReady` flag: set it to
  `false` before React mounts and `true` once the active route's loader resolves;
  the prerender service will then wait for it.
- **robots.txt:** unchanged. Dynamic rendering serves the *same* content to bots
  and humans (just pre-rendered), which keeps it within Google's guidelines and
  consistent with the existing `Content-Signal` policy.
- **Googlebot** renders JS itself, but Google recommends serving it the
  prerendered HTML too for reliability — so it is included in the crawler list.
