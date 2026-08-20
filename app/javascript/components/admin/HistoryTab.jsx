import React, { useContext, useEffect, useState } from "react";
import { EditorContext } from "./AdminShowEditor";
import { adminGet } from "./adminApi";

// The operation vocabulary from TrackEdit::OPERATIONS, in plain language.
// "split" and "combine" are RETIRED: nothing writes them any more, but records
// written before the admin UI dropped those tools still carry them, so they are
// labelled here rather than falling through to the raw string.
const OPERATION_LABELS = {
  trim: "Trimmed audio",
  split: "Split into two tracks",
  combine: "Combined with another track",
  shift_boundary: "Moved the boundary",
  replace_audio: "Replaced audio",
  bulk_replace_audio: "Replaced audio in bulk",
};

const RETIRED_OPERATIONS = ["split", "combine"];

// TimestampShifter's reason vocabulary. An admin reading a queue should not
// have to work out what "past_new_end" meant for the tag in front of them.
export const ORPHAN_REASONS = {
  audio_replaced:
    "The audio file was replaced wholesale. The old offsets cannot be mapped " +
    "onto audio nobody has measured, so every timestamp on the track was set " +
    "aside for review.",
  before_new_start:
    "The moment sat before the start of the audio that survived, so it was cut " +
    "away from the front of the track.",
  past_new_end:
    "The moment sat past the end of the audio that survived, so it was cut away " +
    "from the end of the track.",
};

export const reasonText = (reason) =>
  ORPHAN_REASONS[reason] || `Orphaned with reason "${reason}".`;

const secondsLabel = (value) =>
  value === null || value === undefined ? "unset" : `${Number(value).toFixed(1)}s`;

const durationLabel = (ms) =>
  ms === null || ms === undefined ? "unknown" : `${(ms / 1000).toFixed(1)}s`;

const timestamp = (iso) => (iso ? new Date(iso).toLocaleString() : "");

// A shifted or clamped entry names a child by type and id. The type is what
// makes a row readable: a Track entry is the jam start, not a tag.
const childLabel = (entry) =>
  entry.type === "Track"
    ? `jam start (${entry.field || "jam_starts_at_second"})`
    : `${entry.type} ${entry.id}`;

const MoveList = ({ title, entries, note }) => {
  if (!entries || entries.length === 0) return null;
  return (
    <div className="admin-history-moves">
      <h5>{title}</h5>
      {note && <p className="admin-audio-note">{note}</p>}
      <ul>
        {entries.map((entry, index) => (
          <li key={`${entry.type}-${entry.id}-${index}`}>
            {childLabel(entry)}: {secondsLabel(entry.from)} to{" "}
            {secondsLabel(entry.to)}
          </li>
        ))}
      </ul>
    </div>
  );
};

const OrphanList = ({ entries }) => {
  if (!entries || entries.length === 0) return null;
  return (
    <div className="admin-history-moves">
      <h5>Orphaned</h5>
      <p className="admin-audio-note">
        These kept their original numbers. The numbers are evidence of where each
        one used to point, not where it points now.
      </p>
      <ul>
        {entries.map((entry, index) => (
          <li key={`${entry.type}-${entry.id}-${index}`}>
            {childLabel(entry)} was at {secondsLabel(entry.at)}.{" "}
            {reasonText(entry.reason)}
          </li>
        ))}
      </ul>
    </div>
  );
};

// The keys rendered by name above. The model does not validate the payload
// shape on purpose, so an operation can record something no UI anticipated;
// anything outside this list falls through to "Also recorded" and stays visible
// rather than being silently dropped.
const KNOWN_KEYS = [
  "duration_before_s",
  "duration_after_s",
  "delta_s",
  "shifted",
  "clamped",
  "orphaned",
  "backup_path",
  "notes",
  "trim_start_s",
  "trim_end_s",
  "boundary_delta_s",
  "cut_s",
  "side",
  "paired_track_id",
];

// The operation-specific detail worth a sentence rather than a raw key dump.
// A trim records the bounds it kept; a boundary shift records which side of the
// pair this record describes, which is what tells an admin whether this track
// grew or shrank.
const operationDetail = (operation, payload) => {
  if (operation === "trim" && payload.trim_end_s !== undefined) {
    return (
      `Kept the audio between ${Number(payload.trim_start_s || 0).toFixed(1)}s ` +
      `and ${Number(payload.trim_end_s).toFixed(1)}s of the original file.`
    );
  }
  if (operation === "shift_boundary" && payload.side) {
    const grew =
      payload.side === "first"
        ? payload.boundary_delta_s > 0
        : payload.boundary_delta_s < 0;
    return (
      `The ${payload.side} track of the pair. The boundary moved by ` +
      `${Number(payload.boundary_delta_s ?? 0).toFixed(1)}s, so this track ` +
      `${grew ? "grew" : "shrank"}.`
    );
  }
  return null;
};

const EditRow = ({ edit }) => {
  const payload = edit.payload || {};
  const extras = Object.keys(payload).filter((key) => !KNOWN_KEYS.includes(key));
  const retired = RETIRED_OPERATIONS.includes(edit.operation);
  const detail = operationDetail(edit.operation, payload);
  const nothingMoved =
    Array.isArray(payload.shifted) &&
    payload.shifted.length === 0 &&
    (payload.clamped || []).length === 0 &&
    (payload.orphaned || []).length === 0;

  return (
    <li className="admin-history-edit">
      <div className="admin-history-edit-header">
        <span className="admin-history-operation">
          {OPERATION_LABELS[edit.operation] || edit.operation}
        </span>
        {retired && (
          <span className="admin-tag-managed" title="No longer available in the admin UI">
            retired tool
          </span>
        )}
        <span className="admin-history-when">{timestamp(edit.created_at)}</span>
        {edit.user_email && (
          <span className="admin-history-who">{edit.user_email}</span>
        )}
      </div>

      <dl className="admin-history-facts">
        <div>
          <dt>Duration</dt>
          <dd>
            {payload.duration_before_s === undefined
              ? "not recorded"
              : `${Number(payload.duration_before_s).toFixed(1)}s before, ${
                  payload.duration_after_s === undefined
                    ? "unknown"
                    : `${Number(payload.duration_after_s).toFixed(1)}s`
                } after`}
          </dd>
        </div>
        <div>
          <dt>Shift applied</dt>
          <dd>
            {payload.delta_s === null || payload.delta_s === undefined
              ? "none, offsets could not be mapped"
              : `${Number(payload.delta_s).toFixed(1)}s`}
          </dd>
        </div>
        {edit.admin_job_id && (
          <div>
            <dt>Job</dt>
            <dd>{edit.admin_job_id}</dd>
          </div>
        )}
      </dl>

      {detail && <p className="admin-audio-note">{detail}</p>}

      {nothingMoved && (
        <p className="admin-audio-note">
          Nothing timestamped sat on this track, so nothing moved.
        </p>
      )}

      <MoveList title="Shifted" entries={payload.shifted} />
      <MoveList
        title="Clamped"
        entries={payload.clamped}
        note="These ran past the surviving audio at one end and were narrowed to what is left, so they still describe real audio."
      />
      <OrphanList entries={payload.orphaned} />

      {payload.notes && payload.notes.length > 0 && (
        <div className="admin-history-moves">
          <h5>Notes</h5>
          <ul>
            {payload.notes.map((note, index) => (
              <li key={index}>{note}</li>
            ))}
          </ul>
        </div>
      )}

      {payload.backup_path && (
        <p className="admin-history-backup">
          Original audio backed up at <code>{payload.backup_path}</code>
        </p>
      )}

      {extras.length > 0 && (
        <div className="admin-history-moves">
          <h5>Also recorded</h5>
          <ul>
            {extras.map((key) => (
              <li key={key}>
                {key}: {JSON.stringify(payload[key])}
              </li>
            ))}
          </ul>
        </div>
      )}
    </li>
  );
};

const TrackGroup = ({ group, open, onToggle }) => {
  const gone = group.track_id === null;
  const heading = gone
    ? "Tracks that no longer exist"
    : `${group.position}. ${group.title}`;

  return (
    <li className={`admin-history-group${gone ? " is-orphaned" : ""}`}>
      <button type="button" className="admin-history-toggle" onClick={onToggle}>
        <span className="admin-history-heading">{heading}</span>
        <span className="admin-history-count">
          {group.edits.length} edit{group.edits.length === 1 ? "" : "s"}
        </span>
      </button>
      {gone && (
        <p className="admin-audio-note">
          A combine destroyed the track these edits describe. The records outlive
          their subject on purpose, so they are listed against the show instead.
        </p>
      )}
      {open && (
        <ul className="admin-history-edits">
          {group.edits.map((edit) => (
            <EditRow key={edit.id} edit={edit} />
          ))}
        </ul>
      )}
    </li>
  );
};

const HistoryTab = () => {
  const { show } = useContext(EditorContext);
  const [groups, setGroups] = useState(null);
  const [open, setOpen] = useState({});
  const [error, setError] = useState(null);

  useEffect(() => {
    let live = true;
    adminGet(`/shows/${show.date}/history`)
      .then((data) => {
        if (live) setGroups(data.history);
      })
      .catch((e) => {
        if (live) setError(e.message);
      });
    return () => {
      live = false;
    };
  }, [show.date]);

  if (error) return <p className="admin-error">{error}</p>;
  if (groups === null) return <p>Loading...</p>;

  // Tracks nothing has ever happened to would be all of them on most shows, so
  // an untouched track is left out rather than padding the page with rows that
  // say nothing.
  const withEdits = groups.filter((group) => group.edits.length > 0);

  if (withEdits.length === 0) {
    return (
      <div className="admin-history-tab">
        <p>
          No audio operation has been recorded against this show. Trimming,
          moving a boundary, or replacing audio writes a record here.
        </p>
      </div>
    );
  }

  return (
    <div className="admin-history-tab">
      <p className="admin-audio-note">
        Every audio operation on this show, newest first within each track. These
        records are append-only: nothing in the app edits or deletes one.
      </p>
      <ul className="admin-history-groups">
        {withEdits.map((group) => {
          const key = group.track_id === null ? "gone" : group.track_id;
          return (
            <TrackGroup
              key={key}
              group={group}
              open={open[key] !== false}
              onToggle={() =>
                setOpen((prev) => ({ ...prev, [key]: prev[key] === false }))
              }
            />
          );
        })}
      </ul>
    </div>
  );
};

export default HistoryTab;
