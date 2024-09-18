import React, { useState, useEffect } from "react";
import { useOutletContext, Link } from "react-router-dom";
import TagBadges from "./TagBadges";
import { formatDurationTrack, formatDurationShow, formatDate, toggleLike } from "./utils";
import HighlightedText from "./HighlightedText";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faHeart } from "@fortawesome/free-solid-svg-icons";
import { useFeedback } from "./FeedbackContext";

const Tracks = ({ tracks, setTracks, numbering = false, showView = false, highlight, trackRefs, trackSlug }) => {
  const [trackLikes, setTrackLikes] = useState(tracks);
  const { playTrack, activeTrack } = useOutletContext();
  const { setAlert, setNotice } = useFeedback();

  useEffect(() => {
    setTrackLikes(tracks);
  }, [tracks]);

  const handleTrackClick = (track) => {
    playTrack(tracks, track);
  };

  const handleLikeClick = async (track, e) => {
    e.stopPropagation();
    const jwt = localStorage.getItem("jwt");
    if (!jwt) {
      setAlert("Please login to like a track");
      return;
    }

    const result = await toggleLike({ id: track.id, type: "Track", isLiked: track.liked_by_user, jwt });

    if (result.success) {
      setNotice("Like saved");
      setTracks((prevTracks) =>
        prevTracks.map((t) =>
          t.id === track.id
            ? { ...t, liked_by_user: result.isLiked, likes_count: result.isLiked ? t.likes_count + 1 : t.likes_count - 1 }
            : t
        )
      );
    }
  };

  let lastSetName = null;

  return (
    <ul>
      {trackLikes.map((track, index) => {
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
                <FontAwesomeIcon
                  icon={faHeart}
                  className={`heart-icon ${track.liked_by_user ? "liked" : "heart-icon"}`}
                  onClick={(e) => handleLikeClick(track, e)}
                />
                <span className="likes-count">{track.likes_count}</span>
              </span>
            </li>
          </React.Fragment>
        );
      })}
    </ul>
  );
};

export default Tracks;
