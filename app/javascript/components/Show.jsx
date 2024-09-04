import React, { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { formatDate } from "./utils";
import ErrorPage from "./pages/ErrorPage";
import LayoutWrapper from "./LayoutWrapper";
import Tracks from "./Tracks";

const Show = () => {
  const { route_path } = useParams();
  const [show, setShow] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchShow = async () => {
      try {
        const response = await fetch(`/api/v2/shows/on_date/${route_path}`);
        if (response.status === 404) {
          setError(`No data was found for the date ${route_path}`);
          return;
        }
        const data = await response.json();
        setShow(data);
      } catch (error) {
        console.error("Error fetching show:", error);
        setError("An unexpected error has occurred.");
      }
    };

    fetchShow();
  }, [route_path]);

  if (error) {
    return <ErrorPage message={error} />;
  }

  if (!show) {
    return <div>Loading...</div>;
  }

  const sidebarContent = (
    <div className="sidebar-content">
      <p className="has-text-weight-bold mb-5">Show Details</p>
      <p>Date: {formatDate(show.date)}</p>
      <p>Venue: {show.venue.name}</p>
      <p>Location: {show.venue.location}</p>
    </div>
  );

  return (
    <LayoutWrapper sidebarContent={sidebarContent}>
      <Tracks tracks={show.tracks} set_headers={true} />
    </LayoutWrapper>
  );
};

export default Show;
