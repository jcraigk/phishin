import React, { useState, useEffect } from "react";
import TagBadges from "./TagBadges";
import { formatDurationTrack, formatDate } from "./utils";
import HighlightedText from "./HighlightedText";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faHeart } from "@fortawesome/free-solid-svg-icons";

const Tracks = ({ tracks, playTrack, activeTrack, show_dates }) => {
  const [trackLikes, setTrackLikes] = useState(tracks);

  useEffect(() => {
    setTrackLikes(tracks);
  }, [tracks]);

  const handleTrackClick = (track) => {
    playTrack(tracks, track);
  };

  return (
    <ul>
      {trackLikes.map((track) => (
        <li
          key={track.id}
          className={`list-item ${track.id === activeTrack?.id ? "active-track" : ""}`}
          onClick={() => handleTrackClick(track)}
          style={{
            backgroundImage: `url(${track.waveform_image_url})`,
          }}
        >
          <span className="leftside-primary">
            <HighlightedText
              text={`${show_dates ? formatDate(track.show_date) + " " : ""}${track.title}`}
            />
          </span>
          <span className="leftside-secondary">
            <TagBadges tags={track.tags} />
          </span>
          <span className="rightside-primary">{formatDurationTrack(track.duration)}</span>
          <span className="rightside-secondary">
            <FontAwesomeIcon
              icon={faHeart}
              className={track.liked_by_user ? "heart-icon liked" : "heart-icon"}
            />
            {track.likes_count}
          </span>
        </li>
      ))}
    </ul>
  );
};

export default Tracks;
