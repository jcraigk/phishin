import React from "react";
import { Link } from "react-router-dom";
import { formatDate, formatDurationShow } from "./utils";
import { useNotification } from "./NotificationContext"; // Updated path
import TagBadges from "./TagBadges";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faHeart } from "@fortawesome/free-solid-svg-icons";

const Shows = ({ shows, numbering = false, tour_headers = false }) => {
  const { setAlert } = useNotification();

  let lastTourName = null;

  const toggleLike = async (show) => {
    const jwt = localStorage.getItem("jwt");
    if (!jwt) {
      setAlert("Please log in to like a show.");
      return;
    }

    const isLiked = show.liked_by_user;
    const url = `/api/v2/likes`;
    const method = isLiked ? "DELETE" : "POST";
    const body = JSON.stringify({
      likable_type: "Show",
      likable_id: show.id,
    });

    try {
      const response = await fetch(url, {
        method,
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": jwt,
        },
        body: method === "POST" ? body : null, // Only include body for POST
      });

      if (response.ok) {
        // Update local like state and count
        console.log("Toggled like for show:", show.id);

        show.liked_by_user = !isLiked;
        show.likes_count = isLiked ? show.likes_count - 1 : show.likes_count + 1;
      } else {
        console.error("Failed to toggle like");
      }
    } catch (error) {
      console.error("Error toggling like:", error);
    }
  };

  return (
    <ul>
      {shows.map((show, index) => {
        const isNewTour = show.tour_name !== lastTourName;

        if (isNewTour) {
          lastTourName = show.tour_name;
        }

        // Get total number of shows in the current tour
        const tourShowCount = shows.filter(s => s.tour_name === show.tour_name).length;

        return (
          <React.Fragment key={show.id}>
            {isNewTour && tour_headers && (
              <div className="section-title">
                <div className="title-left">{show.tour_name}</div>
                <span className="detail-right">{tourShowCount} shows</span>
              </div>
            )}
            <Link to={`/${show.date}`} className="list-item-link">
              <li className="list-item">
                {numbering && (
                  <span className="leftside-numbering">#{index + 1}</span>
                )}
                <span className="leftside-primary width-8">{formatDate(show.date)}</span>
                <span className="leftside-secondary">{show.venue.name}</span>
                <span className="leftside-tertiary">
                  <TagBadges tags={show.tags} />
                </span>
                <span className="rightside-primary">{formatDurationShow(show.duration)}</span>
                <span className="rightside-secondary">
                  <FontAwesomeIcon
                    icon={faHeart}
                    className={`heart-icon ${show.liked_by_user ? "liked" : ""}`}
                    onClick={(e) => {
                      e.preventDefault();
                      toggleLike(show);
                    }}
                  />{" "}
                  {show.likes_count}
                </span>
              </li>
            </Link>
          </React.Fragment>
        );
      })}
    </ul>
  );
};

export default Shows;
