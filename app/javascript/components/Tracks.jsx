import React from "react";
import TagBadges from "./TagBadges";
import { formatDurationTrack } from "./utils";

const Tracks = ({ tracks, set_headers = false }) => {
  let lastSetName = null;

  return (
    <ul>
      {tracks.map((track) => {
        const isNewSet = set_headers && track.set_name !== lastSetName;
        lastSetName = track.set_name;

        return (
          <React.Fragment key={track.id}>
            {isNewSet && (
              <div className="section-title">
                <div className="title-left">{track.set_name}</div>
              </div>
            )}
            <li className="list-item">
              <span className="leftside-primary">{track.title}</span>
              <span className="leftside-secondary">
                <TagBadges tags={track.tags} />
              </span>
              <span className="rightside-primary">{formatDurationTrack(track.duration)}</span>
            </li>
          </React.Fragment>
        );
      })}
    </ul>
  );
};

export default Tracks;
