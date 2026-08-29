import React, { useEffect, useState } from "react";
import SongPicker from "./SongPicker";
import { round1 } from "./stagingMath";

const SETS = ["S", "1", "2", "3", "4", "E", "E2", "E3"];
const EDGE_S = 10;
const NUDGES = [-1, -0.1, 0.1, 1];

const formatSeconds = (s) => {
  const total = Math.round(s);
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, "0")}`;
};

// One staged track: metadata fields that PATCH as they settle, audition
// buttons for the whole track and each edge, and the tools that reshape it.
// Every field here (text and number) commits on blur or Enter rather than
// keystroke, so an edit in progress is one request, not one per keystroke.
const StagedTrackRow = ({
  track, next, selected, onSelect, onPlay, onPatch, onSplit, onCombine,
  onBoundary, onRemove, playhead, busy,
}) => {
  const [title, setTitle] = useState(track.title);
  const [boundary, setBoundary] = useState(track.end_s);
  const [fields, setFields] = useState({
    start_s: track.start_s,
    end_s: track.end_s,
    fade_in_s: track.fade_in_s,
    fade_out_s: track.fade_out_s,
  });

  useEffect(() => setTitle(track.title), [track.title]);
  useEffect(() => setBoundary(track.end_s), [track.end_s]);
  useEffect(() => {
    setFields({
      start_s: track.start_s,
      end_s: track.end_s,
      fade_in_s: track.fade_in_s,
      fade_out_s: track.fade_out_s,
    });
  }, [track.start_s, track.end_s, track.fade_in_s, track.fade_out_s]);

  const length = track.end_s - track.start_s;
  const inside = playhead != null && playhead >= track.start_s && playhead <= track.end_s;

  // Number fields commit on blur (or Enter) rather than per keystroke: a
  // stray digit mid-edit should not PATCH, and disabling the input while a
  // prior PATCH is in flight would steal focus out from under the user.
  const commitField = (key) => {
    if (fields[key] !== track[key]) onPatch(track, { [key]: fields[key] });
  };

  const numberField = (label, key, extra = {}) => (
    <label className="admin-audio-field">
      <span>{label}</span>
      <input
        type="number"
        step="0.1"
        min="0"
        value={fields[key]}
        onChange={(e) => setFields((prev) => ({ ...prev, [key]: Number(e.target.value) }))}
        onBlur={() => commitField(key)}
        onKeyDown={(e) => { if (e.key === "Enter") commitField(key); }}
        {...extra}
      />
    </label>
  );

  return (
    <li className={`admin-staging-track${selected ? " is-selected" : ""}`} onClick={() => onSelect(track)}>
      <div className="admin-staging-track-header">
        <span className="admin-audio-position">{track.position}</span>
        <select
          value={track.set}
          disabled={busy}
          onChange={(e) => onPatch(track, { set: e.target.value })}
        >
          {SETS.map((s) => <option key={s} value={s}>{s}</option>)}
        </select>
        <input
          className="admin-staging-title"
          type="text"
          value={title}
          disabled={busy}
          onChange={(e) => setTitle(e.target.value)}
          onBlur={() => { if (title.trim() !== "" && title !== track.title) onPatch(track, { title: title.trim() }); }}
        />
        <span className="admin-audio-duration">
          {formatSeconds(track.start_s)} to {formatSeconds(track.end_s)} ({formatSeconds(length)})
        </span>
        <span className="admin-audio-tools">
          <button type="button" disabled={busy} onClick={(e) => { e.stopPropagation(); onPlay(track); }}>Play</button>
          <button type="button" disabled={busy} onClick={(e) => { e.stopPropagation(); onPlay(track, track.start_s, Math.min(track.end_s, track.start_s + EDGE_S)); }}>Head</button>
          <button type="button" disabled={busy} onClick={(e) => { e.stopPropagation(); onPlay(track, Math.max(track.start_s, track.end_s - EDGE_S), track.end_s); }}>Tail</button>
        </span>
      </div>

      {selected && (
        <div className="admin-staging-track-body">
          <SongPicker
            value={track.song ? [track.song] : []}
            onChange={(list) => onPatch(track, { song_id: list.length ? list[list.length - 1].id : null })}
          />

          <div className="admin-audio-fields">
            {numberField("Start", "start_s")}
            {numberField("End", "end_s")}
            {numberField("Fade in", "fade_in_s")}
            {numberField("Fade out", "fade_out_s")}
          </div>

          <div className="admin-audio-actions">
            <button type="button" disabled={busy || !inside} onClick={() => onPatch(track, { start_s: round1(playhead) })}>
              Start at playhead
            </button>
            <button type="button" disabled={busy || !inside} onClick={() => onPatch(track, { end_s: round1(playhead) })}>
              End at playhead
            </button>
            <button type="button" disabled={busy || !inside} onClick={() => onSplit(track, round1(playhead))}>
              Split at playhead
            </button>
            <button type="button" disabled={busy || !next} onClick={() => onCombine(track)}>
              Combine with next
            </button>
            <button type="button" className="admin-danger" disabled={busy} onClick={() => onRemove(track)}>
              Remove
            </button>
          </div>

          {next && (
            <div className="admin-staging-boundary">
              <span>Boundary with {next.title} at</span>
              <input
                type="number"
                step="0.1"
                value={boundary}
                disabled={busy}
                onChange={(e) => setBoundary(Number(e.target.value))}
                onBlur={() => { if (Math.abs(boundary - track.end_s) > 0.001) onBoundary(track, boundary); }}
              />
              {NUDGES.map((n) => (
                <button key={n} type="button" disabled={busy} onClick={() => onBoundary(track, round1(track.end_s + n))}>
                  {n > 0 ? `+${n}` : n}s
                </button>
              ))}
              <button type="button" disabled={busy || playhead == null} onClick={() => onBoundary(track, round1(playhead))}>
                At playhead
              </button>
              <button
                type="button"
                disabled={busy}
                onClick={() => onPlay(track, Math.max(track.start_s, track.end_s - 5), Math.min(next.end_s, track.end_s + 5), next)}
              >
                Play seam
              </button>
            </div>
          )}
        </div>
      )}
    </li>
  );
};

export default StagedTrackRow;
