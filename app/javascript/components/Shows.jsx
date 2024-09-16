import React from "react";
import { Link, useOutletContext } from "react-router-dom";
import { formatDate, formatDurationShow, toggleLike } from "./utils";
import { useNotification } from "./NotificationContext";
import TagBadges from "./TagBadges";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faHeart } from "@fortawesome/free-solid-svg-icons";

const Shows = ({ shows, setShows, numbering = false, tourHeaders = false }) => {
  const { setAlert, setNotice } = useNotification();
  const { activeTrack } = useOutletContext();

  let lastTourName = null;

  const handleLikeToggle = async (show) => {
    const jwt = localStorage.getItem("jwt");
    if (!jwt) {
      setAlert("Please log in to like a show");
      return;
    }

    const result = await toggleLike({
      id: show.id,
      type: "Show",
      isLiked: show.liked_by_user,
      jwt,
    });

    if (result.success) {
      setNotice("Like saved");

      setShows((prevShows) => {
        const updatedShows = Array.isArray(prevShows) ? prevShows : [prevShows];

        return updatedShows.map((s) =>
          s.id === show.id
            ? {
                ...s,
                liked_by_user: result.isLiked,
                likes_count: result.isLiked ? s.likes_count + 1 : s.likes_count - 1,
              }
            : s
        );
      });
    }
  };

  return (
    <ul>
      {shows.map((show, index) => {
        const isNewTour = show.tour_name !== lastTourName;

        if (isNewTour) {
          lastTourName = show.tour_name;
        }

        const tourShowCount = shows.filter((s) => s.tour_name === show.tour_name).length;

        return (
          <>
            {isNewTour && tourHeaders && (
              <div className="section-title">
                <div className="title-left">{show.tour_name}</div>
                <span className="detail-right">{tourShowCount} shows</span>
              </div>
            )}
            <Link to={`/${show.date}`} className="list-item-link">
              <li className={`list-item ${show.date === activeTrack?.show_date ? "active-item" : ""}`}>
                {numbering && <span className="leftside-numbering">#{index + 1}</span>}
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
                      handleLikeToggle(show);
                    }}
                  />
                  <span className="likes-count">{show.likes_count}</span>
                </span>
              </li>
            </Link>
          </>
        );
      })}
    </ul>
  );
};

export default Shows;
