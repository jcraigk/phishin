import React, { useEffect, useState } from "react";
import { Link } from "react-router";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import {
  faCircleExclamation,
  faClipboardList,
  faCompactDisc,
  faListCheck,
  faSpinner,
  faTableList,
  faTags,
} from "@fortawesome/free-solid-svg-icons";
import { adminGet } from "./adminApi";
import TaginPanel from "./TaginPanel";
import OrphanQueue from "./OrphanQueue";

const KIND_LABELS = {
  bulk_replace_audio: "bulk audio",
  commit_staging: "commit staging",
  ingest: "ingest",
  recompute_gaps: "recompute gaps",
  shift_boundary_apply: "boundary shift",
  shift_boundary_preview: "boundary preview",
  split_preview: "split preview",
  trim_preview: "trim preview",
  tagin_drift: "tag drift",
  tagin_sync: "tag sync",
};

const UNITS = [
  [60, "second"],
  [60, "minute"],
  [24, "hour"],
  [7, "day"],
];

const relativeTime = (iso) => {
  if (!iso) return "";
  let value = (Date.now() - new Date(iso).getTime()) / 1000;
  if (value < 45) return "just now";
  let label = "second";
  for (const [size, next] of UNITS) {
    if (value < size) break;
    value /= size;
    label = next;
  }
  const rounded = Math.round(value);
  return `${rounded} ${label}${rounded === 1 ? "" : "s"} ago`;
};

const kindLabel = (kind) => KIND_LABELS[kind] || kind.replace(/_/g, " ");

const StatCard = ({ label, value, tone, to, icon }) => {
  const body = (
    <>
      <span className={`admin-stat-icon${tone ? ` is-${tone}` : ""}`}>
        <FontAwesomeIcon icon={icon} />
      </span>
      <span className="admin-stat-text">
        <span className={`admin-stat-value${tone ? ` is-${tone}` : ""}`}>{value}</span>
        <span className="admin-stat-label">{label}</span>
      </span>
    </>
  );
  return to ? (
    <Link className="admin-stat" to={to}>{body}</Link>
  ) : (
    <div className="admin-stat">{body}</div>
  );
};

const Card = ({ title, icon, count, action, children }) => (
  <section className="admin-card">
    <header className="admin-card-header">
      <h2>
        {icon && <FontAwesomeIcon icon={icon} className="admin-card-icon" />}
        {title}
        {count != null && count > 0 && <span className="admin-count">{count}</span>}
      </h2>
      {action}
    </header>
    <div className="admin-card-body">{children}</div>
  </section>
);

const Empty = ({ children }) => <p className="admin-empty">{children}</p>;

const DraftRow = ({ show }) => (
  <li className="admin-draft-row">
    <Link className="admin-draft-date" to={`/admin/shows/${show.date}`}>{show.date}</Link>
    <span className="admin-draft-venue">{show.venue_name || "Venue not set"}</span>
    <span className={`admin-pill is-${show.audio_status}`}>{show.audio_status}</span>
    <span className="admin-draft-tracks">
      {show.tracks_count} {show.tracks_count === 1 ? "track" : "tracks"}
    </span>
    <Link className="admin-draft-open" to={`/admin/shows/${show.date}`}>Open</Link>
  </li>
);

const ActivityRow = ({ job }) => (
  <li className="admin-activity-row">
    <span className={`admin-pill is-${job.status}`}>{job.status}</span>
    <span className="admin-activity-kind">{kindLabel(job.kind)}</span>
    <span className="admin-activity-show">
      {job.show_date && <Link to={`/admin/shows/${job.show_date}`}>{job.show_date}</Link>}
    </span>
    <span className="admin-activity-message" title={job.message || ""}>
      {job.message || ""}
    </span>
    <span className="admin-activity-time">{relativeTime(job.created_at)}</span>
  </li>
);

const AdminDashboard = () => {
  const [drafts, setDrafts] = useState(null);
  const [jobs, setJobs] = useState(null);
  const [orphanCount, setOrphanCount] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    adminGet("/shows?published=false")
      .then((data) => setDrafts(data.shows))
      .catch((e) => setError(e.message));
    adminGet("/jobs?limit=20")
      .then((data) => setJobs(data.jobs))
      .catch((e) => setError(e.message));
    adminGet("/track_tags/orphaned")
      .then((data) => setOrphanCount(data.orphans.length))
      .catch(() => setOrphanCount(null));
  }, []);

  const running = (jobs || []).filter((j) => j.status === "running" || j.status === "queued").length;
  const failed = (jobs || []).filter((j) => j.status === "failed").length;
  const dash = (value) => (value == null ? "–" : value);

  return (
    <div className="admin-dashboard">
      {error && <p className="admin-error">{error}</p>}

      <div className="admin-stats">
        <StatCard icon={faCompactDisc} label="Draft shows" value={dash(drafts?.length)} />
        <StatCard icon={faSpinner} label="Jobs in progress" value={dash(jobs && running)} tone={running ? "warm" : null} />
        <StatCard icon={faCircleExclamation} label="Failed recently" value={dash(jobs && failed)} tone={failed ? "bad" : null} />
        <StatCard icon={faTags} label="Tags to review" value={dash(orphanCount)} tone={orphanCount ? "warm" : null} />
      </div>

      <div className="admin-grid">
        <Card title="Draft Shows" icon={faCompactDisc} count={drafts?.length}>
          {drafts === null ? (
            <Empty>Loading</Empty>
          ) : drafts.length === 0 ? (
            <Empty>No drafts. Pick a new date on the Shows page to import one.</Empty>
          ) : (
            <ul className="admin-draft-list">
              {drafts.map((show) => <DraftRow key={show.id} show={show} />)}
            </ul>
          )}
        </Card>

        <Card title="Recent Activity" icon={faListCheck}>
          {jobs === null ? (
            <Empty>Loading</Empty>
          ) : jobs.length === 0 ? (
            <Empty>No jobs have run yet.</Empty>
          ) : (
            <ul className="admin-activity">
              {jobs.map((job) => <ActivityRow key={job.id} job={job} />)}
            </ul>
          )}
        </Card>

        <Card title="Tags Awaiting Review" icon={faClipboardList} count={orphanCount}>
          <OrphanQueue />
        </Card>

        <Card title="Tag Sheet" icon={faTableList}>
          <TaginPanel />
        </Card>
      </div>
    </div>
  );
};

export default AdminDashboard;
