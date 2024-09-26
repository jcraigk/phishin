import React from "react";
import { Link } from "react-router-dom";
import { formatNumber } from "./utils";
import HighlightedText from "./HighlightedText";

const Songs = ({ songs, highlight }) => {
  return (
    <ul>
      {songs.map((song) => (
        <Link to={`/songs/${song.slug}`} key={song.slug} className="list-item-link">
          <li className="list-item">
            <div className="main-row">
              <span className="leftside-primary">
                <HighlightedText text={song.title} highlight={highlight} />
              </span>
              <span className="leftside-secondary">
                {song.original ? "Original" : "Cover"}
              </span>
              <span className="rightside-group">
                {formatNumber(song.tracks_count, 'track')}
              </span>
            </div>
          </li>
        </Link>
      ))}
    </ul>
  );
};

export default Songs;
