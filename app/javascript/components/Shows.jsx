import React from "react";
import { Link } from "react-router-dom";
import { formatDate, formatDurationShow } from "./utils";
import TagBadges from "./TagBadges";

const Shows = ({ shows, numbering = false }) => {
  let lastTourName = null;

  return (
    <ul>
      {shows.map((show, index) => {
        const isNewTour = show.tour_name !== lastTourName;

        if (isNewTour) {
          lastTourName = show.tour_name;
        }

        return (
          <React.Fragment key={show.id}>
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
              </li>
            </Link>
          </React.Fragment>
        );
      })}
    </ul>
  );
};

export default Shows;
