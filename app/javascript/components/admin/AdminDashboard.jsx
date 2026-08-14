import React, { useEffect, useState } from "react";
import { Link } from "react-router";
import { adminGet } from "./adminApi";

const AdminDashboard = () => {
  const [drafts, setDrafts] = useState([]);
  const [error, setError] = useState(null);

  useEffect(() => {
    adminGet("/shows?published=false")
      .then((data) => setDrafts(data.shows))
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
    </div>
  );
};

export default AdminDashboard;
