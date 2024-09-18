import { authFetch } from "./utils";

export const venueShowsLoader = async ({ params, request }) => {
  const { venueSlug } = params;
  const url = new URL(request.url);
  const sortOption = url.searchParams.get("sort") || "date:desc";

  try {
    const venueResponse = await fetch(`/api/v2/venues/${venueSlug}`);
    if (venueResponse.status === 404) {
      throw new Response("Venue not found", { status: 404 });
    }
    if (!venueResponse.ok) throw venueResponse;
    const venueData = await venueResponse.json();

    const showsResponse = await authFetch(`/api/v2/shows?venue_slug=${venueSlug}&sort=${sortOption}&per_page=1000`);
    if (!showsResponse.ok) showsResponse;
    const showsData = await showsResponse.json();

    return { shows: showsData.shows, venue: venueData, sortOption };
  } catch (error) {
    if (error instanceof Response) throw error;
    throw new Response("Error fetching data", { status: 500 });
  }
};

import React from "react";
import { useLoaderData, useNavigate } from "react-router-dom";
import LayoutWrapper from "./LayoutWrapper";
import Shows from "./Shows";
import { Helmet } from 'react-helmet-async';
import { Link } from "react-router-dom";

const VenueShows = () => {
  const { shows, venue, sortOption } = useLoaderData();
  const navigate = useNavigate();

  const handleSortChange = (event) => {
    navigate(`?sort=${event.target.value}`);
  };

  const sidebarContent = (
    <div className="sidebar-content">
      <p className="sidebar-title">{venue.name}</p>
      <p className="sidebar-subtitle">
        <Link to={`/map?term=${venue.location}`}>
            {venue.location}
        </Link>
      </p>
      <p className="sidebar-subtitle sidebar-extras">{venue.shows_count} shows total</p>

      <div className="sidebar-filters">
        <div className="select">
          <select value={sortOption} onChange={handleSortChange}>
            <option value="date:desc">Sort by Date (Newest First)</option>
            <option value="date:asc">Sort by Date (Oldest First)</option>
            <option value="likes_count:desc">Sort by Likes (Most to Least)</option>
            <option value="likes_count:asc">Sort by Likes (Least to Most)</option>
            <option value="duration:desc">Sort by Duration (Longest First)</option>
            <option value="duration:asc">Sort by Duration (Shortest First)</option>
          </select>
        </div>
      </div>
    </div>
  );

  return (
    <>
      <Helmet>
        <title>{venue.name} - Phish.in</title>
      </Helmet>
      <LayoutWrapper sidebarContent={sidebarContent}>
        <Shows shows={shows} setShows={() => {}} />
      </LayoutWrapper>
    </>
  );
};

export default VenueShows;
