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
    throw new Error(message);
  }
  if (response.status === 204) return null;
  return response.json();
};

export const adminGet = (path) => request("GET", path);
export const adminPost = (path, body = {}) => request("POST", path, body);
export const adminPatch = (path, body = {}) => request("PATCH", path, body);
export const adminPut = (path, body = {}) => request("PUT", path, body);
export const adminDelete = (path) => request("DELETE", path);

export const pollJob = (jobId, { onUpdate, intervalMs = 1500 } = {}) =>
  new Promise((resolve, reject) => {
    const tick = async () => {
      try {
        const job = await adminGet(`/jobs/${jobId}`);
        if (onUpdate) onUpdate(job);
        if (job.status === "done") return resolve(job);
        if (job.status === "failed") return reject(new Error(job.message || "Job failed"));
        setTimeout(tick, intervalMs);
      } catch (error) {
        reject(error);
      }
    };
    tick();
  });
