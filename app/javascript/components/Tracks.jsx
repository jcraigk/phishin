import React, { useState, useEffect } from "react";
import { useOutletContext } from "react-router-dom";
import TagBadges from "./TagBadges";
import { formatDurationTrack, formatDate, toggleLike } from "./utils";
import HighlightedText from "./HighlightedText";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faHeart } from "@fortawesome/free-solid-svg-icons";
import { useNotification } from "./NotificationContext";

const Tracks = ({ tracks, setTracks, showDates, numbering = false, setHeaders = false, highlight, trackRefs }) => {
  const [trackLikes, setTrackLikes] = useState(tracks);
  const { playTrack, activeTrack } = useOutletContext();
  const { setAlert, setNotice } = useNotification();

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
      setAlert("Please log in to like a track");
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
        const isNewSet = setHeaders && track.set_name !== lastSetName;
        lastSetName = track.set_name;

        const trackTitle = showDates ? `${formatDate(track.show_date)} ${track.title}` : track.title;

        return (
          <React.Fragment key={track.id}>
            {isNewSet && (
              <div className="section-title">
                <div className="title-left">{track.set_name}</div>
              </div>
            )}
            <li
              className={`list-item track-item ${track.id === activeTrack?.id ? "active-item" : ""}`}
              onClick={() => handleTrackClick(track)}
              ref={(el) => (trackRefs.current[index] = el)}
            >
              {numbering && (
                <span className="leftside-numbering">#{index + 1}</span>
              )}
              <span className="leftside-primary">
                <HighlightedText
                  text={trackTitle}
                  highlight={highlight}
                />
              </span>
              <span className="leftside-secondary">
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
