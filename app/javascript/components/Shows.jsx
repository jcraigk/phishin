import React, { useEffect, useState } from "react";
import { useParams, Link } from "react-router-dom";
import { formatDate, formatNumber, formatDurationShow } from "./utils";
import LayoutWrapper from "./LayoutWrapper";
import TagBadges from "./TagBadges";

const Shows = () => {
  const { route_path, venue_slug } = useParams();
  const [shows, setShows] = useState([]);
  const [venue, setVenue] = useState(null);
  const [sortOption, setSortOption] = useState("date:desc");

  useEffect(() => {
    const fetchShows = async () => {
      try {
        let url = `/api/v2/shows?per_page=1000&sort=${sortOption}`;

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
  }, [route_path, venue_slug, sortOption]);

  useEffect(() => {
    if (venue_slug) {
      const fetchVenue = async () => {
        try {
          const response = await fetch(`/api/v2/venues/${venue_slug}`);
          const data = await response.json();
          setVenue(data);
        } catch (error) {
          console.error("Error fetching venue:", error);
        }
      };

      fetchVenue();
    }
  }, [venue_slug]);

  const handleSortChange = (event) => {
    setSortOption(event.target.value);
  };

  let lastTourName = null;
  let tourShowCount = 0;

  const sidebarContent = (
    <div className="sidebar-content">
      {venue ? (
        <>
          <h1 className="title">{venue.name}</h1>
          <p className="sidebar-detail">{venue.location}</p>
          <p className="sidebar-detail">{formatNumber(venue.shows_count)} shows total</p>
        </>
      ) : (
        <>
          <h1 className="title">{route_path}</h1>
          <p className="sidebar-detail">{formatNumber(shows.length)} shows total</p>
        </>
      )}
      <div className="select is-fullwidth mt-4">
        <select value={sortOption} onChange={handleSortChange}>
          <option value="date:desc">Sort by Date (Newest First)</option>
          <option value="date:asc">Sort by Date (Oldest First)</option>
          <option value="likes_count:desc">Sort by Likes (Most to Least)</option>
          <option value="likes_count:asc">Sort by Likes (Least to Most)</option>
          <option value="duration:desc">Sort by Duration (Longest to Shortest)</option>
          <option value="duration:asc">Sort by Duration (Shortest to Longest)</option>
        </select>
      </div>
    </div>
  );

  return (
    <LayoutWrapper sidebarContent={sidebarContent}>
      <ul>
        {shows.map((show, index) => {
          const isNewTour = show.tour_name !== lastTourName;

          if (isNewTour) {
            tourShowCount = shows.filter((s) => s.tour_name === show.tour_name).length;
            lastTourName = show.tour_name;
          }

          return (
            <React.Fragment key={show.id}>
              {sortOption.startsWith("date") && !venue_slug && isNewTour && (
                <div className="section-title">
                  <div className="title-left">{show.tour_name}</div>
                  <span className="detail-right">{formatNumber(tourShowCount)} shows</span>
                </div>
              )}
              <Link to={`/${show.date}`} className="list-item-link">
                <li className="list-item">
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
    </LayoutWrapper>
  );
};

export default Shows;
