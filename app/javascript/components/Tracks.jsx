import React from "react";
import { useOutletContext, Link } from "react-router-dom";
import { formatDurationTrack, formatDurationShow, formatDate } from "./utils";
import TagBadges from "./TagBadges";
import HighlightedText from "./HighlightedText";
import LikeButton from "./LikeButton";
import TrackContextMenu from "./TrackContextMenu";

const Tracks = ({ tracks, viewStyle, numbering = false, omitSecondary = false, highlight, trackRefs, trackSlug }) => {
  const { playTrack, activeTrack, setCustomPlaylist  } = useOutletContext();

  const handleTrackClick = (track) => {
    playTrack(tracks, track);
    if (viewStyle === "playlist") {
      setCustomPlaylist(tracks);
    } else {
      setCustomPlaylist(null);
    }
  };

  if (tracks.length === 0) {
    return <h1 className="title">No tracks found</h1>;
  }

  let lastSetName = null;

  return (
    <ul>
      {tracks.map((track, index) => {
        const isNewSet = viewStyle === "show" && track.set_name !== lastSetName;
        lastSetName = track.set_name;

        const isExcerpt = track.starts_at_second !== undefined && track.ends_at_second !== undefined;
        const actualDuration = track.starts_at_second && track.ends_at_second
          ? track.ends_at_second - track.starts_at_second
          : track.duration;

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
                `list-item track-item ${track.id === activeTrack?.id ? "active-item" : ""} ${viewStyle === "show" && track.slug === trackSlug ? "focus" : ""}`
              }
              onClick={() => handleTrackClick(track)}
              ref={trackRefs ? (el) => (trackRefs.current[index] = el) : null}
            >
              <div className="main-row">
                {numbering && (
                  <span className="leftside-numbering">#{index + 1}</span>
                )}
                <span className="leftside-primary">
                  {
                    viewStyle !== "show" && (
                      <span className="show-badge">
                        <Link
                          className="date-link"
                          to={`/${track.show_date}/${track.slug}`}
                          onClick={(e) => e.stopPropagation()}
                        >
                          {formatDate(track.show_date)}
                        </Link>
                      </span>
                    )
                  }
                  <HighlightedText
                    text={track.title}
                    highlight={highlight}
                  />
                </span>
                {
                  viewStyle !== "show" && !omitSecondary && (
                    <span className="leftside-secondary">
                      {track.venue_location}
                    </span>
                  )
                }
                <span className="leftside-tertiary">
                  <TagBadges tags={track.tags} parentId={track.id} />
                </span>
                <div className="rightside-group">
                  <span className={`rightside-primary ${isExcerpt ? "excerpt" : ""}`}>
                    {formatDurationTrack(actualDuration)}
                  </span>
                  <span className="rightside-secondary">
                    <LikeButton likable={track} type="Track" />
                  </span>
                  <span className="rightside-menu">
                    <TrackContextMenu track={track} indexInPlaylist={index} />
                  </span>
                </div>
              </div>
            </li>
          </React.Fragment>
        );
      })}
    </ul>
  );
};

export default Tracks;
