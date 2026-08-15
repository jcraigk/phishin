import React, { useContext, useState } from "react";
import { EditorContext } from "./AdminShowEditor";
import TrimPanel from "./TrimPanel";
import SplitPanel, { isSegueTitle } from "./SplitPanel";
import ReplacePanel from "./ReplacePanel";
import CombinePanel from "./CombinePanel";
import BoundaryPanel from "./BoundaryPanel";
import BulkAudioDrop from "./BulkAudioDrop";
import useJobRunner from "./useJobRunner";
import { adminPost } from "./adminApi";

const formatDuration = (ms) => {
  if (!ms) return "";
  const total = Math.round(ms / 1000);
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, "0")}`;
};

const GapBanner = () => {
  const { show, setGapsStale } = useContext(EditorContext);
  const { run, busy, status, error } = useJobRunner();

  return (
    <div className="admin-gap-banner">
      <span>Set lists changed. Recompute gaps.</span>
      <button
        type="button"
        disabled={busy}
        onClick={() =>
          run(
            () => adminPost(`/shows/${show.date}/recompute_gaps`),
            () => setGapsStale(false)
          )
        }
      >
        Recompute Gaps
      </button>
      {status && <span className="admin-audio-status">{status}</span>}
      {error && <span className="admin-error">{error}</span>}
    </div>
  );
};

const TrackAudioRow = ({ track, previous, next }) => {
  const [tool, setTool] = useState(null);
  const hasAudio = track.audio_status !== "missing";
  const splittable = hasAudio && isSegueTitle(track.title);
  // The first track of a show has nothing above it to merge into, and the last
  // has nothing below it to share a boundary with.
  const combinable = Boolean(previous);
  const shiftable = Boolean(next) && hasAudio && next.audio_status !== "missing";

  const toggle = (name) => setTool((prev) => (prev === name ? null : name));

  const toolButton = (name, label, enabled) => (
    <button
      type="button"
      className={tool === name ? "active" : ""}
      disabled={!enabled}
      onClick={() => toggle(name)}
    >
      {label}
    </button>
  );

  return (
    <li className="admin-audio-track">
      <div className="admin-audio-track-header">
        <span className="admin-audio-position">{track.position}</span>
        <span className="admin-audio-title">{track.title}</span>
        <span className="admin-audio-duration">
          {hasAudio ? formatDuration(track.duration) : "no audio"}
        </span>
        <span className="admin-audio-tools">
          {toolButton("trim", "Trim", hasAudio)}
          {toolButton("split", "Split", splittable)}
          {toolButton("replace", "Replace", true)}
          {toolButton("combine", "Combine Up", combinable)}
          {toolButton("boundary", "Boundary", shiftable)}
        </span>
      </div>
      {tool === "trim" && <TrimPanel key={`trim-${track.id}`} track={track} />}
      {tool === "split" && <SplitPanel key={`split-${track.id}`} track={track} />}
      {tool === "replace" && <ReplacePanel key={`replace-${track.id}`} track={track} />}
      {tool === "combine" && combinable && (
        <CombinePanel key={`combine-${track.id}`} track={track} previous={previous} />
      )}
      {tool === "boundary" && shiftable && (
        <BoundaryPanel key={`boundary-${track.id}`} track={track} next={next} />
      )}
    </li>
  );
};

const AudioTab = () => {
  const { show, gapsStale } = useContext(EditorContext);

  return (
    <div className="admin-audio-tab">
      {gapsStale && <GapBanner />}
      {show.tracks.length > 0 && <BulkAudioDrop />}
      {show.tracks.length === 0 ? (
        <p>This show has no tracks yet.</p>
      ) : (
        <ul className="admin-audio-tracks">
          {show.tracks.map((track, index) => (
            <TrackAudioRow
              key={track.id}
              track={track}
              previous={show.tracks[index - 1] || null}
              next={show.tracks[index + 1] || null}
            />
          ))}
        </ul>
      )}
    </div>
  );
};

export default AudioTab;
