import React, { useEffect, useState } from "react";
import { useParams, Link } from "react-router-dom";
import { formatDate, formatNumber, formatDurationShow } from "./utils";

const YearRange = () => {
  const { route_path } = useParams();
  const [shows, setShows] = useState([]);

  useEffect(() => {
    const fetchShows = async () => {
      try {
        const response = await fetch(`/api/v2/shows?per_page=1000&sort=date:desc&${route_path.includes("-") ? `year_range=${route_path}` : `year=${route_path}`}`);
        const data = await response.json();
        setShows(data);
      } catch (error) {
        console.error("Error fetching shows:", error);
      }
    };

    fetchShows();
  }, [route_path]);

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
              {isNewTour && (
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

export default YearRange;
