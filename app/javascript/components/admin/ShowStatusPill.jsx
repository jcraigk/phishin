import React from "react";

const ShowStatusPill = ({ show }) =>
  show.staged && show.tracks_count === 0 ? (
    <span className="admin-pill is-staged">staged</span>
  ) : (
    <span className={`admin-pill is-${show.audio_status}`}>{show.audio_status}</span>
  );

export default ShowStatusPill;
