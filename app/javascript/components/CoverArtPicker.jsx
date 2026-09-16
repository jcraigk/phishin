import React from "react";

const CoverArtPicker = ({ tracks, selectedTrackId, onSelect }) => {
  const options = tracks.filter(
    (track, idx) => tracks.findIndex((t) => t.show_date === track.show_date) === idx
  );
  const selectedTrack = tracks.find((track) => track.id === selectedTrackId) ?? tracks[0];

  if (options.length === 0) return null;

  return (
    <div className="cover-art-picker">
      {options.map((track) => (
        <img
          key={track.show_date}
          src={track.show_cover_art_urls?.medium}
          alt={`Cover art from ${track.show_date}`}
          title={track.show_date}
          className={track.show_date === selectedTrack?.show_date ? "selected" : ""}
          onClick={() => onSelect(track)}
        />
      ))}
    </div>
  );
};

export default CoverArtPicker;
