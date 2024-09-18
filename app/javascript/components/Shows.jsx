import React from "react";
import { Link, useOutletContext } from "react-router-dom";
import { formatDate, formatDurationShow } from "./utils";
import TagBadges from "./TagBadges";
import LikeButton from "./LikeButton";

const Shows = ({ shows, numbering = false, tourHeaders = false }) => {
  const { activeTrack } = useOutletContext();

  let lastTourName = null;

  return (
    <ul>
      {shows.map((show, index) => {
        const isNewTour = show.tour_name !== lastTourName;

        if (isNewTour) {
          lastTourName = show.tour_name;
        }

        const tourShowCount = shows.filter((s) => s.tour_name === show.tour_name).length;

        return (
          <React.Fragment key={show.date}>
            {isNewTour && tourHeaders && (
              <div className="section-title">
                <div className="title-left">{show.tour_name}</div>
                <span className="detail-right">{tourShowCount} shows</span>
              </div>
            )}
            <Link to={`/${show.date}`} className="list-item-link">
              <li
                className={`list-item ${show.date === activeTrack?.show_date ? "active-item" : ""}`}
              >
                {numbering && <span className="leftside-numbering">#{index + 1}</span>}
                <span className="leftside-primary width-8">{formatDate(show.date)}</span>
                <span className="leftside-secondary">{show.venue.name}</span>
                <span className="leftside-tertiary">
                  <TagBadges tags={show.tags} />
                </span>
                <span className="rightside-primary">{formatDurationShow(show.duration)}</span>
                <span className="rightside-secondary">
                  <LikeButton likable={show} />
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
