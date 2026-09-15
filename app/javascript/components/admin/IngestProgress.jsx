import React, { useEffect, useState } from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faXmark } from "@fortawesome/free-solid-svg-icons";
import Spinner from "./Spinner";
import { STOP_IMPORT_CONFIRM } from "./messages";
import { adminPost, pollJob, isPollAbort, isJobCancelled } from "./adminApi";

// Follows an ingest job: the progress card shown on the import page and on a
// draft that is still being imported. Archive downloads can run far past the
// default poll cap, so the job gets two hours before it is declared lost.
const IngestProgress = ({ jobId, title, onDone, onCancelled, onError }) => {
  const [status, setStatus] = useState(null);

  useEffect(() => {
    if (!jobId) return undefined;
    const controller = new AbortController();
    pollJob(jobId, {
      onUpdate: setStatus,
      signal: controller.signal,
      timeoutMs: 2 * 60 * 60 * 1000,
    })
      .then(() => onDone())
      .catch((e) => {
        if (isPollAbort(e)) return;
        if (isJobCancelled(e)) onCancelled();
        else onError(e.message);
      });
    return () => controller.abort();
  }, [jobId]);

  const stop = () => {
    if (!window.confirm(STOP_IMPORT_CONFIRM)) return;
    adminPost(`/jobs/${jobId}/cancel`).catch((e) => onError(e.message));
  };

  return (
    <section className="admin-card admin-card-narrow">
      <header className="admin-card-header">
        <h2>Importing {status?.payload?.headline || title}</h2>
      </header>
      <div className="admin-card-body">
        <div className="admin-stage">
          <div className="admin-stage-progress">
            <div className="admin-stage-bar" role="progressbar" aria-valuenow={status?.progress ?? 0} aria-valuemin={0} aria-valuemax={100}>
              <div className="admin-stage-fill" style={{ width: `${status?.progress ?? 0}%` }} />
            </div>
            <span className="admin-stage-pct">{Math.round(status?.progress ?? 0)}%</span>
          </div>
          <div className="admin-stage-detail">
            <Spinner accent />
            <span>{status?.cancel_requested ? "Stopping..." : status?.message || "Starting..."}</span>
          </div>
          <div className="admin-stage-actions">
            <button
              type="button"
              disabled={!status?.cancellable}
              title="Stop this import and delete everything it has downloaded"
              onClick={stop}
            >
              <FontAwesomeIcon icon={faXmark} /> Cancel
            </button>
          </div>
        </div>
      </div>
    </section>
  );
};

export default IngestProgress;
