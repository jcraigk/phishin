import React, { useEffect, useState } from "react";
import { useNavigate, useSearchParams, Link } from "react-router";
import { adminGet } from "./adminApi";
import { formatDate, formatDurationShow } from "../helpers/utils";
import { plural } from "./format";
import ShowStatusPill from "./ShowStatusPill";

const FIRST_YEAR = 1983;

const YEARS = [];
for (let y = new Date().getFullYear(); y >= FIRST_YEAR; y -= 1) YEARS.push(y);

const AdminShows = () => {
  const navigate = useNavigate();
  const [params, setParams] = useSearchParams();
  const [year, setYear] = useState(String(params.get("year") || YEARS[0]));
  const [shows, setShows] = useState(null);
  const [date, setDate] = useState("");
  const [dateNote, setDateNote] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    let cancelled = false;
    setShows(null);
    adminGet(`/shows?year=${year}`)
      .then((data) => {
        if (!cancelled) setShows(data.shows);
      })
      .catch((e) => {
        if (!cancelled) setError(e.message);
      });
    return () => {
      cancelled = true;
    };
  }, [year]);

  useEffect(() => {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
      setDateNote(null);
      return undefined;
    }
    let cancelled = false;
    adminGet(`/shows/${date}`)
      .then(() => {
        if (!cancelled) navigate(`/admin/shows/${date}`);
      })
      .catch((e) => {
        if (cancelled) return;
        if (e.status === 404) setDateNote("no-show");
        else setError(e.message);
      });
    return () => {
      cancelled = true;
    };
  }, [date, navigate]);

  const chooseYear = (value) => {
    setYear(value);
    setParams((prev) => {
      const next = new URLSearchParams(prev);
      next.set("year", value);
      return next;
    });
  };

  return (
    <div className="admin-import">
      {error && <p className="admin-error">{error}</p>}

      <section className="admin-card">
        <header className="admin-card-header">
          <h2>All Shows</h2>
          <div className="admin-shows-filters">
            <input
              type="date"
              value={date}
              onChange={(e) => setDate(e.target.value)}
              aria-label="Jump to date"
            />
            {dateNote === "no-show" && (
              <span className="admin-pick-note">
                No show on {formatDate(date)}. <Link to="/admin/import">Import it</Link>
              </span>
            )}
            <select value={year} onChange={(e) => chooseYear(e.target.value)}>
              {YEARS.map((y) => <option key={y} value={y}>{y}</option>)}
            </select>
          </div>
        </header>
        <div className="admin-card-body">
          {shows === null ? (
            <p className="admin-empty">Loading</p>
          ) : shows.length === 0 ? (
            <p className="admin-empty">No shows in {year}.</p>
          ) : (
            <ul className="admin-draft-list">
              {shows.map((show) => (
                <li
                  key={show.id}
                  className="admin-show-row"
                  onClick={() => navigate(`/admin/shows/${show.date}`)}
                >
                  <img className="admin-show-art" src={show.cover_art_url} alt="" loading="lazy" />
                  <Link className="admin-draft-date" to={`/admin/shows/${show.date}`}>{formatDate(show.date)}</Link>
                  <span className="admin-draft-venue">{show.venue_name || "Venue not set"}</span>
                  <span className="tag-badges-container">
                    {show.tags.map((tag) => <span key={tag} className="tag-badge">{tag}</span>)}
                  </span>
                  <span className="admin-show-status">
                    {!show.published && <span className="admin-pill">draft</span>}
                    <ShowStatusPill show={show} />
                  </span>
                  <span className="admin-show-meta">
                    {plural(show.tracks_count, "track")}
                  </span>
                  <span className="admin-show-meta">
                    {show.duration > 0 ? formatDurationShow(show.duration) : ""}
                  </span>
                </li>
              ))}
            </ul>
          )}
        </div>
      </section>
    </div>
  );
};

export default AdminShows;
