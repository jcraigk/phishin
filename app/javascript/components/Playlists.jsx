import React from "react";
import { useOutletContext } from "react-router-dom";
import { formatNumber, formatDurationShow } from "./utils";
import LikeButton from "./LikeButton";
import HighlightedText from "./HighlightedText";

const Playlists = ({ playlists, highlight }) => {
  const { setCustomPlaylist } = useOutletContext();

  const handlePlaylistClick = (playlist) => {
    setCustomPlaylist(playlist);
  };

  return (
    <ul>
      {playlists.map((playlist) => (
        <li
          key={playlist.slug}
          className="list-item"
          onClick={() => handlePlaylistClick(playlist)}
        >
          <span className="leftside-primary">
            <HighlightedText
              text={playlist.name}
              highlight={highlight}
            />
          </span>
          <span className="leftside-secondary">{playlist.username}</span>
          <span className="leftside-tertary">
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
        </li>
      ))}
    </ul>
  );
};

export default Playlists;
