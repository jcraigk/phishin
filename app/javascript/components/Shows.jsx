import React from "react";
import { Link } from "react-router-dom";
import { formatDate, formatDurationShow } from "./utils";
import TagBadges from "./TagBadges";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faHeart } from "@fortawesome/free-solid-svg-icons";

const Shows = ({ shows, numbering = false, tour_headers = false }) => {
  let lastTourName = null;

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
                  <FontAwesomeIcon icon={faHeart} /> {show.likes_count}
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
