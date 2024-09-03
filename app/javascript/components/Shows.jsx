import React, { useEffect, useState } from "react";
import { useParams, Link } from "react-router-dom";
import { formatDate, formatNumber, formatDurationShow } from "./utils";

const Shows = () => {
  const { route_path, venue_slug } = useParams(); // Capture both route_path and venue_slug
  const [shows, setShows] = useState([]);

  useEffect(() => {
    const fetchShows = async () => {
      try {
        let url = '/api/v2/shows?per_page=1000&sort=date:desc';

        if (venue_slug) {
          url += `&venue_slug=${venue_slug}`;
        } else if (route_path.includes("-")) {
          url += `&year_range=${route_path}`;
        } else {
          url += `&year=${route_path}`;
        }

        const response = await fetch(url);
        const data = await response.json();
        setShows(data);
      } catch (error) {
        console.error("Error fetching shows:", error);
      }
    };

    fetchShows();
  }, [route_path, venue_slug]);

  let lastTourName = null;
  let tourShowCount = 0;

  return (
    <div className="list-container">
      <ul>
        {shows.map((show, index) => {
          const isNewTour = show.tour_name !== lastTourName;

          if (isNewTour) {
            tourShowCount = shows.filter(s => s.tour_name === show.tour_name).length;
            lastTourName = show.tour_name;
          }

          return (
            <React.Fragment key={show.id}>
              {!venue_slug && isNewTour && (
                <div className="section-title">
                  <div className="title-left">{show.tour_name}</div>
                  <span className="detail-right">{formatNumber(tourShowCount)} shows</span>
                </div>
              )}
              <Link to={`/${show.date}`} className="list-item-link">
                <li className="list-item">
                  <span className="leftside-primary">{formatDate(show.date)}</span>
                  <span className="leftside-secondary">{show.venue.name}</span>
                  <span className="leftside-tertiary">{show.venue.location}</span>
                  <span className="rightside-primary">{formatDurationShow(show.duration)}</span>
                </li>
              </Link>
            </React.Fragment>
          );
        })}
      </ul>
    </div>
  );
};

export default Shows;
