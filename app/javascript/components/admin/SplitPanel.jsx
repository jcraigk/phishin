import React, { useContext, useRef, useState } from "react";
import { EditorContext } from "./AdminShowEditor";
import WaveformScrubber from "./WaveformScrubber";
import PreviewPlayer from "./PreviewPlayer";
import useJobRunner from "./useJobRunner";
import { adminPost, fetchJobAudio } from "./adminApi";

const round = (value) => Math.round(value * 10) / 10;

// Matches SEGUE_RE in TrackSplitService: "A > B" and "A -> B" both split.
const SEGUE_RE = /\s*-?>\s*/;

export const isSegueTitle = (title) => (title || "").split(SEGUE_RE).length === 2;

const SplitPanel = ({ track }) => {
  const { show, reload, setGapsStale } = useContext(EditorContext);
  const duration = (track.duration || 0) / 1000;
  const [cutS, setCutS] = useState(round(duration / 2));
  const [previewUrls, setPreviewUrls] = useState([null, null]);
  const [previewedAt, setPreviewedAt] = useState(null);
  const [playhead, setPlayhead] = useState(0);
  const audioRef = useRef(null);
  const { run, busy, status, error } = useJobRunner();

  const parts = (track.title || "").split(SEGUE_RE);
  const previewCurrent = previewedAt === cutS;

  const clearPreview = () => {
    setPreviewUrls([null, null]);
    setPreviewedAt(null);
  };

  const setCut = (seconds) => {
    setCutS(round(seconds));
    clearPreview();
  };

  const renderPreview = () =>
    run(
      () => adminPost(`/tracks/${track.id}/split_preview`, { cut_s: cutS }),
      async (job) => {
        const [first, second] = await Promise.all([
          fetchJobAudio(job.id, 0),
          fetchJobAudio(job.id, 1),
        ]);
        setPreviewUrls([first, second]);
        setPreviewedAt(cutS);
      }
    );

  const applySplit = () => {
    if (!window.confirm(`Split "${track.title}" into two tracks? The original is backed up.`)) return;
    run(
      () => adminPost(`/tracks/${track.id}/split_apply`, { cut_s: cutS }),
      async () => {
        clearPreview();
        await reload();
        if (show.published) setGapsStale(true);
      }
    );
  };

  return (
    <div className="admin-audio-panel">
      <h4>Split</h4>
      <WaveformScrubber
        waveformUrl={track.waveform_url}
        duration={duration}
        playheadSeconds={playhead}
        markers={[{ name: "cut", seconds: cutS, color: "var(--highlight-orange)" }]}
        onMarkerChange={(_name, seconds) => setCut(seconds)}
        onSeek={(seconds) => {
          if (audioRef.current) audioRef.current.currentTime = seconds;
          setPlayhead(seconds);
        }}
      />

      <div className="admin-audio-fields">
        <label className="admin-audio-field">
          <span>Cut point</span>
          <input
            type="number"
            step="0.1"
            min="0"
            max={round(duration)}
            value={cutS}
            disabled={busy}
            onChange={(e) => setCut(Number(e.target.value))}
          />
        </label>
      </div>

      <div className="admin-preview-player">
        <span className="admin-preview-label">Original</span>
        <audio
          ref={audioRef}
          controls
          src={track.mp3_url}
          onTimeUpdate={(e) => setPlayhead(e.target.currentTime)}
        />
      </div>

      <PreviewPlayer label={parts[0]} url={previewUrls[0]} />
      <PreviewPlayer label={parts[1]} url={previewUrls[1]} />

      <div className="admin-audio-actions">
        <button type="button" onClick={renderPreview} disabled={busy}>
          Render Preview
        </button>
        <button type="button" onClick={applySplit} disabled={busy || !previewCurrent}>
          Apply Split
        </button>
        {previewUrls[0] && !previewCurrent && (
          <span className="admin-audio-status">
            Cut point changed. Render a new preview before applying.
          </span>
        )}
        {status && <span className="admin-audio-status">{status}</span>}
      </div>

      {error && <p className="admin-error">{error}</p>}
    </div>
  );
};

export default SplitPanel;
