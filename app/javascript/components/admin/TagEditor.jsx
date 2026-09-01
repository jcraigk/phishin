import React, { useContext, useEffect, useState } from "react";
import { EditorContext } from "./AdminShowEditor";
import { adminDelete, adminPatch, adminPost } from "./adminApi";
import { reasonText } from "./orphanReasons";

// Blank number inputs mean "no timestamp" rather than zero, so they are sent as
// null instead of being coerced.
const secondsOrNull = (value) => (value.trim() === "" ? null : Number(value));

const TrackTagRow = ({ track, trackTag, managed, onSaved, onError }) => {
  const [notes, setNotes] = useState(trackTag.notes || "");
  const [startsAt, setStartsAt] = useState(String(trackTag.starts_at_second ?? ""));
  const [endsAt, setEndsAt] = useState(String(trackTag.ends_at_second ?? ""));
  const [transcript, setTranscript] = useState(trackTag.transcript || "");
  const [busy, setBusy] = useState(false);

  useEffect(() => setNotes(trackTag.notes || ""), [trackTag.notes]);
  useEffect(
    () => setStartsAt(String(trackTag.starts_at_second ?? "")),
    [trackTag.starts_at_second]
  );
  useEffect(
    () => setEndsAt(String(trackTag.ends_at_second ?? "")),
    [trackTag.ends_at_second]
  );
  useEffect(() => setTranscript(trackTag.transcript || ""), [trackTag.transcript]);

  const save = async (body) => {
    setBusy(true);
    onError(null);
    try {
      onSaved(await adminPatch(`/track_tags/${trackTag.id}`, body));
    } catch (e) {
      onError(e.message);
    } finally {
      setBusy(false);
    }
  };

  const saveNotes = () => {
    if (notes === (trackTag.notes || "")) return;
    save({ notes });
  };

  const saveTranscript = () => {
    if (transcript === (trackTag.transcript || "")) return;
    save({ transcript });
  };

  const saveSecond = (field, value, stored) => {
    if (value === String(stored ?? "")) return;
    // Editing a timestamp is the admin saying where the tag really points, so
    // an orphaned tag resolves in the same request rather than needing a second
    // click to clear a flag the edit already answered.
    const body = { [field]: secondsOrNull(value) };
    if (trackTag.orphaned_at) body.orphaned = false;
    save(body);
  };

  const clearOrphan = () => save({ orphaned: false });

  const remove = async () => {
    if (!window.confirm(`Remove the ${trackTag.tag_name} tag from ${track.title}?`)) return;
    setBusy(true);
    onError(null);
    try {
      onSaved(await adminDelete(`/track_tags/${trackTag.id}`));
    } catch (e) {
      onError(e.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <li className="admin-tag-row">
      <div className="admin-tag-row-header">
        <span className="admin-tag-name">{trackTag.tag_name}</span>
        {managed && <span className="admin-tag-managed">sheet-managed</span>}
        <input
          type="text"
          className="admin-tag-notes"
          placeholder="Notes"
          value={notes}
          disabled={busy}
          onChange={(e) => setNotes(e.target.value)}
          onBlur={saveNotes}
        />
        <input
          type="number"
          min="0"
          placeholder="Start"
          value={startsAt}
          disabled={busy}
          onChange={(e) => setStartsAt(e.target.value)}
          onBlur={() =>
            saveSecond("starts_at_second", startsAt, trackTag.starts_at_second)
          }
        />
        <input
          type="number"
          min="0"
          placeholder="End"
          value={endsAt}
          disabled={busy}
          onChange={(e) => setEndsAt(e.target.value)}
          onBlur={() => saveSecond("ends_at_second", endsAt, trackTag.ends_at_second)}
        />
        <button type="button" className="admin-danger" disabled={busy} onClick={remove}>
          Remove
        </button>
      </div>
      {trackTag.orphaned_at && (
        <div className="admin-tag-orphaned">
          <p>{reasonText(trackTag.orphan_reason)}</p>
          <p className="admin-audio-note">
            The numbers above are where it pointed before the audio changed, not
            where it points now. Correct them and clear the flag, or resolve it
            from the dashboard review queue.
          </p>
          <button type="button" disabled={busy} onClick={clearOrphan}>
            Clear Flag
          </button>
        </div>
      )}
      <textarea
        className="admin-tag-transcript"
        rows={2}
        placeholder="Transcript"
        value={transcript}
        disabled={busy}
        onChange={(e) => setTranscript(e.target.value)}
        onBlur={saveTranscript}
      />
    </li>
  );
};

const AddTrackTag = ({ track, tags, onSaved, onError }) => {
  const [tagId, setTagId] = useState("");
  const [notes, setNotes] = useState("");
  const [startsAt, setStartsAt] = useState("");
  const [endsAt, setEndsAt] = useState("");
  const [busy, setBusy] = useState(false);

  const add = async () => {
    if (tagId === "") return;
    setBusy(true);
    onError(null);
    try {
      onSaved(
        await adminPost(`/tracks/${track.id}/track_tags`, {
          tag_id: Number(tagId),
          notes,
          starts_at_second: secondsOrNull(startsAt),
          ends_at_second: secondsOrNull(endsAt),
        })
      );
      setTagId("");
      setNotes("");
      setStartsAt("");
      setEndsAt("");
    } catch (e) {
      onError(e.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="admin-tag-add">
      <select
        aria-label="Tag"
        value={tagId}
        disabled={busy}
        onChange={(e) => setTagId(e.target.value)}
      >
        <option value="">Add a tag...</option>
        {tags.map((tag) => (
          <option key={tag.id} value={tag.id}>
            {tag.name}
          </option>
        ))}
      </select>
      <input
        type="text"
        className="admin-tag-notes"
        placeholder="Notes"
        value={notes}
        disabled={busy}
        onChange={(e) => setNotes(e.target.value)}
      />
      <input
        type="number"
        min="0"
        placeholder="Start"
        value={startsAt}
        disabled={busy}
        onChange={(e) => setStartsAt(e.target.value)}
      />
      <input
        type="number"
        min="0"
        placeholder="End"
        value={endsAt}
        disabled={busy}
        onChange={(e) => setEndsAt(e.target.value)}
      />
      <button type="button" disabled={busy || tagId === ""} onClick={add}>
        Add
      </button>
    </div>
  );
};

const TagEditor = ({ track, tags, taginTags }) => {
  const { setTrack } = useContext(EditorContext);
  const [error, setError] = useState(null);

  return (
    <div className="admin-tag-editor">
      {track.track_tags.length === 0 ? (
        <p className="admin-audio-status">No tags on this track.</p>
      ) : (
        <ul className="admin-tag-rows">
          {track.track_tags.map((trackTag) => (
            <TrackTagRow
              key={trackTag.id}
              track={track}
              trackTag={trackTag}
              managed={taginTags.includes(trackTag.tag_name)}
              onSaved={setTrack}
              onError={setError}
            />
          ))}
        </ul>
      )}
      <AddTrackTag track={track} tags={tags} onSaved={setTrack} onError={setError} />
      {error && <p className="admin-error">{error}</p>}
    </div>
  );
};

export default TagEditor;
