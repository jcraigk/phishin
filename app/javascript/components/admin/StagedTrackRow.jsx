import React, { useEffect, useState } from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faArrowDownLong, faArrowUpLong, faClockRotateLeft, faPlay, faScissors, faTrashCan } from "@fortawesome/free-solid-svg-icons";
import SongPicker from "./SongPicker";
import { round1 } from "./stagingMath";

const DEFAULT_FADE_IN = 0.2;
const DEFAULT_FADE_OUT = 6.0;
const EDGE_CONTEXT_S = 2;

// One staged track: metadata fields that PATCH as they settle, and the tools
// that reshape it. Each side of the track is either a seam (shared with the
// next track in the same set; moving it moves both tracks, no fades) or a
// trim (a set boundary or the show's edge; audio past it is dropped, fades
// apply).
// Every field here (text and number) commits on blur or Enter rather than
// keystroke, so an edit in progress is one request, not one per keystroke.
const StagedTrackRow = ({
  track, prev, next, startKind, endKind, selected, onSelect, onPlay, onPatch,
  onSplit, onCombine, onUncombine, onBoundary, onPlayFromSeam, onRemove, playhead, transport, busy,
  moveUpTo, moveDownTo, onChangeSet, setName, loading,
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

  const inside = playhead != null && playhead >= track.start_s && playhead <= track.end_s;

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

  // A fade is off until ticked; ticking applies the site's usual length and
  // the number then edits it. The play button auditions that edge: the fade
  // plus a couple of seconds beyond it, with the live fade envelope applied,
  // which is the same linear ramp the commit renders.
  const fadeField = (label, key, defaultValue) => {
    const on = fields[key] > 0;
    const apply = (value) => {
      setFields((prev) => ({ ...prev, [key]: value }));
      onPatch(track, { [key]: value });
    };
    const audition = () => {
      const fade = on ? fields[key] : 0;
      if (key === "fade_in_s") onPlay(track, track.start_s);
      else onPlay(track, Math.max(track.start_s, track.end_s - fade - EDGE_CONTEXT_S));
    };
    return (
      <label className="admin-audio-field admin-fade-field">
        <span>
          <input
            type="checkbox"
            checked={on}
            disabled={busy}
            onChange={(e) => apply(e.target.checked ? defaultValue : 0)}
          />
          {label}
        </span>
        <span className="admin-fade-controls">
          <input
            type="number"
            step="0.1"
            min="0"
            value={on ? fields[key] : defaultValue}
            disabled={!on}
            onChange={(e) => setFields((prev) => ({ ...prev, [key]: Number(e.target.value) }))}
            onBlur={() => commitField(key)}
            onKeyDown={(e) => { if (e.key === "Enter") commitField(key); }}
          />
          <button
            type="button"
            className="admin-trim-play"
            title={key === "fade_in_s" ? "Play the start with its fade" : "Play the end with its fade"}
            aria-label={key === "fade_in_s" ? "Play the start" : "Play the end"}
            disabled={busy || loading}
            onClick={(e) => { e.preventDefault(); e.stopPropagation(); audition(); }}
          >
            <FontAwesomeIcon icon={faPlay} />
          </button>
        </span>
      </label>
    );
  };

  return (
    <li className={`admin-staging-track${selected ? " is-selected" : ""}`} onClick={() => onSelect(track)}>
      <div className="admin-staging-track-header">
        <span className="admin-audio-position">{track.position}</span>
        <input
          className="admin-staging-title"
          type="text"
          value={title}
          disabled={busy}
          onChange={(e) => setTitle(e.target.value)}
          onBlur={() => { if (title.trim() !== "" && title !== track.title) onPatch(track, { title: title.trim() }); }}
        />
        {track.undo_combine && (
          <button
            type="button"
            title={`Undo the combine and restore ${track.undo_combine} as its own track`}
            aria-label={`Undo the combine and restore ${track.undo_combine}`}
            disabled={busy}
            onClick={(e) => { e.stopPropagation(); onUncombine(track); }}
          >
            <FontAwesomeIcon icon={faClockRotateLeft} />
          </button>
        )}
        {moveUpTo && (
          <button
            type="button"
            title={`Move up into ${setName(moveUpTo)}`}
            aria-label={`Move up into ${setName(moveUpTo)}`}
            disabled={busy}
            onClick={(e) => { e.stopPropagation(); onChangeSet(track, moveUpTo); }}
          >
            <FontAwesomeIcon icon={faArrowUpLong} />
          </button>
        )}
        {moveDownTo && (
          <button
            type="button"
            title={`Move down into ${setName(moveDownTo)}`}
            aria-label={`Move down into ${setName(moveDownTo)}`}
            disabled={busy}
            onClick={(e) => { e.stopPropagation(); onChangeSet(track, moveDownTo); }}
          >
            <FontAwesomeIcon icon={faArrowDownLong} />
          </button>
        )}
      </div>

      {selected && (
        <div className="admin-staging-track-body">
          {transport}

          <SongPicker
            value={track.songs}
            onChange={(list) => onPatch(track, { song_ids: list.map((s) => s.id) })}
          />

          <div className="admin-audio-fields">
            {numberField("Start", "start_s")}
            {startKind === "trim" && fadeField("Fade in", "fade_in_s", DEFAULT_FADE_IN)}
            {numberField("End", "end_s")}
            {endKind === "trim" && fadeField("Fade out", "fade_out_s", DEFAULT_FADE_OUT)}
          </div>

          {next && endKind === "seam" && (
            <div className="admin-staging-boundary">
              <span>Seam</span>
              <input
                type="number"
                step="0.1"
                className="admin-seam-input"
                value={boundary}
                disabled={busy}
                onChange={(e) => setBoundary(Number(e.target.value))}
                onBlur={() => { if (Math.abs(boundary - track.end_s) > 0.001) onBoundary(track, boundary); }}
              />
              <button
                type="button"
                disabled={busy || loading}
                title={`Play from the seam so you hear how ${next.title} begins`}
                onClick={() => onPlayFromSeam(track)}
              >
                <FontAwesomeIcon icon={faPlay} />
              </button>
            </div>
          )}

          {next && endKind === "trim" && (
            <div className="admin-staging-boundary is-gap">
              <span>Set break: {next.title} opens set {next.set}</span>
            </div>
          )}

          <div className="admin-audio-actions">
            <button
              type="button"
              title="Split this track in two at the playhead"
              aria-label="Split at playhead"
              disabled={busy || !inside}
              onClick={() => {
                if (window.confirm(`Split "${track.title}" at ${round1(playhead)}s?`)) onSplit(track, round1(playhead));
              }}
            >
              <FontAwesomeIcon icon={faScissors} />
            </button>
            {next && endKind === "seam" && (
              <button
                type="button"
                title={`Combine with ${next.title} into one track`}
                aria-label="Combine down"
                disabled={busy}
                onClick={() => {
                  if (window.confirm(`Combine "${track.title}" and "${next.title}" into one track?`)) onCombine(track);
                }}
              >
                <FontAwesomeIcon icon={faArrowDownLong} />
              </button>
            )}
            <button
              type="button"
              title="Remove this track from the show"
              aria-label="Remove track"
              disabled={busy}
              onClick={() => onRemove(track)}
            >
              <FontAwesomeIcon icon={faTrashCan} />
            </button>
          </div>
        </div>
      )}
    </li>
  );
};

export default StagedTrackRow;
