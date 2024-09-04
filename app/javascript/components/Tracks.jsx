import React from "react";
import TagBadges from "./TagBadges";
import { formatDurationTrack, formatDate } from "./utils";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faHeart } from "@fortawesome/free-solid-svg-icons";

const Tracks = ({ tracks, set_headers = false, numbering = false, show_dates = false }) => {
  let lastSetName = null;

  return (
    <ul>
      {tracks.map((track, index) => {
        const isNewSet = set_headers && track.set_name !== lastSetName;
        lastSetName = track.set_name;

        const trackTitle = show_dates ? `${formatDate(track.show.date)} ${track.title}` : track.title;

        return (
          <React.Fragment key={track.id}>
            {isNewSet && (
              <div className="section-title">
                <div className="title-left">{track.set_name}</div>
              </div>
            )}
            <li className="list-item">
              {numbering && (
                <span className="leftside-numbering">#{index + 1}</span>
              )}
              <span className="leftside-primary">{trackTitle}</span>
              <span className="leftside-secondary">
                <TagBadges tags={track.tags} />
              </span>
              <span className="rightside-primary">{formatDurationTrack(track.duration)}</span>
              <span className="rightside-secondary">
                <FontAwesomeIcon icon={faHeart} /> {track.likes_count}
              </span>
            </li>
          </React.Fragment>
        );
      })}
    </ul>
  );
};

export default Tracks;
