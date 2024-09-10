import React, { useState, useEffect } from "react";
import TagBadges from "./TagBadges";
import { useNotification } from "./NotificationContext";
import { formatDurationTrack, formatDate } from "./utils";
import HighlightedText from "./HighlightedText";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faHeart } from "@fortawesome/free-solid-svg-icons";

const Tracks = ({ tracks, set_headers = false, numbering = false, show_dates = false, user, highlight }) => {
  const [trackLikes, setTrackLikes] = useState(tracks);

  const { setAlert, setNotice } = useNotification();

  useEffect(() => {
    setTrackLikes(tracks);
  }, [tracks]);

  const toggleLike = async (track) => {
    const jwt = localStorage.getItem("jwt");
    if (!jwt) {
      setAlert("You must be logged in to submit Likes");
      return;
    }

    const isLiked = track.liked_by_user;
    const updatedTracks = trackLikes.map((t) => {
      if (t.id === track.id) {
        return {
          ...t,
          likes_count: isLiked ? t.likes_count - 1 : t.likes_count + 1,
          liked_by_user: !isLiked,
        };
      }
      return t;
    });

    setTrackLikes(updatedTracks);

    const url = `/api/v2/likes`;
    const method = isLiked ? "DELETE" : "POST";
    const requestBody = {
      likable_type: "Track",
      likable_id: track.id,
    };

    try {
      const response = await fetch(url, {
        method,
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": jwt,
        },
        body: JSON.stringify(requestBody),
      });

      if (response.ok) {
        setNotice("Like saved");
      } else {
        console.error("Error toggling like");
      }
    } catch (error) {
      console.error("Error:", error);
    }
  };

  let lastSetName = null;

  return (
    <ul>
      {trackLikes.map((track, index) => {
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
              <span className="leftside-primary">
                <HighlightedText text={trackTitle} highlight={highlight} />
              </span>
              <span className="leftside-secondary">
                <TagBadges tags={track.tags} />
              </span>
              <span className="rightside-primary">{formatDurationTrack(track.duration)}</span>
              <span className="rightside-secondary">
                <FontAwesomeIcon
                  icon={faHeart}
                  className={track.liked_by_user ? "heart-icon liked" : "heart-icon"}
                  onClick={() => toggleLike(track)}
                />{" "}
                {track.likes_count}
              </span>
            </li>
          </React.Fragment>
        );
      })}
    </ul>
  );
};

export default Tracks;
