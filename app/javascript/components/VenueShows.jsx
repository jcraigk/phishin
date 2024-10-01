import { authFetch, formatNumber } from "./helpers/utils";

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
import { Link, useLoaderData, useNavigate, useOutletContext } from "react-router-dom";
import { Helmet } from "react-helmet-async";
import LayoutWrapper from "./layout/LayoutWrapper";
import Shows from "./Shows";
import MapView from "./MapView";

const VenueShows = () => {
  const { shows, venue, sortOption } = useLoaderData();
  const { mapboxToken } = useOutletContext();
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
      <p className="sidebar-subtitle">
        {formatNumber(venue.shows_count, 'show')} total
      </p>

      <div className="sidebar-filters">
        <div className="select">
          <select id="sort" value={sortOption} onChange={handleSortChange}>
            <option value="date:desc">Sort by Date (Newest First)</option>
            <option value="date:asc">Sort by Date (Oldest First)</option>
            <option value="likes_count:desc">Sort by Likes (High to Low)</option>
            <option value="likes_count:asc">Sort by Likes (Low to High)</option>
            <option value="duration:desc">Sort by Duration (Longest First)</option>
            <option value="duration:asc">Sort by Duration (Shortest First)</option>
          </select>
        </div>
      </div>

      <div className="sidebar-map mt-3 hidden-mobile">
        <MapView
          mapboxToken={mapboxToken}
          coordinates={{ lat: venue.latitude, lng: venue.longitude }}
          venues={[venue]}
          searchComplete={true}
          controls={false}
        />
      </div>
    </div>
  );

  return (
    <>
      <Helmet>
        <title>{venue.name} - Phish.in</title>
      </Helmet>
      <LayoutWrapper sidebarContent={sidebarContent}>
        <Shows shows={shows} />
      </LayoutWrapper>
    </>
  );
};

export default VenueShows;

