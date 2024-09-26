import React from "react";
import { useNavigate } from "react-router-dom";
import { formatNumber, formatDurationShow, formatDateLong } from "./utils";
import LikeButton from "./LikeButton";
import HighlightedText from "./HighlightedText";

const Playlists = ({ playlists, highlight }) => {
  const navigate = useNavigate();

  const handlePlaylistClick = (playlist) => {
    navigate(`/play/${playlist.slug}`);
  };

  if (playlists.length === 0) {
    return <h1 className="title">No playlists found</h1>;
  }

  return (
    <ul>
      {playlists.map((playlist) => (
        <li
          key={playlist.slug}
          className="list-item"
          onClick={() => handlePlaylistClick(playlist)}
        >
          <div className="main-row">
            <span className="leftside-primary">
              <HighlightedText
                text={playlist.name}
                highlight={highlight}
              />
            </span>
            <span className="leftside-secondary">{playlist.username}</span>
            <span className="leftside-tertiary">
              {formatNumber(playlist.tracks_count, "track")}
            </span>

            <div className="rightside-group">
              <span className="rightside-primary">
                {formatDurationShow(playlist.duration)}
              </span>
              <span className="rightside-secondary">
                <LikeButton likable={playlist} />
              </span>
            </div>
          </div>

          <div className="addendum">
            <div className="description">
            {playlist.description ? (
              <HighlightedText
                text={playlist.description}
                highlight={highlight}
              />
            ) : "(No description)"}
            </div>
            <div className="last-updated">
              Last Updated: {formatDateLong(new Date(playlist.updated_at))}
            </div>
          </div>
        </li>
      ))}
    </ul>
  );
};

export default Playlists;
