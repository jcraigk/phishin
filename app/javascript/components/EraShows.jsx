import React, { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import LayoutWrapper from "./LayoutWrapper";
import Shows from "./Shows";

const EraShows = () => {
  const { route_path } = useParams();
  const [shows, setShows] = useState([]);

  useEffect(() => {
    const fetchShows = async () => {
      try {
        let url = `/api/v2/shows?per_page=1000`;

        if (route_path.includes("-")) {
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
  }, [route_path]);

  const sidebarContent = (
    <div className="sidebar-content">
      <h1 className="title">{route_path}</h1>
      <p className="sidebar-subtitle">{shows.length} shows total</p>
    </div>
  );

  return (
    <LayoutWrapper sidebarContent={sidebarContent}>
      <Shows shows={shows} tour_headers={true} />
    </LayoutWrapper>
  );
};

export default EraShows;
