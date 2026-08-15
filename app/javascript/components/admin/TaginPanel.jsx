import React, { useState } from "react";
import useJobRunner from "./useJobRunner";
import { adminPost } from "./adminApi";

const SYNC_CONFIRM =
  "Syncing rewrites every sheet-managed tag to match the spreadsheet, " +
  "discarding manual edits to those tags. Continue?";

const CATEGORIES = [
  ["missing_in_sheet", "In the database, not in the sheet"],
  ["missing_in_db", "In the sheet, not in the database"],
  ["mismatched", "Notes or timestamps differ"],
];

const FIELD_LABELS = {
  notes: "Notes",
  transcript: "Transcript",
  starts_at_second: "Starts at",
  ends_at_second: "Ends at",
};

const displayValue = (value) =>
  value === null || value === undefined || value === "" ? "(empty)" : String(value);

const EntryLink = ({ entry }) => {
  const label = entry.track_title
    ? `${entry.show_date} ${entry.track_title}`
    : "Unresolved URL";
  return entry.url ? (
    <a href={entry.url} target="_blank" rel="noreferrer">
      {label}
    </a>
  ) : (
    <span>{label}</span>
  );
};

const FieldDiffs = ({ diffs }) => (
  <table className="admin-drift-diffs">
    <thead>
      <tr>
        <th />
        <th>Database</th>
        <th>Sheet</th>
      </tr>
    </thead>
    <tbody>
      {Object.entries(diffs).map(([field, values]) => (
        <tr key={field}>
          <th>{FIELD_LABELS[field] || field}</th>
          <td>{displayValue(values.db)}</td>
          <td>{displayValue(values.sheet)}</td>
        </tr>
      ))}
    </tbody>
  </table>
);

const DriftCategory = ({ label, entries, count }) => {
  const [open, setOpen] = useState(false);
  if (count === 0) return null;

  return (
    <div className="admin-drift-category">
      <button type="button" className={open ? "active" : ""} onClick={() => setOpen(!open)}>
        {label} ({count})
      </button>
      {open && (
        <ul className="admin-drift-entries">
          {entries.map((entry, index) => (
            <li key={`${entry.url}-${index}`}>
              <EntryLink entry={entry} />
              {entry.notes && <span className="admin-drift-notes">{entry.notes}</span>}
              {entry.field_diffs && <FieldDiffs diffs={entry.field_diffs} />}
            </li>
          ))}
          {entries.length < count && (
            <li className="admin-drift-notes">
              Showing the first {entries.length} of {count}. Fix these, then re-run the
              report for the rest.
            </li>
          )}
        </ul>
      )}
    </div>
  );
};

const DriftTag = ({ name, report }) => (
  <section className="admin-drift-tag">
    <h4>{name}</h4>
    {CATEGORIES.map(([key, label]) => (
      <DriftCategory
        key={key}
        label={label}
        entries={report[key] || []}
        count={report.counts[key]}
      />
    ))}
  </section>
);

const DriftReport = ({ payload }) => {
  const drift = payload.drift || {};
  const errors = payload.errors || [];
  const names = Object.keys(drift);

  return (
    <div className="admin-drift-report">
      <div className="admin-drift-header">
        <h3>Drift report</h3>
        <span className="admin-audio-status">
          The sheet is the source of truth. Fix the sheet, then sync.
        </span>
      </div>
      {errors.length > 0 && (
        <ul className="admin-drift-errors">
          {errors.map((entry) => (
            <li key={entry.tag} className="admin-error">
              {entry.tag}: {entry.error}
            </li>
          ))}
        </ul>
      )}
      {names.length === 0 ? (
        <p>No drift detected.</p>
      ) : (
        names.map((name) => <DriftTag key={name} name={name} report={drift[name]} />)
      )}
    </div>
  );
};

const TaginPanel = () => {
  const [drift, setDrift] = useState(null);
  const [synced, setSynced] = useState(null);
  const sync = useJobRunner();
  const report = useJobRunner();

  const busy = sync.busy || report.busy;

  const runSync = () => {
    if (!window.confirm(SYNC_CONFIRM)) return;
    setSynced(null);
    sync.run(
      () => adminPost("/tagin_sync"),
      (job) => setSynced(job.message || "Sync complete.")
    );
  };

  const runDrift = () => {
    setDrift(null);
    report.run(
      () => adminPost("/tagin_drift"),
      (job) => setDrift(job.payload || {})
    );
  };

  return (
    <section className="admin-tagin-panel">
      <div className="admin-tagin-actions">
        <button type="button" disabled={busy} onClick={runSync}>
          {sync.busy ? "Syncing..." : "Sync tags from sheet"}
        </button>
        <button type="button" disabled={busy} onClick={runDrift}>
          {report.busy ? "Comparing..." : "Check sheet drift"}
        </button>
        {busy && <progress className="admin-tagin-progress" />}
        {(sync.status || report.status) && (
          <span className="admin-audio-status">{sync.status || report.status}</span>
        )}
        {synced && !sync.busy && <span className="admin-audio-status">{synced}</span>}
      </div>
      <p className="admin-tagin-note">
        The spreadsheet is the source of truth for sheet-managed tags. A sync overwrites
        manual edits to those tags, so change the sheet rather than the tag here.
      </p>
      {(sync.error || report.error) && (
        <p className="admin-error">{sync.error || report.error}</p>
      )}
      {drift && <DriftReport payload={drift} />}
    </section>
  );
};

export default TaginPanel;
