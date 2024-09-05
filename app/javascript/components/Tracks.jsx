import React, { useState } from "react";
import TagBadges from "./TagBadges";
import { formatDurationTrack, formatDate } from "./utils";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faHeart } from "@fortawesome/free-solid-svg-icons";

const Tracks = ({ tracks, set_headers = false, numbering = false, show_dates = false, user }) => {
  const [trackLikes, setTrackLikes] = useState(tracks);

  const toggleLike = async (track) => {
    const jwt = localStorage.getItem("jwt");
    if (!jwt) {
      alert("You need to be logged in to like a track.");
      return;
    }

    const isLiked = track.liked_by_user;
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
          "X-Auth-Token": jwt, // Pass the jwt for authentication
        },
        body: JSON.stringify(requestBody),
      });

      if (response.ok) {
        // Update the track's likes_count and liked_by_user status locally
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
              <span className="leftside-primary">{trackTitle}</span>
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
