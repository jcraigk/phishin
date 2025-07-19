import React from "react";
import { Link } from "react-router-dom";
import { formatNumber } from "./helpers/utils";
import HighlightedText from "./controls/HighlightedText";
import { useAudioFilter } from "./contexts/AudioFilterContext";

const Songs = ({ songs, highlight }) => {
  const { hideMissingAudio } = useAudioFilter();

  return (
    <ul>
      {songs.map((song) => (
        <Link to={`/songs/${song.slug}`} key={song.slug} className="list-item-link">
          <li className="list-item">
            <div className="main-row">
              <span className="leftside-primary">
                <span className="text">
                  <HighlightedText text={song.title} highlight={highlight} />
                </span>
              </span>
              <span className="leftside-secondary">
                {song.original ? "Original" : "Cover"}
              </span>
              <span className="rightside-group">
                {formatNumber(hideMissingAudio ? song.tracks_with_audio_count : song.tracks_count, 'track')}
              </span>
            </div>
          </li>
        </Link>
      ))}
    </ul>
  );
};

export default Songs;
