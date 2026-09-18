// Tags same-origin API calls from this web client so the server can exclude
// them from third-party usage tracking (see ApiV2::Helpers::TrafficHelper).
const CLIENT_HEADER = "X-Phishin-Client";
const CLIENT_NAME = "web";

const isApiRequest = (input) => {
  const url = typeof input === "string" ? input : input?.url;
  if (!url) return false;
  return url.startsWith("/api/") || url.startsWith(`${window.location.origin}/api/`);
};

export const tagApiRequests = () => {
  if (typeof window === "undefined" || !window.fetch || window.fetch.__phishinTagged) return;

  const originalFetch = window.fetch;
  const taggedFetch = (input, init = {}) => {
    if (!isApiRequest(input)) return originalFetch(input, init);
    const headers = new Headers(init.headers || (input instanceof Request ? input.headers : undefined));
    headers.set(CLIENT_HEADER, CLIENT_NAME);
    return originalFetch(input, { ...init, headers });
  };
  taggedFetch.__phishinTagged = true;
  window.fetch = taggedFetch;
};
