import React from "react";
import { useOutletContext, Link } from "react-router-dom";
import TagBadges from "./TagBadges";
import { formatDurationTrack, formatDurationShow, formatDate } from "./utils";
import HighlightedText from "./HighlightedText";
import LikeButton from "./LikeButton";
import TrackContextMenu from "./TrackContextMenu";

const Tracks = ({ tracks, numbering = false, showView = false, highlight, trackRefs, trackSlug }) => {
  const { playTrack, activeTrack } = useOutletContext();

  const handleTrackClick = (track) => {
    playTrack(tracks, track);
  };

  let lastSetName = null;

  return (
    <ul>
      {tracks.map((track, index) => {
        const isNewSet = showView && track.set_name !== lastSetName;
        lastSetName = track.set_name;

        return (
          <React.Fragment key={track.id}>
          {isNewSet && (
            <div className="section-title">
              <div className="title-left">{track.set_name}</div>
              <span className="detail-right">
                {formatDurationShow(
                  tracks
                    .filter(t => t.set_name === track.set_name)
                    .reduce((total, t) => total + t.duration, 0)
                )}
              </span>
            </div>
          )}
            <li
              className={
                `list-item track-item ${track.id === activeTrack?.id ? "active-item" : ""} ${track.slug === trackSlug ? "focus" : ""}`
              }
              onClick={() => handleTrackClick(track)}
              ref={trackRefs ? (el) => (trackRefs.current[index] = el) : null}
            >
              {numbering && (
                <span className="leftside-numbering">#{index + 1}</span>
              )}
              <span className="leftside-primary">
                {
                  !showView && (
                    <Link
                      className="date"
                      to={`/${track.show_date}/${track.slug}`}
                      onClick={(e) => e.stopPropagation()}
                    >
                      {formatDate(track.show_date)}
                    </Link>
                  )
                }
                <HighlightedText
                  text={track.title}
                  highlight={highlight}
                />
              </span>
              {
                !showView && (
                  <span className="leftside-secondary">
                    {track.venue_location}
                  </span>
                )
              }
              <span className="leftside-tertiary">
                <TagBadges tags={track.tags} />
              </span>
              <span className="rightside-primary">{formatDurationTrack(track.duration)}</span>
              <span className="rightside-secondary">
                <LikeButton likable={track} />
              </span>
              <span className="rightside-menu">
                <TrackContextMenu track={track} />
              </span>
            </li>
          </React.Fragment>
        );
      })}
    </ul>
  );
};

export default Tracks;