import React, { useEffect, useState } from "react";
import { Link } from "react-router";
import { adminGet } from "./adminApi";
import TaginPanel from "./TaginPanel";

const KIND_LABELS = {
  bulk_replace_audio: "bulk audio",
  recompute_gaps: "recompute gaps",
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

const ActivityRow = ({ job }) => (
  <li className="admin-activity-row">
    <span className={`admin-activity-status is-${job.status}`}>{job.status}</span>
    <span className="admin-activity-kind">
      {KIND_LABELS[job.kind] || job.kind.replace(/_/g, " ")}
    </span>
    <span className="admin-activity-show">
      {job.show_date ? (
        <Link to={`/admin/shows/${job.show_date}`}>{job.show_date}</Link>
      ) : (
        ""
      )}
    </span>
    <span className="admin-activity-message">{job.message || ""}</span>
    <span className="admin-activity-time">{relativeTime(job.created_at)}</span>
  </li>
);

const AdminDashboard = () => {
  const [drafts, setDrafts] = useState([]);
  const [jobs, setJobs] = useState([]);
  const [error, setError] = useState(null);

  useEffect(() => {
    adminGet("/shows?published=false")
      .then((data) => setDrafts(data.shows))
      .catch((e) => setError(e.message));
    adminGet("/jobs?limit=20")
      .then((data) => setJobs(data.jobs))
      .catch((e) => setError(e.message));
  }, []);

  return (
    <div className="admin-dashboard">
      <h1>Dashboard</h1>
      {error && <p className="admin-error">{error}</p>}
      <h2>Draft Shows</h2>
      {drafts.length === 0 ? (
        <p>No drafts. Start a new import.</p>
      ) : (
        <ul>
          {drafts.map((show) => (
            <li key={show.id}>
              <Link to={`/admin/shows/${show.date}`}>{show.date}</Link>
              {" "}{show.venue_name} ({show.tracks_count} tracks)
            </li>
          ))}
        </ul>
      )}
      <h2>Recent Activity</h2>
      {jobs.length === 0 ? (
        <p>No jobs have run yet.</p>
      ) : (
        <ul className="admin-activity">
          {jobs.map((job) => (
            <ActivityRow key={job.id} job={job} />
          ))}
        </ul>
      )}
      <h2>Tags</h2>
      <TaginPanel />
    </div>
  );
};

export default AdminDashboard;
