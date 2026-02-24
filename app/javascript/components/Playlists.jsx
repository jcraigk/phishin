import React from "react";
import { useNavigate } from "react-router";
import { formatNumber, formatDurationShow, formatDate } from "./helpers/utils";
import LikeButton from "./controls/LikeButton";
import HighlightedText from "./controls/HighlightedText";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faClock, faCalendar, faInfoCircle, faCompactDisc } from "@fortawesome/free-solid-svg-icons";

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
              <span className="text">
                <HighlightedText
                  text={playlist.name}
                  highlight={highlight}
                />
              </span>
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
                <LikeButton likable={playlist} type="Playlist" />
              </span>
            </div>
          </div>

          <div className="addendum">
            <div className="description">
              <FontAwesomeIcon icon={faInfoCircle} className="mr-1 text-gray" />
              {playlist.description ? (
                <HighlightedText
                  text={playlist.description}
                  highlight={highlight}
                />
              ) : "(No description)"}
              </div>
            <div className="last-updated">
              <FontAwesomeIcon icon={faCalendar} className="mr-1 text-gray" />
              Updated: {formatDate(playlist.updated_at)}
            </div>

            <div className="display-phone-only">
              <p>
                <FontAwesomeIcon icon={faCompactDisc} className="mr-1 text-gray" />
                Tracks: {playlist.tracks_count}
              </p>
              <p className="mb-2">
                <FontAwesomeIcon icon={faClock} className="mr-1 text-gray" />
                Duration: {formatDurationShow(playlist.duration)}
              </p>
            </div>
          </div>
        </li>
      ))}
    </ul>
  );
};

export default Playlists;
