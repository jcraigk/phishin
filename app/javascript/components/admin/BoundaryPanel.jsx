import React, { useContext, useState } from "react";
import { EditorContext } from "./AdminShowEditor";
import PreviewPlayer from "./PreviewPlayer";
import useJobRunner from "./useJobRunner";
import { adminPost, fetchJobAudio } from "./adminApi";

// Mirrors Admin::ShiftBoundaryJob::MIN_PART_S: both sides must keep real audio,
// so the allowed range shown here is the same one the API enforces.
const MIN_PART_S = 1.0;

const round = (value) => Math.round(value * 10) / 10;

const seconds = (ms) => round((ms || 0) / 1000);

const BoundaryPanel = ({ track, next }) => {
  const { show, reload, setGapsStale } = useContext(EditorContext);
  const [deltaS, setDeltaS] = useState(0);
  const [previewUrls, setPreviewUrls] = useState([null, null]);
  const [previewedAt, setPreviewedAt] = useState(null);
  const { run, busy, status, error } = useJobRunner();

  const firstSeconds = seconds(track.duration);
  const secondSeconds = seconds(next.duration);
  const low = round(MIN_PART_S - firstSeconds);
  const high = round(secondSeconds - MIN_PART_S);
  const delta = Number.isFinite(deltaS) ? deltaS : 0;
  const inRange = delta >= low && delta <= high;
  const previewCurrent = previewedAt === delta;

  const clearPreview = () => {
    setPreviewUrls([null, null]);
    setPreviewedAt(null);
  };

  const changeDelta = (value) => {
    setDeltaS(round(value));
    clearPreview();
  };

  const renderPreview = () =>
    run(
      () => adminPost(`/tracks/${track.id}/shift_boundary_preview`, { delta_s: delta }),
      async (job) => {
        const [first, second] = await Promise.all([
          fetchJobAudio(job.id, 0),
          fetchJobAudio(job.id, 1),
        ]);
        setPreviewUrls([first, second]);
        setPreviewedAt(delta);
      }
    );

  const applyShift = () => {
    const message =
      `Move the boundary between "${track.title}" and "${next.title}" by ` +
      `${delta.toFixed(1)}s? Both original audio files are backed up and no ` +
      `metadata changes.`;
    if (!window.confirm(message)) return;
    run(
      () => adminPost(`/tracks/${track.id}/shift_boundary_apply`, { delta_s: delta }),
      async () => {
        clearPreview();
        await reload();
        if (show.published) setGapsStale(true);
      }
    );
  };

  return (
    <div className="admin-audio-panel">
      <h4>Boundary</h4>

      <p className="admin-audio-note">
        Between position {track.position} "{track.title}" and position{" "}
        {next.position} "{next.title}". A positive shift grows the first track
        and shrinks the second; a negative shift does the reverse. Allowed range
        is {low.toFixed(1)}s to {high.toFixed(1)}s.
      </p>

      <div className="admin-audio-fields">
        <label className="admin-audio-field">
          <span>Shift seconds</span>
          <input
            type="number"
            step="0.1"
            min={low}
            max={high}
            value={deltaS}
            disabled={busy}
            onChange={(e) => changeDelta(Number(e.target.value))}
          />
        </label>
      </div>

      <p className="admin-audio-note">
        Now {firstSeconds.toFixed(1)}s and {secondSeconds.toFixed(1)}s. After the
        shift: {round(firstSeconds + delta).toFixed(1)}s and{" "}
        {round(secondSeconds - delta).toFixed(1)}s. The combined length does not
        change.
      </p>

      <PreviewPlayer label={`New "${track.title}"`} url={previewUrls[0]} />
      <PreviewPlayer label={`New "${next.title}"`} url={previewUrls[1]} />

      <div className="admin-audio-actions">
        <button
          type="button"
          onClick={renderPreview}
          disabled={busy || !inRange || delta === 0}
        >
          Render Preview
        </button>
        <button
          type="button"
          onClick={applyShift}
          disabled={busy || !inRange || delta === 0 || !previewCurrent}
        >
          Apply Shift
        </button>
        {!inRange && (
          <span className="admin-audio-status">
            Shift must be between {low.toFixed(1)}s and {high.toFixed(1)}s.
          </span>
        )}
        {previewUrls[0] && !previewCurrent && (
          <span className="admin-audio-status">
            Shift changed. Render a new preview before applying.
          </span>
        )}
        {status && <span className="admin-audio-status">{status}</span>}
      </div>

      {error && <p className="admin-error">{error}</p>}
    </div>
  );
};

export default BoundaryPanel;
