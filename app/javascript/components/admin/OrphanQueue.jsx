import React, { useCallback, useEffect, useState } from "react";
import { Link } from "react-router";
import { adminGet, adminPatch } from "./adminApi";
import { reasonText } from "./HistoryTab";

const secondsOrNull = (value) => (value.trim() === "" ? null : Number(value));

const secondsLabel = (value) =>
  value === null || value === undefined ? "unset" : `${value}s`;

const durationSeconds = (ms) =>
  ms === null || ms === undefined ? null : Math.round(ms / 1000);

const OrphanRow = ({ orphan, onResolved, onError }) => {
  const [startsAt, setStartsAt] = useState(String(orphan.starts_at_second ?? ""));
  const [endsAt, setEndsAt] = useState(String(orphan.ends_at_second ?? ""));
  const [busy, setBusy] = useState(false);

  const trackSeconds = durationSeconds(orphan.track_duration);
  const start = secondsOrNull(startsAt);
  const end = secondsOrNull(endsAt);
  const changed =
    startsAt !== String(orphan.starts_at_second ?? "") ||
    endsAt !== String(orphan.ends_at_second ?? "");
  const outOfRange =
    trackSeconds !== null &&
    ((start !== null && (start < 0 || start > trackSeconds)) ||
      (end !== null && (end < 0 || end > trackSeconds)));

  const patch = async (body) => {
    setBusy(true);
    onError(null);
    try {
      await adminPatch(`/track_tags/${orphan.id}`, body);
      await onResolved();
    } catch (e) {
      onError(e.message);
      setBusy(false);
    }
  };

  // Correcting the numbers and clearing the flag go in one request. Saving the
  // numbers without clearing the flag would leave the tag in the queue looking
  // exactly like an unresolved one, and clearing the flag in a second request
  // could leave a corrected tag still flagged if that request failed.
  const saveAndResolve = () =>
    patch({
      starts_at_second: start,
      ends_at_second: end,
      orphaned: false,
    });

  const clearOnly = () => {
    const message =
      `Clear the orphan flag on the ${orphan.tag_name} tag without changing its ` +
      `timestamps? Use this when the tag still points at the right moment and ` +
      `the flag was wrong.`;
    if (!window.confirm(message)) return;
    patch({ orphaned: false });
  };

  return (
    <li className="admin-orphan-row">
      <div className="admin-orphan-header">
        <span className="admin-tag-name">{orphan.tag_name}</span>
        <Link to={`/admin/shows/${orphan.show_date}`}>{orphan.show_date}</Link>
        <span className="admin-orphan-track">
          {orphan.track_position}. {orphan.track_title}
          {trackSeconds !== null && ` (${trackSeconds}s)`}
        </span>
      </div>

      <p className="admin-orphan-reason">{reasonText(orphan.orphan_reason)}</p>

      <p className="admin-audio-note">
        It used to point at {secondsLabel(orphan.starts_at_second)}
        {orphan.ends_at_second === null || orphan.ends_at_second === undefined
          ? ""
          : ` to ${orphan.ends_at_second}s`}
        . That is where it pointed before the audio changed, not where it points
        now.
      </p>

      {orphan.notes && <p className="admin-audio-note">Notes: {orphan.notes}</p>}

      <div className="admin-orphan-actions">
        <label className="admin-audio-field">
          <span>Start</span>
          <input
            type="number"
            min="0"
            value={startsAt}
            disabled={busy}
            onChange={(e) => setStartsAt(e.target.value)}
          />
        </label>
        <label className="admin-audio-field">
          <span>End</span>
          <input
            type="number"
            min="0"
            value={endsAt}
            disabled={busy}
            onChange={(e) => setEndsAt(e.target.value)}
          />
        </label>
        <button
          type="button"
          disabled={busy || !changed || outOfRange}
          onClick={saveAndResolve}
        >
          Save and Resolve
        </button>
        <button type="button" disabled={busy} onClick={clearOnly}>
          Clear Flag
        </button>
        {outOfRange && (
          <span className="admin-audio-status">
            The track is {trackSeconds}s long. A timestamp outside it would orphan
            the tag again.
          </span>
        )}
      </div>
    </li>
  );
};

const OrphanQueue = () => {
  const [orphans, setOrphans] = useState(null);
  const [error, setError] = useState(null);

  const load = useCallback(async () => {
    try {
      const data = await adminGet("/track_tags/orphaned");
      setOrphans(data.orphans);
    } catch (e) {
      setError(e.message);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  if (error) return <p className="admin-error">{error}</p>;
  if (orphans === null) return <p>Loading...</p>;

  if (orphans.length === 0) {
    return <p>No tags are waiting for review.</p>;
  }

  return (
    <div className="admin-orphan-queue">
      <p className="admin-audio-note">
        An audio operation moved the audio out from under these tags and could
        not work out where they should point instead. Each one kept its original
        numbers so you can see what it used to describe. Give it a timestamp that
        matches the audio the track holds now, or clear the flag if it is already
        right.
      </p>
      <ul className="admin-orphan-rows">
        {orphans.map((orphan) => (
          <OrphanRow
            key={orphan.id}
            orphan={orphan}
            onResolved={load}
            onError={setError}
          />
        ))}
      </ul>
    </div>
  );
};

export default OrphanQueue;
