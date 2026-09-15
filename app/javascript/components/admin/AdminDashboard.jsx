import React, { useEffect, useState } from "react";
import { Link, useNavigate } from "react-router";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import {
  faList,
  faTrashCan,
  faCloudArrowUp,
  faXmark,
} from "@fortawesome/free-solid-svg-icons";
import { adminGet, adminPost, adminDelete } from "./adminApi";
import { formatDate } from "../helpers/utils";
import { plural } from "./format";
import { STOP_IMPORT_CONFIRM, deleteDraftMessage } from "./messages";
import ShowStatusPill from "./ShowStatusPill";

const KIND_LABELS = {
  bulk_audio_prepare: "Bulk audio prep",
  bulk_replace_audio: "Bulk audio",
  commit_staging: "Commit",
  cover_art_edit: "Art edit",
  cover_art_generate: "Art generate",
  cover_art_prompt: "Art prompt",
  cover_art_select: "Art select",
  ingest: "Ingest",
  pnet_tag_check: "PNet check",
  publish: "Publish",
  recompute_gaps: "Recompute gaps",
  replace_audio: "Replace audio",
  shift_boundary_apply: "Boundary shift",
  shift_boundary_preview: "Boundary preview",
  trim_apply: "Trim",
  trim_preview: "Trim preview",
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
  return `${plural(rounded, label)} ago`;
};

const kindLabel = (kind) => KIND_LABELS[kind] || kind.replace(/_/g, " ").replace(/^./, (c) => c.toUpperCase());

const Card = ({ title, count, action, children }) => (
  <section className="admin-card">
    <header className="admin-card-header">
      <h2>
        {title}
        {count != null && count > 0 && <span className="admin-count">{count}</span>}
      </h2>
      {action}
    </header>
    <div className="admin-card-body">{children}</div>
  </section>
);

const Empty = ({ children }) => <p className="admin-empty">{children}</p>;

const DraftRow = ({ show, onDelete }) => {
  const navigate = useNavigate();
  return (
    <li className="admin-draft-row" onClick={() => navigate(`/admin/shows/${show.date}`)}>
      <Link className="admin-draft-date" to={`/admin/shows/${show.date}`}>{formatDate(show.date)}</Link>
      <span className="admin-draft-venue">{show.ingest_job_id ? "" : show.venue_name || "Venue not set"}</span>
      {show.ingest_job_id ? (
        <span className="admin-pill is-running">importing</span>
      ) : (
        <ShowStatusPill show={show} />
      )}
      <span className="admin-draft-tracks">
        {show.ingest_job_id ? "" : plural(show.tracks_count, "track")}
      </span>
      <button
        type="button"
        className="admin-trash-button"
        title="Delete this draft show"
        aria-label={`Delete ${formatDate(show.date)}`}
        disabled={Boolean(show.ingest_job_id)}
        onClick={(e) => {
          e.stopPropagation();
          onDelete(show);
        }}
      >
        <FontAwesomeIcon icon={faTrashCan} />
      </button>
    </li>
  );
};

const ActivityRow = ({ job, onCancel }) => (
  <li className="admin-activity-row">
    <span className={`admin-pill is-${job.status}`}>{job.status}</span>
    <span className="admin-activity-kind">{kindLabel(job.kind)}</span>
    <span className="admin-activity-show">
      {job.show_date && <Link to={`/admin/shows/${job.show_date}`}>{formatDate(job.show_date)}</Link>}
    </span>
    <span className="admin-activity-message" title={job.message}>
      {job.cancel_requested && job.status !== "cancelled" ? "Stopping..." : job.message}
    </span>
    <span className="admin-activity-time">{relativeTime(job.created_at)}</span>
    {job.cancellable && (
      <button
        type="button"
        title="Stop this job and delete everything it has imported"
        onClick={() => onCancel(job)}
      >
        <FontAwesomeIcon icon={faXmark} /> Cancel
      </button>
    )}
  </li>
);

const AdminDashboard = () => {
  const navigate = useNavigate();
  const [drafts, setDrafts] = useState(null);
  const [jobs, setJobs] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    adminGet("/shows?published=false")
      .then((data) => setDrafts(data.shows))
      .catch((e) => setError(e.message));
    adminGet("/jobs?limit=20")
      .then((data) => setJobs(data.jobs))
      .catch((e) => setError(e.message));
  }, []);

  const refreshJobs = () => adminGet("/jobs?limit=20").then((data) => setJobs(data.jobs)).catch(() => {});
  const deleteDraft = async (show) => {
    if (!window.confirm(`Delete the ${formatDate(show.date)} draft? ${deleteDraftMessage(show.tracks_count)}`)) return;
    try {
      await adminDelete(`/shows/${show.date}`);
      setDrafts((prev) => prev.filter((s) => s.id !== show.id));
    } catch (e) {
      setError(e.message);
    }
  };
  const cancelJob = async (job) => {
    if (!window.confirm(STOP_IMPORT_CONFIRM)) return;
    try {
      await adminPost(`/jobs/${job.id}/cancel`);
      await refreshJobs();
    } catch (e) {
      setError(e.message);
    }
  };

  const active = (jobs || []).filter((j) => j.status === "running" || j.status === "queued");
  const finished = (jobs || []).filter((j) => j.status !== "running" && j.status !== "queued");

  useEffect(() => {
    if (active.length === 0) return undefined;
    const timer = setInterval(refreshJobs, 5000);
    return () => clearInterval(timer);
  }, [active.length]);

  return (
    <div className="admin-dashboard">
      {error && <p className="admin-error">{error}</p>}

      <div className="admin-grid">
        <Card
          title="Draft Shows"
          count={drafts?.length}
          action={
            <span className="admin-card-actions">
              <button type="button" title="Stage a new show from archive.org or uploaded files" onClick={() => navigate("/admin/import")}>
                <FontAwesomeIcon icon={faCloudArrowUp} /> Import show
              </button>
              <button type="button" title="Browse every show by date" onClick={() => navigate("/admin/shows")}>
                <FontAwesomeIcon icon={faList} /> All shows
              </button>
            </span>
          }
        >
          {drafts === null ? (
            <Empty>Loading</Empty>
          ) : drafts.length === 0 ? (
            <Empty>No drafts. Import a show to start one.</Empty>
          ) : (
            <ul className="admin-draft-list">
              {drafts.map((show) => <DraftRow key={show.id} show={show} onDelete={deleteDraft} />)}
            </ul>
          )}
        </Card>

        <div className="admin-grid-column">
        <Card title="Jobs in Progress" count={active.length}>
          {jobs === null ? (
            <Empty>Loading</Empty>
          ) : active.length === 0 ? (
            <Empty>Nothing running.</Empty>
          ) : (
            <ul className="admin-activity">
              {active.map((job) => <ActivityRow key={job.id} job={job} onCancel={cancelJob} />)}
            </ul>
          )}
        </Card>

        <Card title="Recent Activity" count={finished.length}>
          {jobs === null ? (
            <Empty>Loading</Empty>
          ) : finished.length === 0 ? (
            <Empty>No jobs have finished yet.</Empty>
          ) : (
            <ul className="admin-activity">
              {finished.map((job) => <ActivityRow key={job.id} job={job} />)}
            </ul>
          )}
        </Card>
        </div>
      </div>
    </div>
  );
};

export default AdminDashboard;
