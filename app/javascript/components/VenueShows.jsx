import React, { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import LayoutWrapper from "./LayoutWrapper";
import Shows from "./Shows";

const VenueShows = () => {
  const { venue_slug } = useParams();
  const [shows, setShows] = useState([]);
  const [venue, setVenue] = useState(null);

  useEffect(() => {
    const fetchShows = async () => {
      try {
        const response = await fetch(`/api/v2/shows?venue_slug=${venue_slug}&per_page=1000`);
        const data = await response.json();
        setShows(data.shows);
      } catch (error) {
        console.error("Error fetching shows:", error);
      }
    };

    const fetchVenue = async () => {
      try {
        const response = await fetch(`/api/v2/venues/${venue_slug}`);
        const data = await response.json();
        setVenue(data);
      } catch (error) {
        console.error("Error fetching venue:", error);
      }
    };

    fetchShows();
    fetchVenue();
  }, [venue_slug]);

  const sidebarContent = venue ? (
    <div className="sidebar-content">
      <h1 className="title">{venue.name}</h1>
      <p className="sidebar-subtitle">{venue.location}</p>
      <p className="sidebar-subtitle">{venue.shows_count} shows total</p>
    </div>
  ) : null;

  return (
    <LayoutWrapper sidebarContent={sidebarContent}>
      <Shows shows={shows} setShows={setShows} />
    </LayoutWrapper>
  );
};

export default VenueShows;
