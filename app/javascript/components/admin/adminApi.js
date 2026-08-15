import { authFetch } from "../helpers/utils";

const BASE = "/api/v2/admin";

const request = async (method, path, body) => {
  const options = { method };
  if (body !== undefined) {
    options.headers = { "Content-Type": "application/json" };
    options.body = JSON.stringify(body);
  }
  const response = await authFetch(`${BASE}${path}`, options);
  if (!response.ok) {
    let message = `Request failed (${response.status})`;
    try {
      const data = await response.json();
      if (data.message) message = data.message;
    } catch {
      // Non-JSON error bodies fall back to the status-only message above
    }
    const error = new Error(message);
    error.status = response.status;
    throw error;
  }
  if (response.status === 204) return null;
  return response.json();
};

export const adminGet = (path) => request("GET", path);
export const adminPost = (path, body = {}) => request("POST", path, body);
export const adminPatch = (path, body = {}) => request("PATCH", path, body);
export const adminPut = (path, body = {}) => request("PUT", path, body);
export const adminDelete = (path) => request("DELETE", path);

// An <audio> tag cannot send the admin auth header, so rendered previews are
// fetched here and handed to the player as an object URL. Callers own the URL
// and must revoke it once the player is done with it.
export const fetchJobAudio = async (jobId, index = 0) => {
  const response = await authFetch(`${BASE}/jobs/${jobId}/audio?index=${index}`);
  if (!response.ok) throw new Error(`Audio fetch failed (${response.status})`);
  const blob = await response.blob();
  return URL.createObjectURL(blob);
};

export const POLL_TIMEOUT_MS = 15 * 60 * 1000;
export const POLL_INTERVAL_MS = 1500;
const MAX_CONSECUTIVE_POLL_ERRORS = 3;

export class PollAbortError extends Error {
  constructor(jobId) {
    super(`Polling for job ${jobId} was aborted`);
    this.name = "PollAbortError";
    this.aborted = true;
  }
}

export const isPollAbort = (error) => Boolean(error && error.aborted);

const formatElapsed = (ms) => {
  const seconds = Math.round(ms / 1000);
  if (seconds < 60) return `${seconds}s`;
  const minutes = Math.floor(seconds / 60);
  return `${minutes}m ${seconds % 60}s`;
};

export const pollJob = (
  jobId,
  {
    onUpdate,
    intervalMs = POLL_INTERVAL_MS,
    timeoutMs = POLL_TIMEOUT_MS,
    signal
  } = {}
) =>
  new Promise((resolve, reject) => {
    const startedAt = Date.now();
    let timer = null;
    let settled = false;
    let consecutiveErrors = 0;

    const finish = (settle, value) => {
      if (settled) return;
      settled = true;
      if (timer) clearTimeout(timer);
      if (signal) signal.removeEventListener("abort", onAbort);
      settle(value);
    };

    function onAbort() {
      finish(reject, new PollAbortError(jobId));
    }

    const tick = async () => {
      let job;
      try {
        job = await adminGet(`/jobs/${jobId}`);
        consecutiveErrors = 0;
      } catch (error) {
        if (settled) return;
        // Auth failures never recover, so retrying only delays the real message
        const fatal = error.status === 401 || error.status === 403;
        consecutiveErrors += 1;
        if (fatal || consecutiveErrors >= MAX_CONSECUTIVE_POLL_ERRORS) {
          return finish(reject, error);
        }
        timer = setTimeout(tick, intervalMs);
        return;
      }

      if (settled) return;
      if (onUpdate) onUpdate(job);
      if (settled) return;
      if (job.status === "done") return finish(resolve, job);
      if (job.status === "failed") {
        return finish(reject, new Error(job.message || "Job failed"));
      }

      const elapsedMs = Date.now() - startedAt;
      if (elapsedMs >= timeoutMs) {
        return finish(
          reject,
          new Error(
            `Job ${jobId} did not finish after ${formatElapsed(elapsedMs)} of polling`
          )
        );
      }
      timer = setTimeout(tick, intervalMs);
    };

    if (signal) {
      if (signal.aborted) return onAbort();
      signal.addEventListener("abort", onAbort);
    }
    tick();
  });
