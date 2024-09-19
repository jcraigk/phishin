import React from "react";
import { Link } from "react-router-dom";
import { formatNumber } from "./utils";
import HighlightedText from "./HighlightedText";

const Venues = ({ venues, highlight }) => {
  return (
    <ul>
      {venues.map((venue) => (
        <Link to={`/venues/${venue.slug}`} key={venue.slug} className="list-item-link">
          <li className="list-item">
            <span className="leftside-primary">
              <HighlightedText text={venue.name} highlight={highlight} />
            </span>
            <span className="leftside-secondary">
              <HighlightedText text={venue.location} highlight={highlight} />
            </span>
            <span className="rightside-group">{formatNumber(venue.shows_count, "show")}</span>
          </li>
        </Link>
      ))}
    </ul>
  );
};

export default Venues;
